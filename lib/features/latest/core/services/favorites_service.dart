import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/latest_item.dart';

class FavoritesService {
  static Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritesJson = prefs.getStringList('favorites') ?? [];
    Set<String> urls = {};
    for (var jsonStr in favoritesJson) {
      final map = jsonDecode(jsonStr);
      if (map['type'] == 'gallery') {
        urls.add((map['url'] as String?) ?? '');
      }
    }
    return urls;
  }

  static Future<bool> toggleFavorite(LatestItem item, Set<String> favoriteUrls) async {
    final url = item.url;
    final fallbackName = (item.name != null && item.name!.isNotEmpty)
        ? item.name!
        : item.title;

    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritesJson = prefs.getStringList('favorites') ?? [];
    List<dynamic> allFavorites =
        favoritesJson.map((json) => jsonDecode(json)).toList();

    final isFavorite = favoriteUrls.contains(url);
    bool added = false;

    if (isFavorite) {
      allFavorites.removeWhere(
        (fav) => fav['type'] == 'gallery' && fav['url'] == url,
      );
      favoriteUrls.remove(url);
    } else {
      final newItem = {
        'type': 'gallery',
        'name': fallbackName,
        'url': url,
        'thumbnailUrl': item.image,
        'celebrityName': fallbackName,
        'date': item.date,
      };
      allFavorites.insert(0, newItem);
      favoriteUrls.add(url);
      added = true;
    }

    await prefs.setStringList(
      'favorites',
      allFavorites.map((i) => jsonEncode(i)).toList(),
    );
    
    return added;
  }
}
