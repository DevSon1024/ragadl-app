import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../widgets/theme_config.dart';
import 'recycle_page.dart';
import 'dart:math';
import '../../permissions.dart';
import 'package:permission_handler/permission_handler.dart';
import 'history_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sub_folder_page.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
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
    _animationController?.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getFolderDetails(Directory dir, {bool countSubfolders = false}) async {
    int imageCount = 0;
    int folderCount = 0;
    int totalSize = 0;
    File? latestImage;
    DateTime? latestModified;

    try {
      final entities = await dir.list(recursive: true).toList();
      for (var entity in entities) {
        if (entity is File && ['jpg', 'jpeg', 'png'].contains(entity.path.toLowerCase().split('.').last)) {
          imageCount++;
          totalSize += entity.statSync().size;
          final modified = entity.statSync().modified;
          if (latestModified == null || modified.isAfter(latestModified)) {
            latestModified = modified;
            latestImage = entity;
          }
        } else if (entity is Directory && countSubfolders) {
          folderCount++;
          // Include size of all files in subfolders
          final subEntities = await Directory(entity.path).list(recursive: true).toList();
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
        _errorMessage = 'Storage or media permission denied. Cannot access or modify downloaded items. Please grant permissions in app settings.';
      });
      return;
    }

    await _loadDownloadedItems();
  }

  Future<bool> _checkAndRequestPermissions() async {
    if (!Platform.isAndroid) {
      // Non-Android platforms use standard storage permissions
      return await PermissionHandler.checkStoragePermissions() ||
          await PermissionHandler.requestAllPermissions(context);
    }

    // Android-specific permission handling
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 30) {
      // Android 11+ (API 30+): Request MANAGE_EXTERNAL_STORAGE
      final manageStorageStatus = await Permission.manageExternalStorage.status;
      if (!manageStorageStatus.isGranted) {
        final result = await Permission.manageExternalStorage.request();
        if (!result.isGranted) {
          // Prompt user to grant permission via settings
          await _showPermissionDialog();
          return false;
        }
      }
    } else {
      // Android 10 or below: Use storage permission
      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        final result = await Permission.storage.request();
        if (!result.isGranted) {
          await _showPermissionDialog();
          return false;
        }
      }
    }

    // Check media permissions for additional safety
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
          'This app requires storage permissions to manage files. Please grant "Manage All Files" permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              Navigator.pop(context);
              // Re-check permissions after returning from settings
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
          _errorMessage = 'No downloads found. Download items to see them here.';
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
            return aStat.size.compareTo(aStat.size);
        }
      });

      setState(() {
        _downloadedItems = items;
        _filteredItems = items;
        _errorMessage = items.isEmpty ? 'No items found in the download directory.' : null;
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
        // For galleriesFolder, collect subfolders (galleries) within each top-level celebrity folder
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
        // Existing logic for other presets
        final entities = await dir.list(recursive: _currentPreset == ViewPreset.images).toList();
        for (var entity in entities) {
          final name = entity.path.split('/').last;
          if (name.startsWith('.trashed-')) continue;

          if (_currentPreset == ViewPreset.images && entity is File) {
            final extension = entity.path.toLowerCase().split('.').last;
            if (['jpg', 'jpeg', 'png'].contains(extension)) {
              items.add(entity);
            }
          } else if (_currentPreset == ViewPreset.celebrityAlbum && entity is Directory) {
            items.add(entity); // Include all top-level directories
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text('Are you sure you want to move ${_selectedItems.length} selected item(s) to the recycle bin?'),
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
      // Re-check permissions before file operations
      final permissionsGranted = await _checkAndRequestPermissions();
      if (!permissionsGranted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot move items: Permission denied')),
        );
        return;
      }

      final deleteCount = _selectedItems.length;
      final List<FileSystemEntity> toDelete = _selectedItems.map((index) => _filteredItems[index]).toList();
      final List<String> trashedPaths = [];

      for (var item in toDelete) {
        final name = item.path.split('/').last;
        final dirPath = item.path.substring(0, item.path.length - name.length);
        final trashedPath = '$dirPath.trashed-${DateTime.now().millisecondsSinceEpoch}-$name';
        await (item is File ? File(item.path) : Directory(item.path)).rename(trashedPath);
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
                final originalPath = trashedPath.replaceFirst(RegExp(r'\.trashed-\d+-'), '', trashedPath.lastIndexOf('/'));
                try {
                  await (trashedPath.endsWith('.jpg') ? File(trashedPath) : Directory(trashedPath)).rename(originalPath);
                } catch (e) {
                  print('Failed to restore $trashedPath: $e');
                }
              }
              await _loadDownloadedItems();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Items restored')),
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
          SnackBar(content: Text('Failed to move items: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _shareSelectedItems() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected')),
      );
      return;
    }
    if (Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing is not supported on Windows')),
      );
      return;
    }
    final List<String> paths = _selectedItems
        .map((index) => _filteredItems[index])
        .where((item) => item is File)
        .map((item) => item.path)
        .toList();
    if (paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images selected for sharing')),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? 'Selected ${_selectedItems.length}' : 'Download History',
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
              Icons.view_module,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => ViewPresetSelector(
                  currentPreset: _currentPreset,
                  currentViewType: _viewType,
                  onPresetSelected: (preset) {
                    setState(() {
                      _currentPreset = preset;
                    });
                    _savePreset(preset);
                    _loadDownloadedItems();
                    Navigator.pop(context);
                  },
                  onViewTypeSelected: (type) {
                    setState(() {
                      _viewType = type;
                    });
                    _saveViewType(type);
                    Navigator.pop(context);
                  },
                ),
              );
            },
            tooltip: 'View Options',
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
                      _loadDownloadedItems();
                      Navigator.pop(context);
                    },
                  ),
                );
              } else if (value == 'delete') {
                _deleteSelectedItems();
              } else if (value == 'share') {
                _shareSelectedItems();
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
                enabled: _selectedItems.isNotEmpty,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete,
                      size: 20,
                      color: _selectedItems.isEmpty ? Colors.grey : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Delete Selected',
                      style: TextStyle(color: _selectedItems.isEmpty ? Colors.grey : Colors.red),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                enabled: _selectedItems.isNotEmpty,
                child: Row(
                  children: [
                    Icon(
                      Icons.share,
                      size: 20,
                      color: _selectedItems.isEmpty ? Colors.grey : Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Share Selected',
                      style: TextStyle(color: _selectedItems.isEmpty ? Colors.grey : Theme.of(context).primaryColor),
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
                hintText: 'Search items...',
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
                    _filterItems();
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
                    '${_selectedItems.length} selected',
                    style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColor),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedItems = Set.from(List.generate(_filteredItems.length, (index) => index));
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
      if (_viewType == ViewType.grid || _currentPreset == ViewPreset.images) {
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
      } else {
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[300],
                ),
                title: Container(
                  height: 12,
                  color: Colors.grey[300],
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
                    await _checkPermissionsAndLoadItems();
                  },
                ),
              ),
          ],
        ),
      );
    }

    if (_filteredItems.isEmpty) {
      return const Center(
        child: Text(
          'No items found.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    if (_currentPreset == ViewPreset.images && _viewType == ViewType.list) {
      return ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          final isSelected = _selectedItems.contains(index);
          final isImage = item is File;

          return ListTile(
            leading: isImage
                ? SizedBox(
              width: 48,
              height: 48,
              child: Image.file(
                File(item.path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.broken_image,
                  size: 48,
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
            )
                : Icon(
              Icons.folder,
              size: 48,
              color: Theme.of(context).iconTheme.color,
            ),
            title: Text(
              item.path.split('/').last,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: isImage
                ? Text(
              '${(File(item.path).lengthSync() / 1024).toStringAsFixed(1)} KB',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
                : null,
            trailing: isSelected
                ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.onPrimary,
            )
                : null,
            onTap: _isLoading ? null : () => _openItem(index),
            onLongPress: () => _toggleSelection(index),
            selected: isSelected,
            selectedTileColor: Colors.blue.withOpacity(0.1),
          );
        },
      );
    }

    if (_currentPreset == ViewPreset.galleriesFolder || _currentPreset == ViewPreset.celebrityAlbum) {
      if (_viewType == ViewType.list) {
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: _filteredItems.length,
          itemBuilder: (context, index) {
            final item = _filteredItems[index];
            final isSelected = _selectedItems.contains(index);

            return FutureBuilder<Map<String, dynamic>>(
              future: item is Directory
                  ? _getFolderDetails(item, countSubfolders: _currentPreset == ViewPreset.celebrityAlbum)
                  : Future.value({'imageCount': 0, 'totalSize': 0, 'latestImage': null}),
              builder: (context, snapshot) {
                final imageCount = snapshot.data?['imageCount'] ?? 0;
                final folderCount = snapshot.data?['folderCount'] ?? 0;
                final totalSize = snapshot.data?['totalSize'] ?? 0;
                final latestImage = snapshot.data?['latestImage'] as File?;
                final sizeInMB = (totalSize / (1024 * 1024)).toStringAsFixed(2);

                Widget leadingIcon = Icon(
                  Icons.folder,
                  size: 48,
                  color: Theme.of(context).iconTheme.color,
                );

                if (latestImage != null) {
                  leadingIcon = SizedBox(
                    width: 48,
                    height: 48,
                    child: Image.file(
                      latestImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.folder,
                        size: 48,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                  );
                }

                return ListTile(
                  leading: leadingIcon,
                  title: Text(
                    item.path.split('/').last,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: item is Directory
                      ? Text(
                    _currentPreset == ViewPreset.celebrityAlbum
                        ? '$folderCount folder${folderCount == 1 ? '' : 's'}, $sizeInMB MB'
                        : '$imageCount image${imageCount == 1 ? '' : 's'}, $sizeInMB MB',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  )
                      : null,
                  trailing: isSelected
                      ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.onPrimary,
                  )
                      : null,
                  onTap: _isLoading ? null : () => _openItem(index),
                  onLongPress: () => _toggleSelection(index),
                  selected: isSelected,
                  selectedTileColor: Colors.blue.withOpacity(0.1),
                );
              },
            );
          },
        );
      } else {
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.75,
          ),
          itemCount: _filteredItems.length,
          itemBuilder: (context, index) {
            final item = _filteredItems[index];
            final isSelected = _selectedItems.contains(index);

            return FutureBuilder<Map<String, dynamic>>(
              future: item is Directory
                  ? _getFolderDetails(item, countSubfolders: _currentPreset == ViewPreset.celebrityAlbum)
                  : Future.value({'imageCount': 0, 'totalSize': 0, 'latestImage': null}),
              builder: (context, snapshot) {
                final imageCount = snapshot.data?['imageCount'] ?? 0;
                final folderCount = snapshot.data?['folderCount'] ?? 0;
                final totalSize = snapshot.data?['totalSize'] ?? 0;
                final latestImage = snapshot.data?['latestImage'] as File?;
                final sizeInMB = (totalSize / (1024 * 1024)).toStringAsFixed(2);

                Widget thumbnail = Icon(
                  Icons.folder,
                  size: 48,
                  color: Theme.of(context).iconTheme.color,
                );

                if (latestImage != null) {
                  thumbnail = Image.file(
                    latestImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.folder,
                      size: 48,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  );
                }

                return GestureDetector(
                  onTap: _isLoading ? null : () => _openItem(index),
                  onLongPress: () => _toggleSelection(index),
                  child: Card(
                    elevation: 2,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        thumbnail,
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
                              _currentPreset == ViewPreset.celebrityAlbum
                                  ? '${item.path.split('/').last}\n$folderCount folder${folderCount == 1 ? '' : 's'}, $sizeInMB MB'
                                  : '${item.path.split('/').last}\n$imageCount image${imageCount == 1 ? '' : 's'}, $sizeInMB MB',
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
          },
        );
      }
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
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
            elevation: 2,
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
                      color: Theme.of(context).iconTheme.color,
                    ),
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder,
                        size: 48,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.path.split('/').last,
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
                      isImage
                          ? '${(File(item.path).lengthSync() / 1024).toStringAsFixed(1)} KB'
                          : item.path.split('/').last,
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