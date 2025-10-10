import 'dart:io';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:open_file/open_file.dart';

enum DownloadStatus { downloading, paused, completed, failed, queued }

class DownloadTask {
  final String url;
  final String fileName;
  final String savePath;
  final String folder;
  final String subFolder;
  final String galleryName;
  CancelToken cancelToken;
  double progress;
  DownloadStatus status;
  int retryCount;
  final void Function(double)? onProgress;
  final void Function(bool)? onComplete;
  final DateTime addedTime;
  DateTime? completedTime;
  String? errorMessage;

  DownloadTask({
    required this.url,
    required this.fileName,
    required this.savePath,
    required this.folder,
    required this.subFolder,
    required this.galleryName,
    required this.cancelToken,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.retryCount = 0,
    this.onProgress,
    this.onComplete,
    DateTime? addedTime,
    this.completedTime,
    this.errorMessage,
  }) : addedTime = addedTime ?? DateTime.now();

  DownloadTask copyWith({
    String? url,
    String? fileName,
    String? savePath,
    String? folder,
    String? subFolder,
    String? galleryName,
    CancelToken? cancelToken,
    double? progress,
    DownloadStatus? status,
    int? retryCount,
    void Function(double)? onProgress,
    void Function(bool)? onComplete,
    DateTime? addedTime,
    DateTime? completedTime,
    String? errorMessage,
  }) {
    return DownloadTask(
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      savePath: savePath ?? this.savePath,
      folder: folder ?? this.folder,
      subFolder: subFolder ?? this.subFolder,
      galleryName: galleryName ?? this.galleryName,
      cancelToken: cancelToken ?? this.cancelToken,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      onProgress: onProgress ?? this.onProgress,
      onComplete: onComplete ?? this.onComplete,
      addedTime: addedTime ?? this.addedTime,
      completedTime: completedTime ?? this.completedTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal() {
    _loadConcurrentDownloads();
  }

  final Map<String, DownloadTask> _activeDownloads = {};
  final Queue<String> _downloadQueue = Queue();
  final Dio _dio = Dio();
  final Set<String> _downloadingUrls = {};

  // Gallery-based download tracking
  final Map<String, int> _galleryTotalCount = {};
  final Map<String, int> _galleryCompletedCount = {};
  final Map<String, int> _galleryFailedCount = {};
  final Map<String, bool> _galleryNotificationShown = {};

  int _maxConcurrentDownloads = 3; // Default value
  static const int maxRetries = 3;

  Map<String, DownloadTask> get activeDownloads => Map.unmodifiable(_activeDownloads);

  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  // Get downloads by status
  Map<String, DownloadTask> get runningDownloads {
    return Map.fromEntries(
        _activeDownloads.entries.where((entry) =>
        entry.value.status == DownloadStatus.downloading ||
            entry.value.status == DownloadStatus.queued
        )
    );
  }

  Map<String, DownloadTask> get failedDownloads {
    return Map.fromEntries(
        _activeDownloads.entries.where((entry) =>
        entry.value.status == DownloadStatus.failed
        )
    );
  }

  Map<String, DownloadTask> get completedDownloads {
    return Map.fromEntries(
        _activeDownloads.entries.where((entry) =>
        entry.value.status == DownloadStatus.completed
        )
    );
  }

  Map<String, DownloadTask> get pausedDownloads {
    return Map.fromEntries(
        _activeDownloads.entries.where((entry) =>
        entry.value.status == DownloadStatus.paused
        )
    );
  }

  // Load concurrent downloads setting
  Future<void> _loadConcurrentDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    _maxConcurrentDownloads = prefs.getInt('max_concurrent_downloads') ?? 3;
  }

  // Set concurrent downloads limit
  Future<void> setMaxConcurrentDownloads(int count) async {
    if (count < 1 || count > 10) return;
    _maxConcurrentDownloads = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_concurrent_downloads', count);
    _processQueue();
  }

  Future<void> addDownload({
    required String url,
    required String folder,
    required String subFolder,
    required String galleryName,
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
        galleryName: galleryName,
        cancelToken: cancelToken,
        progress: 0,
        status: DownloadStatus.queued,
        retryCount: 0,
        onProgress: onProgress,
        onComplete: onComplete,
      );

      _activeDownloads[url] = task;

      // Initialize gallery tracking
      if (batchId != null) {
        _galleryTotalCount[batchId] = (_galleryTotalCount[batchId] ?? 0) + 1;

        // Show initial gallery notification only once
        if (_galleryTotalCount[batchId] == 1) {
          await showGalleryProgressNotification(batchId, galleryName, 0, 1);
        }
      }

      _enqueueDownload(task, batchId);
    } catch (e) {
      if (task != null) {
        _activeDownloads.remove(url);
      }
      if (batchId != null) {
        _galleryFailedCount[batchId] = (_galleryFailedCount[batchId] ?? 0) + 1;
      }
      onComplete(false);
    }
  }

