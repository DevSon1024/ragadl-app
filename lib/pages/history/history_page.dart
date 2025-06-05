import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'recycle_page.dart';
import '../../permissions.dart';
import 'package:permission_handler/permission_handler.dart';
import 'history_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sub_folder_page.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ragalahari_downloader/widgets/grid_utils.dart';

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
  Set<int> _selectedItems = {};
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
      print('Error calculating folder details for ${dir.path}: $e');
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
    if (!Platform.isAndroid) {
      return await PermissionHandler.checkStoragePermissions() ||
          await PermissionHandler.requestAllPermissions(context);
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 30) {
      final manageStorageStatus = await Permission.manageExternalStorage.status;
      if (!manageStorageStatus.isGranted) {
        final result = await Permission.manageExternalStorage.request();
        if (!result.isGranted) {
          await _showPermissionDialog();
          return false;
        }
      }
    } else {
      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        final result = await Permission.storage.request();
        if (!result.isGranted) {
          await _showPermissionDialog();
          return false;
        }
      }
    }

    final mediaPermissions = await PermissionHandler.checkStoragePermissions();
    if (!mediaPermissions) {
      final granted = await PermissionHandler.requestAllPermissions(context);
      if (!granted) {
        await _showPermissionDialog();
        return false;
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
            'This app requires storage permissions. Please grant "Manage All Files" in app settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              Navigator.pop(context);
              await _checkPermissionsAndLoadItems();
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
      print('Error scanning directory ${dir.path}: $e');
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

    setState(() {
      _isLoading = true;
    });

    try {
      final permissionsGranted = await _checkAndRequestPermissions();
      if (!permissionsGranted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot move items: Permission denied')));
        return;
      }

      final deleteCount = _selectedItems.length;
      final List<FileSystemEntity> toDelete =
      _selectedItems.map((index) => _filteredItems[index]).toList();
      final List<String> trashedPaths = [];

      for (var item in toDelete) {
        final name = item.path.split('/').last;
        final dirPath = item.path.substring(0, item.path.length - name.length);
        final trashedPath =
            '$dirPath.trashed-${DateTime.now().millisecondsSinceEpoch}-$name';
        await (item is File ? File(item.path) : Directory(item.path))
            .rename(trashedPath);
        trashedPaths.add(trashedPath);
      }

      await _loadDownloadedItems();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deleteCount item(s) moved to recycle bin'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              for (var trashedPath in trashedPaths) {
                final originalPath = trashedPath.replaceFirst(
                    RegExp(r'\.trashed-\d+-'), '', trashedPath.lastIndexOf('/'));
                try {
                  await (trashedPath.endsWith('.jpg')
                      ? File(trashedPath)
                      : Directory(trashedPath))
                      .rename(originalPath);
                } catch (e) {
                  print('Failed to restore $trashedPath: $e');
                }
              }
              await _loadDownloadedItems();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Items restored')));
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..showSnackBar(SnackBar(content: Text('Failed to move items: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _shareSelectedItems() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No items selected')));
      return;
    }
    if (Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing is not supported on Windows')));
      return;
    }
    final List<String> paths = _selectedItems
        .map((index) => _filteredItems[index])
        .where((item) => item is File)
        .map((item) => item.path)
        .toList();
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No images selected for sharing')));
      return;
    }
    await Share.shareFiles(
      paths,
      text: 'Sharing items from Ragalahari Downloader',
    );
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
          _isSelectionMode ? 'Selected ${_selectedItems.length}' : 'Download History',
        ),
        centerTitle: true,
        titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        backgroundColor: theme.colorScheme.surface, // Fixed: Removed incorrect 'of'
        surfaceTintColor: theme.colorScheme.surfaceTint, // Fixed: Removed incorrect 'of'
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: _clearSelection,
          tooltip: 'Cancel Selection',
        )
            : null,
        actions: [
          IconButton(
            icon: Icon(Icons.view_module, color: theme.colorScheme.onSurface),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('View Options',
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      Text('Preset', style: theme.textTheme.bodyMedium),
                      ...ViewPreset.values.map((e) => RadioListTile(
                        title: Text(e.toString().split('.').last.capitalize(),
                            style: theme.textTheme.bodyLarge),
                        value: e,
                        groupValue: _currentPreset,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _currentPreset = value;
                            });
                            _savePreset(value);
                            _loadDownloadedItems();
                            Navigator.pop(context);
                          }
                        },
                      )),
                      const Divider(),
                      Text('View Type', style: theme.textTheme.bodyMedium),
                      ...ViewType.values.map((e) => RadioListTile(
                        title: Text(e.toString().split('.').last.capitalize(),
                            style: theme.textTheme.bodyLarge),
                        value: e,
                        groupValue: _viewType,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _viewType = value;
                            });
                            _saveViewType(value);
                            Navigator.pop(context);
                          }
                        },
                      )),
                    ],
                  ),
                ),
              );
            },
            tooltip: 'View Options',
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep, color: theme.colorScheme.onSurface),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const RecyclePage()));
            },
            tooltip: 'Recycle Bin',
          ),
          PopupMenuButton(
            icon: Icon(Icons.sort, color: theme.colorScheme.onSurface),
            onSelected: (value) {
              FocusScope.of(context).unfocus();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sort by'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: SortOption.values.map((option) => RadioListTile(
                      title: Text(option.toString().split('.').last.capitalize(),
                          style: theme.textTheme.bodyLarge),
                      value: option,
                      groupValue: _currentSort,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _currentSort = value;
                          });
                          _loadDownloadedItems();
                          Navigator.pop(context);
                        }
                      },
                    )).toList(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
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
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon:
                Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear,
                      color: theme.colorScheme.onSurfaceVariant),
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
                fillColor: theme.colorScheme.surfaceContainer,
              ),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (_isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedItems.length} selected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary) ??
                        TextStyle(color: theme.colorScheme.primary), // Fixed: Null check
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedItems =
                            Set.from(List.generate(_filteredItems.length, (index) => index));
                      });
                    },
                    child: Text('Select All', style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildContent(crossAxisCount: calculateGridColumns(context))),
        ],
      ),
      bottomNavigationBar: _isSelectionMode
          ? BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: Icon(Icons.delete, color: Colors.red),
              label: const Text('Delete Selected',
                  style: TextStyle(color: Colors.red)),
              onPressed: _deleteSelectedItems,
            ),
            TextButton.icon(
              icon: Icon(Icons.share, color: theme.colorScheme.primary),
              label: Text('Share Selected',
                  style: TextStyle(color: theme.colorScheme.primary)),
              onPressed: _shareSelectedItems,
            ),
          ],
        ),
      )
          : null,
    );
  }

  Widget _buildContent({required int crossAxisCount}) {
    final theme = Theme.of(context);
    if (_isLoading) {
      if (_viewType == ViewType.grid || _currentPreset == ViewPreset.images) {
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: calculateGridColumns(context),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Shimmer.fromColors(
              baseColor: theme.colorScheme.surfaceContainer,
              highlightColor: theme.colorScheme.surfaceContainerHigh,
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(color: theme.colorScheme.surface),
                    ),
                    Container(
                      color: theme.colorScheme.surfaceContainer,
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        height: 12,
                        color: theme.colorScheme.surface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Shimmer.fromColors(
              baseColor: theme.colorScheme.surfaceContainer,
              highlightColor: theme.colorScheme.surfaceContainerHigh,
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainer,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading:
                  Container(width: 48, height: 48, color: theme.colorScheme.surface),
                  title: Container(height: 12, color: theme.colorScheme.surface),
                ),
              ),
            );
          },
        );
      }
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (_errorMessage!.contains('permission'))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  icon: Icon(Icons.settings, color: theme.colorScheme.onPrimary),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await openAppSettings();
                    await _checkPermissionsAndLoadItems();
                  },
                ),
              ),
          ],
        ),
      );
    }

    if (_filteredItems.isEmpty) {
      return Center(
          child: Text('No items found.', style: theme.textTheme.bodyLarge));
    }

    if (_currentPreset == ViewPreset.images && _viewType == ViewType.list) {
      return ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          final isSelected = _selectedItems.contains(index);
          final isImage = item is File;

          return Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: isImage
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(item.path),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.broken_image,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
                  : Icon(Icons.folder,
                  size: 48, color: theme.colorScheme.onSurfaceVariant),
              title: Text(
                item.path.split('/').last,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: isImage
                  ? Text(
                '${(File(item.path).lengthSync() / 1024).toStringAsFixed(1)} KB',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              )
                  : null,
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                  : null,
              onTap: _isLoading ? null : () => _openItem(index),
              onLongPress: () => _toggleSelection(index),
              selected: isSelected,
              selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
            ),
          );
        },
      );
    }

    if (_currentPreset == ViewPreset.galleriesFolder ||
        _currentPreset == ViewPreset.celebrityAlbum) {
      if (_viewType == ViewType.list) {
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: _filteredItems.length,
          itemBuilder: (context, index) {
            final item = _filteredItems[index];
            final isSelected = _selectedItems.contains(index);

            return FutureBuilder<Map<String, dynamic>>(
              future: item is Directory
                  ? _getFolderDetails(item,
                  countSubfolders: _currentPreset == ViewPreset.celebrityAlbum)
                  : Future.value(
                  {'imageCount': 0, 'totalSize': 0, 'latestImage': null}),
              builder: (context, snapshot) {
                final imageCount = snapshot.data?['imageCount'] ?? 0;
                final folderCount = snapshot.data?['folderCount'] ?? 0;
                final totalSize = snapshot.data?['totalSize'] ?? 0;
                final latestImage = snapshot.data?['latestImage'] as File?;
                final sizeInMB = (totalSize / (1024 * 1024)).toStringAsFixed(2);

                Widget leadingIcon = Icon(Icons.folder,
                    size: 48, color: theme.colorScheme.onSurfaceVariant);

                if (latestImage != null) {
                  leadingIcon = ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      latestImage,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.folder,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: leadingIcon,
                    title: Text(
                      item.path.split('/').last,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: item is Directory
                        ? Text(
                      _currentPreset == ViewPreset.celebrityAlbum
                          ? '$folderCount folder${folderCount == 1 ? '' : 's'}, $sizeInMB MB'
                          : '$imageCount image${imageCount == 1 ? '' : 's'}, $sizeInMB MB',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    )
                        : null,
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                        : null,
                    onTap: _isLoading ? null : () => _openItem(index),
                    onLongPress: () => _toggleSelection(index),
                    selected: isSelected,
                    selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                );
              },
            );
          },
        );
      } else {
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: calculateGridColumns(context),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemCount: _filteredItems.length,
          itemBuilder: (context, index) {
            final item = _filteredItems[index];
            final isSelected = _selectedItems.contains(index);

            return FutureBuilder<Map<String, dynamic>>(
              future: item is Directory
                  ? _getFolderDetails(item,
                  countSubfolders: _currentPreset == ViewPreset.celebrityAlbum)
                  : Future.value(
                  {'imageCount': 0, 'totalSize': 0, 'latestImage': null}),
              builder: (context, snapshot) {
                final imageCount = snapshot.data?['imageCount'] ?? 0;
                final folderCount = snapshot.data?['folderCount'] ?? 0;
                final totalSize = snapshot.data?['totalSize'] ?? 0;
                final latestImage = snapshot.data?['latestImage'] as File?;
                final sizeInMB = (totalSize / (1024 * 1024)).toStringAsFixed(2);

                Widget thumbnail = Icon(Icons.folder,
                    size: 48, color: theme.colorScheme.onSurfaceVariant);

                if (latestImage != null) {
                  thumbnail = Image.file(
                    latestImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.folder,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }

                return GestureDetector(
                  onTap: _isLoading ? null : () => _openItem(index),
                  onLongPress: () => _toggleSelection(index),
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        thumbnail,
                        if (isSelected)
                          Container(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            child: Icon(Icons.check_circle,
                                color: theme.colorScheme.onPrimary, size: 30),
                          ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              _currentPreset == ViewPreset.celebrityAlbum
                                  ? '${item.path.split('/').last}\n$folderCount folder${folderCount == 1 ? '' : 's'}, $sizeInMB MB'
                                  : '${item.path.split('/').last}\n$imageCount image${imageCount == 1 ? '' : 's'}, $sizeInMB MB',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface),
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
          },
        );
      }
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: calculateGridColumns(context),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final isSelected = _selectedItems.contains(index);
        final isImage = item is File;

        return GestureDetector(
          onTap: _isLoading ? null : () => _openItem(index),
          onLongPress: () => _toggleSelection(index),
          child: Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isImage)
                  Image.file(
                    File(item.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.broken_image,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder,
                          size: 48, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(
                        item.path.split('/').last,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                if (isSelected)
                  Container(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    child: Icon(Icons.check_circle,
                        color: theme.colorScheme.onPrimary, size: 30),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      isImage
                          ? '${(File(item.path).lengthSync() / 1024).toStringAsFixed(1)} KB'
                          : item.path.split('/').last,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface),
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}