import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';
import 'history_page.dart';

enum ViewPreset {
  images,
  galleriesFolder,
  celebrityAlbum,
}

enum ViewType {
  list,
  grid,
}

class ViewPresetSelector extends StatelessWidget {
  final ViewPreset currentPreset;
  final ViewType currentViewType;
  final Function(ViewPreset) onPresetSelected;
  final Function(ViewType) onViewTypeSelected;

  const ViewPresetSelector({
    super.key,
    required this.currentPreset,
    required this.currentViewType,
    required this.onPresetSelected,
    required this.onViewTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'View Preset',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.image,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Images'),
            trailing: currentPreset == ViewPreset.images
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onPresetSelected(ViewPreset.images),
          ),
          ListTile(
            leading: Icon(
              Icons.folder,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Galleries Folder'),
            trailing: currentPreset == ViewPreset.galleriesFolder
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onPresetSelected(ViewPreset.galleriesFolder),
          ),
          ListTile(
            leading: Icon(
              Icons.person,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Celebrity Album'),
            trailing: currentPreset == ViewPreset.celebrityAlbum
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onPresetSelected(ViewPreset.celebrityAlbum),
          ),
          const Divider(),
          const Text(
            'View Type',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.list,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('List View'),
            trailing: currentViewType == ViewType.list
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onViewTypeSelected(ViewType.list),
          ),
          ListTile(
            leading: Icon(
              Icons.grid_view,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Grid View'),
            trailing: currentViewType == ViewType.grid
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onViewTypeSelected(ViewType.grid),
          ),
        ],
      ),
    );
  }
}

class SortOptionsSheet extends StatelessWidget {
  final SortOption currentSort;
  final Function(SortOption) onSortSelected;

  const SortOptionsSheet({
    super.key,
    required this.currentSort,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sort By',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.access_time,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Newest First'),
            trailing: currentSort == SortOption.newest
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onSortSelected(SortOption.newest),
          ),
          ListTile(
            leading: Icon(
              Icons.access_time,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Oldest First'),
            trailing: currentSort == SortOption.oldest
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onSortSelected(SortOption.oldest),
          ),
          ListTile(
            leading: Icon(
              Icons.storage,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Largest First'),
            trailing: currentSort == SortOption.largest
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onSortSelected(SortOption.largest),
          ),
          ListTile(
            leading: Icon(
              Icons.storage,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('Smallest First'),
            trailing: currentSort == SortOption.smallest
                ? Icon(
              Icons.check,
              color: Theme.of(context).iconTheme.color,
            )
                : null,
            onTap: () => onSortSelected(SortOption.smallest),
          ),
        ],
      ),
    );
  }
}

class FullImageViewer extends StatefulWidget {
  final List<FileSystemEntity> images;
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
  late int _currentIndex;
  bool _isDeleting = false;
  final List<TransformationController> _transformationControllers = [];
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    for (int i = 0; i < widget.images.length; i++) {
      _transformationControllers.add(TransformationController());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _transformationControllers) {
      controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _deleteImage(File file) async {
    setState(() => _isDeleting = true);
    try {
      final fileName = file.path.split('/').last;
      final dirPath = file.path.substring(0, file.path.length - fileName.length);
      final trashedPath = '$dirPath.trashed-${DateTime.now().millisecondsSinceEpoch}-$fileName';
      await file.rename(trashedPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image moved to recycle bin')),
        );
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
              pageBuilder: (_, __, ___) => FullImageViewer(
                images: updatedImages,
                initialIndex: _currentIndex,
              ),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showDeleteConfirmation(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to move this image to the recycle bin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteImage(file);
              Navigator.pop(context);
            },
            child: const Text('Move to Recycle Bin', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _copyImagePath(String path) {
    Clipboard.setData(ClipboardData(text: path));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image path copied to clipboard')),
    );
  }

  void _openFile(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open image: ${result.message}')),
      );
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

  @override
  Widget build(BuildContext context) {
    final currentImage = File(widget.images[_currentIndex].path);
    return Scaffold(
      appBar: AppBar(
        title: Text('Image ${_currentIndex + 1} of ${widget.images.length}'),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.copy,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () => _copyImagePath(currentImage.path),
            tooltip: 'Copy Path',
          ),
          IconButton(
            icon: _isDeleting
                ? const CircularProgressIndicator()
                : Icon(
              Icons.delete,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: _isDeleting ? null : () => _showDeleteConfirmation(currentImage),
            tooltip: 'Delete Image',
          ),
          IconButton(
            icon: Icon(
              Icons.open_in_new,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () => _openFile(currentImage.path),
            tooltip: 'Open in File Explorer',
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _navigateToPrevious();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _navigateToNext();
            }
          }
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final imageFile = File(widget.images[index].path);
                return InteractiveViewer(
                  transformationController: _transformationControllers[index],
                  minScale: 0.1,
                  maxScale: 4.0,
                  child: Hero(
                    tag: imageFile.path,
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (widget.images.length > 1) ...[
              Positioned(
                left: 16,
                top: MediaQuery.of(context).size.height / 2 - 24,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: _currentIndex > 0 ? _navigateToPrevious : null,
                  backgroundColor: _currentIndex > 0 ? Theme.of(context).primaryColor : Colors.grey,
                  child: const Icon(Icons.arrow_left),
                ),
              ),
              Positioned(
                right: 16,
                top: MediaQuery.of(context).size.height / 2 - 24,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: _currentIndex < widget.images.length - 1 ? _navigateToNext : null,
                  backgroundColor: _currentIndex < widget.images.length - 1 ? Theme.of(context).primaryColor : Colors.grey,
                  child: const Icon(Icons.arrow_right),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}