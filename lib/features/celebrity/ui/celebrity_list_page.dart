import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ragalahari_downloader/features/celebrity/data/celebrity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/celebrity_utils.dart';
import 'gallery_links_page.dart';
import '../../downloader/ui/ragalahari_downloader.dart';

class CelebrityListPage extends StatefulWidget {
  final DownloadSelectedCallback? onDownloadSelected;

  const CelebrityListPage({super.key, this.onDownloadSelected});

  @override
  _CelebrityListPageState createState() => _CelebrityListPageState();
}

class _CelebrityListPageState extends State<CelebrityListPage> {
  // Get the singleton instance of the repository
  final CelebrityRepository _repository = CelebrityRepository.instance;

  List<Map<String, String>> _filteredCelebrities = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  SortOption _currentSortOption = SortOption.az;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSortOption();
    _initializeData(); // Changed from _loadCelebrities
    _searchController.addListener(_filterCelebrities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // This method now fetches data from the repository, which loads it only once.
  Future<void> _initializeData() async {
    try {
      // This will only perform a heavy load on the first call.
      // Subsequent calls will return instantly.
      await _repository.loadCelebrities();

      setState(() {
        _filteredCelebrities = List.from(_repository.celebrities);
        _isLoading = false;
        _sortCelebrities();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load celebrities. Please try again.';
      });
    }
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

  void _sortCelebrities() {
    setState(() {
      _filteredCelebrities = List.from(_repository.celebrities);

      switch (_currentSortOption) {
        case SortOption.celebrityActors:
          _filteredCelebrities = _filteredCelebrities
              .where(
                  (celebrity) => _repository.actorUrls.contains(celebrity['url']))
              .toList();
          break;
        case SortOption.celebrityActresses:
          _filteredCelebrities = _filteredCelebrities
              .where((celebrity) =>
              _repository.actressUrls.contains(celebrity['url']))
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
            .where(
                (celebrity) => celebrity['name']!.toLowerCase().contains(query))
            .toList();
      }

      switch (_currentSortOption) {
        case SortOption.az:
        case SortOption.celebrityAll:
        case SortOption.celebrityActors:
        case SortOption.celebrityActresses:
          _filteredCelebrities
              .sort((a, b) => a['name']!.compareTo(b['name']!));
          break;
        case SortOption.za:
          _filteredCelebrities
              .sort((a, b) => b['name']!.compareTo(a['name']!));
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
      Map<String, String>.from(
          jsonDecode(json) as Map<String, dynamic>),
    ))
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
      Map<String, String>.from(
          jsonDecode(json) as Map<String, dynamic>),
    ))
        .toList();
    return favorites.any((item) =>
    item.type == 'celebrity' && item.name == name && item.url == url);
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
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainer,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {});
                _filterCelebrities();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _filteredCelebrities.isEmpty
                ? const Center(
                child: Text('No matching celebrities found'))
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100.0),
              itemCount: _filteredCelebrities.length,
              itemBuilder: (context, index) {
                final celebrity = _filteredCelebrities[index];
                return FutureBuilder<bool>(
                  future: _isCelebrityFavorite(
                      celebrity['name']!, celebrity['url']!),
                  builder: (context, snapshot) {
                    final isFavorite = snapshot.data ?? false;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: isFavorite
                          ? Colors.yellow.withOpacity(0.1)
                          : theme.colorScheme.surface,
                      child: ListTile(
                        contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        title: Text(
                          celebrity['name'] ?? 'Unknown',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GalleryLinksPage(
                                celebrityName:
                                celebrity['name']!,
                                profileUrl: celebrity['url']!,
                                onDownloadSelected:
                                widget.onDownloadSelected,
                              ),
                            ),
                          );
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isFavorite
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: isFavorite
                                    ? Colors.amber
                                    : theme.colorScheme
                                    .onSurfaceVariant,
                              ),
                              onPressed: () =>
                                  _toggleCelebrityFavorite(
                                      celebrity['name']!,
                                      celebrity['url']!),
                              tooltip: isFavorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add_box_outlined,
                                color: theme
                                    .colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () =>
                                  _handleDownloadPress(
                                      celebrity['name']!),
                              tooltip:
                              'Add Name to The Main Folder Input',
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