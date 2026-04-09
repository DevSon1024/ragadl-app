import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'link_history_page.dart';
import '../controllers/downloader_controller.dart';
import '../utils/navigation_helper.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/controls_section.dart';
import '../widgets/loading_section.dart';
import '../../../../shared/widgets/common_error_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/floating_button.dart';
import '../widgets/image_grid.dart';

class RagaDL extends ConsumerStatefulWidget {
  final String? initialUrl;
  final String? initialFolder;
  final String? galleryTitle;

  const RagaDL({
    super.key,
    this.initialUrl,
    this.initialFolder,
    this.galleryTitle,
  });

  @override
  ConsumerState<RagaDL> createState() => _RagadlState();
}

class _RagadlState extends ConsumerState<RagaDL>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(downloaderControllerProvider).initializeFields(
        initialUrl: widget.initialUrl,
        initialFolder: widget.initialFolder,
        processGallery: (url) => ref.read(downloaderControllerProvider).processGallery(
          baseUrl: url,
          galleryTitle: widget.galleryTitle,
          context: context,
          showSnackBar: (msg, icon, {isError = false}) {
            SnackbarHelper.showModernSnackBar(
              context: context, 
              message: msg, 
              icon: icon, 
              isError: isError,
            );
          }
        ),
      );
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void didUpdateWidget(RagaDL oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != oldWidget.initialUrl ||
        widget.initialFolder != oldWidget.initialFolder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(downloaderControllerProvider).initializeFields(
          initialUrl: widget.initialUrl,
          initialFolder: widget.initialFolder,
          processGallery: (url) => ref.read(downloaderControllerProvider).processGallery(
            baseUrl: url,
            galleryTitle: widget.galleryTitle,
            context: context,
            showSnackBar: (msg, icon, {isError = false}) {
              SnackbarHelper.showModernSnackBar(
                context: context, 
                message: msg, 
                icon: icon, 
                isError: isError,
              );
            }
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final controller = ref.watch(downloaderControllerProvider);

    return Scaffold(
      backgroundColor: color.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: color.surface,
        surfaceTintColor: color.surfaceTint,
        title: const Text(
          'Gallery Downloader',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.history_rounded, color: color.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  NavigationHelper.createModernPageRoute(const LinkHistoryPage()),
                );
              },
              tooltip: 'Link History',
            ),
          ),
        ],
      ),
      floatingActionButton: DownloaderFloatingButton(
        controller: controller,
        galleryTitle: widget.galleryTitle,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ControlsSection(
                  controller: controller,
                  galleryTitle: widget.galleryTitle,
                ),
              ),
              if (controller.isLoading)
                SliverToBoxAdapter(
                  child: LoadingSection(controller: controller),
                ),
              if (controller.error != null)
                SliverToBoxAdapter(
                  child: CommonErrorView(
                    error: controller.error!,
                    isSection: true,
                    onRetry: () {
                      controller.clearError();
                      final url = controller.urlController.text.trim();
                      if (url.isNotEmpty && controller.downloaderService.isValidRagaUrl(url)) {
                        controller.processGallery(
                          baseUrl: url,
                          galleryTitle: widget.galleryTitle,
                          context: context,
                          showSnackBar: (msg, icon, {isError = false}) {
                            SnackbarHelper.showModernSnackBar(
                              context: context,
                              message: msg,
                              icon: icon,
                              isError: isError,
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              if (!controller.isLoading && controller.imageUrls.isNotEmpty)
                DownloaderImageGrid(controller: controller),
              if (!controller.isLoading && controller.imageUrls.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
