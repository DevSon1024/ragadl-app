import '../data/models/celebrity_model.dart';
import '../../../shared/utils/celebrity_utils.dart';

class CelebrityState {
  final List<CelebrityModel> items;
  final bool isLoading;
  final bool isFetching;
  final bool hasMore;
  final SortOption sortOption;
  final String? errorMessage;
  final int offset;

  const CelebrityState({
    required this.items,
    this.isLoading = true,
    this.isFetching = false,
    this.hasMore = true,
    this.sortOption = SortOption.az,
    this.errorMessage,
    this.offset = 0,
  });

  CelebrityState copyWith({
    List<CelebrityModel>? items,
    bool? isLoading,
    bool? isFetching,
    bool? hasMore,
    SortOption? sortOption,
    String? errorMessage,
    int? offset,
  }) {
    return CelebrityState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isFetching: isFetching ?? this.isFetching,
      hasMore: hasMore ?? this.hasMore,
      sortOption: sortOption ?? this.sortOption,
      errorMessage: errorMessage,
      offset: offset ?? this.offset,
    );
  }
}
