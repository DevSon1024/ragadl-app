import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
// import 'models/image_data.dart';
// import 'package:open_filex/open_filex.dart';

enum SortOption {
  newest,
  oldest,
  largest,
  smallest,
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<FileSystemEntity> _downloadedImages = [];
  SortOption _currentSort = SortOption.newest;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadImages();
  }

  Future<void> _checkPermissionsAndLoadImages() async {
    if (Platform.isAndroid) {
      final permissionStatus = await Permission.storage.status;
      final manageStorageStatus = await Permission.manageExternalStorage.status;

      if (!permissionStatus.isGranted && !manageStorageStatus.isGranted) {
        final newStatus = await Permission.manageExternalStorage.request();
        if (!newStatus.isGranted) {
          setState(() {
            _errorMessage =
            'Storage permission denied. Cannot access downloaded images.';
          });
          return;
        }
      }
    }

    await _loadDownloadedImages();
  }

  Future<void> _loadDownloadedImages() async {
    try {
      Directory? baseDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download/Ragalahari Downloads')
          : await getApplicationDocumentsDirectory();

      if (!await baseDir.exists()) {
        setState(() {
          _downloadedImages = [];
          _errorMessage =
          'No downloads found. Download images to see them here.';
        });
        return;
      }

      // Recursively collect all .jpg files from subdirectories
      final List<FileSystemEntity> imageFiles = [];
      await _collectImages(baseDir, imageFiles);

      // Sort the collected images
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
        _errorMessage = imageFiles.isEmpty
            ? 'No images found in the download directory.'
            : null;
      });
    } catch (e) {
      setState(() {
        _downloadedImages = [];
        _errorMessage = 'Error loading images: $e';
      });
    }
  }

  Future<void> _collectImages(
      Directory dir, List<FileSystemEntity> imageFiles) async {
    try {
      final entities = await dir.list(recursive: false).toList();
      for (var entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
          imageFiles.add(entity);
        } else if (entity is Directory) {
          await _collectImages(
              entity, imageFiles); // Recurse into subdirectories
        }
      }
    } catch (e) {
      print('Error scanning directory ${dir.path}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download History'),
        actions: [
          PopupMenuButton<SortOption>(
            onSelected: (option) {
              setState(() => _currentSort = option);
              _loadDownloadedImages();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.newest,
                child: Text('Newest First'),
              ),
              const PopupMenuItem(
                value: SortOption.oldest,
                child: Text('Oldest First'),
              ),
              const PopupMenuItem(
                value: SortOption.largest,
                child: Text('Largest First'),
              ),
              const PopupMenuItem(
                value: SortOption.smallest,
                child: Text('Smallest First'),
              ),
            ],
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            if (_errorMessage!.contains('permission'))
              ElevatedButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
          ],
        ),
      );
    }

    if (_downloadedImages.isEmpty) {
      return const Center(child: Text('No downloaded images found.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: _downloadedImages.length,
      itemBuilder: (context, index) {
        final file = File(_downloadedImages[index].path);
        return GestureDetector(
          onTap: () => _openImage(file),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openImage(File imageFile) async {
    final result = await OpenFilex.open(imageFile.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open image: ${result.message}')),
      );
    }
  }
}
