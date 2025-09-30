import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:isolate';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/celebrity_utils.dart';
import '../../downloader/ui/ragalahari_downloader.dart';
import 'package:ragalahari_downloader/shared/widgets/grid_utils.dart';

// Data class for passing data to isolate
class GalleryScrapingData {
  final String profileUrl;
  final Map<String, String> headers;
  final List<String> thumbnailDomains;
  final int batchSize;
  final bool sortNewestFirst;

  GalleryScrapingData({
    required this.profileUrl,
    required this.headers,
    required this.thumbnailDomains,
    required this.batchSize,
    required this.sortNewestFirst,
  });
}

// Data class for isolate results
class GalleryScrapingResult {
  final List<GalleryItem>? items;
  final String? error;
  final bool isPartialUpdate;
  final int processedCount;
  final int totalCount;

  GalleryScrapingResult({
    this.items,
    this.error,
    this.isPartialUpdate = false,
    this.processedCount = 0,
    this.totalCount = 0,
  });
}

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

  // Progress tracking
  int _processedCount = 0;
  int _totalCount = 0;
  ReceivePort? _receivePort;
  Isolate? _isolate;

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
    _receivePort?.close();
    _isolate?.kill();
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
    _scrapeGalleryLinksWithIsolate();
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

  Future<void> _scrapeGalleryLinksWithIsolate() async {
    try {
      _receivePort = ReceivePort();

      // Listen for messages from isolate
      _receivePort!.listen((message) {
        if (message is GalleryScrapingResult) {
          _handleIsolateResult(message);
        }
      });

      final scrapingData = GalleryScrapingData(
        profileUrl: widget.profileUrl,
        headers: headers,
        thumbnailDomains: thumbnailDomains,
        batchSize: _batchSize,
        sortNewestFirst: _sortNewestFirst,
      );

      _isolate = await Isolate.spawn(
        _scrapeGalleryLinksIsolate,
        [_receivePort!.sendPort, scrapingData],
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to start scraping: $e';
        _isLoading = false;
      });
    }
  }

  void _handleIsolateResult(GalleryScrapingResult result) {
    if (result.error != null) {
      setState(() {
        _error = result.error;
        _isLoading = false;
      });
      return;
    }

    if (result.items != null) {
      setState(() {
        if (result.isPartialUpdate) {
          // Add new items to existing list
          _galleryItems.addAll(result.items!);
          // Re-sort the entire list
          _galleryItems.sort(
                (a, b) => _sortNewestFirst
                ? b.date.compareTo(a.date)
                : a.date.compareTo(b.date),
          );
        } else {
          _galleryItems = result.items!;
        }

        _filteredItems = List.from(_galleryItems);
        _updateDisplayedItems();
        _processedCount = result.processedCount;
        _totalCount = result.totalCount;

        // If this is the final result, stop loading
        if (!result.isPartialUpdate || result.processedCount >= result.totalCount) {
          _isLoading = false;
          _cacheGalleryLinks();
        }
      });
    }
  }

  // Static isolate function
  static Future<void> _scrapeGalleryLinksIsolate(List<dynamic> args) async {
    final SendPort sendPort = args[0];
    final GalleryScrapingData data = args[1];

    try {
      // Fetch main page
      final response = await http
          .get(Uri.parse(data.profileUrl), headers: data.headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        sendPort.send(GalleryScrapingResult(
          error: 'Failed to load page: ${response.statusCode}',
        ));
        return;
      }

      final document = html_parser.parse(response.body);
      final links = _extractGalleryLinksIsolate(document, data.profileUrl);

      if (links.isEmpty) {
        sendPort.send(GalleryScrapingResult(items: []));
        return;
      }

      // Process links in batches and send partial updates
      final items = <GalleryItem>[];
      final batches = <List<String>>[];

      for (var i = 0; i < links.length; i += data.batchSize) {
        batches.add(
          links.sublist(
            i,
            i + data.batchSize > links.length ? links.length : i + data.batchSize,
          ),
        );
      }

      for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
        final batch = batches[batchIndex];
        final futures = batch.map((link) =>
            _processSingleLinkIsolate(link, data.headers, data.thumbnailDomains)
        ).toList();

        final results = await Future.wait(futures);
        final batchItems = results.whereType<GalleryItem>().toList();

        // Sort batch items
        batchItems.sort(
              (a, b) => data.sortNewestFirst
              ? b.date.compareTo(a.date)
              : a.date.compareTo(b.date),
        );

        items.addAll(batchItems);

        // Send partial update after each batch
        sendPort.send(GalleryScrapingResult(
          items: batchItems,
          isPartialUpdate: true,
          processedCount: (batchIndex + 1) * data.batchSize,
          totalCount: links.length,
        ));
      }

      // Send final sorted result
      items.sort(
            (a, b) => data.sortNewestFirst
            ? b.date.compareTo(a.date)
            : a.date.compareTo(b.date),
      );

      sendPort.send(GalleryScrapingResult(
        items: items,
        isPartialUpdate: false,
        processedCount: links.length,
        totalCount: links.length,
      ));
    } catch (e) {
      sendPort.send(GalleryScrapingResult(error: 'Failed to scrape gallery links: $e'));
    }
  }

  static List<String> _extractGalleryLinksIsolate(dom.Document document, String profileUrl) {
    final galleriesPanel = document.getElementById('galleries_panel');
    if (galleriesPanel == null) return [];

    return galleriesPanel
        .getElementsByClassName('galimg')
        .map((element) => element.attributes['href'] ?? '')
        .where((href) => href.isNotEmpty)
        .map((href) => Uri.parse(profileUrl).resolve(href).toString())
        .toList();
  }

  static Future<GalleryItem?> _processSingleLinkIsolate(
      String link,
      Map<String, String> headers,
      List<String> thumbnailDomains) async {
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

      final (pages, date) = await _getGalleryInfoIsolate(link, headers);

      return GalleryItem(
        url: link,
        title: title,
        thumbnailUrl: thumbnailUrl,
        pages: pages,
        date: date,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<(int, DateTime)> _getGalleryInfoIsolate(String url, Map<String, String> headers) async {
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
    return Column(
      children: [
        // Progress indicator
        if (_totalCount > 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _processedCount / _totalCount,
                ),
                const SizedBox(height: 8),
                Text(
                  'Loading galleries: $_processedCount / $_totalCount',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: calculateGridColumns(context),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: _displayedItems.isNotEmpty ? _displayedItems.length : _itemsPerPage,
            itemBuilder: (context, index) {
              // Show actual items if available, otherwise show shimmer
              if (index < _displayedItems.length) {
                final item = _displayedItems[index];
                return FutureBuilder<bool>(
                  future: _isGalleryFavorite(item.url),
                  builder: (context, snapshot) {
                    final isFavorite = snapshot.data ?? false;
                    return _buildGalleryCard(item, isFavorite);
                  },
                );
              } else {
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
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryCard(GalleryItem item, bool isFavorite) {
    return GestureDetector(
      onTap: () => _navigateToDownloader(item.url, item.title),
      onLongPress: () => _toggleGalleryFavorite(item),
      child: Card(
        elevation: 2,
        color: isFavorite
            ? Theme.of(context).colorScheme.surfaceTint.withOpacity(0.1)
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
                        alignment: Alignment.topCenter,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleSmall,
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
                onTap: () => _toggleGalleryFavorite(item),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.yellow : Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
      body: _error != null
          ? Center(child: Text(_error!))
          : _filteredItems.isEmpty && !_isLoading
          ? const Center(child: Text('No galleries found'))
          : _isLoading
          ? _buildShimmerLoading()
          : Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: calculateGridColumns(context),
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
                    return _buildGalleryCard(item, isFavorite);
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