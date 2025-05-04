import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/navbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import '../screens/ragalahari_downloader_screen.dart';

// Headers for HTTP requests
final Map<String, String> headers = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.5',
  'Connection': 'keep-alive',
};

// Domain patterns for thumbnail detection
final List<String> thumbnailDomains = [
  "media.ragalahari.com",
  "img.ragalahari.com",
  "szcdn.ragalahari.com",
  "starzone.ragalahari.com",
  "imgcdn.ragalahari.com",
];

class GalleryItem {
  final String url;
  final String title;
  final String? thumbnailUrl;
  final int pages;
  final DateTime date;

  GalleryItem({
    required this.url,
    required this.title,
    this.thumbnailUrl,
    required this.pages,
    required this.date,
  });
}

// Define a FavoriteItem class to handle both gallery and celebrity favorites
class FavoriteItem {
  final String type; // 'celebrity' or 'gallery'
  final String name; // Celebrity name or gallery title
  final String url; // Profile URL or gallery URL
  final String? thumbnailUrl; // Optional for galleries
  final String? celebrityName; // For galleries, to store associated celebrity

  FavoriteItem({
    required this.type,
    required this.name,
    required this.url,
    this.thumbnailUrl,
    this.celebrityName,
  });

  Map<String, String> toJson() => {
    'type': type,
    'name': name,
    'url': url,
    'thumbnailUrl': thumbnailUrl ?? '',
    'celebrityName': celebrityName ?? '',
  };

  factory FavoriteItem.fromJson(Map<String, String> json) => FavoriteItem(
    type: json['type']!,
    name: json['name']!,
    url: json['url']!,
    thumbnailUrl: json['thumbnailUrl']!.isEmpty ? null : json['thumbnailUrl'],
    celebrityName: json['celebrityName']!.isEmpty ? null : json['celebrityName'],
  );
}

// Define a callback type for download selection
typedef DownloadSelectedCallback = void Function(String url, String folder, String? galleryTitle);

class CelebrityListPage extends StatefulWidget {
  final DownloadSelectedCallback? onDownloadSelected;

  const CelebrityListPage({
    Key? key,
    this.onDownloadSelected,
  }) : super(key: key);

  @override
  _CelebrityListPageState createState() => _CelebrityListPageState();
}

