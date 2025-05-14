import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum SortOption {
  newest,
  oldest,
  largest,
  smallest,
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  List<FileSystemEntity> _downloadedImages = [];
  List<FileSystemEntity> _filteredImages = [];
  SortOption _currentSort = SortOption.newest;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSelectionMode = false;
  Set<int> _selectedImages = {};
  final TextEditingController _searchController = TextEditingController();
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _searchController.addListener(_filterImages);
    _checkPermissionsAndLoadImages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionsAndLoadImages() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      bool isPermissionGranted = false;

      if (androidInfo.version.sdkInt >= 33) {
        final photoStatus = await Permission.photos.status;
        if (!photoStatus.isGranted) {
          final newStatus = await Permission.photos.request();
          isPermissionGranted = newStatus.isGranted;
        } else {
          isPermissionGranted = true;
        }
      } else if (androidInfo.version.sdkInt >= 30) {
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        if (!manageStorageStatus.isGranted) {
          final newStatus = await Permission.manageExternalStorage.request();
          isPermissionGranted = newStatus.isGranted;
        } else {
          isPermissionGranted = true;
        }
      } else {
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          final newStatus = await Permission.storage.request();
          isPermissionGranted = newStatus.isGranted;
        } else {
          isPermissionGranted = true;
        }
      }

      if (!isPermissionGranted) {
        setState(() {
          _errorMessage = 'Storage or media permission denied. Cannot access downloaded images.';
        });
        return;
      }
    }

    await _loadDownloadedImages();
  }

  Future<void> _loadDownloadedImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSelectionMode = false;
      _selectedImages.clear();
    });

    try {
      Directory? baseDir;
      if (Platform.isWindows){
        baseDir = await getApplicationDocumentsDirectory();
        baseDir = Directory('${baseDir.path}/Ragalahari Downloads');
      } else if(Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0/Download/Ragalahari Downloads');
        if (!await baseDir.exists()) {
          baseDir = await getExternalStorageDirectory();
          if (baseDir != null) {
            baseDir = Directory('${baseDir.path}/Ragalahari Downloads');
          }
        }
      } else {
        baseDir = await getApplicationDocumentsDirectory();
        baseDir = Directory('${baseDir.path}/Ragalahari Downloads');
      }

      if (baseDir == null || !await baseDir.exists()) {
        setState(() {
          _downloadedImages = [];
          _filteredImages = [];
          _errorMessage = 'No downloads found. Download images to see them here.';
          _isLoading = false;
        });
        return;
      }

      final List<FileSystemEntity> imageFiles = [];
      await _collectImages(baseDir, imageFiles);

      imageFiles.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();

        switch (_currentSort) {
          case SortOption.newest:
            return bStat.modified.compareTo(aStat.modified);
          case SortOption.oldest:
            return aStat.modified.compareTo(bStat.modified);
          case SortOption.largest:
            return bStat.size.compareTo(aStat.size);
          case SortOption.smallest:
            return aStat.size.compareTo(bStat.size);
        }
      });

      setState(() {
        _downloadedImages = imageFiles;
        _filteredImages = imageFiles;
        _errorMessage = imageFiles.isEmpty
            ? 'No images found in the download directory.'
            : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _downloadedImages = [];
        _filteredImages = [];
        _errorMessage = 'Error loading images: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _collectImages(Directory dir, List<FileSystemEntity> imageFiles) async {
    try {
      final entities = await dir.list(recursive: false).toList();
      for (var entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
          imageFiles.add(entity);
        } else if (entity is Directory) {
          await _collectImages(entity, imageFiles);
        }
      }
    } catch (e) {
      print('Error scanning directory ${dir.path}: $e');
    }
  }

  void _filterImages() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredImages = _downloadedImages.where((file) {
        final fileName = file.path.split('/').last.toLowerCase();
        return fileName.contains(query);
      }).toList();
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedImages.contains(index)) {
        _selectedImages.remove(index);
      } else {
        _selectedImages.add(index);
      }
      _isSelectionMode = _selectedImages.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedImages.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedImages() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images selected')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Images'),
        content: Text('Are you sure you want to delete ${_selectedImages.length} selected image(s)?'),
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

    setState(() {
      _isLoading = true;
    });

    try {
      final List<FileSystemEntity> toDelete = _selectedImages.map((index) => _filteredImages[index]).toList();
      for (var file in toDelete) {
        await File(file.path).delete();
      }

      await _loadDownloadedImages();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${toDelete.length} image(s)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete images: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _shareSelectedImages() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images selected')),
      );
      return;
    }
    if (Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing is not supported on Windows')),
      );
      return;
    }
    final List<String> paths =
    _selectedImages.map((index) => _filteredImages[index].path).toList();
    await Share.shareFiles(
      paths,
      text: 'Sharing images from Ragalahari Downloader',
    );
  }

  void _openImage(int index) async {
    if (_isSelectionMode) {
      _toggleSelection(index);
    } else {
      final filePath = _filteredImages[index].path;
      if (Platform.isWindows) {
        final uri = Uri.file(filePath);
        await launchUrl(uri);
      } else {
        await OpenFilex.open(filePath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? 'Selected ${_selectedImages.length}' : 'Download History',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: _isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
          tooltip: 'Cancel Selection',
        )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDownloadedImages,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              FocusScope.of(context).unfocus();
              if (value == 'sort') {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SortOptionsSheet(
                    currentSort: _currentSort,
                    onSortSelected: (option) {
                      setState(() {
                        _currentSort = option;
                      });
                      _loadDownloadedImages();
                      Navigator.pop(context);
                    },
                  ),
                );
              } else if (value == 'delete') {
                _deleteSelectedImages();
              } else if (value == 'share') {
                _shareSelectedImages();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    Icon(Icons.sort, size: 20),
                    SizedBox(width: 8),
                    Text('Sort'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                enabled: _selectedImages.isNotEmpty,
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: _selectedImages.isEmpty ? Colors.grey : Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'Delete Selected',
                      style: TextStyle(color: _selectedImages.isEmpty ? Colors.grey : Colors.red),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                enabled: _selectedImages.isNotEmpty,
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20, color: _selectedImages.isEmpty ? Colors.grey : Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Share Selected',
                      style: TextStyle(color: _selectedImages.isEmpty ? Colors.grey : Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search images...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterImages();
                  },
                )
                    : null,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
            ),
          ),
          if (_isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedImages.length} selected',
                    style: const TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedImages = Set.from(List.generate(_filteredImages.length, (index) => index));
                      });
                    },
                    child: const Text('Select All'),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildContent()),
        ],
      ),
    );

  }

  Widget _buildContent() {
    // Determine crossAxisCount based on platform
    final crossAxisCount = Platform.isWindows ? 4 : 2;

    if (_isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount, // Use runtime variable
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Card(
              elevation: 2,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.grey[300],
                    ),
                  ),
                  Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      height: 12,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (_errorMessage!.contains('permission'))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                  onPressed: () async {
                    await openAppSettings();
                    await _checkPermissionsAndLoadImages();
                  },
                ),
              ),
          ],
        ),
      );
    }

    if (_filteredImages.isEmpty) {
      return const Center(
        child: Text(
          'No downloaded images found.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, // Use runtime variable
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.75,
      ),
      itemCount: _filteredImages.length,
      itemBuilder: (context, index) {
        final file = _filteredImages[index];
        final isSelected = _selectedImages.contains(index);
        return GestureDetector(
          onTap: _isLoading ? null : () => _openImage(index),
          onLongPress: () => _toggleSelection(index),
          child: Card(
            elevation: 2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(file.path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
                if (isSelected)
                  Container(
                    color: Colors.blue.withOpacity(0.3),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      '${(File(file.path).lengthSync() / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            leading: const Icon(Icons.access_time),
            title: const Text('Newest First'),
            trailing: currentSort == SortOption.newest ? const Icon(Icons.check) : null,
            onTap: () => onSortSelected(SortOption.newest),
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Oldest First'),
            trailing: currentSort == SortOption.oldest ? const Icon(Icons.check) : null,
            onTap: () => onSortSelected(SortOption.oldest),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Largest First'),
            trailing: currentSort == SortOption.largest ? const Icon(Icons.check) : null,
            onTap: () => onSortSelected(SortOption.largest),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Smallest First'),
            trailing: currentSort == SortOption.smallest ? const Icon(Icons.check) : null,
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
    super.dispose();
  }

  Future<void> _deleteImage(File file) async {
    setState(() => _isDeleting = true);
    try {
      await file.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted successfully')),
        );
        // Remove the image from the list and update the UI
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
          SnackBar(content: Text('Failed to delete image: $e')),
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
        content: const Text('Are you sure you want to delete this image?'),
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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

  @override
  Widget build(BuildContext context) {
    final currentImage = File(widget.images[_currentIndex].path);
    return Scaffold(
      appBar: AppBar(
        title: Text('Image ${_currentIndex + 1} of ${widget.images.length}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _copyImagePath(currentImage.path),
            tooltip: 'Copy Path',
          ),
          IconButton(
            icon: _isDeleting
                ? const CircularProgressIndicator()
                : const Icon(Icons.delete),
            onPressed: _isDeleting
                ? null
                : () => _showDeleteConfirmation(currentImage),
            tooltip: 'Delete Image',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openFile(currentImage.path),
            tooltip: 'Open in File Explorer',
          ),
        ],
      ),
      body: PageView.builder(
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
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}