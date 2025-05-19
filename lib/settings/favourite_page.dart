import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_Preferences.dart';
import 'dart:convert';
import '../screens/ragalahari_downloader_screen.dart';
import '../pages/celebrity/celebrity_list_page.dart'; // Import to reuse FavoriteItem and navigate

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
        SnackBar(content: Text('${item.name} removed from favorites')));
  }

  void _onReorder(int oldIndex, int newIndex, String type) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final items = _favorites.where((item) => item.type == type).toList();
      final item = items[oldIndex];
      items.removeAt(oldIndex);
      items.insert(newIndex, item);
      // Rebuild _favorites with reordered items
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
    final celebrities = _favorites.where((item) => item.type == 'celebrity').toList();
    final galleries = _favorites.where((item) => item.type == 'gallery').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourites'),
        bottom: TabBar(
          controller: _tabController,
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
            padding: const EdgeInsets.all(8.0),
            child: celebrities.isEmpty
                ? const Center(child: Text('No favorite celebrities'))
                : ReorderableListView(
              onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, 'celebrity'),
              children: List.generate(celebrities.length, (index) {
                final item = celebrities[index];
                return Card(
                  key: ValueKey(item.url),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(item.name),
                    hoverColor: Theme.of(context).primaryColor.withOpacity(0.1),
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
                      icon: const Icon(Icons.delete),
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
            padding: const EdgeInsets.all(8.0),
            child: galleries.isEmpty
                ? const Center(child: Text('No favorite galleries'))
                : ReorderableListView(
              onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, 'gallery'),
              children: List.generate(galleries.length, (index) {
                final item = galleries[index];
                return Card(
                  key: ValueKey(item.url),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        item.thumbnailUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 60),
                      ),
                    )
                        : const Icon(Icons.image, size: 60),
                    title: Text(item.name),
                    subtitle: Text('Celebrity: ${item.celebrityName ?? 'Unknown'}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RagalahariDownloaderScreen(
                            initialUrl: item.url,
                            initialFolder: item.celebrityName,
                          ),
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
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