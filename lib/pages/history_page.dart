import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';


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
    try {
      Directory? baseDir;
      if (Platform.isAndroid) {
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
          _errorMessage = 'No downloads found. Download images to see them here.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download History'),
        actions: [
          PopupMenuButton<SortOption>(
            onSelected: (option) {
              print('Sort option selected: $option, unfocusing');
              FocusScope.of(context).unfocus(); // Unfocus before state change
              setState(() {
                _currentSort = option;
                print('Sort option set to $_currentSort');
              });
              // Delay loading images to ensure focus is cleared
              Future.microtask(() {
                print('Loading images for sort: $_currentSort');
                _loadDownloadedImages();
              });
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
                onPressed: () async {
                  await openAppSettings();
                  await _checkPermissionsAndLoadImages();
                },
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
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
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