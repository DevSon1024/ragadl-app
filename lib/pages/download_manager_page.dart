import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

enum DownloadStatus { downloading, paused, completed, failed }

class DownloadTask {
  final String url;
  final String fileName;
  final String savePath;
  final String folder;
  final String subFolder;
  final CancelToken cancelToken;
  double progress;
  DownloadStatus status;

  DownloadTask({
    required this.url,
    required this.fileName,
    required this.savePath,
    required this.folder,
    required this.subFolder,
    required this.cancelToken,
    this.progress = 0.0,
    this.status = DownloadStatus.downloading,
  });

  DownloadTask copyWith({
    String? url,
    String? fileName,
    String? savePath,
    String? folder,
    String? subFolder,
    CancelToken? cancelToken,
    double? progress,
    DownloadStatus? status,
  }) {
    return DownloadTask(
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      savePath: savePath ?? this.savePath,
      folder: folder ?? this.folder,
      subFolder: subFolder ?? this.subFolder,
      cancelToken: cancelToken ?? this.cancelToken,
      progress: progress ?? this.progress,
      status: status ?? this.status,
    );
  }
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final Map<String, DownloadTask> _activeDownloads = {};
  final Dio _dio = Dio();
  int _batchDownloadCount = 0; // Track number of downloads in current batch
  int _completedDownloads = 0; // Track completed downloads in batch
  int _failedDownloads = 0; // Track failed downloads in batch
  String? _currentBatchId; // Identify current batch

  Map<String, DownloadTask> get activeDownloads => Map.unmodifiable(_activeDownloads);

