import 'package:flutter/material.dart';
import '../../logic/gallery_scraper.dart';
import '../../logic/gallery_cache_service.dart';
import '../../../../shared/utils/celebrity_utils.dart';
import 'dart:math';

class GalleryLinksController extends ChangeNotifier {
  final GalleryScraper _scraper;
  final GalleryCacheService _cacheService;

  final String celebrityName;
  final String profileUrl;
  final String? thumbnailUrl;

  // State
  List<String> allGalleryUrls = [];
  Map<String, GalleryItem> loadedItems = {};
  List<String> filteredUrls = [];
  bool isLoadingUrls = true;
  String? error;

  int currentPage = 1;
  final int itemsPerPage = 30;
  final Set<int> loadingPages = {};
  final Set<int> loadedPages = {};

  bool isCelebrityFavorite = false;
  bool isNavigating = false;

  GalleryLinksController({
    required this.celebrityName,
    required this.profileUrl,
    this.thumbnailUrl,
    GalleryScraper? scraper,
    GalleryCacheService? cacheService,
  })  : _scraper = scraper ?? GalleryScraper(),
        _cacheService = cacheService ?? GalleryCacheService() {
    _init();
  }

  int get totalPages => (filteredUrls.length / itemsPerPage).ceil();

  List<String> get currentPageUrls {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = min(startIndex + itemsPerPage, filteredUrls.length);
    return filteredUrls.sublist(startIndex, endIndex);
  }

  Future<void> _init() async {
    isCelebrityFavorite = await _cacheService.isCelebrityInFavorites(celebrityName, profileUrl);
    notifyListeners();
    await loadAllData();
  }

  Future<void> loadAllData() async {
    // 1. Load from cache
    allGalleryUrls = await _cacheService.loadCachedUrls(profileUrl);
    loadedItems = await _cacheService.loadCachedItems(profileUrl);

    if (allGalleryUrls.isNotEmpty) {
      filteredUrls = List.from(allGalleryUrls);
      isLoadingUrls = false;
      notifyListeners();
      _loadPageItems(currentPage);
    }

    // 2. Fetch fresh URLs in background
    _fetchFreshGalleryUrls();
  }

  Future<void> _fetchFreshGalleryUrls() async {
    try {
      final result = await _scraper.fetchGalleryUrls(profileUrl);
      if (result.error != null) {
        error = result.error;
      } else if (result.urls != null) {
        allGalleryUrls = result.urls!;
        filteredUrls = List.from(allGalleryUrls);
        await _cacheService.cacheUrls(profileUrl, allGalleryUrls);

        if (!loadedPages.contains(currentPage)) {
          _loadPageItems(currentPage);
        }
      }
    } catch (e) {
      error = 'Failed to fetch gallery URLs: $e';
    } finally {
      isLoadingUrls = false;
      notifyListeners();
    }
  }

  Future<void> _loadPageItems(int page) async {
    if (loadingPages.contains(page) || loadedPages.contains(page)) return;

    loadingPages.add(page);
    notifyListeners();

    final startIndex = (page - 1) * itemsPerPage;
    final endIndex = min(startIndex + itemsPerPage, filteredUrls.length);
    final pageUrls = filteredUrls.sublist(startIndex, endIndex);

    final urlsToLoad = pageUrls.where((url) => !loadedItems.containsKey(url)).toList();

    if (urlsToLoad.isEmpty) {
      loadingPages.remove(page);
      loadedPages.add(page);
      notifyListeners();
      return;
    }

    try {
      final result = await _scraper.loadBatchItems(urlsToLoad);
      if (result.items != null) {
        for (final item in result.items!) {
          loadedItems[item.url] = item;
        }
        await _cacheService.cacheItems(profileUrl, loadedItems);
        loadedPages.add(page);
      }
    } finally {
      loadingPages.remove(page);
      notifyListeners();
    }
  }

  void filterGalleries(String query) {
    if (query.isEmpty) {
      filteredUrls = List.from(allGalleryUrls);
    } else {
      filteredUrls = allGalleryUrls.where((url) {
        final galleryId = url.split('/')
            .where((segment) => RegExp(r'^\d+$').hasMatch(segment))
            .firstOrNull;
        return galleryId != null && galleryId.startsWith(query);
      }).toList();
    }
    currentPage = 1;
    loadedPages.clear();
    notifyListeners();
    _loadPageItems(currentPage);
  }

  void changePage(int page) {
    currentPage = page;
    notifyListeners();
    _loadPageItems(page);
  }

  Future<void> toggleCelebrityFavorite() async {
    final isFav = await _cacheService.toggleCelebrityFavorite(celebrityName, profileUrl, thumbnailUrl);
    isCelebrityFavorite = isFav;
    notifyListeners();
  }

  Future<void> toggleGalleryFavorite(GalleryItem item) async {
    await _cacheService.toggleGalleryFavorite(item, celebrityName);
    notifyListeners(); // Refresh UI for the specific card
  }

  Future<bool> isGalleryFavorite(String url) async {
    return await _cacheService.isGalleryFavorite(url, celebrityName);
  }

  Future<bool> checkGalleryAvailability(String galleryUrl) async {
    if (isNavigating) return false;
    isNavigating = true;
    notifyListeners();

    try {
      return await _scraper.checkGalleryAvailability(galleryUrl);
    } finally {
      isNavigating = false;
      notifyListeners();
    }
  }
}