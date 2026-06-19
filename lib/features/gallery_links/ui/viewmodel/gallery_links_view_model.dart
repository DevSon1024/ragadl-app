import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/gallery_repository.dart';
import '../../logic/gallery_cache_service.dart';
import '../../utils/gallery_utils.dart';
import '../../../../shared/utils/celebrity_utils.dart';

@immutable
class GalleryLinksParam {
  final String celebrityName;
  final String profileUrl;
  final String? thumbnailUrl;

  const GalleryLinksParam({
    required this.celebrityName,
    required this.profileUrl,
    this.thumbnailUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GalleryLinksParam &&
          runtimeType == other.runtimeType &&
          celebrityName == other.celebrityName &&
          profileUrl == other.profileUrl &&
          thumbnailUrl == other.thumbnailUrl;

  @override
  int get hashCode =>
      celebrityName.hashCode ^ profileUrl.hashCode ^ thumbnailUrl.hashCode;
}

@immutable
class GalleryLinksState {
  final List<String> allGalleryUrls;
  final Map<String, GalleryItem> loadedItems;
  final List<String> filteredUrls;
  final Set<String> favoriteUrls;
  final Map<String, String> urlToCodeMap;
  final int currentPage;
  final int itemsPerPage;
  final Set<int> loadingPages;
  final Set<int> loadedPages;
  final bool isCelebrityFavorite;
  final bool isNavigating;

  const GalleryLinksState({
    required this.allGalleryUrls,
    required this.loadedItems,
    required this.filteredUrls,
    required this.favoriteUrls,
    required this.urlToCodeMap,
    required this.currentPage,
    this.itemsPerPage = 30,
    required this.loadingPages,
    required this.loadedPages,
    required this.isCelebrityFavorite,
    required this.isNavigating,
  });

  int get totalPages => (filteredUrls.length / itemsPerPage).ceil();

  List<String> get currentPageUrls {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = min(startIndex + itemsPerPage, filteredUrls.length);
    if (startIndex >= filteredUrls.length) return const [];
    return filteredUrls.sublist(startIndex, endIndex);
  }

  GalleryLinksState copyWith({
    List<String>? allGalleryUrls,
    Map<String, GalleryItem>? loadedItems,
    List<String>? filteredUrls,
    Set<String>? favoriteUrls,
    Map<String, String>? urlToCodeMap,
    int? currentPage,
    Set<int>? loadingPages,
    Set<int>? loadedPages,
    bool? isCelebrityFavorite,
    bool? isNavigating,
  }) {
    return GalleryLinksState(
      allGalleryUrls: allGalleryUrls ?? this.allGalleryUrls,
      loadedItems: loadedItems ?? this.loadedItems,
      filteredUrls: filteredUrls ?? this.filteredUrls,
      favoriteUrls: favoriteUrls ?? this.favoriteUrls,
      urlToCodeMap: urlToCodeMap ?? this.urlToCodeMap,
      currentPage: currentPage ?? this.currentPage,
      itemsPerPage: itemsPerPage,
      loadingPages: loadingPages ?? this.loadingPages,
      loadedPages: loadedPages ?? this.loadedPages,
      isCelebrityFavorite: isCelebrityFavorite ?? this.isCelebrityFavorite,
      isNavigating: isNavigating ?? this.isNavigating,
    );
  }
}

final galleryLinksViewModelProvider = AsyncNotifierProvider.family
    .autoDispose<GalleryLinksViewModel, GalleryLinksState, GalleryLinksParam>(
  () => GalleryLinksViewModel(),
);

class GalleryLinksViewModel
    extends AutoDisposeFamilyAsyncNotifier<GalleryLinksState, GalleryLinksParam> {
  
  @override
  FutureOr<GalleryLinksState> build(GalleryLinksParam arg) async {
    final cacheService = ref.watch(galleryCacheServiceProvider);

    final isCelebrityFavorite = await cacheService.isCelebrityInFavorites(
      arg.celebrityName,
      arg.profileUrl,
    );
    final favoriteUrls = await cacheService.getFavoriteGalleryUrls(arg.celebrityName);
    final allGalleryUrls = await cacheService.loadCachedUrls(arg.profileUrl);
    final loadedItems = await cacheService.loadCachedItems(arg.profileUrl);

    Map<String, String> urlToCodeMap = {};
    List<String> filteredUrls = [];

    if (allGalleryUrls.isNotEmpty) {
      urlToCodeMap = _precomputeUrlCodes(allGalleryUrls);
      filteredUrls = List.from(allGalleryUrls);
    }

    final initialState = GalleryLinksState(
      allGalleryUrls: allGalleryUrls,
      loadedItems: loadedItems,
      filteredUrls: filteredUrls,
      favoriteUrls: favoriteUrls,
      urlToCodeMap: urlToCodeMap,
      currentPage: 1,
      loadingPages: {},
      loadedPages: {},
      isCelebrityFavorite: isCelebrityFavorite,
      isNavigating: false,
    );

    if (allGalleryUrls.isNotEmpty) {
      _loadPageItemsInBackground(initialState, 1);
      _fetchFreshGalleryUrlsInBackground(initialState);
      return initialState;
    } else {
      return _fetchFreshGalleryUrls(initialState);
    }
  }

  Map<String, String> _precomputeUrlCodes(List<String> urls) {
    final Map<String, String> map = {};
    for (final url in urls) {
      final galleryId = GalleryUtils.extractGalleryId(url);
      if (galleryId != null) {
        map[url] = galleryId;
      }
    }
    return map;
  }

  Future<GalleryLinksState> _fetchFreshGalleryUrls(GalleryLinksState currentState) async {
    final repository = ref.read(galleryRepositoryProvider);
    final cacheService = ref.read(galleryCacheServiceProvider);

    try {
      final result = await repository.fetchGalleryUrls(arg.profileUrl);
      if (result.error != null) {
        throw Exception(result.error);
      }
      final urls = result.urls ?? [];
      final urlToCodeMap = _precomputeUrlCodes(urls);
      await cacheService.cacheUrls(arg.profileUrl, urls);

      var updatedState = currentState.copyWith(
        allGalleryUrls: urls,
        filteredUrls: List.from(urls),
        urlToCodeMap: urlToCodeMap,
      );

      updatedState = await _loadPageItems(updatedState, updatedState.currentPage);
      return updatedState;
    } catch (e) {
      if (currentState.allGalleryUrls.isNotEmpty) {
        return currentState;
      } else {
        rethrow;
      }
    }
  }

  Future<void> _fetchFreshGalleryUrlsInBackground(GalleryLinksState currentState) async {
    final repository = ref.read(galleryRepositoryProvider);
    final cacheService = ref.read(galleryCacheServiceProvider);

    try {
      final result = await repository.fetchGalleryUrls(arg.profileUrl);
      if (result.error != null) {
        return;
      }
      final urls = result.urls ?? [];
      final urlToCodeMap = _precomputeUrlCodes(urls);
      await cacheService.cacheUrls(arg.profileUrl, urls);

      if (!state.hasValue) return;

      var updatedState = state.value!.copyWith(
        allGalleryUrls: urls,
        filteredUrls: List.from(urls),
        urlToCodeMap: urlToCodeMap,
      );

      if (!updatedState.loadedPages.contains(updatedState.currentPage)) {
        updatedState = await _loadPageItems(updatedState, updatedState.currentPage);
      }

      state = AsyncData(updatedState);
    } catch (_) {
      // Ignore background errors
    }
  }

  Future<GalleryLinksState> _loadPageItems(GalleryLinksState currentState, int page) async {
    if (currentState.loadingPages.contains(page) || currentState.loadedPages.contains(page)) {
      return currentState;
    }

    final loadingPages = Set<int>.from(currentState.loadingPages)..add(page);
    var updatedState = currentState.copyWith(loadingPages: loadingPages);

    state = AsyncData(updatedState);

    final startIndex = (page - 1) * updatedState.itemsPerPage;
    final endIndex = min(startIndex + updatedState.itemsPerPage, updatedState.filteredUrls.length);
    if (startIndex >= updatedState.filteredUrls.length) {
      final newLoadingPages = Set<int>.from(updatedState.loadingPages)..remove(page);
      return updatedState.copyWith(loadingPages: newLoadingPages);
    }

    final pageUrls = updatedState.filteredUrls.sublist(startIndex, endIndex);
    final urlsToLoad = pageUrls.where((url) => !updatedState.loadedItems.containsKey(url)).toList();

    if (urlsToLoad.isEmpty) {
      final newLoadingPages = Set<int>.from(updatedState.loadingPages)..remove(page);
      final loadedPages = Set<int>.from(updatedState.loadedPages)..add(page);
      return updatedState.copyWith(
        loadingPages: newLoadingPages,
        loadedPages: loadedPages,
      );
    }

    try {
      final repository = ref.read(galleryRepositoryProvider);
      final cacheService = ref.read(galleryCacheServiceProvider);

      final result = await repository.loadBatchItems(urlsToLoad);

      final newLoadedItems = Map<String, GalleryItem>.from(updatedState.loadedItems);
      if (result.items != null) {
        for (final item in result.items!) {
          newLoadedItems[item.url] = item;
        }
        await cacheService.cacheItems(arg.profileUrl, newLoadedItems);
      }

      final newLoadingPages = Set<int>.from(updatedState.loadingPages)..remove(page);
      final loadedPages = Set<int>.from(updatedState.loadedPages)..add(page);

      return updatedState.copyWith(
        loadedItems: newLoadedItems,
        loadingPages: newLoadingPages,
        loadedPages: loadedPages,
      );
    } catch (_) {
      final newLoadingPages = Set<int>.from(updatedState.loadingPages)..remove(page);
      return updatedState.copyWith(loadingPages: newLoadingPages);
    }
  }

  Future<void> _loadPageItemsInBackground(GalleryLinksState currentState, int page) async {
    try {
      final updatedState = await _loadPageItems(currentState, page);
      if (state.hasValue) {
        state = AsyncData(updatedState);
      }
    } catch (_) {}
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cacheService = ref.read(galleryCacheServiceProvider);

      final isCelebrityFavorite = await cacheService.isCelebrityInFavorites(
        arg.celebrityName,
        arg.profileUrl,
      );
      final favoriteUrls = await cacheService.getFavoriteGalleryUrls(arg.celebrityName);

      final initialState = GalleryLinksState(
        allGalleryUrls: [],
        loadedItems: {},
        filteredUrls: [],
        favoriteUrls: favoriteUrls,
        urlToCodeMap: {},
        currentPage: 1,
        loadingPages: {},
        loadedPages: {},
        isCelebrityFavorite: isCelebrityFavorite,
        isNavigating: false,
      );

      return _fetchFreshGalleryUrls(initialState);
    });
  }

