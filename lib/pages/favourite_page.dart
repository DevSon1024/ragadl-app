import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../screens/ragalahari_downloader_screen.dart';
import 'celebrity_list_page.dart'; // Import to reuse FavoriteItem and navigate

class FavouritePage extends StatefulWidget {
  const FavouritePage({super.key});

  @override
  _FavouritePageState createState() => _FavouritePageState();
}

class _FavouritePageState extends State<FavouritePage> {
  List<FavoriteItem> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
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
    await prefs.setStringList(favoriteKey,
        favorites.map((item) => jsonEncode(item.toJson())).toList());

    setState(() {
      _favorites = favorites;
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} removed from favorites')));
  }

  @override
  Widget build(BuildContext context) {
    final celebrities = _favorites.where((item) => item.type == 'celebrity').toList();
    final galleries = _favorites.where((item) => item.type == 'gallery').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favourites'),
      ),
      body: SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Celebrities Section
              const Text(
              'Celebrities',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            celebrities.isEmpty
                ? const Center(child: Text('No favorite celebrities'))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: celebrities.length,
              itemBuilder: (context, index) {
                final item = celebrities[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(item.name),
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
              },
            ),
            const SizedBox(height: 16),
            // Galleries Section
            const Text(
              'Galleries',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            galleries.isEmpty
                ? const Center(child: Text ('No favorite galleries'))
            : ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: galleries.length,
        itemBuilder: (context, index) {
          final item = galleries[index];
          return Card(
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
                      // galleryTitle: item.name,
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
        },
      ),
      ],
    ),
    ),
    ),
    );
  }
}