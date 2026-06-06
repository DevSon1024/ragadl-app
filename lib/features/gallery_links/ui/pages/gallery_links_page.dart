import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/gallery_links_controller.dart';
import '../widgets/gallery_grid.dart';
import '../../../../shared/widgets/search_bar.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/loading_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../widgets/empty_view.dart';
import '../../../downloader/ui/pages/ragadl_page.dart';
import '../../../../shared/utils/celebrity_utils.dart';

class GalleryLinksPage extends StatefulWidget {
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
  State<GalleryLinksPage> createState() => _GalleryLinksPageState();
}

class _GalleryLinksPageState extends State<GalleryLinksPage> {
  late final GalleryLinksController _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = GalleryLinksController(
      celebrityName: widget.celebrityName,
      profileUrl: widget.profileUrl,
      thumbnailUrl: widget.thumbnailUrl,
    );

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _controller.filterGalleries(_searchController.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDownloadNavigation(String url, String title) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking gallery availability...')),
    );

    final isAvailable = await _controller.checkGalleryAvailability(url);
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

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
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
                  _controller.isCelebrityFavorite
                      ? Icons.star
                      : Icons.star_border,
                  color: _controller.isCelebrityFavorite ? Colors.amber : null,
                ),
                onPressed: _controller.toggleCelebrityFavorite,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: CommonSearchBar(
                controller: _searchController,
                isAppBarStyle: true,
                hintText:
                    widget.profileUrl.toLowerCase().contains('ragalahari.com')
                        ? 'Search gallery name...'
                        : 'Search by gallery code...',
                keyboardType:
                    widget.profileUrl.toLowerCase().contains('ragalahari.com')
                        ? TextInputType.text
                        : TextInputType.number,
              ),
            ),
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_controller.error != null) {
      return CommonErrorView(error: _controller.error!);
    }
    if (_controller.isLoadingUrls) {
      return const LoadingView();
    }
    if (_controller.filteredUrls.isEmpty) {
      return const EmptyView();
    }

    return Column(
      children: [
        if (_controller.loadingPages.contains(_controller.currentPage))
          LinearProgressIndicator(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          ),

        Expanded(
          child: GalleryGrid(
            controller: _controller,
            onTapCard: _handleDownloadNavigation,
          ),
        ),

        if (_controller.totalPages > 1)
          PaginationBar(
            currentPage: _controller.currentPage,
            totalPages: _controller.totalPages,
            onPageChanged: _controller.changePage,
          ),
      ],
    );
  }
}
