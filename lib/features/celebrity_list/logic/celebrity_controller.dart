import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/celebrity_repository.dart';
import '../data/models/celebrity_model.dart';
import '../../../shared/utils/celebrity_utils.dart';

class CelebrityListState {
  final List<CelebrityModel> items;
  final bool hasMore;
  final int offset;
  final bool isFetchingNextPage;

  const CelebrityListState({
    required this.items,
    this.hasMore = true,
    this.offset = 0,
    this.isFetchingNextPage = false,
  });

  CelebrityListState copyWith({
    List<CelebrityModel>? items,
    bool? hasMore,
    int? offset,
    bool? isFetchingNextPage,
  }) {
    return CelebrityListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      isFetchingNextPage: isFetchingNextPage ?? this.isFetchingNextPage,
    );
  }
}

class CelebritySortNotifier extends Notifier<SortOption> {
  static const String _sortKey = 'sortOption';

  @override
  SortOption build() {
    _loadSavedSort();
    return SortOption.az;
  }

  Future<void> _loadSavedSort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSort = prefs.getString(_sortKey);
      if (savedSort != null) {
        final option = SortOption.values.firstWhere(
          (opt) => opt.toString() == savedSort,
          orElse: () => SortOption.az,
        );
        state = option;
      }
    } catch (_) {}
  }

  Future<void> changeSort(SortOption option) async {
    if (state == option) return;
    state = option;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sortKey, option.toString());
    } catch (_) {}
  }
}

final celebritySortProvider = NotifierProvider<CelebritySortNotifier, SortOption>(CelebritySortNotifier.new);

class CelebrityListViewModel extends AsyncNotifier<CelebrityListState> {
  static const int _pageSize = 50;

  @override
  Future<CelebrityListState> build() async {
    final repository = ref.watch(celebrityRepositoryProvider);
    final sort = ref.watch(celebritySortProvider);

    await repository.loadSources();

    final pageMaps = await repository.fetchPage(
      offset: 0,
      limit: _pageSize,
      sort: sort,
    );

    final items = pageMaps.map((map) => CelebrityModel(
      name: map['name'] ?? 'Unknown',
      url: map['url'] ?? '',
    )).toList();

    return CelebrityListState(
      items: items,
      hasMore: items.length == _pageSize,
      offset: items.length,
      isFetchingNextPage: false,
    );
  }

  Future<void> fetchNextPage() async {
    final currentState = state.valueOrNull;
    if (currentState == null || currentState.isFetchingNextPage || !currentState.hasMore) return;

    state = AsyncData(currentState.copyWith(isFetchingNextPage: true));

    try {
      final repository = ref.read(celebrityRepositoryProvider);
      final sort = ref.read(celebritySortProvider);

      final pageMaps = await repository.fetchPage(
        offset: currentState.offset,
        limit: _pageSize,
        sort: sort,
      );

      final newItems = pageMaps.map((map) => CelebrityModel(
        name: map['name'] ?? 'Unknown',
        url: map['url'] ?? '',
      )).toList();

      final updatedState = currentState.copyWith(
        items: [...currentState.items, ...newItems],
        offset: currentState.offset + newItems.length,
        hasMore: newItems.length == _pageSize,
        isFetchingNextPage: false,
      );

      state = AsyncData(updatedState);
    } catch (e, stackTrace) {
      if (state.hasValue) {
        state = AsyncData(state.requireValue.copyWith(isFetchingNextPage: false));
      } else {
        state = AsyncError(e, stackTrace);
      }
    }
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    ref.invalidateSelf();
  }
}

final celebrityListProvider = AsyncNotifierProvider<CelebrityListViewModel, CelebrityListState>(CelebrityListViewModel.new);
