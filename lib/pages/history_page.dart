import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../widgets/theme_config.dart';
import 'recycle_page.dart';
import 'dart:math';
import '../permissions.dart';
import 'package:permission_handler/permission_handler.dart';

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
    bool permissionsGranted = await PermissionHandler.checkStoragePermissions();
    if (!permissionsGranted) {
      permissionsGranted = await PermissionHandler.requestAllPermissions(context);
    }

    if (!permissionsGranted) {
      setState(() {
        _errorMessage = 'Storage or media permission denied. Cannot access downloaded images.';
      });
      return;
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
      if (Platform.isWindows) {
        baseDir = await getApplicationDocumentsDirectory();
        baseDir = Directory('${baseDir.path}/Ragalahari Downloads');
      } else if (Platform.isAndroid) {
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
          // Skip files that are marked as trashed (e.g., starting with .trashed-)
          final fileName = entity.path.split('/').last;
          if (!fileName.startsWith('.trashed-')) {
            imageFiles.add(entity);
          }
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
        content: Text('Are you sure you want to move ${_selectedImages.length} selected image(s) to the recycle bin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Recycle Bin', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final deleteCount = _selectedImages.length; // Store count before clearing
      final List<FileSystemEntity> toDelete = _selectedImages.map((index) => _filteredImages[index]).toList();
      final List<String> trashedPaths = [];

      // Move files to a "trashed" state with new naming convention
      for (var file in toDelete) {
        final fileName = file.path.split('/').last;
        final dirPath = file.path.substring(0, file.path.length - fileName.length);
        final trashedPath = '$dirPath.trashed-${DateTime.now().millisecondsSinceEpoch}-$fileName';
        await File(file.path).rename(trashedPath);
        trashedPaths.add(trashedPath);
      }

      await _loadDownloadedImages();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deleteCount image(s) moved to recycle bin'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              // Restore trashed files
              setState(() {
                _isLoading = true;
              });
              for (var trashedPath in trashedPaths) {
                final originalPath = trashedPath.replaceFirst(RegExp(r'^\.trashed-\d+-'), '', trashedPath.lastIndexOf('/'));
                await File(trashedPath).rename(originalPath);
              }
              await _loadDownloadedImages();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Images restored')),
                );
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move images: $e')),
        );
      }
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

  void _openImage(int index) {
    if (_isSelectionMode) {
      _toggleSelection(index);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullImageViewer(
            images: _filteredImages,
            initialIndex: index,
          ),
        ),
      );
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
          icon: Icon(
            Icons.close,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: _clearSelection,
          tooltip: 'Cancel Selection',
        )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: _loadDownloadedImages,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(
              Icons.delete_sweep,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecyclePage()),
              );
            },
            tooltip: 'Recycle Bin',
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).iconTheme.color,
            ),
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
              PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    Icon(
                      Icons.sort,
                      size: 20,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                enabled: _selectedImages.isNotEmpty,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete,
                      size: 20,
                      color: _selectedImages.isEmpty ? Colors.grey : Colors.red,
                    ),
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
                    Icon(
                      Icons.share,
                      size: 20,
                      color: _selectedImages.isEmpty ? Colors.grey : Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Share Selected',
                      style: TextStyle(color: _selectedImages.isEmpty ? Colors.grey : Theme.of(context).primaryColor),
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
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).iconTheme.color,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Theme.of(context).iconTheme.color,
                  ),
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
                    style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColor),
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
    final themeConfig = Provider.of<ThemeConfig>(context);
    final crossAxisCount = Platform.isWindows ? max(themeConfig.gridColumns, 2) : themeConfig.gridColumns;

    if (_isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
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
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
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
                  icon: Icon(
                    Icons.settings,
                    color: Theme.of(context).primaryColor,
                  ),
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
        crossAxisCount: crossAxisCount,
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
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Theme.of(context).iconTheme.color,
                  ),
                ),
                if (isSelected)
                  Container(
                    color: Colors.blue.withOpacity(0.3),
                    child: Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.onPrimary,
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                      ),
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
      final fileName = file.path.split('/').last;
      final dirPath = file.path.substring(0, file.path.length - fileName.length);
      final trashedPath = '$dirPath.trashed-${DateTime.now().millisecondsSinceEpoch}-$fileName';
      await file.rename(trashedPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image moved to recycle bin')),
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
    );
  }
}