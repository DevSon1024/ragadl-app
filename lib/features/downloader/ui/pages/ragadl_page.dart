import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'link_history_page.dart';
import '../controllers/downloader_controller.dart';
import '../utils/navigation_helper.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/controls_section.dart';
import '../widgets/loading_section.dart';
import '../../../../shared/widgets/error_view.dart';
import '../widgets/empty_state.dart';
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
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: color.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.help_outline_rounded, color: color.primary),
              onPressed: () {
                ControlsSection.showSupportedPortalsBottomSheet(context);
              },
              tooltip: 'Supported Portals',
            ),
          ),
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
      bottomNavigationBar: _buildBottomBar(context, controller),
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
                      if (url.isNotEmpty && controller.downloaderService.isValidUrl(url)) {
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
              if (controller.hasMorePages && !controller.isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                    child: controller.isLoadMoreLoading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : OutlinedButton.icon(
                            onPressed: () {
                              final url = controller.urlController.text.trim();
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
                                isLoadMore: true,
                              );
                            },
                            icon: const Icon(Icons.arrow_downward_rounded),
                            label: const Text('Load More Images'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                  ),
                ),
              if (!controller.isLoading && controller.imageUrls.isNotEmpty)
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
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

  Widget? _buildBottomBar(BuildContext context, DownloaderController controller) {
    if (controller.imageUrls.isEmpty || controller.isLoading) return null;

    final color = Theme.of(context).colorScheme;
    final isAllSelected = controller.selectedImages.length == controller.imageUrls.length;
    final isAnySelected = controller.selectedImages.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.surface,
        border: Border(
          top: BorderSide(
            color: color.outline.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: color.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Checkbox(
              value: isAllSelected,
              tristate: controller.selectedImages.isNotEmpty && !isAllSelected,
              onChanged: (bool? value) {
                HapticFeedback.lightImpact();
                controller.toggleSelectAll();
              },
            ),
            Text(
              'Select All',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            if (isAnySelected)
              Text(
                '(${controller.selectedImages.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color.primary,
                ),
              ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: !isAnySelected || controller.isDownloading
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      controller.downloadSelectedImages(
                        galleryTitle: widget.galleryTitle,
                        onResult: (success, message) {
                          SnackbarHelper.showModernSnackBar(
                            context: context,
                            message: message,
                            icon: success
                                ? Icons.download_for_offline_rounded
                                : Icons.error_rounded,
                            isError: !success,
                          );
                        },
                      );
                    },
              icon: controller.isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download_for_offline_rounded),
              label: Text(
                controller.isDownloading ? 'Downloading...' : 'Download Selected',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color.primary,
                foregroundColor: color.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ).copyWith(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return color.surfaceContainerHighest.withValues(alpha: 0.5);
                  }
                  return color.primary;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return color.onSurfaceVariant.withValues(alpha: 0.5);
                  }
                  return color.onPrimary;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
