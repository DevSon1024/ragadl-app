import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class FullImageViewer extends StatefulWidget {
  final List<FileSystemEntity> images;
  final int initialIndex;

  const FullImageViewer({super.key, required this.images, required this.initialIndex});

  @override
  _FullImageViewerState createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _isDeleting = false;
  bool _showUI = true;
  bool _isLoading = false;
  final List<TransformationController> _transformationControllers = [];
  final FocusNode _focusNode = FocusNode();
  late AnimationController _uiAnimationController;
  late Animation<double> _uiAnimation;
  double _scale = 1.0;
  String? _imageInfo;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _uiAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _uiAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _uiAnimationController, curve: Curves.easeInOut),
    );
    _uiAnimationController.forward();

    for (int i = 0; i < widget.images.length; i++) {
      _transformationControllers.add(TransformationController());
    }

    _loadImageInfo();
    _autoHideUI();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _uiAnimationController.dispose();
    for (var controller in _transformationControllers) {
      controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _autoHideUI() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showUI) {
        _toggleUI();
      }
    });
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    if (_showUI) {
      _uiAnimationController.forward();
      _autoHideUI();
    } else {
      _uiAnimationController.reverse();
    }
  }

  Future<void> _loadImageInfo() async {
    setState(() => _isLoading = true);
    try {
      final currentImage = File(widget.images[_currentIndex].path);
      final stat = await currentImage.stat();
      final sizeInMB = (stat.size / (1024 * 1024)).toStringAsFixed(2);
      final fileName = currentImage.path.split('/').last;
      final lastModified = stat.modified.toString().split('.')[0];
      final resolution = await _getImageResolution(currentImage);

      setState(() {
        _imageInfo = '$fileName\nSize: ${sizeInMB}MB\nModified: $lastModified\nResolution: $resolution';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _imageInfo = 'Unable to load image info';
        _isLoading = false;
      });
    }
  }

  Future<String> _getImageResolution(File image) async {
    try {
      final bytes = await image.readAsBytes();
      final imageData = await decodeImageFromList(bytes);
      return '${imageData.width}x${imageData.height}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _deleteImage(File file) async {
    setState(() => _isDeleting = true);
    try {
      final fileName = file.path.split('/').last;
      final dirPath = file.path.substring(0, file.path.length - fileName.length);
      final trashedPath = '$dirPath.trashed-${DateTime.now().millisecondsSinceEpoch}-$fileName';
      await file.rename(trashedPath);

      if (mounted) {
        _showCustomSnackBar('Image moved to trash', Icons.delete, Colors.orange);
        final updatedImages = List<FileSystemEntity>.from(widget.images)..removeAt(_currentIndex);

        if (updatedImages.isEmpty) {
          Navigator.pop(context);
        } else {
          if (_currentIndex >= updatedImages.length) {
            _currentIndex = updatedImages.length - 1;
          }
          _pageController = PageController(initialPage: _currentIndex);
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => FullImageViewer(images: updatedImages, initialIndex: _currentIndex),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('Failed to move image: $e', Icons.error, Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showCustomSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showDeleteConfirmation(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Delete Image'),
          ],
        ),
        content: const Text('Are you sure you want to move this image to the trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteImage(file);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
  }

  void _showImageInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Image Information',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_imageInfo != null)
              Text(
                _imageInfo!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  'Copy Path',
                  Icons.copy,
                      () {
                    _copyImagePath(File(widget.images[_currentIndex].path).path);
                    Navigator.pop(context);
                  },
                ),
                _buildActionButton(
                  'Share',
                  Icons.share,
                      () {
                    Navigator.pop(context);
                    _shareImage();
                  },
                ),
                _buildActionButton(
                  'Open',
                  Icons.open_in_new,
                      () {
                    Navigator.pop(context);
                    _openFile(File(widget.images[_currentIndex].path).path);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: IconButton(
            icon: Icon(icon, color: Theme.of(context).primaryColor),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  void _copyImagePath(String path) {
    Clipboard.setData(ClipboardData(text: path));
    _showCustomSnackBar('Image path copied to clipboard', Icons.copy, Colors.green);
  }

  void _shareImage() async {
    try {
      final path = widget.images[_currentIndex].path;
      await Share.shareFiles(
        [path],
        text: 'Sharing image from Ragalahari Downloader',
      );
    } catch (e) {
      _showCustomSnackBar('Failed to share image: $e', Icons.error, Colors.red);
    }
  }

  void _openFile(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      _showCustomSnackBar('Could not open image: ${result.message}', Icons.error, Colors.red);
    }
  }

  void _navigateToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToNext() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _resetZoom() {
    _transformationControllers[_currentIndex].value = Matrix4.identity();
    setState(() => _scale = 1.0);
  }

  void _fitToScreen() {
    _transformationControllers[_currentIndex].value = Matrix4.identity()..scale(0.8);
    setState(() => _scale = 0.8);
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = File(widget.images[_currentIndex].path);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showUI
          ? AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} of ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showImageInfo,
            tooltip: 'Image Info',
          ),
          IconButton(
            icon: _isDeleting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _isDeleting ? null : () => _showDeleteConfirmation(currentImage),
            tooltip: 'Delete Image',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'reset_zoom':
                  _resetZoom();
                  break;
                case 'fit_screen':
                  _fitToScreen();
                  break;
                case 'copy_path':
                  _copyImagePath(currentImage.path);
                  break;
                case 'open_file':
                  _openFile(currentImage.path);
                  break;
                case 'share':
                  _shareImage();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset_zoom',
                child: Row(
                  children: [
                    Icon(Icons.zoom_out_map),
                    SizedBox(width: 8),
                    Text('Reset Zoom'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'fit_screen',
                child: Row(
                  children: [
                    Icon(Icons.fit_screen),
                    SizedBox(width: 8),
                    Text('Fit to Screen'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_path',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Copy Path'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_file',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new),
                    SizedBox(width: 8),
                    Text('Open in Explorer'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Share Image'),
                  ],
                ),
              ),
            ],
          ),
        ],
      )
          : null,
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _navigateToPrevious();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _navigateToNext();
            } else if (event.logicalKey == LogicalKeyboardKey.space) {
              _toggleUI();
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(context);
            }
          }
        },
        child: GestureDetector(
          onTap: _toggleUI,
          onDoubleTap: () {
            if (_scale > 1.0) {
              _resetZoom();
            } else {
              _transformationControllers[_currentIndex].value = Matrix4.identity()..scale(2.0);
              setState(() => _scale = 2.0);
            }
          },
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.images.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  _loadImageInfo();
                },
                itemBuilder: (context, index) {
                  final imageFile = File(widget.images[index].path);
                  return InteractiveViewer(
                    transformationController: _transformationControllers[index],
                    minScale: 0.1,
                    maxScale: 10.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: Hero(
                      tag: imageFile.path,
                      child: Center(
                        child: Image.file(
                          imageFile,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Unable to load image',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (widget.images.length > 1)
                AnimatedBuilder(
                  animation: _uiAnimation,
                  builder: (context, child) => Opacity(
                    opacity: _uiAnimation.value * 0.8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Material(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(30),
                              child: IconButton(
                                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                                onPressed: _currentIndex > 0 ? _navigateToPrevious : null,
                                splashRadius: 25,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Material(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(30),
                              child: IconButton(
                                icon: const Icon(Icons.chevron_right, color: Colors.white, size: 30),
                                onPressed: _currentIndex < widget.images.length - 1 ? _navigateToNext : null,
                                splashRadius: 25,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.images.length > 1)
                AnimatedBuilder(
                  animation: _uiAnimation,
                  builder: (context, child) => Positioned(
                    bottom: 30,
                    left: 16,
                    right: 16,
                    child: Transform.translate(
                      offset: Offset(0, 60 * (1 - _uiAnimation.value)),
                      child: Opacity(
                        opacity: _uiAnimation.value,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: widget.images.length <= 20
                                ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int i = 0; i < widget.images.length; i++)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                    decoration: BoxDecoration(
                                      color: i == _currentIndex
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                              ],
                            )
                                : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_currentIndex + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Text(
                                  '${widget.images.length}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}