import 'dart:io';
import 'package:flutter/material.dart';
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
  _FullImageViewerState createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  late PageController _pageController;
  late ValueNotifier<int> _currentIndexNotifier;
  late List<TransformationController> _controllers;
  bool _firstBuild = true;

  @override
  void initState() {
    super.initState();
    _currentIndexNotifier = ValueNotifier<int>(widget.initialIndex);
    _pageController = PageController(initialPage: widget.initialIndex);
    _controllers = List.generate(widget.images.length, (_) => TransformationController());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_firstBuild) {
      _firstBuild = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final idx = _currentIndexNotifier.value;
        final len = widget.images.length;
        if (idx > 0) {
          precacheImage(FileImage(widget.images[idx - 1]), context);
        }
        if (idx < len - 1) {
          precacheImage(FileImage(widget.images[idx + 1]), context);
        }
      });
    }
  }

  @override
  void dispose() {
    _currentIndexNotifier.dispose();
    _pageController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _shareImage() async {
    final idx = _currentIndexNotifier.value;
    final imagePath = widget.images[idx].path;
    await Share.shareXFiles([XFile(imagePath)], text: 'Sharing image');
  }

  Future<void> _deleteImage() async {
    final idx = _currentIndexNotifier.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to move this image to the recycle bin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final imageFile = widget.images[idx];
    final newPath = imageFile.path.replaceFirst(
      RegExp(r'([^/]+)$'),
      '.trashed-${DateTime.now().millisecondsSinceEpoch}-${imageFile.path.split('/').last}',
    );

    try {
      await imageFile.rename(newPath);
      widget.images.removeAt(idx);
      _controllers.removeAt(idx);
      if (widget.images.isEmpty) {
        Navigator.pop(context);
      } else {
        final newLen = widget.images.length;
        final newIdx = idx >= newLen ? newLen - 1 : idx;
        _currentIndexNotifier.value = newIdx;
        setState(() {});
        _pageController.jumpToPage(newIdx);
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: ValueListenableBuilder<int>(
          valueListenable: _currentIndexNotifier,
          builder: (context, index, child) => Text(
            '${index + 1} of ${widget.images.length}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareImage,
            tooltip: 'Share Image',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _deleteImage,
            tooltip: 'Delete Image',
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: _currentIndexNotifier,
        builder: (context, index, child) {
          return Stack(
            children: [
              child!,
              if (index > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
              if (index < widget.images.length - 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                    onPressed: () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
            ],
          );
        },
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          onPageChanged: (int i) {
            _currentIndexNotifier.value = i;
            _controllers[i].value = Matrix4.identity();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final len = widget.images.length;
              if (i > 0) {
                precacheImage(FileImage(widget.images[i - 1]), context);
              }
              if (i < len - 1) {
                precacheImage(FileImage(widget.images[i + 1]), context);
              }
            });
          },
          itemBuilder: (context, index) {
            final controller = _controllers[index];
            return InteractiveViewer(
              transformationController: controller,
              minScale: 1.0,
              maxScale: 4.0,
              child: GestureDetector(
                onDoubleTap: () {
                  final size = MediaQuery.of(context).size;
                  final matrix = controller.value;
                  final currentScale = matrix.entry(0, 0).abs();
                  final targetScale = currentScale > 1.5 ? 1.0 : 2.0;
                  if (targetScale == 1.0) {
                    controller.value = Matrix4.identity();
                  } else {
                    final x = size.width / 2;
                    final y = size.height / 2;
                    controller.value = Matrix4.translationValues(-x, -y, 0)
                      ..scale(targetScale)
                      ..translate(x, y, 0);
                  }
                },
                child: Hero(
                  tag: widget.images[index],
                  child: Image.file(
                    widget.images[index],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}