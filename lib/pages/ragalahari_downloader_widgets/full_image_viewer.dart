import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../download_manager_page.dart';
import 'package:flutter/services.dart';
import '../ragalahari_downloader.dart';

class FullImageViewer extends StatefulWidget {
  final List<ImageData> imageUrls;
  final int initialIndex;

  const FullImageViewer({super.key, required this.imageUrls, required this.initialIndex});

  @override
  _FullImageViewerState createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;
  final List<TransformationController> _transformationControllers = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    for (int i = 0; i < widget.imageUrls.length; i++) {
      _transformationControllers.add(TransformationController());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _transformationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _downloadImage(String imageUrl) async {
    setState(() => _isDownloading = true);
    try {
      final downloadManager = DownloadManager();
      downloadManager.addDownload(
        url: imageUrl,
        folder: "SingleImages",
        subFolder: DateTime.now().toString().split(' ')[0],
        onProgress: (progress) {},
        onComplete: (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(success
                    ? 'Added to download manager'
                    : 'Failed to add download')));
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to download: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImageData = widget.imageUrls[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Image ${_currentIndex + 1} of ${widget.imageUrls.length}'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: currentImageData.originalUrl));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Image URL copied to clipboard')));
            },
          ),
          IconButton(
            icon: _isDownloading
                ? const CircularProgressIndicator()
                : const Icon(Icons.download),
            onPressed: _isDownloading
                ? null
                : () => _downloadImage(currentImageData.originalUrl),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final imageData = widget.imageUrls[index];
          return InteractiveViewer(
            transformationController: _transformationControllers[index],
            minScale: 0.1,
            maxScale: 4.0,
            child: Hero(
              tag: imageData.originalUrl,
              child: CachedNetworkImage(
                imageUrl: imageData.originalUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          );
        },
      ),
    );
  }
}