  void _enqueueDownload(DownloadTask task, String? batchId) {
    if (_downloadingUrls.length < _maxConcurrentDownloads) {
      _startDownload(task, batchId);
    } else {
      _downloadQueue.add(task.url);
      // Update status to queued
      _activeDownloads[task.url] = task.copyWith(status: DownloadStatus.queued);
    }
  }

  void _startDownload(DownloadTask task, String? batchId) {
    _downloadingUrls.add(task.url);
    _activeDownloads[task.url] = task.copyWith(status: DownloadStatus.downloading);
    _download(task, (success) {
      _handleDownloadComplete(task.url, success, batchId);
    });
  }

  void _handleDownloadComplete(String url, bool success, String? batchId) {
    _downloadingUrls.remove(url);
    final task = _activeDownloads[url];

    if (success) {
      if (task != null) {
        final completedTask = task.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          completedTime: DateTime.now(),
        );
        _activeDownloads[url] = completedTask;

        if (batchId != null) {
          _galleryCompletedCount[batchId] = (_galleryCompletedCount[batchId] ?? 0) + 1;
          _updateGalleryProgress(batchId, task.galleryName);
        }

        task.onComplete?.call(true);
      }
    } else {
      if (task != null && task.retryCount < maxRetries && task.status != DownloadStatus.paused) {
        // Retry logic
        final newTask = task.copyWith(
          retryCount: task.retryCount + 1,
          status: DownloadStatus.downloading,
          progress: 0.0,
          cancelToken: CancelToken(),
        );
        _activeDownloads[url] = newTask;
        _startDownload(newTask, batchId);
        return;
      }

      // Final failure
      if (task != null) {
        final failedTask = task.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'Download failed after ${task.retryCount + 1} attempts',
        );
        _activeDownloads[url] = failedTask;

        if (batchId != null) {
          _galleryFailedCount[batchId] = (_galleryFailedCount[batchId] ?? 0) + 1;
          _updateGalleryProgress(batchId, task.galleryName);
        }

        task.onComplete?.call(false);
      }
    }

    _processQueue();
  }

  void _processQueue() {
    while (_downloadQueue.isNotEmpty && _downloadingUrls.length < _maxConcurrentDownloads) {
      final url = _downloadQueue.removeFirst();
      final task = _activeDownloads[url];
      if (task != null && task.status != DownloadStatus.paused) {
        _startDownload(task, null);
      }
    }
  }

  Future<void> _updateGalleryProgress(String batchId, String galleryName) async {
    final total = _galleryTotalCount[batchId] ?? 0;
    final completed = _galleryCompletedCount[batchId] ?? 0;
    final failed = _galleryFailedCount[batchId] ?? 0;

    // Update progress notification
    await showGalleryProgressNotification(batchId, galleryName, completed + failed, total);

    // Check if all downloads are complete
    if (completed + failed >= total) {
      await showGalleryCompleteNotification(batchId, galleryName, completed, failed);

      // Cleanup
      _galleryTotalCount.remove(batchId);
      _galleryCompletedCount.remove(batchId);
      _galleryFailedCount.remove(batchId);
      _galleryNotificationShown.remove(batchId);
    }
  }

  /// Show gallery progress notification with proper updates
  Future<void> showGalleryProgressNotification(
      String batchId,
      String galleryName,
      int current,
      int total,
      ) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: batchId.hashCode,
        channelKey: 'download_channel',
        title: 'Downloading $galleryName',
        body: 'Progress: $current of $total images',
        notificationLayout: NotificationLayout.ProgressBar,
        progress: total > 0 ? ((current / total) * 100).toDouble() : 0,
        locked: false,  // ✅ Changed from true - allows dismissal
        category: NotificationCategory.Progress,
        autoDismissible: false,
      ),
    );
  }

  /// Show completion notification and cancel progress
  Future<void> showGalleryCompleteNotification(
      String batchId,
      String galleryName,
      int completed,
      int failed,
      ) async {
    // ✅ Cancel the progress notification first
    await AwesomeNotifications().cancel(batchId.hashCode);

    await Future.delayed(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    String basePath = prefs.getString('base_download_path') ??
        '/storage/emulated/0/Download/';
    String folderPath = '$basePath/$galleryName';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: batchId.hashCode + 1,  // Different ID for completion
        channelKey: 'download_channel',
        title: '$galleryName Downloaded',
        body: '$completed images saved to $folderPath'
            '${failed > 0 ? " ($failed failed)" : ""}',
        notificationLayout: NotificationLayout.Default,
        color: failed > 0 ? Colors.orange : Colors.green,
        locked: false,
        autoDismissible: true,
        payload: {'action': 'open_folder', 'path': folderPath},
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'open_folder',
          label: 'Open Folder',
          actionType: ActionType.Default,
        ),
        NotificationActionButton(
          key: 'dismiss',
          label: 'Dismiss',
          actionType: ActionType.DismissAction,
        ),
      ],
    );
  }

  Future<void> _download(
      DownloadTask task,
      void Function(bool success) onCompleteInner,
      ) async {
    final file = File(task.savePath);
    int start = 0;
    bool canResume = false;
    int? totalBytes;

    // Check for partial downloads
    if (await file.exists()) {
      start = await file.length();
      if (start > 0) {
        try {
          final headResponse = await _dio.head(
            task.url,
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
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
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
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
          if (canResume && start > 0 && total != -1) {
            progress = (start + received) / (total + start);
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
      if (e is DioException && CancelToken.isCancel(e)) {
        // Don't mark as failed if paused
        if (task.status == DownloadStatus.paused) {
          onCompleteInner(false);
          return;
        }
      }
      onCompleteInner(false);
    }
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
      task.cancelToken.cancel('Download paused');
      _activeDownloads[url] = task.copyWith(status: DownloadStatus.paused);
      _downloadingUrls.remove(url);
      _processQueue();
    }
  }

  void resumeDownload(String url) {
    final task = _activeDownloads[url];
    if (task != null && task.status == DownloadStatus.paused) {
      final newCancelToken = CancelToken();
      final newTask = task.copyWith(
        cancelToken: newCancelToken,
        status: DownloadStatus.queued,
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
        _processQueue();
      }

      _activeDownloads.remove(url);
      _downloadQueue.remove(url);
    }
  }

  void retryFailedDownload(String url) {
    final task = _activeDownloads[url];
    if (task != null && task.status == DownloadStatus.failed) {
      final newTask = task.copyWith(
        status: DownloadStatus.queued,
        retryCount: 0,
        progress: 0.0,
        cancelToken: CancelToken(),
        errorMessage: null,
      );
      _activeDownloads[url] = newTask;
      _enqueueDownload(newTask, null);
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

  void clearCompleted() {
    final completedUrls = _activeDownloads.entries
        .where((entry) => entry.value.status == DownloadStatus.completed)
        .map((entry) => entry.key)
        .toList();

    for (var url in completedUrls) {
      _activeDownloads.remove(url);
    }
  }

  void clearFailed() {
    final failedUrls = _activeDownloads.entries
        .where((entry) => entry.value.status == DownloadStatus.failed)
        .map((entry) => entry.key)
        .toList();

    for (var url in failedUrls) {
      _activeDownloads.remove(url);
    }
  }
}

// Main Download Manager Page with Tabs
class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  _DownloadManagerPageState createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> with SingleTickerProviderStateMixin {
  final DownloadManager _downloadManager = DownloadManager();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshDownloads();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshDownloads() {
    if (mounted) {
      setState(() {});
      Future.delayed(const Duration(seconds: 1), () {
        _refreshDownloads();
      });
    }
  }

  Future<void> _showConcurrentDownloadsDialog() async {
    int currentValue = _downloadManager.maxConcurrentDownloads;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Concurrent Downloads'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select how many downloads can run simultaneously'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Threads: $currentValue', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${currentValue} at once'),
                    ],
                  ),
                  Slider(
                    value: currentValue.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: currentValue.toString(),
                    onChanged: (value) {
                      setDialogState(() {
                        currentValue = value.toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentValue <= 3 ? 'Light Load - Recommended for slower connections' :
                    currentValue <= 6 ? 'Moderate Load - Balanced performance' :
                    'Heavy Load - For fast connections only',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    _downloadManager.setMaxConcurrentDownloads(currentValue);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Concurrent downloads set to $currentValue')),
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Manager', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.downloading_rounded),
              text: 'Running (${_downloadManager.runningDownloads.length + _downloadManager.pausedDownloads.length})',
            ),
            Tab(
              icon: const Icon(Icons.error_rounded),
              text: 'Failed (${_downloadManager.failedDownloads.length})',
            ),
            Tab(
              icon: const Icon(Icons.check_circle_rounded),
              text: 'Completed (${_downloadManager.completedDownloads.length})',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showConcurrentDownloadsDialog,
            tooltip: 'Concurrent Downloads Settings',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RunningDownloadsTab(downloadManager: _downloadManager),
          FailedDownloadsTab(downloadManager: _downloadManager),
          CompletedDownloadsTab(downloadManager: _downloadManager),
        ],
      ),
    );
  }
}

// Running Downloads Tab
class RunningDownloadsTab extends StatelessWidget {
  final DownloadManager downloadManager;

  const RunningDownloadsTab({super.key, required this.downloadManager});

  @override
  Widget build(BuildContext context) {
    final runningTasks = {...downloadManager.runningDownloads, ...downloadManager.pausedDownloads};

    if (runningTasks.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.download_done_rounded,
        'No active downloads',
        'Downloads in progress will appear here',
      );
    }

    return ListView.builder(
      itemCount: runningTasks.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final task = runningTasks.values.elementAt(index);
        return RunningDownloadItem(
          task: task,
          onPause: () => downloadManager.pauseDownload(task.url),
          onResume: () => downloadManager.resumeDownload(task.url),
          onCancel: () => downloadManager.cancelDownload(task.url),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, IconData icon, String title, String subtitle) {
    final color = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color.outline),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, color: color.onSurface, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 14, color: color.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class RunningDownloadItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const RunningDownloadItem({
    super.key,
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final isPaused = task.status == DownloadStatus.paused;
    final isQueued = task.status == DownloadStatus.queued;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(task.status, color),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: isQueued ? null : task.progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                isPaused ? Colors.orange : isQueued ? Colors.blue[300] : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isQueued ? 'Queued...' : '${(task.progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isQueued) ...[
                      IconButton(
                        icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                        onPressed: isPaused ? onResume : onPause,
                        tooltip: isPaused ? 'Resume' : 'Pause',
                        iconSize: 20,
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel),
                        onPressed: onCancel,
                        tooltip: 'Cancel',
                        iconSize: 20,
                      ),
                    ],
                    if (isQueued)
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
    );
  }

  Widget _buildStatusChip(DownloadStatus status, ColorScheme color) {
    String label;
    Color chipColor;

    switch (status) {
      case DownloadStatus.downloading:
        label = 'Downloading';
        chipColor = Colors.blue;
        break;
      case DownloadStatus.paused:
        label = 'Paused';
        chipColor = Colors.orange;
        break;
      case DownloadStatus.queued:
        label = 'Queued';
        chipColor = Colors.grey;
        break;
      default:
        label = 'Unknown';
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor),
      ),
      child: Text(
        label,
        style: TextStyle(color: chipColor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Failed Downloads Tab
class FailedDownloadsTab extends StatelessWidget {
  final DownloadManager downloadManager;

  const FailedDownloadsTab({super.key, required this.downloadManager});

  @override
  Widget build(BuildContext context) {
    final failedTasks = downloadManager.failedDownloads;

    if (failedTasks.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.check_circle_outline_rounded,
        'No failed downloads',
        'Failed downloads will appear here',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  downloadManager.clearFailed();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: failedTasks.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final task = failedTasks.values.elementAt(index);
              return FailedDownloadItem(
                task: task,
                onRetry: () => downloadManager.retryFailedDownload(task.url),
                onRemove: () => downloadManager.removeCompletedDownload(task.url),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, IconData icon, String title, String subtitle) {
    final color = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color.outline),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, color: color.onSurface, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 14, color: color.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class FailedDownloadItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  const FailedDownloadItem({
    super.key,
    required this.task,
    required this.onRetry,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.error, color: Colors.red),
        ),
        title: Text(
          task.fileName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${task.folder}/${task.subFolder}'),
            if (task.errorMessage != null)
              Text(
                task.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRetry,
              tooltip: 'Retry',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onRemove,
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}

// Completed Downloads Tab
class CompletedDownloadsTab extends StatelessWidget {
  final DownloadManager downloadManager;

  const CompletedDownloadsTab({super.key, required this.downloadManager});

  @override
  Widget build(BuildContext context) {
    final completedTasks = downloadManager.completedDownloads.values.toList()
      ..sort((a, b) => (b.completedTime ?? DateTime.now()).compareTo(a.completedTime ?? DateTime.now()));

    if (completedTasks.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.history_rounded,
        'No completed downloads',
        'Completed downloads history will appear here',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  downloadManager.clearCompleted();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear History'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: completedTasks.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final task = completedTasks[index];
              return CompletedDownloadItem(
                task: task,
                onTap: () async {
                  final result = await OpenFile.open(task.savePath);
                  if (result.type != ResultType.done) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open file: ${result.message}')),
                    );
                  }
                },
                onRemove: () => downloadManager.removeCompletedDownload(task.url),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, IconData icon, String title, String subtitle) {
    final color = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color.outline),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, color: color.onSurface, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 14, color: color.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class CompletedDownloadItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const CompletedDownloadItem({
    super.key,
    required this.task,
    required this.onTap,
    required this.onRemove,
  });

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.check_circle, color: Colors.green),
        ),
        title: Text(
          task.fileName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.savePath, style: const TextStyle(fontSize: 11)),
            Text(
              _formatTime(task.completedTime),
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemove,
          tooltip: 'Remove from history',
        ),
        onTap: onTap,
      ),
    );
  }
}