class _CelebrityListPageState extends State<CelebrityListPage> {
  List<Map<String, String>> _celebrities = [];
  List<Map<String, String>> _filteredCelebrities = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCelebrities();
    _searchController.addListener(_filterCelebrities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCelebrities() async {
    try {
      final csvString = await DefaultAssetBundle.of(context).loadString('assets/data/Fetched_StarZone_Data.csv');
      final lines = csvString.split('\n');
      setState(() {
        _celebrities = lines
            .where((line) => line.contains(','))
            .map((line) {
          final parts = line.split(',');
          return {'name': parts[0].trim(), 'url': parts[1].trim()};
        })
            .toList();
        _filteredCelebrities = List.from(_celebrities);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading celebrities: $e')),
      );
    }
  }

  void _filterCelebrities() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCelebrities = _celebrities
          .where((celebrity) => celebrity['name']!.toLowerCase().contains(query))
          .toList();
    });
  }

  // Method to handle download button press
  void _handleDownloadPress(String celebrityName) {
    if (widget.onDownloadSelected != null) {
      widget.onDownloadSelected!('', celebrityName, null);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RagalahariDownloaderScreen(initialFolder: celebrityName),
        ),
      );
    }
  }

  // Function to toggle favorite status for celebrities
  Future<void> _toggleCelebrityFavorite(String name, String url) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteKey = 'favorites';
    List<String> favoritesJson = prefs.getStringList(favoriteKey) ?? [];
    List<FavoriteItem> favorites = favoritesJson
        .map((json) => FavoriteItem.fromJson(
        Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>)))
        .toList();

    final favoriteItem = FavoriteItem(type: 'celebrity', name: name, url: url);
    final isFavorite = favorites.any((item) =>
    item.type == 'celebrity' && item.name == name && item.url == url);

    if (isFavorite) {
      favorites.removeWhere((item) =>
      item.type == 'celebrity' && item.name == name && item.url == url);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name removed from favorites')));
    } else {
      favorites.add(favoriteItem);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name added to favorites')));
    }

    await prefs.setStringList(favoriteKey,
        favorites.map((item) => jsonEncode(item.toJson())).toList());
    setState(() {}); // Trigger rebuild to update icon
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Celebrity Profiles'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search celebrities...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              autofocus: false,
            ),
          ),
        ),
      ),
      body: _celebrities.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _filteredCelebrities.isEmpty
          ? const Center(child: Text('No matching celebrities found'))
          : ListView.builder(
        itemCount: _filteredCelebrities.length,
        itemBuilder: (context, index) {
          final celebrity = _filteredCelebrities[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text(celebrity['name'] ?? 'Unknown'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GalleryLinksPage(
                      celebrityName: celebrity['name']!,
                      profileUrl: celebrity['url']!,
                      onDownloadSelected: widget.onDownloadSelected,
                    ),
                  ),
                );
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<bool>(
                    future: _isCelebrityFavorite(
                        celebrity['name']!, celebrity['url']!),
                    builder: (context, snapshot) {
                      final isFavorite = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(
                          isFavorite
                              ? Icons.star
                              : Icons.star_border,
                          color: isFavorite ? Colors.yellow : null,
                        ),
                        onPressed: () => _toggleCelebrityFavorite(
                            celebrity['name']!, celebrity['url']!),
                        tooltip: isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_box_outlined),
                    onPressed: () =>
                        _handleDownloadPress(celebrity['name']!),
                    tooltip: 'Download images',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper to check if a celebrity is in favorites
  Future<bool> _isCelebrityFavorite(String name, String url) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteKey = 'favorites';
    final favoritesJson = prefs.getStringList(favoriteKey) ?? [];
    final favorites = favoritesJson
        .map((json) => FavoriteItem.fromJson(
        Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>)))
        .toList();
    return favorites.any((item) =>
    item.type == 'celebrity' && item.name == name && item.url == url);
  }
}

class GalleryLinksPage extends StatefulWidget {
  final String celebrityName;
  final String profileUrl;
  final DownloadSelectedCallback? onDownloadSelected;

  const GalleryLinksPage({
    Key? key,
    required this.celebrityName,
    required this.profileUrl,
    this.onDownloadSelected,
  }) : super(key: key);

  @override
  _GalleryLinksPageState createState() => _GalleryLinksPageState();
}

class _GalleryLinksPageState extends State<GalleryLinksPage> {
  List<GalleryItem> _galleryItems = [];
  List<GalleryItem> _displayedItems = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  final int _itemsPerPage = 30;
  bool _sortNewestFirst = true;
  final int _batchSize = 10;

  @override
  void initState() {
    super.initState();
    _scrapeGalleryLinks();
  }

  // Function to toggle favorite status for galleries
  Future<void> _toggleGalleryFavorite(GalleryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteKey = 'favorites';
    List<String> favoritesJson = prefs.getStringList(favoriteKey) ?? [];
    List<FavoriteItem> favorites = favoritesJson
        .map((json) => FavoriteItem.fromJson(
        Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>)))
        .toList();

    final favoriteItem = FavoriteItem(
      type: 'gallery',
      name: item.title,
      url: item.url,
      thumbnailUrl: item.thumbnailUrl,
      celebrityName: widget.celebrityName,
    );

    final isFavorite = favorites.any((fav) =>
    fav.type == 'gallery' &&
        fav.url == item.url &&
        fav.celebrityName == widget.celebrityName);

