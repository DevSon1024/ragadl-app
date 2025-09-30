import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../utils/celebrity_utils.dart';
import 'gallery_links_page.dart';
import '../../downloader/ui/ragalahari_downloader.dart';
import 'dart:convert';

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
  Set<String> _actorUrls = {};
  Set<String> _actressUrls = {};

  @override
  void initState() {
    super.initState();
    _loadSortOption();
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
          builder: (_) => RagalahariDownloader(initialFolder: celebrityName),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Celebrity Profiles',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
        elevation: 2,
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (SortOption newValue) {
              setState(() {
                _currentSortOption = newValue;
                _saveSortOption();
                _sortCelebrities();
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: SortOption.az,
                child: Text('A-Z'),
              ),
              const PopupMenuItem(
                value: SortOption.za,
                child: Text('Z-A'),
              ),
              PopupMenuItem(
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
              PopupMenuItem(
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
              PopupMenuItem(
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainer,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {});
                _filterCelebrities();
              },
            ),
          ),
          Expanded(
            child: _celebrities.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _filteredCelebrities.isEmpty
                ? const Center(child: Text('No matching celebrities found'))
                : ListView.builder(
              itemCount: _filteredCelebrities.length,
              itemBuilder: (context, index) {
                final celebrity = _filteredCelebrities[index];
                return FutureBuilder<bool>(
                  future: _isCelebrityFavorite(
                      celebrity['name']!, celebrity['url']!),
                  builder: (context, snapshot) {
                    final isFavorite = snapshot.data ?? false;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      color: isFavorite
                          ? Colors.yellow[100]
                          : theme.colorScheme.surfaceContainer,
                      surfaceTintColor: theme.colorScheme.surfaceTint,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        title: Text(
                          celebrity['name'] ?? 'Unknown',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                            IconButton(
                              icon: Icon(
                                isFavorite ? Icons.star : Icons.star_border,
                                color: isFavorite ? Colors.yellow[700] : theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => _toggleCelebrityFavorite(
                                  celebrity['name']!, celebrity['url']!),
                              tooltip: isFavorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add_box_outlined,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () =>
                                  _handleDownloadPress(celebrity['name']!),
                              tooltip: 'Add Name to The Main Folder Input',
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
        ],
      ),
    );
  }
}