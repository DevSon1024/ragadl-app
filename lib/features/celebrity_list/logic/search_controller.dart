import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/celebrity_repository.dart';
import '../data/models/celebrity_model.dart';
import '../../celebrity/utils/celebrity_utils.dart';
import 'celebrity_controller.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchProvider = StateNotifierProvider<SearchController, List<CelebrityModel>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final sortOption = ref.watch(celebrityProvider.select((state) => state.sortOption));
  return SearchController(CelebrityRepository.instance, query, sortOption);
});

class SearchController extends StateNotifier<List<CelebrityModel>> {
  final CelebrityRepository _repository;
  Timer? _debouncer;
  final String _query;
  final SortOption _sortOption;

  SearchController(this._repository, this._query, this._sortOption) : super([]) {
    _performSearch();
  }

  void search(String query) {
    // Controller handles search state independently
  }

  CategoryOption _sortToCategory(SortOption option) {
    switch (option) {
      case SortOption.celebrityActors:
        return CategoryOption.actors;
      case SortOption.celebrityActresses:
        return CategoryOption.actresses;
      default:
        return CategoryOption.all;
    }
  }

  Future<void> _performSearch() async {
    if (_debouncer?.isActive ?? false) _debouncer!.cancel();
    
    _debouncer = Timer(const Duration(milliseconds: 500), () async {
      if (_query.isEmpty) {
        state = [];
        return;
      }

      try {
        final matches = await _repository.searchByName(
          query: _query,
          limit: 120,
          category: _sortToCategory(_sortOption),
        );
        
        state = matches.map((map) => CelebrityModel(
          name: map['name'] ?? 'Unknown',
          url: map['url'] ?? '',
        )).toList();
      } catch (_) {
        // Handle search errors silently in UI as it is typahead
      }
    });
  }

  @override
  void dispose() {
    _debouncer?.cancel();
    super.dispose();
  }
}
