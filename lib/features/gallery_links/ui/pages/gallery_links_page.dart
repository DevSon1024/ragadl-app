import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodel/gallery_links_view_model.dart';
import '../widgets/gallery_grid.dart';
import '../../../../shared/widgets/search_bar.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/loading_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../widgets/empty_view.dart';
import '../../../downloader/ui/pages/ragadl_page.dart';
import '../../../../shared/utils/celebrity_utils.dart';

class GalleryLinksPage extends ConsumerStatefulWidget {
  final String celebrityName;
  final String profileUrl;
  final String? thumbnailUrl;

  final DownloadSelectedCallback? onDownloadSelected;

  const GalleryLinksPage({
    super.key,
    required this.celebrityName,
    required this.profileUrl,
    this.thumbnailUrl,
    this.onDownloadSelected,
  });

  @override
  ConsumerState<GalleryLinksPage> createState() => _GalleryLinksPageState();
}

class _GalleryLinksPageState extends ConsumerState<GalleryLinksPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  late final GalleryLinksParam _param;

  @override
  void initState() {
    super.initState();
    _param = GalleryLinksParam(
      celebrityName: widget.celebrityName,
      profileUrl: widget.profileUrl,
      thumbnailUrl: widget.thumbnailUrl,
    );

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        ref
            .read(galleryLinksViewModelProvider(_param).notifier)
            .filterGalleries(_searchController.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleDownloadNavigation(String url, String title) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking gallery availability...')),
    );

    final isAvailable = await ref
        .read(galleryLinksViewModelProvider(_param).notifier)
        .checkGalleryAvailability(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (isAvailable) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  RagaDL(initialUrl: url, initialFolder: widget.celebrityName),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This gallery or image is not on the server'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncState = ref.watch(galleryLinksViewModelProvider(_param));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.celebrityName} - Galleries',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              asyncState.maybeWhen(
                data:
                    (state) =>
                        state.isCelebrityFavorite
                            ? Icons.star
                            : Icons.star_border,
                orElse: () => Icons.star_border,
              ),
              color: asyncState.maybeWhen(
                data:
                    (state) => state.isCelebrityFavorite ? Colors.amber : null,
                orElse: () => null,
              ),
            ),
            onPressed: () {
              ref
                  .read(galleryLinksViewModelProvider(_param).notifier)
                  .toggleCelebrityFavorite();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: CommonSearchBar(
            controller: _searchController,
            isAppBarStyle: true,
            hintText: 'Search by gallery code...',
            keyboardType: TextInputType.number,
          ),
        ),
      ),
      body: asyncState.when(
        loading: () => const LoadingView(),
        error:
            (err, stack) => CommonErrorView(
              error: err.toString().replaceAll('Exception: ', ''),
              onRetry:
                  () =>
                      ref
                          .read(galleryLinksViewModelProvider(_param).notifier)
                          .retry(),
            ),
        data: (state) {
          if (state.filteredUrls.isEmpty) {
            return const EmptyView();
          }

          return Column(
            children: [
              if (state.loadingPages.contains(state.currentPage))
                LinearProgressIndicator(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainer,
                ),

              Expanded(
                child: GalleryGrid(
                  state: state,
                  param: _param,
                  onTapCard: _handleDownloadNavigation,
                ),
              ),

              if (state.totalPages > 1)
                PaginationBar(
                  currentPage: state.currentPage,
                  totalPages: state.totalPages,
                  onPageChanged:
                      (page) => ref
                          .read(galleryLinksViewModelProvider(_param).notifier)
                          .changePage(page),
                ),
            ],
          );
        },
      ),
    );
  }
}
