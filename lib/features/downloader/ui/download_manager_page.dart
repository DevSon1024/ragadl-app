import 'dart:io';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
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
  int retryCount;
  final void Function(double)? onProgress;
  final void Function(bool)? onComplete;

  DownloadTask({
    required this.url,
    required this.fileName,
    required this.savePath,
    required this.folder,
    required this.subFolder,
    required this.cancelToken,
    this.progress = 0.0,
    this.status = DownloadStatus.downloading,
    this.retryCount = 0,
    this.onProgress,
    this.onComplete,
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
    int? retryCount,
    void Function(double)? onProgress,
    void Function(bool)? onComplete,
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
      retryCount: retryCount ?? this.retryCount,
      onProgress: onProgress ?? this.onProgress,
      onComplete: onComplete ?? this.onComplete,
    );
  }
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final Map<String, DownloadTask> _activeDownloads = {};
  final List<String> _downloadQueue = [];
  final Dio _dio = Dio();
  final Set<String> _downloadingUrls = <String>{};
  int _batchDownloadCount = 0;
  int _completedDownloads = 0;
  int _failedDownloads = 0;
  String? _currentBatchId;
  static const int maxConcurrent = 5;
  static const int maxRetries = 3;

  Map<String, DownloadTask> get activeDownloads => Map.unmodifiable(_activeDownloads);

  Map<String, DownloadTask> get visibleDownloads {
    return Map.fromEntries(
        _activeDownloads.entries.where((entry) =>
        entry.value.status == DownloadStatus.failed ||
            entry.value.status == DownloadStatus.paused ||
            entry.value.status == DownloadStatus.downloading));
  }

  Future<void> addDownload({
    required String url,
    required String folder,
    required String subFolder,
    required void Function(double progress) onProgress,
    required void Function(bool success) onComplete,
    String? batchId,
  }) async {
    if (_activeDownloads.containsKey(url)) {
      final task = _activeDownloads[url]!;
      if (task.status == DownloadStatus.paused) {
        resumeDownload(url);
      }
      return;
    }

    DownloadTask? task;
    try {
      final directory = await _getDownloadDirectory(folder, subFolder);
      final fileName = url.split('/').last;
      final savePath = '${directory.path}/$fileName';
      final cancelToken = CancelToken();

      task = DownloadTask(
        url: url,
        fileName: fileName,
        savePath: savePath,
        folder: folder,
        subFolder: subFolder,
        cancelToken: cancelToken,
        progress: 0,
        status: DownloadStatus.downloading,
        retryCount: 0,
        onProgress: onProgress,
        onComplete: onComplete,
      );

      _activeDownloads[url] = task;

      if (batchId != null) {
        if (_currentBatchId == null || _currentBatchId != batchId) {
          _currentBatchId = batchId;
          _batchDownloadCount = 0;
          _completedDownloads = 0;
          _failedDownloads = 0;
        }
        _batchDownloadCount++;
      }

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

      _enqueueDownload(task, batchId);
    } catch (e) {
      if (task != null) {
        _activeDownloads.remove(url);
      }
      if (batchId != null) {
        _failedDownloads++;
        if (_completedDownloads + _failedDownloads == _batchDownloadCount) {
          _notifyBatchComplete(batchId);
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

  void _enqueueDownload(DownloadTask task, String? batchId) {
    if (_downloadingUrls.length < maxConcurrent) {
      _startDownload(task, batchId);
    } else {
      _downloadQueue.add(task.url);
    }
  }

  void _startDownload(DownloadTask task, String? batchId) {
    _downloadingUrls.add(task.url);
    _download(task, (success) {
      _handleDownloadComplete(task.url, success, batchId);
    });
  }

  void _handleDownloadComplete(String url, bool success, String? batchId) {
    _downloadingUrls.remove(url);
    final task = _activeDownloads[url];

    if (success) {
      if (task != null) {
        final completedTask = task.copyWith(status: DownloadStatus.completed, progress: 1.0);
        _activeDownloads[url] = completedTask;
        if (batchId == null) {
          AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: url.hashCode,
              channelKey: 'download_channel',
              title: 'Download Completed',
              body: '${task.fileName} downloaded successfully',
              notificationLayout: NotificationLayout.Default,
              color: Colors.green,
              locked: false,
            ),
          );
        } else {
          _completedDownloads++;
        }
        Future.delayed(const Duration(seconds: 2), () {
          _activeDownloads.remove(url);
        });
        task.onComplete?.call(true);
      }
    } else {
      if (task != null && task.retryCount < maxRetries) {
        final newTask = task.copyWith(
          retryCount: task.retryCount + 1,
          status: DownloadStatus.downloading,
          progress: 0.0,
        );
        _activeDownloads[url] = newTask;
        _startDownload(newTask, batchId);
        return;
      }
      // Final failure
      if (task != null) {
        final failedTask = task.copyWith(status: DownloadStatus.failed);
        _activeDownloads[url] = failedTask;
        if (batchId == null) {
          AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: url.hashCode,
              channelKey: 'download_channel',
              title: 'Download Failed',
              body: 'Failed to download ${task.fileName} after ${task.retryCount + 1} attempts',
              notificationLayout: NotificationLayout.Default,
              color: Colors.red,
              locked: false,
            ),
          );
        } else {
          _failedDownloads++;
        }
        task.onComplete?.call(false);
      }
    }

    if (batchId != null && _completedDownloads + _failedDownloads == _batchDownloadCount) {
      _notifyBatchComplete(batchId);
    }

    _processQueue(batchId);
  }

  void _processQueue(String? batchId) {
    while (_downloadQueue.isNotEmpty && _downloadingUrls.length < maxConcurrent) {
      final url = _downloadQueue.removeAt(0);
      final task = _activeDownloads[url];
      if (task != null) {
        _startDownload(task, batchId);
      }
    }
  }

  Future<void> _download(
      DownloadTask task,
      void Function(bool success) onCompleteInner,
      ) async {
    final file = File(task.savePath);
    int start = 0;
    bool canResume = false;
    int? totalBytes;

    if (await file.exists()) {
      start = await file.length();
      if (start > 0) {
        try {
          final headResponse = await _dio.head(
            task.url,
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
              },
            ),
          );
          if (headResponse.headers.value('accept-ranges') == 'bytes') {
            canResume = true;
            final totalStr = headResponse.headers.value('content-length');
            if (totalStr != null) {
              totalBytes = int.parse(totalStr);
              if (start >= totalBytes) {
                onCompleteInner(true);
                return;
              }
              final initialProgress = start / totalBytes;
              _activeDownloads[task.url] = task.copyWith(progress: initialProgress);
              task.onProgress?.call(initialProgress);
            }
          } else {
            await file.delete();
            start = 0;
          }
        } catch (e) {
          await file.delete();
          start = 0;
        }
      }
    }

    try {
      final headers = <String, dynamic>{
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      };
      if (canResume && start > 0) {
        headers['Range'] = 'bytes=$start-';
      }
      await _dio.download(
        task.url,
        task.savePath,
        cancelToken: task.cancelToken,
        deleteOnError: false,
        onReceiveProgress: (received, total) {
          double progress;
          if (canResume && start > 0 && total != null) {
            progress = (start + received) / total;
          } else {
            progress = total > 0 ? received / total : 0.0;
          }
          _activeDownloads[task.url] = task.copyWith(progress: progress);
          task.onProgress?.call(progress);
        },
        options: Options(
          headers: headers,
          followRedirects: true,
          maxRedirects: 5,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      onCompleteInner(true);
    } catch (e) {
      print('Download error for ${task.url}: $e');
      if (e is DioException && CancelToken.isCancel(e)) {
        onCompleteInner(false);
      } else {
        onCompleteInner(false);
      }
    }
  }

  void _notifyBatchComplete(String batchId) {
    AwesomeNotifications().createNotification(
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
    _currentBatchId = null;
    _batchDownloadCount = 0;
    _completedDownloads = 0;
    _failedDownloads = 0;
  }

  Future<Directory> _getDownloadDirectory(String folder, String subFolder) async {
    final prefs = await SharedPreferences.getInstance();
    String basePath = prefs.getString('base_download_path') ?? '/storage/emulated/0/Download';
    Directory directory;

    if (Platform.isAndroid) {
      directory = Directory('$basePath/$folder/$subFolder');
    } else {
      directory = await getApplicationDocumentsDirectory();
      directory = Directory('${directory.path}/$folder/$subFolder');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  void pauseDownload(String url) {
    final task = _activeDownloads[url];
    if (task != null && task.status == DownloadStatus.downloading) {
      _activeDownloads[url] = task.copyWith(status: DownloadStatus.paused);
      task.cancelToken.cancel('Download paused');
      _downloadingUrls.remove(url);
      _processQueue(null);
    }
  }

  void resumeDownload(String url) {
    final task = _activeDownloads[url];
    if (task != null && task.status == DownloadStatus.paused) {
      final newCancelToken = CancelToken();
      final newTask = task.copyWith(
        cancelToken: newCancelToken,
        status: DownloadStatus.downloading,
      );
      _activeDownloads[url] = newTask;
      _enqueueDownload(newTask, null);
    }
  }

  void cancelDownload(String url) {
    final task = _activeDownloads[url];
    if (task != null) {
      if (task.status == DownloadStatus.downloading) {
        task.cancelToken.cancel('Download canceled');
        _downloadingUrls.remove(url);
        _processQueue(null);
      }
      _activeDownloads.remove(url);
      _downloadQueue.remove(url);
      if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.paused) {
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
    _loadVisibleDownloads();

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
      Future.delayed(const Duration(seconds: 1), () {
        _refreshDownloads();
      });
    }
  }

  void _loadVisibleDownloads() {
    setState(() {
      _downloadTasks = _downloadManager.visibleDownloads;
    });
  }

  void _cancelAllDownloadsAndDeleteFolder() async {
    final urls = List<String>.from(_downloadTasks.keys);
    for (final url in urls) {
      _downloadManager.cancelDownload(url);
    }

    final prefs = await SharedPreferences.getInstance();
    String basePath = prefs.getString('base_download_path') ?? '/storage/emulated/0/Download';
    for (var task in _downloadTasks.values) {
      final folderPath = Directory('$basePath/${task.folder}/${task.subFolder}');
      if (await folderPath.exists()) {
        await folderPath.delete(recursive: true);
      }
    }

    setState(() {
      _downloadTasks.clear();
    });
    _loadVisibleDownloads();
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
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearFailedAndPaused,
            tooltip: 'Clear Failed & Paused Downloads',
          ),
          IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: _cancelAllDownloadsAndDeleteFolder,
            tooltip: 'Cancel All Downloads and Delete Folders',
          ),
        ],
      ),
      body: _downloadTasks.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_done,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No active downloads',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Failed and paused downloads will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
          : ListView(
        children: _downloadTasks.values.map((task) => DownloadItem(
          task: task,
          onPause: () => _pauseDownload(task.url),
          onResume: () => _resumeDownload(task.url),
          onCancel: () => _cancelDownload(task.url),
          onRemove: () => _removeDownload(task.url),
          onRedownload: task.status == DownloadStatus.failed
              ? () => _redownloadFailed(task.url)
              : null,
        )).toList(),
      ),
    );
  }

  void _pauseDownload(String url) {
    _downloadManager.pauseDownload(url);
    _loadVisibleDownloads();
  }

  void _resumeDownload(String url) {
    _downloadManager.resumeDownload(url);
    _loadVisibleDownloads();
  }

  void _cancelDownload(String url) {
    _downloadManager.cancelDownload(url);
    _loadVisibleDownloads();
  }

  void _removeDownload(String url) {
    _downloadManager.removeCompletedDownload(url);
    _loadVisibleDownloads();
  }

  void _clearFailedAndPaused() {
    final urlsToRemove = _downloadTasks.keys
        .where((url) =>
    _downloadTasks[url]!.status == DownloadStatus.failed ||
        _downloadTasks[url]!.status == DownloadStatus.paused)
        .toList();

    for (final url in urlsToRemove) {
      _downloadManager.removeCompletedDownload(url);
    }
    _loadVisibleDownloads();

    if (urlsToRemove.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleared ${urlsToRemove.length} downloads')),
      );
    }
  }

  void _redownloadFailed(String url) {
    final task = _downloadTasks[url];
    if (task != null && task.status == DownloadStatus.failed) {
      _downloadManager.removeCompletedDownload(url);
      _downloadManager.addDownload(
        url: task.url,
        folder: task.folder,
        subFolder: task.subFolder,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              final currentTask = _downloadManager.activeDownloads[url];
              if (currentTask != null) {
                _downloadTasks[url] = currentTask;
              } else {
                _downloadTasks[url] = task.copyWith(progress: progress, status: DownloadStatus.downloading);
              }
            });
          }
        },
        onComplete: (success) {
          if (mounted) {
            setState(() {
              _loadVisibleDownloads();
            });
          }
        },
      );
    }
  }
}

class DownloadItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback? onRemove;
  final VoidCallback? onRedownload;

  const DownloadItem({
    super.key,
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
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
                        if (task.retryCount > 0)
                          Text(
                            'Retries: ${task.retryCount}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                            ),
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
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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