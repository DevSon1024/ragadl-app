import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'celebrity_utils.dart';
import '../ragalahari_downloader.dart';

class GalleryLinksPage extends StatefulWidget {
  final String celebrityName;
  final String profileUrl;
  final DownloadSelectedCallback? onDownloadSelected;

  const GalleryLinksPage({
    super.key,
    required this.celebrityName,
    required this.profileUrl,
    this.onDownloadSelected,
  });

  @override
  _GalleryLinksPageState createState() => _GalleryLinksPageState();
}

class _GalleryLinksPageState extends State<GalleryLinksPage> {
  List<GalleryItem> _galleryItems = [];
  List<GalleryItem> _displayedItems = [];
  List<GalleryItem> _filteredItems = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  final int _itemsPerPage = 30;
  bool _sortNewestFirst = true;
  final int _batchSize = 10;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCachedGalleryLinks();
    _searchController.addListener(_filterGalleries);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCachedGalleryLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'gallery_cache_${widget.profileUrl.hashCode}';
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final List<dynamic> jsonData = jsonDecode(cachedData);
      setState(() {
        _galleryItems = jsonData
            .map((item) => GalleryItem(
          url: item['url'],
          title: item['title'],
          thumbnailUrl: item['thumbnailUrl'],
          pages: item['pages'],
          date: DateTime.parse(item['date']),
        ))
            .toList();
        _filteredItems = List.from(_galleryItems);
        _updateDisplayedItems();
        _isLoading = false;
      });
    }
    _scrapeGalleryLinks();
  }

  Future<void> _cacheGalleryLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'gallery_cache_${widget.profileUrl.hashCode}';
    final jsonData = _galleryItems
        .map((item) => {
      'url': item.url,
      'title': item.title,
      'thumbnailUrl': item.thumbnailUrl,
      'pages': item.pages,
      'date': item.date.toIso8601String(),
    })
        .toList();
    await prefs.setString(cacheKey, jsonEncode(jsonData));
  }

  Future<void> _toggleGalleryFavorite(GalleryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteKey = 'favorites';
    List<String> favoritesJson = prefs.getStringList(favoriteKey) ?? [];
    List<FavoriteItem> favorites = favoritesJson
        .map((json) => FavoriteItem.fromJson(
      Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>),
    ))
        .toList();

    final favoriteItem = FavoriteItem(
      type: 'gallery',
      name: item.title,
      url: item.url,
      thumbnailUrl: item.thumbnailUrl,
      celebrityName: widget.celebrityName,
    );

    final isFavorite = favorites.any(
          (fav) =>
      fav.type == 'gallery' &&
          fav.url == item.url &&
          fav.celebrityName == widget.celebrityName,
    );

    if (isFavorite) {
      favorites.removeWhere(
            (fav) =>
        fav.type == 'gallery' &&
            fav.url == item.url &&
            fav.celebrityName == widget.celebrityName,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title} removed from favorites')),
      );
    } else {
      favorites.add(favoriteItem);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title} added to favorites')),
      );
    }

    await prefs.setStringList(
      favoriteKey,
      favorites.map((item) => jsonEncode(item.toJson())).toList(),
    );
    setState(() {});
  }

  void _navigateToDownloader(String galleryUrl, String galleryTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RagalahariDownloader(
          initialUrl: galleryUrl,
          initialFolder: widget.celebrityName,
        ),
      ),
    ).then((_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Returned from downloader')));
    });
  }

  Future<void> _scrapeGalleryLinks() async {
    try {
      final response = await http
          .get(Uri.parse(widget.profileUrl), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final links = _extractGalleryLinks(document);
        final items = await _processGalleryLinks(links);

        setState(() {
          _galleryItems = items;
          _filteredItems = List.from(_galleryItems);
          _updateDisplayedItems();
          _isLoading = false;
        });
        await _cacheGalleryLinks();
      } else {
        throw 'Failed to load page: ${response.statusCode}';
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to scrape gallery links: $e';
        _isLoading = false;
      });
    }
  }

  List<String> _extractGalleryLinks(dom.Document document) {
    final galleriesPanel = document.getElementById('galleries_panel');
    if (galleriesPanel == null) return [];

    return galleriesPanel
        .getElementsByClassName('galimg')
        .map((element) => element.attributes['href'] ?? '')
        .where((href) => href.isNotEmpty)
        .map((href) => Uri.parse(widget.profileUrl).resolve(href).toString())
        .toList();
  }

  Future<List<GalleryItem>> _processGalleryLinks(List<String> links) async {
    final items = <GalleryItem>[];
    final batches = <List<String>>[];

    for (var i = 0; i < links.length; i += _batchSize) {
      batches.add(
        links.sublist(
          i,
          i + _batchSize > links.length ? links.length : i + _batchSize,
        ),
      );
    }

    for (final batch in batches) {
      final futures = batch.map((link) => _processSingleLink(link)).toList();
      final results = await Future.wait(futures);
      items.addAll(results.whereType<GalleryItem>());
    }

    items.sort(
          (a, b) => _sortNewestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
    );
    return items;
  }

  Future<GalleryItem?> _processSingleLink(String link) async {
    try {
      final response = await http
          .get(Uri.parse(link), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final document = html_parser.parse(response.body);

      String title = '';
      final titleElement = document.querySelector('h1.gallerytitle') ??
          document.querySelector('.gallerytitle') ??
          document.querySelector('h1');

      if (titleElement != null && titleElement.text.trim().isNotEmpty) {
        title = titleElement.text.trim();
      } else {
        final uri = Uri.parse(link);
        final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        title = link.split('/').last.replaceAll(".aspx", "");
        if (pathSegments.length > 2) {
          title =
          '${pathSegments[pathSegments.length - 2]}-${pathSegments.last.replaceAll(".aspx", "")}';
        }
      }

      String? thumbnailUrl;
      final images = document.getElementsByTagName('img');
      for (final img in images) {
        final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
        if (thumbnailDomains.any((domain) => src.contains(domain))) {
          thumbnailUrl = src;
          break;
        }
      }

      final (pages, date) = await _getGalleryInfo(link);

      return GalleryItem(
        url: link,
        title: title,
        thumbnailUrl: thumbnailUrl,
        pages: pages,
        date: date,
      );
    } catch (e) {
      debugPrint('Error processing $link: $e');
      return null;
    }
  }

  Future<(int, DateTime)> _getGalleryInfo(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return (1, DateTime(1900));

      final document = html_parser.parse(response.body);

      final pageLinks = document.getElementsByClassName('otherPage');
      final lastPage = pageLinks.isEmpty
          ? 1
          : pageLinks.map((e) => int.tryParse(e.text.trim()) ?? 1).reduce(max);

      final dateElement = document.querySelector('.gallerydate time');
      final dateStr = dateElement?.text.trim() ?? '';
      final date = dateStr.startsWith('Updated on ')
          ? DateFormat('MMMM dd, yyyy').parse(dateStr.substring(11))
          : DateTime.now();

      return (lastPage, date);
    } catch (e) {
      return (1, DateTime(1900));
    }
  }

  void _filterGalleries() {
    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_galleryItems);
      } else {
        _filteredItems = _galleryItems
            .where((item) {
          final galleryId = item.url
              .split('/')
              .where((segment) => RegExp(r'^\d+$').hasMatch(segment))
              .firstOrNull;
          return galleryId != null && galleryId.startsWith(query);
        })
            .toList();
      }
      _currentPage = 1;
      _updateDisplayedItems();
    });
  }

  void _updateDisplayedItems() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    setState(() {
      _displayedItems = _filteredItems.sublist(
        startIndex,
        endIndex > _filteredItems.length ? _filteredItems.length : endIndex,
      );
    });
  }

  void _changePage(int page) {
    setState(() {
      _currentPage = page;
      _updateDisplayedItems();
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _sortNewestFirst = !_sortNewestFirst;
      _filteredItems.sort(
            (a, b) => _sortNewestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
      );
      _currentPage = 1;
      _updateDisplayedItems();
    });
  }

  Widget _buildShimmerLoading() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _itemsPerPage,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(color: Colors.grey),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 16, color: Colors.grey),
                      const SizedBox(height: 4),
                      Container(height: 12, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _isGalleryFavorite(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteKey = 'favorites';
    final favoritesJson = prefs.getStringList(favoriteKey) ?? [];
    final favorites = favoritesJson
        .map((json) => FavoriteItem.fromJson(
      Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>),
    ))
        .toList();
    return favorites.any(
          (item) =>
      item.type == 'gallery' &&
          item.url == url &&
          item.celebrityName == widget.celebrityName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_filteredItems.length / _itemsPerPage).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.celebrityName} - Galleries',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: _sortNewestFirst ? 'Sort Oldest First' : 'Sort Newest First',
            onPressed: _toggleSortOrder,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search by gallery code...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                    _filterGalleries();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              keyboardType: TextInputType.number,
              autofocus: false,
              onChanged: (value) {
                setState(() {});
                _filterGalleries();
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : _error != null
          ? Center(child: Text(_error!))
          : _filteredItems.isEmpty
          ? const Center(child: Text('No galleries found'))
          : Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: _displayedItems.length,
              itemBuilder: (context, index) {
                final item = _displayedItems[index];
                return FutureBuilder<bool>(
                  future: _isGalleryFavorite(item.url),
                  builder: (context, snapshot) {
                    final isFavorite = snapshot.data ?? false;
                    return GestureDetector(
                      onTap: () => _navigateToDownloader(item.url, item.title),
                      onLongPress: () => _toggleGalleryFavorite(item),
                      child: Card(
                        elevation: 2,
                        color: isFavorite
                            ? Theme.of(context)
                            .colorScheme
                            .surfaceTint
                            .withOpacity(0.1)
                            : Theme.of(context).colorScheme.surface,
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12)),
                                    child: item.thumbnailUrl != null &&
                                        item.thumbnailUrl!.isNotEmpty
                                        ? Container(
                                      width: double.infinity,
                                      child: Image.network(
                                        item.thumbnailUrl!,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter, // This ensures vertical images show from top
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        },
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.red.shade200,
                                          child: const Icon(
                                            Icons.broken_image,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    )
                                        : Container(
                                      color: Colors.red.shade200,
                                      child: const Icon(
                                        Icons.error,
                                        size: 60,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.pages} pages • ${DateFormat('MMM dd, yyyy').format(item.date)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => _toggleGalleryFavorite(item), // Add tap functionality to star
                                child: Container(
                                  padding: const EdgeInsets.all(4), // Add padding for better tap area
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3), // Add background for better visibility
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isFavorite ? Icons.star : Icons.star_border,
                                    color: isFavorite
                                        ? Colors.yellow
                                        : Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.tonal(
                    onPressed: _currentPage > 1
                        ? () => _changePage(_currentPage - 1)
                        : null,
                    child: const Icon(Icons.chevron_left),
                  ),
                  const SizedBox(width: 16),
                  Text('Page $_currentPage of $totalPages'),
                  const SizedBox(width: 16),
                  FilledButton.tonal(
                    onPressed: _currentPage < totalPages
                        ? () => _changePage(_currentPage + 1)
                        : null,
                    child: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}