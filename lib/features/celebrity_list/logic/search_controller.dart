import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/celebrity_repository.dart';
import '../data/models/celebrity_model.dart';
import '../../../shared/utils/celebrity_utils.dart';
import 'celebrity_controller.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

class DebouncedQuery extends Notifier<String> {
  Timer? _timer;

  @override
  String build() {
    final query = ref.watch(searchQueryProvider);

    if (query.isEmpty) {
      return '';
    }

    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () {
      state = query;
    });

    ref.onDispose(() {
      _timer?.cancel();
    });

    return state;
  }
}

final debouncedQueryProvider = NotifierProvider<DebouncedQuery, String>(DebouncedQuery.new);

final searchProvider = FutureProvider<List<CelebrityModel>>((ref) async {
  final query = ref.watch(debouncedQueryProvider);
  if (query.isEmpty) return const [];

  final sortOption = ref.watch(celebritySortProvider);
  final repository = ref.watch(celebrityRepositoryProvider);

  CategoryOption sortToCategory(SortOption option) {
    switch (option) {
      case SortOption.celebrityActors:
        return CategoryOption.actors;
      case SortOption.celebrityActresses:
        return CategoryOption.actresses;
      default:
        return CategoryOption.all;
    }
  }

  final matches = await repository.searchByName(
    query: query,
    limit: 120,
    category: sortToCategory(sortOption),
  );

  return matches.map((map) => CelebrityModel(
    name: map['name'] ?? 'Unknown',
    url: map['url'] ?? '',
  )).toList();
});
