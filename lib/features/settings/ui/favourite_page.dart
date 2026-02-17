import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../celebrity/utils/celebrity_utils.dart';
import '../../celebrity/ui/gallery_links_page.dart';
import '../../celebrity/widgets/celebrity_card.dart';
import '../../downloader/ui/ragadl_page.dart';

class FavouritePage extends StatefulWidget {
  const FavouritePage({super.key});

  @override
  _FavouritePageState createState() => _FavouritePageState();
}

class _FavouritePageState extends State<FavouritePage> {
  List<FavoriteItem> celebrities = [];
  List<FavoriteItem> galleries = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritesJson = prefs.getStringList('favorites') ?? [];

    final List<FavoriteItem> allFavorites =
        favoritesJson
            .map(
              (json) => FavoriteItem.fromJson(
                Map<String, String>.from(
                  jsonDecode(json) as Map<String, dynamic>,
                ),
              ),
            )
            .toList();

    setState(() {
      celebrities =
          allFavorites.where((item) => item.type == 'celebrity').toList();
      galleries = allFavorites.where((item) => item.type == 'gallery').toList();
      isLoading = false;
    });
  }

  Future<void> _removeFavorite(FavoriteItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritesJson = prefs.getStringList('favorites') ?? [];

    final List<FavoriteItem> allFavorites =
        favoritesJson
            .map(
              (json) => FavoriteItem.fromJson(
                Map<String, String>.from(
                  jsonDecode(json) as Map<String, dynamic>,
                ),
              ),
            )
            .toList();

    allFavorites.removeWhere(
      (fav) =>
          fav.type == item.type &&
          fav.url == item.url &&
          fav.celebrityName == item.celebrityName,
    );

    await prefs.setStringList(
      'favorites',
      allFavorites.map((item) => jsonEncode(item.toJson())).toList(),
    );

    _loadFavorites();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Removed from favorites')));
    }
  }

  void _navigateToItem(FavoriteItem item) {
    if (item.type == 'celebrity') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => GalleryLinksPage(
                profileUrl: item.url,
                celebrityName: item.name,
                thumbnailUrl: item.thumbnailUrl,
              ),
        ),
      );
    } else {
      // For galleries, navigate to RagaDL
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => RagaDL(
                initialUrl: item.url,
                galleryTitle: item.name,
                initialFolder: item.celebrityName ?? '',
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (celebrities.isEmpty && galleries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No favorites yet'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: CustomScrollView(
        slivers: [
          // Favorite Celebrities Section
          if (celebrities.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Favorite Celebrities',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.55,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = celebrities[index];
                  return CelebrityCard(
                    imageUrl: item.thumbnailUrl ?? '',
                    title: item.name,
                    date: item.date,
                    onTap: () => _navigateToItem(item),
                    onActionPressed: () => _removeFavorite(item),
                    isLoadingAction: false,
                    actionLabel: 'Remove',
                  );
                }, childCount: celebrities.length),
              ),
            ),
          ],

          // Favorite Galleries Section
          if (galleries.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Favorite Galleries',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.55,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = galleries[index];
                  return CelebrityCard(
                    imageUrl: item.thumbnailUrl ?? '',
                    title: item.name,
                    date: item.date,
                    onTap: () => _navigateToItem(item),
                    onActionPressed: () => _removeFavorite(item),
                    isLoadingAction: false,
                    actionLabel: 'Remove',
                  );
                }, childCount: galleries.length),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
