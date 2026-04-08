import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../celebrity/utils/celebrity_utils.dart';

final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  return FavoritesService();
});

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  final service = ref.watch(favoritesServiceProvider);
  return FavoritesNotifier(service);
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final FavoritesService _service;

  FavoritesNotifier(this._service) : super({}) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    state = await _service.loadFavorites();
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
    await _service.toggleFavorite(name, url, isFavorite);
    
    return !isFavorite;
  }
}

class FavoritesService {
  static const String _favoriteKey = 'favorites';

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoriteKey) ?? [];
    final urls = <String>{};

    for (var jsonStr in favoritesJson) {
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (decoded['type'] == 'celebrity' && decoded['url'] != null) {
          urls.add(decoded['url'].toString());
        }
      } catch (_) {}
    }
    
    return urls;
  }

  Future<void> toggleFavorite(String name, String url, bool isCurrentlyFavorite) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoriteKey) ?? [];

    List<FavoriteItem> favorites = favoritesJson.map((json) {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return FavoriteItem.fromJson(
        decoded.map((key, value) => MapEntry(key, value?.toString() ?? '')),
      );
    }).toList();

    if (isCurrentlyFavorite) {
      favorites.removeWhere((item) =>
          item.type == 'celebrity' && item.name == name && item.url == url);
    } else {
      final favoriteItem = FavoriteItem(
        type: 'celebrity',
        name: name,
        url: url,
      );
      favorites.insert(0, favoriteItem);
    }

    await prefs.setStringList(
      _favoriteKey,
      favorites.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }
}
