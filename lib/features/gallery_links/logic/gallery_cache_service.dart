// lib/features/gallery_links/logic/gallery_cache_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../celebrity/utils/celebrity_utils.dart';

class GalleryCacheService {
  static const String _favoriteKey = 'favorites';

  Future<List<String>> loadCachedUrls(String profileUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'gallery_urls_${profileUrl.hashCode}';
    final cachedData = prefs.getString(cacheKey);

    if (cachedData != null) {
      final List<dynamic> jsonData = jsonDecode(cachedData);
      return jsonData.cast<String>();
    }
    return [];
  }

  Future<void> cacheUrls(String profileUrl, List<String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'gallery_urls_${profileUrl.hashCode}';
    await prefs.setString(cacheKey, jsonEncode(urls));
  }

  Future<Map<String, GalleryItem>> loadCachedItems(String profileUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'gallery_items_${profileUrl.hashCode}';
    final cachedData = prefs.getString(cacheKey);

    if (cachedData != null) {
      final Map<String, dynamic> jsonData = jsonDecode(cachedData);
      // FIXED: Added <String, GalleryItem> to strongly type the map
      return jsonData.map<String, GalleryItem>((url, data) => MapEntry(
        url,
        GalleryItem(
          url: data['url'],
          title: data['title'],
          thumbnailUrl: data['thumbnailUrl'],
          pages: data['pages'],
          date: DateTime.parse(data['date']),
        ),
      ));
    }
    return {};
  }

  Future<void> cacheItems(String profileUrl, Map<String, GalleryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'gallery_items_${profileUrl.hashCode}';
    final jsonData = items.map((url, item) => MapEntry(url, {
      'url': item.url,
      'title': item.title,
      'thumbnailUrl': item.thumbnailUrl,
      'pages': item.pages,
      'date': item.date.toIso8601String(),
    }));
    await prefs.setString(cacheKey, jsonEncode(jsonData));
  }

  // --- Favorites Logic ---

  Future<List<FavoriteItem>> _getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoriteKey) ?? [];
    return favoritesJson.map((json) =>
        FavoriteItem.fromJson(Map<String, String>.from(jsonDecode(json) as Map<String, dynamic>))
    ).toList();
  }

  Future<void> _saveFavorites(List<FavoriteItem> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteKey, favorites.map((item) => jsonEncode(item.toJson())).toList());
  }

  Future<bool> isCelebrityInFavorites(String name, String url) async {
    final favorites = await _getFavorites();
    return favorites.any((item) => item.type == 'celebrity' && item.name == name && item.url == url);
  }

  Future<bool> toggleCelebrityFavorite(String name, String url, String? thumbnailUrl) async {
    List<FavoriteItem> favorites = await _getFavorites();

    final isFavorite = favorites.any((fav) => fav.type == 'celebrity' && fav.name == name && fav.url == url);

    if (isFavorite) {
      favorites.removeWhere((fav) => fav.type == 'celebrity' && fav.name == name && fav.url == url);
    } else {
      favorites.insert(0, FavoriteItem(
        type: 'celebrity',
        name: name,
        url: url,
        thumbnailUrl: thumbnailUrl,
        celebrityName: name,
        date: DateFormat('MMM dd, yyyy').format(DateTime.now()),
      ));
    }

    await _saveFavorites(favorites);
    return !isFavorite;
  }

  Future<bool> isGalleryFavorite(String url, String celebrityName) async {
    final favorites = await _getFavorites();
    return favorites.any((item) => item.type == 'gallery' && item.url == url && item.celebrityName == celebrityName);
  }

  Future<void> toggleGalleryFavorite(GalleryItem item, String celebrityName) async {
    List<FavoriteItem> favorites = await _getFavorites();

    final isFavorite = favorites.any((fav) => fav.type == 'gallery' && fav.url == item.url && fav.celebrityName == celebrityName);

    if (isFavorite) {
      favorites.removeWhere((fav) => fav.type == 'gallery' && fav.url == item.url && fav.celebrityName == celebrityName);
    } else {
      favorites.add(FavoriteItem(
        type: 'gallery',
        name: item.title,
        url: item.url,
        thumbnailUrl: item.thumbnailUrl,
        celebrityName: celebrityName,
        date: DateFormat('MMM dd, yyyy').format(item.date),
      ));
    }

    await _saveFavorites(favorites);
  }
}