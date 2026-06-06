import 'dart:io';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ragadl/core/services/notification_controller.dart';
import '../models/download_task.dart';

export '../models/download_task.dart';

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal() {
    _loadConcurrentDownloads();
  }

  final Map<String, DownloadTask> _activeDownloads = {};
  final Queue<String> _downloadQueue = Queue();
  final Dio _dio = Dio();
  final Set<String> _downloadingUrls = {};

  final Map<String, int> _galleryTotalCount = {};
  final Map<String, int> _galleryCompletedCount = {};
  final Map<String, int> _galleryFailedCount = {};
  final Map<String, String> _galleryNameMap = {};

  bool _isPaused = false;

  int _maxConcurrentDownloads = 3;
  static const int maxRetries = 3;

  Map<String, DownloadTask> get activeDownloads =>
      Map.unmodifiable(_activeDownloads);

  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  // Filtered views by status
  Map<String, DownloadTask> get runningDownloads {
    return Map.fromEntries(
      _activeDownloads.entries.where(
        (MapEntry<String, DownloadTask> e) =>
            e.value.status == DownloadStatus.downloading ||
            e.value.status == DownloadStatus.queued,
      ),
    );
  }

  Map<String, DownloadTask> get failedDownloads {
    return Map.fromEntries(
      _activeDownloads.entries.where(
        (MapEntry<String, DownloadTask> e) => e.value.status == DownloadStatus.failed,
      ),
    );
  }

  Map<String, DownloadTask> get completedDownloads {
    return Map.fromEntries(
      _activeDownloads.entries.where(
        (MapEntry<String, DownloadTask> e) => e.value.status == DownloadStatus.completed,
      ),
    );
  }

  Map<String, DownloadTask> get pausedDownloads {
    return Map.fromEntries(
      _activeDownloads.entries.where(
        (MapEntry<String, DownloadTask> e) => e.value.status == DownloadStatus.paused,
      ),
    );
  }

  // Settings
  Future<void> _loadConcurrentDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    _maxConcurrentDownloads = prefs.getInt('max_concurrent_downloads') ?? 3;
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    if (count < 1 || count > 10) return;
    _maxConcurrentDownloads = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_concurrent_downloads', count);
    _processQueue();
    notifyListeners();
  }

  // Public API — add / pause / resume / cancel / retry / clear
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
        batchId: batchId,
        cancelToken: cancelToken,
        progress: 0,
        status: DownloadStatus.queued,
        retryCount: 0,
        onProgress: onProgress,
        onComplete: onComplete,
      );

      _activeDownloads[url] = task;

      if (batchId != null) {
        _galleryTotalCount[batchId] = (_galleryTotalCount[batchId] ?? 0) + 1;
        _galleryNameMap[batchId] = galleryName;
      }

      _enqueueDownload(task);
      notifyListeners();
    } catch (e) {
      if (task != null) {
        _activeDownloads.remove(url);
      }
      if (batchId != null) {
        _galleryFailedCount[batchId] = (_galleryFailedCount[batchId] ?? 0) + 1;
      }
      onComplete(false);
      notifyListeners();
    }
  }

  void pauseDownload(String url) {
    final task = _activeDownloads[url];
    if (task != null && task.status == DownloadStatus.downloading) {
      task.cancelToken.cancel('Download paused');
      _activeDownloads[url] = task.copyWith(status: DownloadStatus.paused);
      _downloadingUrls.remove(url);
      _processQueue();
      notifyListeners();
    }
  }

  void resumeDownload(String url) {
    final task = _activeDownloads[url];
    if (task != null && task.status == DownloadStatus.paused) {
      final newTask = task.copyWith(
        cancelToken: CancelToken(),
        status: DownloadStatus.queued,
      );
      _activeDownloads[url] = newTask;
      _enqueueDownload(newTask);
      notifyListeners();
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
      notifyListeners();
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
      _enqueueDownload(newTask);
      notifyListeners();
    }
  }

  void removeCompletedDownload(String url) {
    if (_activeDownloads.containsKey(url)) {
      final task = _activeDownloads[url]!;
      if (task.status == DownloadStatus.completed ||
          task.status == DownloadStatus.failed) {
        _activeDownloads.remove(url);
        notifyListeners();
      }
    }
  }

  void clearCompleted() {
    _activeDownloads.removeWhere(
      (String _, DownloadTask t) => t.status == DownloadStatus.completed,
    );
    notifyListeners();
  }

  void clearFailed() {
    _activeDownloads.removeWhere((String _, DownloadTask t) => t.status == DownloadStatus.failed);
    notifyListeners();
  }

  void pauseAll() {
    _isPaused = true;
    for (final url in List<String>.from(_downloadingUrls)) {
      final task = _activeDownloads[url];
      if (task != null) {
        task.cancelToken.cancel('Paused');
        final paused = task.copyWith(
          status: DownloadStatus.paused,
          cancelToken: CancelToken(),
        );
        _activeDownloads[url] = paused;
        _downloadQueue.addFirst(url);
      }
    }
    _downloadingUrls.clear();
    for (final url in List<String>.from(_downloadQueue)) {
      final task = _activeDownloads[url];
      if (task != null && task.status == DownloadStatus.queued) {
        _activeDownloads[url] = task.copyWith(status: DownloadStatus.paused);
      }
    }
    _refreshBatchNotification(isPaused: true);
    notifyListeners();
  }

  void resumeAll() {
    _isPaused = false;
    final pausedUrls =
        _activeDownloads.entries
            .where((MapEntry<String, DownloadTask> e) => e.value.status == DownloadStatus.paused)
            .map((MapEntry<String, DownloadTask> e) => e.key)
            .toList();
    for (final url in pausedUrls) {
      final task = _activeDownloads[url];
      if (task != null) {
        final queued = task.copyWith(
          status: DownloadStatus.queued,
          cancelToken: CancelToken(),
        );
        _activeDownloads[url] = queued;
        if (!_downloadQueue.contains(url)) {
          _downloadQueue.add(url);
        }
      }
    }
    _processQueue();
    _refreshBatchNotification(isPaused: false);
    notifyListeners();
  }

  void cancelAll() {
    _isPaused = false;
    for (final url in List<String>.from(_downloadingUrls)) {
      _activeDownloads[url]?.cancelToken.cancel('Cancelled');
    }
    _downloadingUrls.clear();
    _downloadQueue.clear();
    _activeDownloads.removeWhere(
      (String _, DownloadTask t) =>
          t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.queued ||
          t.status == DownloadStatus.paused,
    );
    _galleryTotalCount.clear();
    _galleryCompletedCount.clear();
    _galleryFailedCount.clear();
    _galleryNameMap.clear();
    NotificationController.cancelBatchNotification();
    notifyListeners();
  }

  // Internal queue management
  void _enqueueDownload(DownloadTask task) {
    if (_downloadingUrls.length < _maxConcurrentDownloads) {
      _startDownload(task);
    } else {
      _downloadQueue.add(task.url);
      _activeDownloads[task.url] = task.copyWith(status: DownloadStatus.queued);
    }
  }

  void _startDownload(DownloadTask task) {
    _downloadingUrls.add(task.url);
    _activeDownloads[task.url] = task.copyWith(
      status: DownloadStatus.downloading,
    );
    notifyListeners();
    _download(task, (bool success) {
      _handleDownloadComplete(task.url, success, task.batchId);
    });
  }

  void _handleDownloadComplete(String url, bool success, String? batchId) {
    _downloadingUrls.remove(url);
    final task = _activeDownloads[url];

    if (success) {
      if (task != null) {
        _activeDownloads[url] = task.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          completedTime: DateTime.now(),
        );
        if (batchId != null) {
          _galleryCompletedCount[batchId] =
              (_galleryCompletedCount[batchId] ?? 0) + 1;
          _updateGalleryProgress(batchId, task.galleryName);
        }
        task.onComplete?.call(true);
      }
    } else {
      if (task != null &&
          task.retryCount < maxRetries &&
          task.status != DownloadStatus.paused) {
        // Retry
        final newTask = task.copyWith(
          retryCount: task.retryCount + 1,
          status: DownloadStatus.downloading,
          progress: 0.0,
          cancelToken: CancelToken(),
        );
        _activeDownloads[url] = newTask;
        _startDownload(newTask);
        return;
      }
      // Final failure
      if (task != null) {
        _activeDownloads[url] = task.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'Download failed after ${task.retryCount + 1} attempts',
        );
        if (batchId != null) {
          _galleryFailedCount[batchId] =
              (_galleryFailedCount[batchId] ?? 0) + 1;
          _updateGalleryProgress(batchId, task.galleryName);
        }
        task.onComplete?.call(false);
      }
    }

    notifyListeners();
    _processQueue();
  }

  void _processQueue() {
    if (_isPaused) return;
    while (_downloadQueue.isNotEmpty &&
        _downloadingUrls.length < _maxConcurrentDownloads) {
      final url = _downloadQueue.removeFirst();
      final task = _activeDownloads[url];
      if (task != null && task.status != DownloadStatus.paused) {
        _startDownload(task);
      }
    }
  }

  // Notifications
  void _refreshBatchNotification({required bool isPaused}) {
    int completed = 0;
    int total = 0;
    String galleryName = 'Download';
    for (final batchId in _galleryTotalCount.keys) {
      total += _galleryTotalCount[batchId] ?? 0;
      completed += _galleryCompletedCount[batchId] ?? 0;
      galleryName = _galleryNameMap[batchId] ?? galleryName;
    }
    if (total > 0) {
      NotificationController.showBatchProgress(
        completed: completed,
        total: total,
        galleryName: galleryName,
        isPaused: isPaused,
      );
    }
  }

  Future<void> _updateGalleryProgress(
    String batchId,
    String galleryName,
  ) async {
    final total = _galleryTotalCount[batchId] ?? 0;
    final completed = _galleryCompletedCount[batchId] ?? 0;
    final failed = _galleryFailedCount[batchId] ?? 0;
    final processed = completed + failed;

    await NotificationController.showBatchProgress(
      completed: completed,
      total: total,
      galleryName: galleryName,
      isPaused: _isPaused,
    );

    if (processed >= total) {
      final prefs = await SharedPreferences.getInstance();
      final basePath =
          prefs.getString('base_download_path') ??
          '/storage/emulated/0/Download';
      final folderPath = '$basePath/$galleryName';

      await NotificationController.showBatchComplete(
        galleryName: galleryName,
        completed: completed,
        failed: failed,
        folderPath: folderPath,
      );

      _galleryTotalCount.remove(batchId);
      _galleryCompletedCount.remove(batchId);
      _galleryFailedCount.remove(batchId);
      _galleryNameMap.remove(batchId);
    }
  }

  // Download execution (Dio)
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
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
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
              _activeDownloads[task.url] = task.copyWith(
                progress: initialProgress,
              );
            }
          } else {
            await file.delete();
            start = 0;
          }
        } catch (_) {
          await file.delete();
          start = 0;
        }
      }
    }

    try {
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      };
      if (canResume && start > 0) {
        headers['Range'] = 'bytes=$start-';
      }

      await _dio.download(
        task.url,
        task.savePath,
        cancelToken: task.cancelToken,
        deleteOnError: false,
        onReceiveProgress: null,
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
        final liveTask = _activeDownloads[task.url];
        if (liveTask != null && liveTask.status == DownloadStatus.paused) {
          return;
        }
        return;
      }
      onCompleteInner(false);
    }
  }

  // File system helpers
  Future<Directory> _getDownloadDirectory(
    String folder,
    String subFolder,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final basePath =
        prefs.getString('base_download_path') ?? '/storage/emulated/0/Download';

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
}
