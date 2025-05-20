import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../widgets/theme_config.dart';
import 'dart:math';

class RecyclePage extends StatefulWidget {
  const RecyclePage({super.key});

  @override
  _RecyclePageState createState() => _RecyclePageState();
}

class _RecyclePageState extends State<RecyclePage> with SingleTickerProviderStateMixin {
  List<FileSystemEntity> _trashedImages = [];
  List<FileSystemEntity> _trashedFolders = [];
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSelectionMode = false;
  Set<int> _selectedImages = {};
  Set<int> _selectedFolders = {};
  int _autoDeleteDays = 7; // Default to 7 days
  static const List<int> _autoDeleteOptions = [7, 15, 30]; // Options: 7 days, 15 days, 30 days
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPreferences();
    _loadTrashedItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoDeleteDays = prefs.getInt('autoDeleteDays') ?? 7;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autoDeleteDays', _autoDeleteDays);
  }

  Future<void> _loadTrashedItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSelectionMode = false;
      _selectedImages.clear();
      _selectedFolders.clear();
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
          _trashedImages = [];
          _trashedFolders = [];
          _errorMessage = 'No trashed items found.';
          _isLoading = false;
        });
        return;
      }

      final List<FileSystemEntity> trashedImages = [];
      final List<FileSystemEntity> trashedFolders = [];
      await _collectTrashedItems(baseDir, trashedImages, trashedFolders);

      // Filter out items past their deletion date and delete them
      final now = DateTime.now();
      final List<FileSystemEntity> validTrashedImages = [];
      final List<FileSystemEntity> validTrashedFolders = [];

      for (var file in trashedImages) {
        final trashedTime = _getTrashedTime(file);
        final daysSinceTrashed = now.difference(trashedTime).inDays;
        if (daysSinceTrashed >= _autoDeleteDays) {
          await File(file.path).delete();
        } else {
          validTrashedImages.add(file);
        }
      }

      for (var folder in trashedFolders) {
        final trashedTime = _getTrashedTime(folder);
        final daysSinceTrashed = now.difference(trashedTime).inDays;
        if (daysSinceTrashed >= _autoDeleteDays) {
          await Directory(folder.path).delete(recursive: true);
        } else {
          validTrashedFolders.add(folder);
        }
      }

      validTrashedImages.sort((a, b) => _getTrashedTime(b).compareTo(_getTrashedTime(a)));
      validTrashedFolders.sort((a, b) => _getTrashedTime(b).compareTo(_getTrashedTime(a)));

      setState(() {
        _trashedImages = validTrashedImages;
        _trashedFolders = validTrashedFolders;
        _errorMessage = validTrashedImages.isEmpty && validTrashedFolders.isEmpty ? 'No trashed items found.' : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _trashedImages = [];
        _trashedFolders = [];
        _errorMessage = 'Error loading trashed items: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _collectTrashedItems(Directory dir, List<FileSystemEntity> trashedImages, List<FileSystemEntity> trashedFolders) async {
    try {
      final entities = await dir.list(recursive: false).toList();
      for (var entity in entities) {
        final entityName = entity.path.split('/').last;
        if (entityName.startsWith('.trashed-')) {
          if (entity is File && entity.path.toLowerCase().endsWith('.jpg') && RegExp(r'^\.trashed-\d+-.*\.jpg$').hasMatch(entityName)) {
            trashedImages.add(entity);
          } else if (entity is Directory && RegExp(r'^\.trashed-\d+-').hasMatch(entityName)) {
            trashedFolders.add(entity);
          }
        }
        if (entity is Directory) {
          await _collectTrashedItems(entity, trashedImages, trashedFolders);
        }
      }
    } catch (e) {
      print('Error scanning directory ${dir.path}: $e');
    }
  }

  DateTime _getTrashedTime(FileSystemEntity entity) {
    final entityName = entity.path.split('/').last;
    final regex = RegExp(r'^\.trashed-(\d+)-');
    final match = regex.firstMatch(entityName);
    if (match != null) {
      final timestamp = int.parse(match.group(1)!);
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return DateTime.now();
  }

  void _toggleSelection(int index, bool isImage) {
    setState(() {
      if (isImage) {
        if (_selectedImages.contains(index)) {
          _selectedImages.remove(index);
        } else {
          _selectedImages.add(index);
        }
      } else {
        if (_selectedFolders.contains(index)) {
          _selectedFolders.remove(index);
        } else {
          _selectedFolders.add(index);
        }
      }
      _isSelectionMode = _selectedImages.isNotEmpty || _selectedFolders.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedImages.clear();
      _selectedFolders.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _restoreSelectedItems() async {
    if (_selectedImages.isEmpty && _selectedFolders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final restoreCount = _selectedImages.length + _selectedFolders.length;
      final List<FileSystemEntity> toRestoreImages = _selectedImages.map((index) => _trashedImages[index]).toList();
      final List<FileSystemEntity> toRestoreFolders = _selectedFolders.map((index) => _trashedFolders[index]).toList();
      final List<String> restoredPaths = [];

      for (var file in toRestoreImages) {
        final fileName = file.path.split('/').last;
        final originalFileName = fileName.replaceFirst(RegExp(r'^\.trashed-\d+-'), '');
        final dirPath = file.path.substring(0, file.path.length - fileName.length);
        final originalPath = '$dirPath$originalFileName';

        final sourceFile = File(file.path);
        if (await sourceFile.exists()) {
          await sourceFile.rename(originalPath);
          restoredPaths.add(originalPath);
        } else {
          throw Exception('File does not exist: ${file.path}');
        }
      }

      for (var folder in toRestoreFolders) {
        final folderName = folder.path.split('/').last;
        final originalFolderName = folderName.replaceFirst(RegExp(r'^\.trashed-\d+-'), '');
        final dirPath = folder.path.substring(0, folder.path.length - folderName.length);
        final originalPath = '$dirPath$originalFolderName';

        final sourceFolder = Directory(folder.path);
        if (await sourceFolder.exists()) {
          await sourceFolder.rename(originalPath);
          restoredPaths.add(originalPath);
        } else {
          throw Exception('Folder does not exist: ${folder.path}');
        }
      }

      await _loadTrashedItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$restoreCount item(s) restored successfully'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                setState(() => _isLoading = true);
                for (var originalPath in restoredPaths) {
                  final entityName = originalPath.split('/').last;
                  final dirPath = originalPath.substring(0, originalPath.length - entityName.length);
                  final trashedPath = '$dirPath.trashed-${DateTime.now().millisecondsSinceEpoch}-$entityName';
                  try {
                    if (originalPath.endsWith('.jpg')) {
                      await File(originalPath).rename(trashedPath);
                    } else {
                      await Directory(originalPath).rename(trashedPath);
                    }
                  } catch (e) {
                    print('Failed to move back $originalPath: $e');
                  }
                }
                await _loadTrashedItems();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Items moved back to recycle bin')),
                  );
                }
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore items: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _permanentlyDeleteSelectedItems() async {
    if (_selectedImages.isEmpty && _selectedFolders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete Items'),
        content: Text('Are you sure you want to permanently delete ${_selectedImages.length + _selectedFolders.length} selected item(s)? This action cannot be undone.'),
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

    setState(() => _isLoading = true);
    try {
      final deleteCount = _selectedImages.length + _selectedFolders.length;
      final List<FileSystemEntity> toDeleteImages = _selectedImages.map((index) => _trashedImages[index]).toList();
      final List<FileSystemEntity> toDeleteFolders = _selectedFolders.map((index) => _trashedFolders[index]).toList();

      for (var file in toDeleteImages) {
        final sourceFile = File(file.path);
        if (await sourceFile.exists()) {
          await sourceFile.delete();
        } else {
          throw Exception('File does not exist: ${file.path}');
        }
      }

      for (var folder in toDeleteFolders) {
        final sourceFolder = Directory(folder.path);
        if (await sourceFolder.exists()) {
          await sourceFolder.delete(recursive: true);
        } else {
          throw Exception('Folder does not exist: ${folder.path}');
        }
      }

      await _loadTrashedItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deleteCount item(s) permanently deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete items: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setAutoDeletePeriod(int days) async {
    setState(() {
      _autoDeleteDays = days;
    });
    await _savePreferences();
    await _loadTrashedItems(); // Reload to apply new deletion period
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-delete period set to $days days')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = Provider.of<ThemeConfig>(context);
    final crossAxisCount = Platform.isWindows ? max(themeConfig.gridColumns, 2) : themeConfig.gridColumns;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? 'Selected ${_selectedImages.length + _selectedFolders.length}' : 'Recycle Bin',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: _isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
          tooltip: 'Cancel Selection',
        )
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Images'),
            Tab(text: 'Folders'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'set_period') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Set Auto-Delete Period'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _autoDeleteOptions.map((days) => RadioListTile<int>(
                        title: Text('$days Days'),
                        value: days,
                        groupValue: _autoDeleteDays,
                        onChanged: (value) {
                          if (value != null) {
                            _setAutoDeletePeriod(value);
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
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'set_period',
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 20),
                    SizedBox(width: 8),
                    Text('Set Auto-Delete Period'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedImages.length + _selectedFolders.length} selected',
                    style: const TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedImages = Set.from(List.generate(_trashedImages.length, (index) => index));
                        _selectedFolders = Set.from(List.generate(_trashedFolders.length, (index) => index));
                      });
                    },
                    child: const Text('Select All'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            )
                : TabBarView(
              controller: _tabController,
              children: [
                // Images Tab
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _trashedImages.isEmpty
                      ? const Center(child: Text('No trashed images'))
                      : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _trashedImages.length,
                    itemBuilder: (context, index) {
                      final file = _trashedImages[index];
                      final trashedTime = _getTrashedTime(file);
                      final daysRemaining = _autoDeleteDays - DateTime.now().difference(trashedTime).inDays;
                      final isSelected = _selectedImages.contains(index);
                      return GestureDetector(
                        onTap: _isLoading ? null : () => _toggleSelection(index, true),
                        onLongPress: () => _toggleSelection(index, true),
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
                                    'Expires in $daysRemaining day${daysRemaining == 1 ? '' : 's'}',
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
                  ),
                ),
                // Folders Tab
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _trashedFolders.isEmpty
                      ? const Center(child: Text('No trashed folders'))
                      : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _trashedFolders.length,
                    itemBuilder: (context, index) {
                      final folder = _trashedFolders[index];
                      final trashedTime = _getTrashedTime(folder);
                      final daysRemaining = _autoDeleteDays - DateTime.now().difference(trashedTime).inDays;
                      final isSelected = _selectedFolders.contains(index);
                      return GestureDetector(
                        onTap: _isLoading ? null : () => _toggleSelection(index, false),
                        onLongPress: () => _toggleSelection(index, false),
                        child: Card(
                          elevation: 2,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.folder,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    folder.path.split('/').last.replaceFirst(RegExp(r'^\.trashed-\d+-'), ''),
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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
                                    'Expires in $daysRemaining day${daysRemaining == 1 ? '' : 's'}',
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isSelectionMode
          ? BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.restore, color: Colors.blue),
              label: const Text('Restore', style: TextStyle(color: Colors.blue)),
              onPressed: _restoreSelectedItems,
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: _permanentlyDeleteSelectedItems,
            ),
          ],
        ),
      )
          : null,
    );
  }
}