  Future<void> addDownload({
    required String url,
    required String folder,
    required String subFolder,
    required void Function(double progress) onProgress,
    required void Function(bool success) onComplete,
    String? batchId, // Optional batch ID to group downloads
  }) async {
    if (_activeDownloads.containsKey(url)) {
      final task = _activeDownloads[url]!;
      if (task.status == DownloadStatus.paused) {
        resumeDownload(url);
      }
      return;
    }

    try {
      final directory = await _getDownloadDirectory(folder, subFolder);
      final fileName = url.split('/').last;
      final savePath = '${directory.path}/$fileName';
      final cancelToken = CancelToken();

      final task = DownloadTask(
        url: url,
        fileName: fileName,
        savePath: savePath,
        folder: folder,
        subFolder: subFolder,
        cancelToken: cancelToken,
        progress: 0,
        status: DownloadStatus.downloading,
      );

      _activeDownloads[url] = task;

      // Increment batch counter if part of a batch
      if (batchId != null) {
        if (_currentBatchId == null || _currentBatchId != batchId) {
          _currentBatchId = batchId;
          _batchDownloadCount = 0;
          _completedDownloads = 0;
          _failedDownloads = 0;
        }
        _batchDownloadCount++;
      }

      // Send initial batch notification only for the first download in a batch
      if (batchId != null && _batchDownloadCount == 1) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: batchId.hashCode,
            channelKey: 'download_channel',
            title: 'Downloading Images',
            body: 'Starting download of multiple images...',
            notificationLayout: NotificationLayout.Default,
            locked: true,
          ),
        );
      }

      _download(task, onProgress, (success) async {
        // Update batch counters
        if (batchId != null) {
          if (success) {
            _completedDownloads++;
          } else {
            _failedDownloads++;
          }

          // Check if all downloads in the batch are complete
          if (_completedDownloads + _failedDownloads == _batchDownloadCount) {
            await AwesomeNotifications().createNotification(
              content: NotificationContent(
                id: batchId.hashCode,
                channelKey: 'download_channel',
                title: 'Download Complete',
                body: '$_completedDownloads Images Downloaded${_failedDownloads > 0 ? ', $_failedDownloads Failed' : ''}',
                notificationLayout: NotificationLayout.Default,
                color: _failedDownloads == 0 ? Colors.green : Colors.orange,
                locked: false,
              ),
            );
            // Reset batch counters
            _currentBatchId = null;
            _batchDownloadCount = 0;
            _completedDownloads = 0;
            _failedDownloads = 0;
          }
        } else {
          // For single downloads, show completion notification
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: url.hashCode,
              channelKey: 'download_channel',
              title: success ? 'Download Completed' : 'Download Failed',
              body: success
                  ? '${task.fileName} downloaded successfully'
                  : 'Failed to download ${task.fileName}',
              notificationLayout: NotificationLayout.Default,
              color: success ? Colors.green : Colors.red,
              locked: false,
            ),
          );
        }
        onComplete(success);
      });
    } catch (e) {
      if (batchId != null) {
        _failedDownloads++;
        if (_completedDownloads + _failedDownloads == _batchDownloadCount) {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: batchId.hashCode,
              channelKey: 'download_channel',
              title: 'Download Complete',
              body: '$_completedDownloads Images Downloaded${_failedDownloads > 0 ? ', $_failedDownloads Failed' : ''}',
              notificationLayout: NotificationLayout.Default,
              color: _failedDownloads == 0 ? Colors.green : Colors.orange,
              locked: false,
            ),
          );
          // Reset batch counters
          _currentBatchId = null;
          _batchDownloadCount = 0;
          _completedDownloads = 0;
          _failedDownloads = 0;
        }
      } else {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: url.hashCode,
            channelKey: 'download_channel',
            title: 'Download Failed',
            body: 'Error downloading $url: $e',
            notificationLayout: NotificationLayout.Default,
            color: Colors.red,
          ),
        );
      }
      onComplete(false);
    }
  }

  Future<void> _download(
      DownloadTask task,
      void Function(double progress) onProgress,
      void Function(bool success) onComplete,
      ) async {
    const maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        await _dio.download(
          task.url,
          task.savePath,
          cancelToken: task.cancelToken,
          onReceiveProgress: (received, total) {
            final progress = total > 0 ? received / total : 0.0;
            _activeDownloads[task.url] = task.copyWith(progress: progress);
            onProgress(progress);
            // Skip progress notifications to reduce performance impact
          },
          options: Options(
            headers: {
              'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
            },
            followRedirects: true,
            maxRedirects: 5,
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 15),
          ),
        );

        _activeDownloads[task.url] = task.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
        );
        onComplete(true);
        return;
      } catch (e) {
        attempt++;
        if (e is DioException && CancelToken.isCancel(e)) {
          final currentTask = _activeDownloads[task.url];
          if (currentTask != null && currentTask.status == DownloadStatus.paused) {
            return;
          } else if (task.status == DownloadStatus.paused) {
            return;
          } else {
            _activeDownloads.remove(task.url);
          }
          return;
        }
        if (attempt == maxRetries) {
          _activeDownloads[task.url] = task.copyWith(status: DownloadStatus.failed);
          onComplete(false);
        } else {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
  }

  Future<Directory> _getDownloadDirectory(String folder, String subFolder) async {
    Directory directory;
    final prefs = await SharedPreferences.getInstance();
    String basePath = prefs.getString('base_download_path') ?? '/storage/emulated/0/Download';

    if (Platform.isAndroid) {
      directory = Directory('$basePath/Ragalahari Downloads/$folder/$subFolder');
    } else {
      directory = await getApplicationDocumentsDirectory();
      directory = Directory('${directory.path}/Ragalahari Downloads/$folder/$subFolder');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  void pauseDownload(String url) {
    if (_activeDownloads.containsKey(url)) {
      final task = _activeDownloads[url]!;
      if (task.status == DownloadStatus.downloading) {
        _activeDownloads[url] = task.copyWith(status: DownloadStatus.paused);
        task.cancelToken.cancel('Download paused');
      }
    }
  }

  void resumeDownload(String url) {
    if (_activeDownloads.containsKey(url)) {
      final task = _activeDownloads[url]!;
      if (task.status == DownloadStatus.paused) {
        final newCancelToken = CancelToken();
        final newTask = task.copyWith(
          cancelToken: newCancelToken,
          status: DownloadStatus.downloading,
        );
        _activeDownloads[url] = newTask;

        _download(
          newTask,
              (progress) {},
              (success) {},
        );
      }
    }
  }

  void cancelDownload(String url) {
    if (_activeDownloads.containsKey(url)) {
      final task = _activeDownloads[url]!;
      if (task.status == DownloadStatus.downloading) {
        task.cancelToken.cancel('Download canceled');
        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: url.hashCode,
            channelKey: 'download_channel',
            title: 'Download Cancelled',
            body: '${task.fileName} download was cancelled',
            notificationLayout: NotificationLayout.Default,
            color: Colors.orange,
          ),
        );
      }
      _activeDownloads.remove(url);
    }
  }

  void removeCompletedDownload(String url) {
    if (_activeDownloads.containsKey(url)) {
      final task = _activeDownloads[url]!;
      if (task.status == DownloadStatus.completed || task.status == DownloadStatus.failed) {
        _activeDownloads.remove(url);
      }
    }
  }

  List<DownloadTask> getAllDownloads() {
    return _activeDownloads.values.toList();
  }
}

