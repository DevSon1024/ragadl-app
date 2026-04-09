import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/celebrity_utils.dart';

final favoritesServiceProvider = Provider<CommonFavoritesService>((ref) {
  return CommonFavoritesService();
});

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (ref) {
    final service = ref.watch(favoritesServiceProvider);
    return FavoritesNotifier(service);
  },
);

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final CommonFavoritesService _service;

  FavoritesNotifier(this._service) : super({}) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    state = await _service.loadFavorites(type: 'celebrity');
  }

  Future<bool> toggleFavorite(String name, String url) async {
    final isFavorite = state.contains(url);

    // Optimistic update
    final newSet = Set<String>.from(state);
    if (isFavorite) {
      newSet.remove(url);
    } else {
      newSet.add(url);
    }
    state = newSet;

    // Background process
    await _service.toggleFavorite(
      type: 'celebrity',
      name: name,
      url: url,
      isCurrentlyFavorite: isFavorite,
    );

    return !isFavorite;
  }
}

class CommonFavoritesService {
  static const String _favoriteKey = 'favorites';

  Future<Set<String>> loadFavorites({required String type}) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoriteKey) ?? [];
    final urls = <String>{};

    for (var jsonStr in favoritesJson) {
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (decoded['type'] == type && decoded['url'] != null) {
          urls.add(decoded['url'].toString());
        }
      } catch (_) {}
    }

    return urls;
  }

  Future<void> toggleFavorite({
    required String type,
    required String name,
    required String url,
    required bool isCurrentlyFavorite,
    String? thumbnailUrl,
    String? date,
    String? celebrityName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoriteKey) ?? [];

    List<FavoriteItem> favorites =
        favoritesJson.map((json) {
          final decoded = jsonDecode(json) as Map<String, dynamic>;
          return FavoriteItem.fromJson(
            decoded.map((key, value) => MapEntry(key, value?.toString() ?? '')),
          );
        }).toList();

    if (isCurrentlyFavorite) {
      favorites.removeWhere((item) => item.type == type && item.url == url);
    } else {
      final favoriteItem = FavoriteItem(
        type: type,
        name: name,
        url: url,
        thumbnailUrl: thumbnailUrl,
        date: date,
        celebrityName: celebrityName,
      );
      favorites.insert(0, favoriteItem);
    }

    await prefs.setStringList(
      _favoriteKey,
      favorites.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  // Static helpers for backwards compatibility with LatestController
  static Future<Set<String>> loadLatestFavorites() async {
    return CommonFavoritesService().loadFavorites(type: 'gallery');
  }

  static Future<bool> toggleLatestFavorite(
    dynamic item,
    Set<String> favoriteUrls,
  ) async {
    final url = item.url;
    final fallbackName =
        (item.name != null && item.name!.isNotEmpty) ? item.name! : item.title;

    final isFavorite = favoriteUrls.contains(url);

    await CommonFavoritesService().toggleFavorite(
      type: 'gallery',
      name: fallbackName,
      url: url,
      isCurrentlyFavorite: isFavorite,
      thumbnailUrl: item.image,
      date: item.date,
      celebrityName: fallbackName,
    );

    if (isFavorite) {
      favoriteUrls.remove(url);
      return false;
    } else {
      favoriteUrls.add(url);
      return true;
    }
  }
}
