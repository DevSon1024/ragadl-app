import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/theme_config.dart';
import 'history_settings.dart';
import 'history_page.dart';
import 'dart:math';
import 'package:shimmer/shimmer.dart';

class SubFolderPage extends StatefulWidget {
  final FileSystemEntity directory;
  final SortOption sortOption;

  const SubFolderPage({
    super.key,
    required this.directory,
    required this.sortOption,
  });

  @override
  _SubFolderPageState createState() => _SubFolderPageState();
}

class _SubFolderPageState extends State<SubFolderPage> {
  List<FileSystemEntity> _items = [];
  List<FileSystemEntity> _filteredItems = [];
  bool _isLoading = false;
  bool _isSelectionMode = false;
  Set<int> _selectedItems = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<FileSystemEntity> items = [];
      final dir = Directory(widget.directory.path);
      final entities = await dir.list(recursive: false).toList();
      for (var entity in entities) {
        final name = entity.path.split('/').last;
        if (name.startsWith('.trashed-')) continue;
        if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
          items.add(entity);
        } else if (entity is Directory) {
          items.add(entity);
        }
      }

      items.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        switch (widget.sortOption) {
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
        _items = items;
        _filteredItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _items = [];
        _filteredItems = [];
        _isLoading = false;
      });
    }
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items.where((item) {
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
              sortOption: widget.sortOption,
            ),
          ),
        );
      }
    }
  }
  Future<Map<String, dynamic>> _getFolderDetails(Directory dir) async {
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
        } else if (entity is Directory) {
          folderCount++;
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

  @override
  Widget build(BuildContext context) {
    final themeConfig = Provider.of<ThemeConfig>(context);
    final crossAxisCount = Platform.isWindows ? max(themeConfig.gridColumns, 2) : themeConfig.gridColumns;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.directory.path.split('/').last),
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
          Expanded(
            child: _isLoading
                ? GridView.builder(
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
            )
                : _filteredItems.isEmpty
                ? const Center(
              child: Text(
                'No items found.',
                style: TextStyle(fontSize: 16),
              ),
            )
                : GridView.builder(
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

                return FutureBuilder<Map<String, dynamic>>(
                  future: isImage ? Future.value({'totalSize': item.statSync().size, 'imageCount': 1}) : _getFolderDetails(Directory(item.path)),
                  builder: (context, snapshot) {
                    final size = snapshot.data != null ? snapshot.data!['totalSize'] as int : 0;
                    final imageCount = snapshot.data != null ? snapshot.data!['imageCount'] as int : 0;
                    final latestImage = snapshot.data != null ? snapshot.data!['latestImage'] as File? : null;

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
                              latestImage != null
                                  ? Image.file(
                                latestImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Column(
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
                              )
                                  : Column(
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
                                child: Column(
                                  children: [
                                    Text(
                                      isImage
                                          ? '${(size / 1024).toStringAsFixed(1)} KB'
                                          : '${(size / (1024 * 1024)).toStringAsFixed(2)} MB',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      '$imageCount images',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
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
            ),
          ),
        ],
      ),
    );
  }
}