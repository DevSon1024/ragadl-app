import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'recycle_page.dart';
import 'package:ragalahari_downloader/permissions.dart';
import 'package:permission_handler/permission_handler.dart';
import 'history_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sub_folder_page.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ragalahari_downloader/widgets/grid_utils.dart';
import 'history_full_image_viewer.dart';

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

class _HistoryPageState extends State<HistoryPage> {
  List<FileSystemEntity> _downloadedItems = [];
  List<FileSystemEntity> _filteredItems = [];
  SortOption _currentSort = SortOption.newest;
  ViewPreset _currentPreset = ViewPreset.images;
  ViewType _viewType = ViewType.list;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSelectionMode = false;
  final Set<int> _selectedItems = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _loadPreset();
    _loadViewType();
    _checkPermissionsAndLoadItems();
  }

  Future<void> _loadPreset() async {
    final prefs = await SharedPreferences.getInstance();
    final presetString = prefs.getString('viewPreset');
    if (presetString != null) {
      setState(() {
        _currentPreset = ViewPreset.values.firstWhere(
              (preset) => preset.toString() == presetString,
          orElse: () => ViewPreset.images,
        );
      });
    }
  }

  Future<void> _savePreset(ViewPreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('viewPreset', preset.toString());
  }

  Future<void> _loadViewType() async {
    final prefs = await SharedPreferences.getInstance();
    final viewTypeString = prefs.getString('viewType');
    if (viewTypeString != null) {
      setState(() {
        _viewType = ViewType.values.firstWhere(
              (type) => type.toString() == viewTypeString,
          orElse: () => ViewType.list,
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

  Future<Map<String, dynamic>> _getFolderDetails(Directory dir,
      {bool countSubfolders = false}) async {
    int imageCount = 0;
    int folderCount = 0;
    int totalSize = 0;
    File? latestImage;
    DateTime? latestModified;

    try {
      final entities = await dir.list(recursive: true).toList();
      for (var entity in entities) {
        if (entity is File &&
            ['jpg', 'jpeg', 'png']
                .contains(entity.path.toLowerCase().split('.').last)) {
          imageCount++;
          totalSize += entity.statSync().size;
          final modified = entity.statSync().modified;
          if (latestModified == null || modified.isAfter(latestModified)) {
            latestModified = modified;
            latestImage = entity;
          }
        } else if (entity is Directory && countSubfolders) {
          folderCount++;
          final subEntities =
          await Directory(entity.path).list(recursive: true).toList();
          for (var subEntity in subEntities) {
            if (subEntity is File) {
              totalSize += subEntity.statSync().size;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating folder details for ${dir.path}: $e');
    }
    return {
      'imageCount': imageCount,
      'folderCount': folderCount,
      'totalSize': totalSize,
      'latestImage': latestImage,
    };
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
        // Android 11 and above
        if (!await Permission.manageExternalStorage.isGranted) {
          final result = await Permission.manageExternalStorage.request();
          if (!result.isGranted) {
            await _showPermissionDialog();
            return false;
          }
        }
      } else {
        // Android 10 and below
        if (!await Permission.storage.isGranted) {
          final result = await Permission.storage.request();
          if (!result.isGranted) {
            await _showPermissionDialog();
            return false;
          }
        }
      }
    } else {
      // For other platforms like iOS, Windows etc.
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
        baseDir = Directory('/storage/emulated/0/Download/Ragalahari Downloads');
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

      final List<FileSystemEntity> items = [];
      await _collectItems(baseDir, items);

      items.sort((a, b) {
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

  Future<void> _collectItems(Directory dir, List<FileSystemEntity> items) async {
    try {
      if (_currentPreset == ViewPreset.galleriesFolder) {
        final topLevelEntities = await dir.list(recursive: false).toList();
        for (var entity in topLevelEntities) {
          if (entity is Directory) {
            final subDir = Directory(entity.path);
            final subEntities = await subDir.list(recursive: false).toList();
            for (var subEntity in subEntities) {
              final name = subEntity.path.split('/').last;
              if (subEntity is Directory && !name.startsWith('.trashed-')) {
                items.add(subEntity);
              }
            }
          }
        }
      } else {
        final entities =
        await dir.list(recursive: _currentPreset == ViewPreset.images).toList();
        for (var entity in entities) {
          final name = entity.path.split('/').last;
          if (name.startsWith('.trashed-')) continue;
          if (_currentPreset == ViewPreset.images && entity is File) {
            final extension = entity.path.toLowerCase().split('.').last;
            if (['jpg', 'jpeg', 'png'].contains(extension)) {
              items.add(entity);
            }
          } else if (_currentPreset == ViewPreset.celebrityAlbum &&
              entity is Directory) {
            items.add(entity);
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory ${dir.path}: $e');
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
            child:
            const Text('Move to Recycle Bin', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final toDelete = _selectedItems.map((index) => _filteredItems[index]).toList();
      for (var item in toDelete) {
        final name = item.path.split('/').last;
        final dirPath = item.path.substring(0, item.path.length - name.length);
        final trashedPath =
            '$dirPath.trashed-${DateTime.now().millisecondsSinceEpoch}-$name';
        await (item is File ? item : Directory(item.path))
            .rename(trashedPath);
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

    final paths = _selectedItems
        .map((index) => _filteredItems[index].path)
        .toList();

    await Share.shareFiles(paths, text: 'Sharing items from Ragalahari Downloader');
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
              initialIndex: _filteredItems.whereType<File>().toList().indexOf(item),
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
          _isSelectionMode ? '${_selectedItems.length} selected' : 'Download History',
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
            icon: const Icon(Icons.view_module_outlined),
            onPressed: () => _showViewOptions(context, theme),
            tooltip: 'View Options',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const RecyclePage()));
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
                        _selectedItems.addAll(List.generate(_filteredItems.length, (i) => i));
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

  void _showViewOptions(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('View Options', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Preset'),
            ...ViewPreset.values.map((preset) => RadioListTile(
              title: Text(preset.name.capitalize()),
              value: preset,
              groupValue: _currentPreset,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _currentPreset = value);
                  _savePreset(value);
                  _loadDownloadedItems();
                  Navigator.pop(context);
                }
              },
            )),
            const Divider(),
            const Text('View Type'),
            ...ViewType.values.map((type) => RadioListTile(
              title: Text(type.name.capitalize()),
              value: type,
              groupValue: _viewType,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _viewType = value);
                  _saveViewType(value);
                  Navigator.pop(context);
                }
              },
            )),
          ],
        ),
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
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                    ),
                  ),
                if (item is Directory)
                  const Center(child: Icon(Icons.folder, size: 48)),
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.white),
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
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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
              child: Image.file(
                item,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            )
                : const Icon(Icons.folder, size: 40),
            title: Text(item.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
                '${(item.statSync().size / 1024).toStringAsFixed(2)} KB',
                style: Theme.of(context).textTheme.bodySmall
            ),
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