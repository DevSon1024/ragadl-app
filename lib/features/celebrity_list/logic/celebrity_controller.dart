import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/celebrity_repository.dart';
import '../data/models/celebrity_model.dart';
import '../../celebrity/utils/celebrity_utils.dart';
import 'celebrity_state.dart';

final celebrityProvider = StateNotifierProvider<CelebrityController, CelebrityState>((ref) {
  return CelebrityController(CelebrityRepository.instance);
});

class CelebrityController extends StateNotifier<CelebrityState> {
  final CelebrityRepository _repository;
  static const int _pageSize = 50;
  static const String _sortKey = 'sortOption';

  CelebrityController(this._repository) : super(const CelebrityState(items: [])) {
    initialize();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, errorMessage: null, items: [], offset: 0, hasMore: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSort = prefs.getString(_sortKey);
      SortOption initialSort = SortOption.az;
      
      if (savedSort != null) {
        initialSort = SortOption.values.firstWhere(
          (opt) => opt.toString() == savedSort,
          orElse: () => SortOption.az,
        );
      }

      state = state.copyWith(sortOption: initialSort);
      
      await _repository.loadSources();
      await fetchNextPage(reset: true);
      
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load celebrities. Please try again.',
      );
    }
  }

  Future<void> fetchNextPage({bool reset = false}) async {
    if (state.isFetching || (!reset && !state.hasMore)) return;

    state = state.copyWith(isFetching: true);

    int currentOffset = reset ? 0 : state.offset;
    List<CelebrityModel> currentItems = reset ? [] : List.from(state.items);

    try {
      final pageMaps = await _repository.fetchPage(
        offset: currentOffset,
        limit: _pageSize,
        sort: state.sortOption,
      );

      final page = pageMaps.map((map) => CelebrityModel(
        name: map['name'] ?? 'Unknown',
        url: map['url'] ?? '',
      )).toList();

      state = state.copyWith(
        items: [...currentItems, ...page],
        offset: currentOffset + page.length,
        hasMore: page.length == _pageSize,
        isFetching: false,
      );
    } catch (e) {
      state = state.copyWith(isFetching: false);
    }
  }

  Future<void> changeSort(SortOption option) async {
    if (state.sortOption == option) return;

    state = state.copyWith(sortOption: option);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortKey, option.toString());
    
    await initialize();
  }

  void retry() {
    initialize();
  }
}