// Rest of download_manager_page.dart remains unchanged

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  _DownloadManagerPageState createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  final DownloadManager _downloadManager = DownloadManager();
  Map<String, DownloadTask> _downloadTasks = {};

  @override
  void initState() {
    super.initState();
    _loadActiveDownloads();

    // Set up periodic refresh
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _refreshDownloads();
      }
    });
  }

  void _refreshDownloads() {
    if (mounted) {
      setState(() {
        _downloadTasks = _downloadManager.activeDownloads;
      });

      // Schedule next refresh
      Future.delayed(const Duration(seconds: 1), () {
        _refreshDownloads();
      });
    }
  }

  void _loadActiveDownloads() {
    setState(() {
      _downloadTasks = _downloadManager.activeDownloads;
    });
  }

  void _cancelAllDownloadsAndDeleteFolder() async {
    // Cancel all active downloads
    final urls = _downloadTasks.keys.toList();
    for (final url in urls) {
      _downloadManager.cancelDownload(url);
    }

    // Delete the folder if it exists
    final prefs = await SharedPreferences.getInstance();
    String basePath = prefs.getString('base_download_path') ?? '/storage/emulated/0/Download';
    for (var task in _downloadTasks.values) {
      final folderPath = Directory('$basePath/Ragalahari Downloads/${task.folder}/${task.subFolder}');
      if (await folderPath.exists()) {
        await folderPath.delete(recursive: true);
      }
    }

    // Clear the download tasks and refresh
    setState(() {
      _downloadTasks.clear();
    });
    _loadActiveDownloads();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All downloads cancelled and folders deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Download Manager',
          style: TextStyle(
            // color: Colors.white, // Change this to your desired color
            fontWeight: FontWeight.bold, // Optional: Enhance visibility
          ),
        ),

        flexibleSpace: Container(
          decoration: const BoxDecoration(
            // gradient: LinearGradient(
            //   colors: [Colors.black, Colors.white],
            //   begin: Alignment.topLeft,
            //   end: Alignment.bottomRight,
            // ),
            // borderRadius: BorderRadius.vertical(
            //   top: Radius.circular(30),
            //   bottom: Radius.circular(30), // Adjust the radius as needed
            // ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
                 Icons.delete_sweep,
                // color: Colors.green,
            ),
            onPressed: _clearCompleted,
            tooltip: 'Clear Completed Downloads',
          ),
          IconButton(
            icon: const Icon(
                Icons.cancel,
                // color: Colors.green,
            ),
            onPressed: _cancelAllDownloadsAndDeleteFolder,
            tooltip: 'Cancel All Downloads and Delete Folders',
          ),
        ],
      ),
      body: _downloadTasks.isEmpty
          ? const Center(child: Text('No active downloads'))
          : ListView(
        children: _downloadTasks.values.map((task) => DownloadItem(
          task: task,
          onPause: () => _pauseDownload(task.url),
          onResume: () => _resumeDownload(task.url),
          onCancel: () => _cancelDownload(task.url),
          onOpen: task.status == DownloadStatus.completed
              ? () => _openFile(task.savePath)
              : null,
          onRemove: (task.status == DownloadStatus.completed || task.status == DownloadStatus.failed)
              ? () => _removeDownload(task.url)
              : null,
          onRedownload: task.status == DownloadStatus.failed
              ? () => _redownloadFailed(task.url)
              : null,
        )).toList(),
      ),
    );
  }

  void _pauseDownload(String url) {
    _downloadManager.pauseDownload(url);
    _loadActiveDownloads();
  }

  void _resumeDownload(String url) {
    _downloadManager.resumeDownload(url);
    _loadActiveDownloads();
  }

  void _cancelDownload(String url) {
    _downloadManager.cancelDownload(url);
    _loadActiveDownloads();
  }

  void _removeDownload(String url) {
    _downloadManager.removeCompletedDownload(url);
    _loadActiveDownloads();
  }

  void _clearCompleted() {
    final completedUrls = _downloadTasks.keys
        .where((url) => _downloadTasks[url]!.status == DownloadStatus.completed)
        .toList();
    for (final url in completedUrls) {
      _downloadManager.removeCompletedDownload(url);
    }
    _loadActiveDownloads();
  }

  void _redownloadFailed(String url) {
    final task = _downloadTasks[url];
    if (task != null && task.status == DownloadStatus.failed) {
      _downloadManager.removeCompletedDownload(url); // Remove failed task
      _downloadManager.addDownload(
        url: task.url,
        folder: task.folder,
        subFolder: task.subFolder,
        onProgress: (progress) {
          setState(() {
            _downloadTasks[url] = task.copyWith(progress: progress, status: DownloadStatus.downloading);
          });
        },
        onComplete: (success) {
          setState(() {
            if (success) {
              _downloadTasks[url] = task.copyWith(status: DownloadStatus.completed, progress: 1.0);
            } else {
              _downloadTasks[url] = task.copyWith(status: DownloadStatus.failed);
            }
          });
        },
      );
      _loadActiveDownloads();
    }
  }

  void _openFile(String path) {
    // Uncomment the below code after adding open_filex package
    OpenFilex.open(path);

    // For now just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening file: $path')),
    );
  }
}

class DownloadItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;
  final VoidCallback? onRedownload;

  const DownloadItem({
    super.key,
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    this.onOpen,
    this.onRemove,
    this.onRedownload,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        if (task.status == DownloadStatus.failed || task.status == DownloadStatus.paused) {
          _copyImageUrlToClipboard(task.url, context);
        }
      },
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.fileName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${task.folder}/${task.subFolder}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(task.status),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: task.progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getColorForStatus(task.status),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(task.progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onOpen != null)
                        IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: onOpen,
                          tooltip: 'Open file',
                          iconSize: 20,
                        ),
                      if (onRemove != null)
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: onRemove,
                          tooltip: 'Remove from list',
                          iconSize: 20,
                        ),
                      if (task.status == DownloadStatus.failed)
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => onRedownload?.call(),
                          tooltip: 'Retry download',
                          iconSize: 20,
                        ),
                      if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.paused)
                        IconButton(
                          icon: Icon(
                            task.status == DownloadStatus.paused ? Icons.play_arrow : Icons.pause,
                          ),
                          onPressed: task.status == DownloadStatus.paused ? onResume : onPause,
                          tooltip: task.status == DownloadStatus.paused ? 'Resume' : 'Pause',
                          iconSize: 20,
                        ),
                      if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.paused)
                        IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: onCancel,
                          tooltip: 'Cancel',
                          iconSize: 20,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyImageUrlToClipboard(String url, BuildContext context) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image URL copied to clipboard')),
    );
  }

  Widget _buildStatusChip(DownloadStatus status) {
    String label;
    Color color;

    switch (status) {
      case DownloadStatus.downloading:
        label = 'Downloading';
        color = Colors.blue;
        break;
      case DownloadStatus.paused:
        label = 'Paused';
        color = Colors.orange;
        break;
      case DownloadStatus.completed:
        label = 'Completed';
        color = Colors.green;
        break;
      case DownloadStatus.failed:
        label = 'Failed';
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getColorForStatus(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
    }
  }
}