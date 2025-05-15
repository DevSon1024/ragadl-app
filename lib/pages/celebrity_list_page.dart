import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/ragalahari_downloader_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Headers for HTTP requests
final Map<String, String> headers = {
  'User-Agent':
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
  'Accept':
  'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
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

// Add enums for sorting
enum SortOption {
  az,
  za,
  celebrityAll,
  celebrityActors,
  celebrityActresses,
}
enum CategoryOption { all, actors, actresses }

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

class FavoriteItem {
  final String type;
  final String name;
  final String url;
  final String? thumbnailUrl;
  final String? celebrityName;

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
    celebrityName:
    json['celebrityName']!.isEmpty ? null : json['celebrityName'],
  );
}

typedef DownloadSelectedCallback =
void Function(String url, String folder, String? galleryTitle);

class CelebrityListPage extends StatefulWidget {
  final DownloadSelectedCallback? onDownloadSelected;

  const CelebrityListPage({super.key, this.onDownloadSelected});

  @override
  _CelebrityListPageState createState() => _CelebrityListPageState();
}

class _CelebrityListPageState extends State<CelebrityListPage> {
  List<Map<String, String>> _celebrities = [];
  List<Map<String, String>> _filteredCelebrities = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  SortOption _currentSortOption = SortOption.az;
  CategoryOption _currentCategoryOption = CategoryOption.all;
  Set<String> _actorUrls = {};
  Set<String> _actressUrls = {};

  @override
  void initState() {
    super.initState();
    _loadSortOption(); // Load saved sort option
    _loadCelebrities();
    _searchController.addListener(_filterCelebrities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSortOption = prefs.getString('sortOption');
    if (savedSortOption != null) {
      setState(() {
        _currentSortOption = SortOption.values.firstWhere(
              (option) => option.toString() == savedSortOption,
          orElse: () => SortOption.az,
        );
      });
    }
  }

  Future<void> _saveSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sortOption', _currentSortOption.toString());
  }