  void filterGalleries(String query) async {
    if (!state.hasValue) return;

    final currentState = state.value!;
    List<String> filteredUrls;
    if (query.isEmpty) {
      filteredUrls = List.from(currentState.allGalleryUrls);
    } else {
      filteredUrls = currentState.allGalleryUrls.where((url) {
        final code = currentState.urlToCodeMap[url];
        return code != null && code.startsWith(query);
      }).toList();
    }

    var updatedState = currentState.copyWith(
      filteredUrls: filteredUrls,
      currentPage: 1,
      loadedPages: {},
    );

    state = AsyncData(updatedState);

    final afterLoadState = await _loadPageItems(updatedState, 1);
    state = AsyncData(afterLoadState);
  }

  void changePage(int page) async {
    if (!state.hasValue) return;

    var updatedState = state.value!.copyWith(currentPage: page);
    state = AsyncData(updatedState);

    final afterLoadState = await _loadPageItems(updatedState, page);
    state = AsyncData(afterLoadState);
  }

  Future<void> toggleCelebrityFavorite() async {
    if (!state.hasValue) return;

    final cacheService = ref.read(galleryCacheServiceProvider);
    final isFav = await cacheService.toggleCelebrityFavorite(
      arg.celebrityName,
      arg.profileUrl,
      arg.thumbnailUrl,
    );

    state = AsyncData(state.value!.copyWith(isCelebrityFavorite: isFav));
  }

  Future<void> toggleGalleryFavorite(GalleryItem item) async {
    if (!state.hasValue) return;

    final cacheService = ref.read(galleryCacheServiceProvider);
    await cacheService.toggleGalleryFavorite(item, arg.celebrityName);

    final favoriteUrls = Set<String>.from(state.value!.favoriteUrls);
    if (favoriteUrls.contains(item.url)) {
      favoriteUrls.remove(item.url);
    } else {
      favoriteUrls.add(item.url);
    }

    state = AsyncData(state.value!.copyWith(favoriteUrls: favoriteUrls));
  }

  Future<bool> checkGalleryAvailability(String galleryUrl) async {
    if (!state.hasValue || state.value!.isNavigating) return false;

    state = AsyncData(state.value!.copyWith(isNavigating: true));

    try {
      final repository = ref.read(galleryRepositoryProvider);
      return await repository.checkGalleryAvailability(galleryUrl);
    } finally {
      if (state.hasValue) {
        state = AsyncData(state.value!.copyWith(isNavigating: false));
      }
    }
  }
}
