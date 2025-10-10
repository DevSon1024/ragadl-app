import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../downloader/ui/ragalahari_downloader_page.dart';
import '../../celebrity/ui/gallery_links_page.dart';
import '../../celebrity/utils/celebrity_utils.dart';

class FavouritePage extends StatefulWidget {
  const FavouritePage({super.key});

  @override
  _FavouritePageState createState() => _FavouritePageState();
}

class _FavouritePageState extends State<FavouritePage> with SingleTickerProviderStateMixin {
  List<FavoriteItem> _favorites = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteKey = 'favorites';
    final favoritesJson = prefs.getStringList(favoriteKey) ?? [];
    setState(() {
      _favorites = favoritesJson
          .map((json) => FavoriteItem.fromJson(
          Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>)))
          .toList();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteKey = 'favorites';
    await prefs.setStringList(
        favoriteKey, _favorites.map((item) => jsonEncode(item.toJson())).toList());
  }

  Future<void> _removeFavorite(FavoriteItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteKey = 'favorites';
    List<String> favoritesJson = prefs.getStringList(favoriteKey) ?? [];
    List<FavoriteItem> favorites = favoritesJson
        .map((json) => FavoriteItem.fromJson(
        Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>)))
        .toList();

    favorites.removeWhere((fav) =>
    fav.type == item.type &&
        fav.url == item.url &&
        fav.name == item.name &&
        fav.celebrityName == item.celebrityName);
    await prefs.setStringList(
        favoriteKey, favorites.map((item) => jsonEncode(item.toJson())).toList());

    setState(() {
      _favorites = favorites;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} removed from favorites'),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex, String type) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final items = _favorites.where((item) => item.type == type).toList();
      final item = items[oldIndex];
      items.removeAt(oldIndex);
      items.insert(newIndex, item);
      _favorites = [
        if (type == 'celebrity') ...items,
        if (type == 'gallery') ..._favorites.where((item) => item.type == 'celebrity'),
        if (type == 'celebrity') ..._favorites.where((item) => item.type == 'gallery'),
        if (type == 'gallery') ...items,
      ];
    });
    _saveFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final celebrities = _favorites.where((item) => item.type == 'celebrity').toList();
    final galleries = _favorites.where((item) => item.type == 'gallery').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Favourites',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'Celebrities'),
            Tab(text: 'Galleries'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Celebrities Tab
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: celebrities.isEmpty
                ? Center(
              child: Text(
                'No favorite celebrities',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
                : ReorderableListView(
              onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, 'celebrity'),
              children: List.generate(celebrities.length, (index) {
                final item = celebrities[index];
                return Card(
                  key: ValueKey(item.url),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  surfaceTintColor: theme.colorScheme.surfaceTint,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GalleryLinksPage(
                            celebrityName: item.name,
                            profileUrl: item.url,
                          ),
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () => _removeFavorite(item),
                      tooltip: 'Remove from favorites',
                    ),
                  ),
                );
              }),
            ),
          ),
          // Galleries Tab
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: galleries.isEmpty
                ? Center(
              child: Text(
                'No favorite galleries',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
                : ReorderableListView(
              onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, 'gallery'),
              children: List.generate(galleries.length, (index) {
                final item = galleries[index];
                return Card(
                  key: ValueKey(item.url),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  surfaceTintColor: theme.colorScheme.surfaceTint,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.thumbnailUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image,
                          size: 60,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                        : Icon(
                      Icons.image,
                      size: 60,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Celebrity: ${item.celebrityName ?? 'Unknown'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RagalahariDownloader(
                            initialUrl: item.url,
                            initialFolder: item.celebrityName,
                          ),
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () => _removeFavorite(item),
                      tooltip: 'Remove from favorites',
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}