  Future<void> _loadCelebrities() async {
    try {
      String csvString;
      if (Platform.isWindows) {
        final saveDir = await getApplicationDocumentsDirectory();
        final file = File('${saveDir.path}/RagalahariData/Fetched_StarZone_Data.csv');
        if (await file.exists()) {
          csvString = await file.readAsString();
        } else {
          csvString = await DefaultAssetBundle.of(context)
              .loadString('assets/data/Fetched_StarZone_Data.csv');
        }
      } else {
        csvString = await DefaultAssetBundle.of(context)
            .loadString('assets/data/Fetched_StarZone_Data.csv');
      }
      final lines = csvString.split('\n');
      final celebrities = lines
          .skip(1)
          .where((line) => line.trim().isNotEmpty && line.contains(','))
          .map((line) {
        final parts = line.split(',');
        if (parts.length >= 2) {
          return {'name': parts[0].trim(), 'url': parts[1].trim()};
        }
        return {'name': 'Unknown', 'url': ''};
      })
          .where((celebrity) => celebrity['name']!.isNotEmpty)
          .toList();

      final jsonString = await DefaultAssetBundle.of(context)
          .loadString('assets/data/Fetched_Albums_StarZone.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final actors = (jsonData['actors'] as List<dynamic>)
          .map((e) => e['URL'] as String)
          .toSet();
      final actresses = (jsonData['actresses'] as List<dynamic>)
          .map((e) => e['URL'] as String)
          .toSet();

      setState(() {
        _celebrities = celebrities;
        _actorUrls = actors;
        _actressUrls = actresses;
        _filteredCelebrities = List.from(_celebrities);
        _sortCelebrities();
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading celebrities: $e')));
    }
  }

  void _sortCelebrities() {
    setState(() {
      _filteredCelebrities = List.from(_celebrities);

      switch (_currentSortOption) {
        case SortOption.celebrityActors:
          _filteredCelebrities = _filteredCelebrities
              .where((celebrity) => _actorUrls.contains(celebrity['url']))
              .toList();
          break;
        case SortOption.celebrityActresses:
          _filteredCelebrities = _filteredCelebrities
              .where((celebrity) => _actressUrls.contains(celebrity['url']))
              .toList();
          break;
        case SortOption.celebrityAll:
        case SortOption.az:
        case SortOption.za:
          break;
      }

      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        _filteredCelebrities = _filteredCelebrities
            .where((celebrity) => celebrity['name']!.toLowerCase().contains(query))
            .toList();
      }

      switch (_currentSortOption) {
        case SortOption.az:
        case SortOption.celebrityAll:
        case SortOption.celebrityActors:
        case SortOption.celebrityActresses:
          _filteredCelebrities.sort((a, b) => a['name']!.compareTo(b['name']!));
          break;
        case SortOption.za:
          _filteredCelebrities.sort((a, b) => b['name']!.compareTo(a['name']!));
          break;
      }
    });
  }

  void _filterCelebrities() {
    _sortCelebrities();
  }

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

  Future<void> _toggleCelebrityFavorite(String name, String url) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteKey = 'favorites';
    List<String> favoritesJson = prefs.getStringList(favoriteKey) ?? [];
    List<FavoriteItem> favorites = favoritesJson
        .map((json) => FavoriteItem.fromJson(
      Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>),
    ))
        .toList();

    final favoriteItem = FavoriteItem(type: 'celebrity', name: name, url: url);
    final isFavorite = favorites
        .any((item) => item.type == 'celebrity' && item.name == name && item.url == url);

    if (isFavorite) {
      favorites.removeWhere(
              (item) => item.type == 'celebrity' && item.name == name && item.url == url);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$name removed from favorites')));
    } else {
      favorites.add(favoriteItem);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$name added to favorites')));
    }

    await prefs.setStringList(
      favoriteKey,
      favorites.map((item) => jsonEncode(item.toJson())).toList(),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Celebrity Profiles',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          DropdownButton<SortOption>(
            value: _currentSortOption,
            icon: const Icon(Icons.sort),
            onChanged: (SortOption? newValue) {
              if (newValue != null) {
                setState(() {
                  _currentSortOption = newValue;
                  _saveSortOption(); // Save the new sort option
                  _sortCelebrities();
                });
              }
            },
            items: [
              const DropdownMenuItem(
                value: SortOption.az,
                child: Text('A-Z'),
              ),
              const DropdownMenuItem(
                value: SortOption.za,
                child: Text('Z-A'),
              ),
              DropdownMenuItem(
                value: SortOption.celebrityAll,
                child: Row(
                  children: [
                    const Text('Celebrity'),
                    const SizedBox(width: 8),
                    Text(
                      'All',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: SortOption.celebrityActors,
                child: Row(
                  children: [
                    const Text('Celebrity'),
                    const SizedBox(width: 8),
                    Text(
                      'Actors',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: SortOption.celebrityActresses,
                child: Row(
                  children: [
                    const Text('Celebrity'),
                    const SizedBox(width: 8),
                    Text(
                      'Actresses',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
              bottom: Radius.circular(20),
            ),
          ),
        ),
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
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                    _filterCelebrities();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              autofocus: false,
              onChanged: (value) {
                setState(() {});
                _filterCelebrities();
              },
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListTile(
              title: Text(celebrity['name'] ?? 'Unknown'),
              hoverColor: Theme.of(context).primaryColor.withOpacity(0.1),
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
                          isFavorite ? Icons.star : Icons.star_border,
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
                    tooltip: 'Add Name to The Main Folder Input',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _isCelebrityFavorite(String name, String url) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteKey = 'favorites';
    final favoritesJson = prefs.getStringList(favoriteKey) ?? [];
    final favorites = favoritesJson
        .map((json) => FavoriteItem.fromJson(
      Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>),
    ))
        .toList();
    return favorites
        .any((item) => item.type == 'celebrity' && item.name == name && item.url == url);
  }
}

// GalleryLinksPage remains unchanged
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
        builder: (_) => RagalahariDownloaderScreen(
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
      _galleryItems.sort(
            (a, b) => _sortNewestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
      );
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
              leading: Container(width: 60, height: 60, color: Colors.grey),
              title: Container(height: 16, color: Colors.grey),
              subtitle: Container(height: 12, color: Colors.grey),
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
                child: Text(
                  _sortNewestFirst ? 'Sort: Oldest First' : 'Sort: Newest First',
                ),
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
                  margin:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: item.thumbnailUrl != null &&
                        item.thumbnailUrl!.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        item.thumbnailUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        loadingBuilder:
                            (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            width: 60,
                            height: 60,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          size: 60,
                        ),
                      ),
                    )
                        : Container(
                      width: 60,
                      height: 60,
                      color: Colors.red.shade200,
                      child: const Icon(
                        Icons.error,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.pages} pages • ${DateFormat('MMM dd, yyyy').format(item.date)}',
                    ),
                    onTap: () =>
                        _navigateToDownloader(item.url, item.title),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FutureBuilder<bool>(
                          future: _isGalleryFavorite(item.url),
                          builder: (context, snapshot) {
                            final isFavorite = snapshot.data ?? false;
                            return IconButton(
                              icon: Icon(
                                isFavorite
                                    ? Icons.star
                                    : Icons.star_border,
                                color:
                                isFavorite ? Colors.yellow : null,
                              ),
                              onPressed: () => _toggleGalleryFavorite(item),
                              tooltip: isFavorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                            );
                          },
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
                    onPressed: _currentPage > 1
                        ? () => _changePage(_currentPage - 1)
                        : null,
                  ),
                  Text('Page $_currentPage of $totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages
                        ? () => _changePage(_currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}