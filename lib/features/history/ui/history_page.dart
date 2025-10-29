import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ragadl/shared/widgets/grid_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'history_full_image_viewer.dart';
import 'recycle_page.dart';

// Helper function to be executed in an isolate
Future<List<FileSystemEntity>> _loadItemsIsolate(Map<String, dynamic> args) async {
  final Directory baseDir = args['baseDir'];
  final SortOption currentSort = args['currentSort'];
  final List<FileSystemEntity> items = [];

  Future<void> _collectItems(Directory dir, List<FileSystemEntity> items) async {
    try {
      final entities = await dir.list(recursive: true).toList();
      for (var entity in entities) {
        final name = entity.path.split('/').last;
        if (name.startsWith('.trashed-')) continue;
        if (entity is File) {
          final extension = entity.path.toLowerCase().split('.').last;
          if (['jpg', 'jpeg', 'png'].contains(extension)) {
            items.add(entity);
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory ${dir.path}: $e');
    }
  }

  await _collectItems(baseDir, items);
  items.sort((a, b) {
    final aStat = a.statSync();
    final bStat = b.statSync();
    switch (currentSort) {
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
  return items;
}

enum SortOption { newest, oldest, largest, smallest }

enum ViewType { list, grid }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<FileSystemEntity> _downloadedItems = [];
  List<FileSystemEntity> _filteredItems = [];
  SortOption _currentSort = SortOption.newest;
  ViewType _viewType = ViewType.grid;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSelectionMode = false;
  final Set<int> _selectedItems = {};
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showStatsCard = true;
  int _totalImages = 0;
  double _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _scrollController.addListener(_onScroll);
    _loadViewType();
    _checkPermissionsAndLoadItems();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final bool shouldShowCard = _scrollController.offset <= 100;
      if (shouldShowCard != _showStatsCard) {
        setState(() => _showStatsCard = shouldShowCard);
      }
    }
  }

  Future<void> _calculateStats() async {
    if (_filteredItems.isEmpty) {
      _totalImages = 0;
      _totalSize = 0;
      return;
    }

    _totalImages = _filteredItems.length;
    _totalSize = 0;

    for (final item in _filteredItems) {
      if (item is File) {
        try {
          final size = await item.length();
          _totalSize += size;
        } catch (e) {
          debugPrint('Error getting file size: $e');
        }
      }
    }
  }

  String _formatBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _loadViewType() async {
    final prefs = await SharedPreferences.getInstance();
    final viewTypeString = prefs.getString('viewType');
    if (viewTypeString != null) {
      setState(() {
        _viewType = ViewType.values.firstWhere(
              (type) => type.toString() == viewTypeString,
          orElse: () => ViewType.grid,
        );
      });
    }
  }

  Future<void> _saveViewType(ViewType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('viewType', type.toString());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionsAndLoadItems() async {
    bool permissionsGranted = await _checkAndRequestPermissions();
    if (!permissionsGranted) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Storage or media permission denied. Please grant permissions in app settings.';
      });
      return;
    }
    await _loadDownloadedItems();
  }

  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      if (sdkInt >= 30) {
        if (!await Permission.manageExternalStorage.isGranted) {
          final result = await Permission.manageExternalStorage.request();
          if (!result.isGranted) {
            await _showPermissionDialog();
            return false;
          }
        }
      } else {
        if (!await Permission.storage.isGranted) {
          final result = await Permission.storage.request();
          if (!result.isGranted) {
            await _showPermissionDialog();
            return false;
          }
        }
      }
    } else {
      if (!await Permission.storage.isGranted) {
        if (await Permission.storage.request().isDenied) {
          await _showPermissionDialog();
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _showPermissionDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text('This app requires storage permissions to function properly. Please grant the necessary permissions in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDownloadedItems() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSelectionMode = false;
      _selectedItems.clear();
    });

    try {
      Directory? baseDir;
      if (Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0/Download/Ragalahari Downloads');
      } else {
        baseDir = await getApplicationDocumentsDirectory();
        baseDir = Directory('${baseDir.path}/Ragalahari Downloads');
      }

      if (!await baseDir.exists()) {
        if (!mounted) return;
        setState(() {
          _downloadedItems = [];
          final query = _searchController.text.toLowerCase();
          _filteredItems = [];
          _errorMessage = 'No downloads found.';
          _isLoading = false;
        });
        return;
      }

      final items = await compute(_loadItemsIsolate, {
        'baseDir': baseDir,
        'currentSort': _currentSort,
      });

      if (mounted) {
        setState(() {
          _downloadedItems = items;
          final query = _searchController.text.toLowerCase();
          _filteredItems = items.where((item) {
            final name = item.path.split('/').last.toLowerCase();
            return name.contains(query);
          }).toList();
          _errorMessage = items.isEmpty ? 'No items found.' : null;
          _isLoading = false;
        });
        await _calculateStats();
        setState(() {}); // Refresh to show calculated stats
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadedItems = [];
          _filteredItems = [];
          _errorMessage = 'Error loading items: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _filterItems() async {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _downloadedItems.where((item) {
        final name = item.path.split('/').last.toLowerCase();
        return name.contains(query);
      }).toList();
    });
    await _calculateStats();
    setState(() {});
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedItems.contains(index)) {
        _selectedItems.remove(index);
      } else {
        _selectedItems.add(index);
      }
      _isSelectionMode = _selectedItems.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedItems.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items selected')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text('Move ${_selectedItems.length} selected item(s) to the recycle bin?'),
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
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final toDelete = _selectedItems.map((index) => _filteredItems[index]).toList();
      for (var item in toDelete) {
        final name = item.path.split('/').last;
        final dirPath = item.path.substring(0, item.path.length - name.length);
        final trashedPath = '$dirPath.trashed-${DateTime.now().millisecondsSinceEpoch}-$name';
        await (item is File ? item : Directory(item.path)).rename(trashedPath);
      }
      await _loadDownloadedItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to move items: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareSelectedItems() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items selected')));
      return;
    }

    final paths = _selectedItems.map((index) => _filteredItems[index].path).toList();
    await Share.shareFiles(paths, text: 'Sharing items from RagaDL');
  }

  void _openItem(int index) {
    if (_isSelectionMode) {
      _toggleSelection(index);
    } else {
      final item = _filteredItems[index];
      if (item is File) {
        Navigator.push(
          context,
          _ModernPageRoute(
            FullImageViewer(
              images: _filteredItems.whereType<File>().toList(),
              initialIndex: _filteredItems.whereType<File>().toList().indexOf(item),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: color.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: color.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _isSelectionMode ? '${_selectedItems.length} selected' : 'Download History',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: _isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _clearSelection,
        )
            : null,
        actions: _isSelectionMode
            ? [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteSelectedItems,
            tooltip: 'Delete Selected',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareSelectedItems,
            tooltip: 'Share Selected',
          ),
        ]
            : [
          IconButton(
            icon: Icon(_viewType == ViewType.grid ? Icons.view_list_rounded : Icons.view_module_rounded),
            onPressed: () {
              setState(() {
                _viewType = _viewType == ViewType.grid ? ViewType.list : ViewType.grid;
                _saveViewType(_viewType);
              });
            },
            tooltip: _viewType == ViewType.grid ? 'List View' : 'Grid View',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const RecyclePage()));
            },
            tooltip: 'Recycle Bin',
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: () => _showSortOptions(context),
            tooltip: 'Sort Options',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.outline.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: color.shadow.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search images...',
                      hintStyle: TextStyle(color: color.onSurfaceVariant),
                      prefixIcon: Icon(Icons.search_rounded, color: color.onSurfaceVariant),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: color.onSurfaceVariant),
                        onPressed: () {
                          _searchController.clear();
                          _filterItems();
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),

              // Selection Actions
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedItems.addAll(List.generate(_filteredItems.length, (i) => i));
                          });
                        },
                        icon: const Icon(Icons.select_all_rounded),
                        label: const Text('Select All'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _clearSelection,
                        icon: const Icon(Icons.clear_all_rounded),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                ),

              // Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadDownloadedItems,
                  child: _buildContent(),
                ),
              ),
            ],
          ),

          // Floating Stats Card
          if (_showStatsCard && !_isLoading && _filteredItems.isNotEmpty)
            Positioned(
              top: _isSelectionMode ? 120 : 80,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                opacity: _showStatsCard ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300)
              ),
            ),
        ],
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: color.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort By', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...SortOption.values.map((option) => RadioListTile<SortOption>(
              title: Text(option.name.capitalize()),
              value: option,
              groupValue: _currentSort,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _currentSort = value);
                  _loadDownloadedItems();
                  Navigator.pop(context);
                }
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (_filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    if (_viewType == ViewType.grid) {
      return _buildGridView();
    }

    return _buildListView();
  }

  Widget _buildLoadingShimmer() {
    final color = Theme.of(context).colorScheme;
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: calculateGridColumns(context),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: color.surfaceVariant.withOpacity(0.3),
          highlightColor: color.surface,
          child: Container(
            decoration: BoxDecoration(
              color: color.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    final color = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.errorContainer.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 64, color: color.error),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _checkPermissionsAndLoadItems,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final color = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.photo_library_outlined, size: 64, color: color.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'No images found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Try downloading some images first or adjust your search filters.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: calculateGridColumns(context),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final isSelected = _selectedItems.contains(index);

        return _ImageCard(
          item: item,
          isSelected: isSelected,
          onTap: () => _openItem(index),
          onLongPress: () => _toggleSelection(index),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final isSelected = _selectedItems.contains(index);

        return _ImageListTile(
          item: item,
          isSelected: isSelected,
          onTap: () => _openItem(index),
          onLongPress: () => _toggleSelection(index),
        );
      },
    );
  }
}

