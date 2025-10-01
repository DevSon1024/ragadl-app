import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ragalahari_downloader/shared/widgets/grid_utils.dart';
import 'package:ragalahari_downloader/shared/widgets/thumbnail_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import 'history_full_image_viewer.dart';
import 'recycle_page.dart';
import 'sub_folder_page.dart';

// Helper function to be executed in an isolate
Future<List<FileSystemEntity>> _loadItemsIsolate(
    Map<String, dynamic> args) async {
  final Directory baseDir = args['baseDir'];
  final SortOption currentSort = args['currentSort'];

  final List<FileSystemEntity> items = [];

  Future<void> _collectItems(
      Directory dir, List<FileSystemEntity> items) async {
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

enum SortOption {
  newest,
  oldest,
  largest,
  smallest,
}

enum ViewType { list, grid }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _loadViewType();
    _checkPermissionsAndLoadItems();
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
    super.dispose();
  }

  Future<void> _checkPermissionsAndLoadItems() async {
    bool permissionsGranted = await _checkAndRequestPermissions();
    if (!permissionsGranted) {
      setState(() {
        _errorMessage =
        'Storage or media permission denied. Please grant permissions in app settings.';
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
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
            'This app requires storage permissions to function properly. Please grant the necessary permissions in your device settings.'),
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSelectionMode = false;
      _selectedItems.clear();
    });

    try {
      Directory? baseDir;
      if (Platform.isAndroid) {
        baseDir =
            Directory('/storage/emulated/0/Download/Ragalahari Downloads');
      } else {
        baseDir = await getApplicationDocumentsDirectory();
        baseDir = Directory('${baseDir.path}/Ragalahari Downloads');
      }

      if (!await baseDir.exists()) {
        setState(() {
          _downloadedItems = [];
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

      setState(() {
        _downloadedItems = items;
        _filteredItems = items;
        _errorMessage = items.isEmpty ? 'No items found.' : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _downloadedItems = [];
        _filteredItems = [];
        _errorMessage = 'Error loading items: $e';
        _isLoading = false;
      });
    }
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _downloadedItems.where((item) {
        final name = item.path.split('/').last.toLowerCase();
        return name.contains(query);
      }).toList();
    });
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No items selected')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text(
            'Move ${_selectedItems.length} selected item(s) to the recycle bin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Recycle Bin',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final toDelete =
      _selectedItems.map((index) => _filteredItems[index]).toList();
      for (var item in toDelete) {
        final name = item.path.split('/').last;
        final dirPath = item.path.substring(0, item.path.length - name.length);
        final trashedPath =
            '$dirPath.trashed-${DateTime.now().millisecondsSinceEpoch}-$name';
        await (item is File ? item : Directory(item.path)).rename(trashedPath);
      }

      await _loadDownloadedItems();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to move items: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareSelectedItems() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No items selected')));
      return;
    }

    final paths =
    _selectedItems.map((index) => _filteredItems[index].path).toList();

    await Share.shareFiles(paths,
        text: 'Sharing items from Ragalahari Downloader');
  }

  void _openItem(int index) {
    if (_isSelectionMode) {
      _toggleSelection(index);
    } else {
      final item = _filteredItems[index];
      if (item is File) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullImageViewer(
              images: _filteredItems.whereType<File>().toList(),
              initialIndex:
              _filteredItems.whereType<File>().toList().indexOf(item),
            ),
          ),
        );
      } else if (item is Directory) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubFolderPage(
              directory: item,
              sortOption: _currentSort,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedItems.length} selected'
              : 'Download History',
        ),
        leading: _isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        )
            : null,
        actions: _isSelectionMode
            ? [
          IconButton(
            icon: const Icon(Icons.delete_outline),
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
            icon: Icon(_viewType == ViewType.grid
                ? Icons.view_list
                : Icons.view_module),
            onPressed: () {
              setState(() {
                _viewType = _viewType == ViewType.grid
                    ? ViewType.list
                    : ViewType.grid;
                _saveViewType(_viewType);
              });
            },
            tooltip:
            _viewType == ViewType.grid ? 'List View' : 'Grid View',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const RecyclePage()));
            },
            tooltip: 'Recycle Bin',
          ),
          IconButton(
            icon: const Icon(Icons.sort_outlined),
            onPressed: () => _showSortOptions(context, theme),
            tooltip: 'Sort Options',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterItems();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
          ),
          if (_isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedItems.addAll(
                            List.generate(_filteredItems.length, (i) => i));
                      });
                    },
                    child: const Text('Select All'),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildContent(theme)),
        ],
      ),
    );
  }

  void _showSortOptions(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort By', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            ...SortOption.values.map((option) => RadioListTile(
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
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return _buildLoadingShimmer(theme);
    }

    if (_errorMessage != null) {
      return _buildErrorWidget(theme);
    }

    if (_filteredItems.isEmpty) {
      return const Center(child: Text('No items found.'));
    }

    if (_viewType == ViewType.grid) {
      return _buildGridView();
    }

    return _buildListView();
  }

  Widget _buildLoadingShimmer(ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: calculateGridColumns(context),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: theme.colorScheme.surface,
          highlightColor: theme.colorScheme.surface.withOpacity(0.5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _checkPermissionsAndLoadItems,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: calculateGridColumns(context),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final isSelected = _selectedItems.contains(index);

        return GestureDetector(
          onTap: () => _openItem(index),
          onLongPress: () => _toggleSelection(index),
          child: Card(
            elevation: isSelected ? 8 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSelected
                  ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                  : BorderSide.none,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item is File)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.file(
                      item,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                      const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                if (item is Directory)
                  const Center(
                      child: Icon(Icons.folder, size: 48, color: Colors.grey)),
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                    const Icon(Icons.check_circle, color: Colors.white),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      item.path.split('/').last,
                      style:
                      const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final isSelected = _selectedItems.contains(index);

        return Card(
          elevation: isSelected ? 8 : 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: (item is File)
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Image.file(
                  item,
                  fit: BoxFit.cover,
                ),
              ),
            )
                : const Icon(Icons.folder, size: 40),
            title: Text(item.path.split('/').last,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: item is File
                ? FutureBuilder<int>(
              future: item.length(), // Now only called on File objects
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    '${(snapshot.data! / 1024).toStringAsFixed(2)} KB',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return const Text('...'); // Placeholder for size
              },
            )
                : null, // No subtitle for directories
            onTap: () => _openItem(index),
            onLongPress: () => _toggleSelection(index),
            selected: isSelected,
            selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return isNotEmpty ? "${this[0].toUpperCase()}${substring(1)}" : this;
  }
}