    if (isFavorite) {
      favorites.removeWhere((fav) =>
      fav.type == 'gallery' &&
          fav.url == item.url &&
          fav.celebrityName == widget.celebrityName);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.title} removed from favorites')));
    } else {
      favorites.add(favoriteItem);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.title} added to favorites')));
    }

    await prefs.setStringList(favoriteKey,
        favorites.map((item) => jsonEncode(item.toJson())).toList());
    setState(() {}); // Trigger rebuild to update icon
  }

  void _navigateToDownloader(String galleryUrl, String galleryTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RagalahariDownloaderScreen(
          initialUrl: galleryUrl,
          initialFolder: widget.celebrityName,
        ),
      ),
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Returned from downloader')),
      );
    });
  }

  Future<void> _scrapeGalleryLinks() async {
    try {
      final response = await http.get(
        Uri.parse(widget.profileUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final links = _extractGalleryLinks(document);
        final items = await _processGalleryLinks(links);

        setState(() {
          _galleryItems = items;
          _updateDisplayedItems();
          _isLoading = false;
        });
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
        .map((a) => a.attributes['href'] ?? '')
        .where((href) => href.isNotEmpty)
        .map((href) => Uri.parse(widget.profileUrl).resolve(href).toString())
        .toList();
  }

  Future<List<GalleryItem>> _processGalleryLinks(List<String> links) async {
    final items = <GalleryItem>[];
    final batches = <List<String>>[];

    for (var i = 0; i < links.length; i += _batchSize) {
      batches.add(links.sublist(
          i, i + _batchSize > links.length ? links.length : i + _batchSize));
    }

    for (final batch in batches) {
      final futures = batch.map((link) => _processSingleLink(link)).toList();
      final results = await Future.wait(futures);
      items.addAll(results.whereType<GalleryItem>());
    }

    items.sort((a, b) =>
    _sortNewestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
    return items;
  }

  Future<GalleryItem?> _processSingleLink(String link) async {
    try {
      final response =
      await http.get(Uri.parse(link), headers: headers).timeout(const Duration(seconds: 5));
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
      final response =
      await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 5));
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

  Future<void> _launchURL(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _updateDisplayedItems() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    setState(() {
      _displayedItems = _galleryItems.sublist(
        startIndex,
        endIndex > _galleryItems.length ? _galleryItems.length : endIndex,
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
      _galleryItems.sort((a, b) =>
      _sortNewestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
      _currentPage = 1;
      _updateDisplayedItems();
    });
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: _itemsPerPage,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: Container(
                width: 60,
                height: 60,
                color: Colors.grey,
              ),
              title: Container(
                height: 16,
                color: Colors.grey,
              ),
              subtitle: Container(
                height: 12,
                color: Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper to check if a gallery is in favorites
  Future<bool> _isGalleryFavorite(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteKey = 'favorites';
    final favoritesJson = prefs.getStringList(favoriteKey) ?? [];
    final favorites = favoritesJson
        .map((json) => FavoriteItem.fromJson(
        Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>)))
        .toList();
    return favorites.any((item) =>
    item.type == 'gallery' &&
        item.url == url &&
        item.celebrityName == widget.celebrityName);
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_galleryItems.length / _itemsPerPage).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.celebrityName} - Galleries'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'sort') _toggleSortOrder();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'sort',
                child: Text(_sortNewestFirst ? 'Sort: Oldest First' : 'Sort: Newest First'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : _error != null
          ? Center(child: Text(_error!))
          : _galleryItems.isEmpty
          ? const Center(child: Text('No galleries found'))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _displayedItems.length,
              itemBuilder: (context, index) {
                final item = _displayedItems[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        item.thumbnailUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            width: 60,
                            height: 60,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 60),
                      ),
                    )
                        : Container(
                      width: 60,
                      height: 60,
                      color: Colors.red.shade200,
                      child: const Icon(Icons.error, size: 40, color: Colors.white),
                    ),
                    title: Text(item.title),
                    subtitle:
                    Text('${item.pages} pages • ${DateFormat('MMM dd, yyyy').format(item.date)}'),
                    onTap: () => _navigateToDownloader(item.url, item.title),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FutureBuilder<bool>(
                          future: _isGalleryFavorite(item.url),
                          builder: (context, snapshot) {
                            final isFavorite = snapshot.data ?? false;
                            return IconButton(
                              icon: Icon(
                                isFavorite ? Icons.star : Icons.star_border,
                                color: isFavorite ? Colors.yellow : null,
                              ),
                              onPressed: () => _toggleGalleryFavorite(item),
                              tooltip: isFavorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => _navigateToDownloader(item.url, item.title),
                          tooltip: 'Download gallery',
                        ),
                      ],
                    ),
                  ),
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
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                  ),
                  Text('Page $_currentPage of $totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages ? () => _changePage(_currentPage + 1) : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}