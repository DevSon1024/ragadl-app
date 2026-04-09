import 'package:flutter/material.dart';
import '../models/latest_item.dart';
import '../services/latest_scraper_service.dart';
import '../../../../shared/services/favorites_service.dart';
import '../services/profile_fetch_service.dart';

class LatestController extends ChangeNotifier {
  final LatestScraperService _scraperService = LatestScraperService();
  
  List<LatestItem> items = [];
  bool isLoading = true;
  Map<int, bool> loadingProfileLinks = {};
  Set<String> favoriteUrls = {};

  Future<void> initialize(String endpointUrl) async {
    await loadFavorites();
    await fetchItems(endpointUrl);
  }

  Future<void> loadFavorites() async {
    favoriteUrls = await CommonFavoritesService.loadLatestFavorites();
    notifyListeners();
  }

  Future<void> toggleFavorite(BuildContext context, int index) async {
    final item = items[index];
    final fallbackName = (item.name != null && item.name!.isNotEmpty)
        ? item.name!
        : item.title;
        
    bool added = await CommonFavoritesService.toggleLatestFavorite(item, favoriteUrls);
    notifyListeners();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added ? 'Added $fallbackName to favorites' : 'Removed $fallbackName from favorites'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> fetchItems(String url) async {
    isLoading = true;
    notifyListeners();
    try {
      items = await _scraperService.fetchStarzoneLinks(url);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCelebrityName(BuildContext context, int index) async {
    final item = items[index];
    await ProfileFetchService.fetchCelebrityName(context, item, (name, href) {
      items[index].name = name;
      items[index].profileLink = href;
      notifyListeners();
    });
  }

  Future<void> fetchAndNavigateToProfile(BuildContext context, int index) async {
    final item = items[index];
    await ProfileFetchService.fetchAndNavigateToProfile(
      context,
      item,
      () {
        loadingProfileLinks[index] = true;
        notifyListeners();
      },
      (name, href) {
        if (name != null) items[index].name = name;
        if (href != null) items[index].profileLink = href;
        loadingProfileLinks[index] = false;
        notifyListeners();
      },
    );
  }
}