class _ImageCard extends StatelessWidget {
  final FileSystemEntity item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ImageCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: color.surface,
        elevation: isSelected ? 8 : 2,
        shadowColor: isSelected ? color.primary.withOpacity(0.4) : color.shadow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isSelected ? Border.all(color: color.primary, width: 2) : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item is File
                      ? Hero(
                    tag: item.path,
                    child: Image.file(
                      item as File,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: color.surfaceVariant,
                        child: Icon(Icons.broken_image_rounded, color: color.onSurfaceVariant),
                      ),
                    ),
                  )
                      : Container(
                    color: color.surfaceVariant,
                    child: Icon(Icons.folder_rounded, size: 48, color: color.onSurfaceVariant),
                  ),
                ),

                // Selection overlay
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      color: color.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                // Selection indicator
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.check_rounded, color: color.onPrimary, size: 16),
                    ),
                  ),

                // File name overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      item.path.split('/').last,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageListTile extends StatelessWidget {
  final FileSystemEntity item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ImageListTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color.surface,
        elevation: isSelected ? 4 : 1,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isSelected ? Border.all(color: color.primary, width: 2) : null,
              color: isSelected ? color.primaryContainer.withOpacity(0.1) : null,
            ),
            child: Row(
              children: [
                // Image thumbnail
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item is File
                        ? Hero(
                      tag: item.path,
                      child: Image.file(
                        item as File,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          color: color.surfaceVariant,
                          child: Icon(Icons.broken_image_rounded, color: color.onSurfaceVariant),
                        ),
                      ),
                    )
                        : Container(
                      color: color.surfaceVariant,
                      child: Icon(Icons.folder_rounded, color: color.onSurfaceVariant),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.path.split('/').last,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (item is File)
                        FutureBuilder<int>(
                          future: (item as File).length(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final sizeKB = (snapshot.data! / 1024).toStringAsFixed(1);
                              return Text(
                                '$sizeKB KB',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color.onSurfaceVariant),
                              );
                            }
                            return Text(
                              '...',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color.onSurfaceVariant),
                            );
                          },
                        ),
                    ],
                  ),
                ),

                // Selection indicator
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded, color: color.onPrimary, size: 16),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: color.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernPageRoute extends PageRouteBuilder {
  _ModernPageRoute(Widget page)
      : super(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

extension StringExtension on String {
  String capitalize() {
    return isNotEmpty ? "${this[0].toUpperCase()}${substring(1)}" : this;
  }
}
