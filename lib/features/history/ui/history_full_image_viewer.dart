import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class FullImageViewer extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const FullImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late ValueNotifier<int> _currentIndexNotifier;
  late List<TransformationController> _controllers;
  late AnimationController _uiAnimController;
  late Animation<double> _uiAnim;

  // Image cache
  final Map<int, ImageProvider> _imageCache = {};
  final Set<int> _precachedIndices = {};

  bool _firstBuild = true;
  bool _showControls = true;
  bool _isZoomed = false;

  //  System UI
  // We use edgeToEdge so the status-bar and nav-bar are ALWAYS drawn (just
  // transparent).  This means the host page's insets never change on pop,
  // eliminating the layout jitter.
  static void _applyViewerSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  //  Lifecycle
  @override
  void initState() {
    super.initState();
    _currentIndexNotifier = ValueNotifier(widget.initialIndex);
    _pageController = PageController(initialPage: widget.initialIndex);
    _controllers = List.generate(
      widget.images.length,
      (_) => TransformationController(),
    );

    _uiAnimController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _uiAnim = CurvedAnimation(
      parent: _uiAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _uiAnimController.forward();

    _applyViewerSystemUI();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_firstBuild) {
      _firstBuild = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _precacheAdjacentImages(_currentIndexNotifier.value);
      });
    }
  }

  @override
  void dispose() {
    // Restore the exact same edgeToEdge mode the rest of the app uses, but
    // with the app's standard overlay style (light icons on coloured bars).
    // We do NOT toggle back to manual/immersive, so no inset change occurs.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _currentIndexNotifier.dispose();
    _pageController.dispose();
    _uiAnimController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    _imageCache.clear();
    _precachedIndices.clear();
    super.dispose();
  }

  //  Image caching
  void _precacheAdjacentImages(int current) {
    final len = widget.images.length;
    final toCache = <int>[
      current,
      if (current > 0) current - 1,
      if (current > 1) current - 2,
      if (current < len - 1) current + 1,
      if (current < len - 2) current + 2,
    ];
    for (final i in toCache) {
      if (!_precachedIndices.contains(i)) {
        final provider = FileImage(widget.images[i]);
        _imageCache[i] = provider;
        precacheImage(
          provider,
          context,
        ).then((_) => _precachedIndices.add(i)).catchError((Object e) {
          debugPrint('Failed to precache image at index $i: $e');
          return false; // satisfy FutureOr<bool>
        });
      }
    }
    _cleanupDistantCache(current);
  }

  void _cleanupDistantCache(int current) {
    final stale =
        _imageCache.keys.where((i) => (i - current).abs() > 3).toList();
    for (final i in stale) {
      _imageCache.remove(i);
      _precachedIndices.remove(i);
    }
  }

  //  Controls toggle
  void _toggleControls() {
    if (_isZoomed) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _uiAnimController.forward();
    } else {
      _uiAnimController.reverse();
    }
  }

  //  Actions
  Future<void> _shareImage() async {
    HapticFeedback.mediumImpact();
    final idx = _currentIndexNotifier.value;
    await Share.shareXFiles([
      XFile(widget.images[idx].path),
    ], text: 'Sharing image from RagaDL');
  }

  Future<void> _deleteImage() async {
    final idx = _currentIndexNotifier.value;
    final confirmed = await _showDeleteDialog();
    if (confirmed != true) return;

    HapticFeedback.heavyImpact();
    final imageFile = widget.images[idx];
    final newPath = imageFile.path.replaceFirst(
      RegExp(r'([^/]+)$'),
      '.trashed-${DateTime.now().millisecondsSinceEpoch}-${imageFile.path.split('/').last}',
    );

    try {
      await imageFile.rename(newPath);
      _imageCache.remove(idx);
      _precachedIndices.remove(idx);
      widget.images.removeAt(idx);
      _controllers.removeAt(idx);

      if (widget.images.isEmpty) {
        if (mounted) Navigator.pop(context);
      } else {
        final newLen = widget.images.length;
        final newIdx = idx >= newLen ? newLen - 1 : idx;
        _currentIndexNotifier.value = newIdx;
        setState(() {});
        _pageController.jumpToPage(newIdx);
        _precacheAdjacentImages(newIdx);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image moved to recycle bin'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete image: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<bool?> _showDeleteDialog() {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Delete Image',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: const Text(
              'Are you sure you want to move this image to the recycle bin?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  //  Zoom interaction
  void _onInteractionUpdate(
    ScaleUpdateDetails details,
    TransformationController controller,
  ) {
    final scale = controller.value.getMaxScaleOnAxis();
    final nowZoomed = scale > 1.1;
    if (nowZoomed != _isZoomed) {
      setState(() {
        _isZoomed = nowZoomed;
        if (_isZoomed && _showControls) {
          _showControls = false;
          _uiAnimController.reverse();
        }
      });
    }
  }

  void _onInteractionEnd(ScaleEndDetails details, int index) {
    final scale = _controllers[index].value.getMaxScaleOnAxis();
    if (scale < 1.05 && scale > 0.95) {
      _controllers[index].value = Matrix4.identity();
      setState(() {
        _isZoomed = false;
        if (!_showControls) {
          _showControls = true;
          _uiAnimController.forward();
        }
      });
    }
  }

  void _handleDoubleTap(int index) {
    final controller = _controllers[index];
    final currentScale = controller.value.getMaxScaleOnAxis();
    final targetScale = currentScale > 1.5 ? 1.0 : 3.5;

    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final begin = controller.value;
    final end = targetScale == 1.0
        ? Matrix4.identity()
        : (Matrix4.translationValues(cx, cy, 0)
          ..multiply(Matrix4.diagonal3Values(targetScale, targetScale, 1))
          ..multiply(Matrix4.translationValues(-cx, -cy, 0)));

    final animCtrl = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    final animation = Matrix4Tween(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: animCtrl, curve: Curves.easeOut));

    animation.addListener(() => controller.value = animation.value);
    animCtrl.forward().then((_) {
      animCtrl.dispose();
      setState(() {
        _isZoomed = targetScale > 1.0;
        if (_isZoomed && _showControls) {
          _showControls = false;
          _uiAnimController.reverse();
        } else if (!_isZoomed && !_showControls) {
          _showControls = true;
          _uiAnimController.forward();
        }
      });
    });
    HapticFeedback.mediumImpact();
  }

  //  Build
  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          //  Image pager
          _buildPageView(),

          //  Top bar
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar(padding)),

          //  Side nav arrows
          if (_showControls && !_isZoomed) _buildSideNavButtons(),

          //  Bottom info pill
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(padding),
          ),
        ],
      ),
    );
  }

  //  Top bar
  Widget _buildTopBar(EdgeInsets padding) {
    return FadeTransition(
      opacity: _uiAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(_uiAnim),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: EdgeInsets.only(
                top: padding.top,
                left: 8,
                right: 8,
                bottom: 12,
              ),
              child: Row(
                children: [
                  // Back button
                  _GlassButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 8),

                  // Counter pill
                  Expanded(
                    child: Center(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _currentIndexNotifier,
                        builder: (context, index, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              '${index + 1} / ${widget.images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Share
                  _GlassButton(
                    icon: Icons.share_rounded,
                    onPressed: _shareImage,
                  ),
                  const SizedBox(width: 4),
                  // Delete
                  _GlassButton(
                    icon: Icons.delete_outline_rounded,
                    onPressed: _deleteImage,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  //  Page view
  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.images.length,
      physics:
          _isZoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
      onPageChanged: (i) {
        _currentIndexNotifier.value = i;
        for (int j = 0; j < _controllers.length; j++) {
          if (j != i) _controllers[j].value = Matrix4.identity();
        }
        setState(() {
          _isZoomed = false;
          if (!_showControls) {
            _showControls = true;
            _uiAnimController.forward();
          }
        });
        HapticFeedback.selectionClick();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _precacheAdjacentImages(i),
        );
      },
      itemBuilder: (context, index) => _buildImageItem(index),
    );
  }

  Widget _buildImageItem(int index) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      onDoubleTap: () => _handleDoubleTap(index),
      child: InteractiveViewer(
        transformationController: _controllers[index],
        minScale: 1.0,
        maxScale: 15.0,
        panEnabled: _isZoomed,
        scaleEnabled: true,
        constrained: true,
        onInteractionUpdate:
            (d) => _onInteractionUpdate(d, _controllers[index]),
        onInteractionEnd: (d) => _onInteractionEnd(d, index),
        child: Hero(
          tag: widget.images[index].path,
          child: Center(child: _buildCachedImage(index)),
        ),
      ),
    );
  }

  Widget _buildCachedImage(int index) {
    final imageProvider = _imageCache[index] ?? FileImage(widget.images[index]);

    return Image(
      image: imageProvider,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child:
              frame == null
                  ? Container(
                    key: const ValueKey('loading'),
                    color: Colors.grey[900],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white54,
                        ),
                      ),
                    ),
                  )
                  : SizedBox(key: const ValueKey('loaded'), child: child),
        );
      },
      errorBuilder:
          (context, error, _) => Container(
            color: Colors.grey[900],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white38,
                    size: 64,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  //  Side nav arrows
  Widget _buildSideNavButtons() {
    return ValueListenableBuilder<int>(
      valueListenable: _currentIndexNotifier,
      builder: (context, index, _) {
        return Stack(
          children: [
            if (index > 0)
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildNavArrow(
                    icon: Icons.chevron_left_rounded,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                      );
                    },
                  ),
                ),
              ),
            if (index < widget.images.length - 1)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildNavArrow(
                    icon: Icons.chevron_right_rounded,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNavArrow({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 30),
            onPressed: onPressed,
            padding: const EdgeInsets.all(10),
          ),
        ),
      ),
    );
  }

  //  Bottom panel
  Widget _buildBottomPanel(EdgeInsets padding) {
    return FadeTransition(
      opacity: _uiAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(_uiAnim),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: padding.bottom + 16,
              ),
              child: ValueListenableBuilder<int>(
                valueListenable: _currentIndexNotifier,
                builder: (context, index, _) {
                  final fileName = widget.images[index].path.split('/').last;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // File name
                      Text(
                        fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Meta row: size + hint
                      Row(
                        children: [
                          FutureBuilder<int>(
                            future: widget.images[index].length(),
                            builder: (context, snap) {
                              if (!snap.hasData) return const SizedBox.shrink();
                              final kb = (snap.data! / 1024).toStringAsFixed(1);
                              return Row(
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$kb KB',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const Spacer(),
                          Icon(
                            Icons.touch_app_outlined,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tap · double-tap to zoom',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

//  Reusable glass icon button
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 20),
            onPressed: onPressed,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ),
      ),
    );
  }
}
