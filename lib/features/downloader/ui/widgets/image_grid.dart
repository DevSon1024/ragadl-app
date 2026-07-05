import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/downloader_service.dart';
import '../../../settings/logic/settings_service.dart';
import '../controllers/downloader_controller.dart';
import '../utils/navigation_helper.dart';

class DownloaderImageGrid extends ConsumerWidget {
  final DownloaderController controller;

  const DownloaderImageGrid({
    super.key,
    required this.controller,
  });

  int _getColumnCount(BuildContext context, WidgetRef ref) {
    return ref.watch(settingsServiceProvider).gridColumns;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getColumnCount(context, ref),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final imageData = controller.imageUrls[index];
          final isSelected = controller.selectedImages.contains(index);

          return ImageGridItem(
            imageData: imageData,
            index: index,
            isSelected: isSelected,
            onTap: () {
              if (controller.isImgBB || controller.isSelectionMode) {
                controller.toggleSelection(index);
              } else {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.push(
                  context,
                  NavigationHelper.createModernPageRoute(
                    FullImagePage(
                      imageUrls: controller.imageUrls,
                      initialIndex: index,
                      downloaderService: controller.downloaderService,
                    ),
                  ),
                );
              }
            },
            onLongPress: () => controller.toggleSelection(index),
            theme: Theme.of(context),
          );
        }, childCount: controller.imageUrls.length),
      ),
    );
  }
}

class ImageGridItem extends StatelessWidget {
  final ImageData imageData;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ThemeData theme;

  const ImageGridItem({
    super.key,
    required this.imageData,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = theme.colorScheme;

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: color.surface,
          elevation: isSelected ? 8 : 2,
          shadowColor:
              isSelected
                  ? color.primary.withValues(alpha: 0.4)
                  : color.shadow.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border:
                    isSelected
                        ? Border.all(color: color.primary, width: 2)
                        : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Hero(
                      tag: imageData.originalUrl,
                      child: CachedNetworkImage(
                        imageUrl: imageData.thumbnailUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 250,
                        placeholder:
                            (context, url) => Shimmer.fromColors(
                              baseColor: color.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              highlightColor: color.surface,
                              child: Container(
                                color: color.surfaceContainerHighest,
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              color: color.errorContainer.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: color.error,
                              ),
                            ),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      decoration: BoxDecoration(
                        color: color.primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: color.onPrimary,
                          size: 16,
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Image ${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FullImagePage extends StatefulWidget {
  final List<ImageData> imageUrls;
  final int initialIndex;
  final DownloaderService downloaderService;

  const FullImagePage({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.downloaderService,
  });

  @override
  State<FullImagePage> createState() => _FullImagePageState();
}

class _FullImagePageState extends State<FullImagePage> {
  late PageController pageController;
  late int currentIndex;
  bool isDownloading = false;

  // State notifier to track if the current active image is zoomed in.
  // This is used to dynamically disable PageView horizontal swipe physics.
  late final ValueNotifier<bool> _isZoomedNotifier;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
    _isZoomedNotifier = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    pageController.dispose();
    _isZoomedNotifier.dispose();
    super.dispose();
  }

  Future<void> _downloadImage(String imageUrl) async {
    setState(() {
      isDownloading = true;
    });

    final result = await widget.downloaderService.downloadSingleImage(
      imageUrl: imageUrl,
    );

    if (mounted) {
      setState(() {
        isDownloading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success'] ? result['message'] : 'Failed: ${result['error']}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImageData = widget.imageUrls[currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        title: Text(
          'Image ${currentIndex + 1} of ${widget.imageUrls.length}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.copy),
              color: Colors.white,
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: currentImageData.originalUrl),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image URL copied to clipboard'),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon:
                  isDownloading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.download),
              color: Colors.white,
              onPressed:
                  isDownloading
                      ? null
                      : () => _downloadImage(currentImageData.originalUrl),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isZoomedNotifier,
        builder: (context, isZoomed, child) {
          return PageView.builder(
            controller: pageController,
            physics: isZoomed
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                currentIndex = index;
              });
              // Reset the zoom level state notifier on page transition
              _isZoomedNotifier.value = false;
            },
            itemBuilder: (context, index) {
              final imageData = widget.imageUrls[index];
              return ZoomableImageItem(
                imageData: imageData,
                onZoomChanged: (zoomed) {
                  // Only update the page scroll-locking state if the event belongs
                  // to the current visible page.
                  if (index == currentIndex) {
                    _isZoomedNotifier.value = zoomed;
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ZoomableImageItem extends StatefulWidget {
  final ImageData imageData;
  final ValueChanged<bool> onZoomChanged;

  const ZoomableImageItem({
    super.key,
    required this.imageData,
    required this.onZoomChanged,
  });

  @override
  State<ZoomableImageItem> createState() => _ZoomableImageItemState();
}

class _ZoomableImageItemState extends State<ZoomableImageItem>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;

  // Track the double-tap location to zoom in on that specific coordinate
  Offset _doubleTapPosition = Offset.zero;

  // Track whether the current image is zoomed to avoid redundant callbacks
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_handleTransformationChanged);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Listens to matrix updates from manual gestures or double-tap animations
  void _handleTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    // Using a tolerance slightly above 1.0 to account for floating-point inaccuracies
    final isZoomed = scale > 1.01;
    if (_isZoomed != isZoomed) {
      _isZoomed = isZoomed;
      widget.onZoomChanged(isZoomed);
    }
  }

  /// Stops any running animations when the user starts a manual gesture
  void _handleInteractionStart(ScaleStartDetails details) {
    if (_animationController.isAnimating) {
      _animationController.stop();
    }
  }

  /// Stores the location of the double tap down gesture
  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  /// Toggles zoom state smoothly centering on the double tap position
  void _handleDoubleTap() {
    if (_animationController.isAnimating) return;

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final bool isCurrentlyZoomed = currentScale > 1.01;

    final double targetScale = isCurrentlyZoomed ? 1.0 : 3.0;

    final Matrix4 begin = _transformationController.value;
    final Matrix4 end;

    if (targetScale == 1.0) {
      end = Matrix4.identity();
    } else {
      final x = _doubleTapPosition.dx;
      final y = _doubleTapPosition.dy;
      
      // Compute the pivot matrix around the tapped coordinate
      end = Matrix4.identity()
        ..translate(x, y)
        ..scale(targetScale)
        ..translate(-x, -y);
    }

    _zoomAnimation = Matrix4Tween(
      begin: begin,
      end: end,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _zoomAnimation!.addListener(_onAnimationTick);

    _animationController.forward(from: 0.0).then((_) {
      if (mounted) {
        _zoomAnimation?.removeListener(_onAnimationTick);
        _zoomAnimation = null;
      }
    });
  }

  void _onAnimationTick() {
    if (_zoomAnimation != null) {
      _transformationController.value = _zoomAnimation!.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 8.0,
        onInteractionStart: _handleInteractionStart,
        child: Hero(
          tag: widget.imageData.originalUrl,
          child: CachedNetworkImage(
            imageUrl: widget.imageData.originalUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }
}