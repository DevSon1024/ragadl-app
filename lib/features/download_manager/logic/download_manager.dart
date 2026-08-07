import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:ragadl/core/services/dio_client.dart';
import 'package:ragadl/core/services/notification_controller.dart';
import 'package:ragadl/core/services/image_viewer_service.dart';
import 'package:ragadl/features/settings/logic/settings_service.dart';
import '../models/download_task.dart';

export '../models/download_task.dart';

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal() {
    _downloadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
    SettingsService().addListener(() {
      notifyListeners();
      _processQueue();
    });
  }

  final Map<String, DownloadTask> _tasks = {};
  final Map<String, DownloadTask> _runningDownloads = {};
  final Map<String, DownloadTask> _failedDownloads = {};
  final Map<String, DownloadTask> _completedDownloads = {};
  final Map<String, DownloadTask> _pausedDownloads = {};
  final List<DownloadTask> _pendingQueue = [];
  final Dio _dio = DioClient().dio;
  late final Dio _downloadDio;

  final Map<String, int> _galleryTotalCount = {};
  final Map<String, int> _galleryCompletedCount = {};
  final Map<String, int> _galleryFailedCount = {};
  final Map<String, String> _galleryNameMap = {};
  final Map<String, String> _galleryDirectoryMap = {};

  bool _isPaused = false;

  int get maxConcurrentDownloads => SettingsService().concurrentDownloads;
  int _activeDownloads = 0;
  int get maxRetries => SettingsService().maxRetries;

  Map<String, DownloadTask> get activeDownloads =>
      Map.unmodifiable(_tasks);

  // Filtered views by status (cached/persistent to avoid GC thrashing)
  Map<String, DownloadTask> get runningDownloads =>
      Map.unmodifiable(_runningDownloads);

  Map<String, DownloadTask> get failedDownloads =>
      Map.unmodifiable(_failedDownloads);

  Map<String, DownloadTask> get completedDownloads =>
      Map.unmodifiable(_completedDownloads);

  Map<String, DownloadTask> get pausedDownloads =>
      Map.unmodifiable(_pausedDownloads);

  void _updateTask(String url, DownloadTask? task) {
    if (task == null) {
      _tasks.remove(url);
      _runningDownloads.remove(url);
      _failedDownloads.remove(url);
      _completedDownloads.remove(url);
      _pausedDownloads.remove(url);
    } else {
      _tasks[url] = task;
      _runningDownloads.remove(url);
      _failedDownloads.remove(url);
      _completedDownloads.remove(url);
      _pausedDownloads.remove(url);
      switch (task.status) {
        case DownloadStatus.queued:
        case DownloadStatus.downloading:
        case DownloadStatus.scraping:
          _runningDownloads[url] = task;
          break;
        case DownloadStatus.completed:
          _completedDownloads[url] = task;
          break;
        case DownloadStatus.failed:
          _failedDownloads[url] = task;
          break;
        case DownloadStatus.paused:
          _pausedDownloads[url] = task;
          break;
      }
    }
  }

  // Settings
  Future<void> setMaxConcurrentDownloads(int count) async {
    await SettingsService().setConcurrentDownloads(count);
  }

  // Public API - add / pause / resume / cancel / retry / clear
  Future<String> getResolvedTargetDirectory({
    required String url,
    required String galleryName,
    String? albumName,
  }) async {
    String cleanedAlbum = (albumName ?? galleryName).replaceAll(RegExp(r'\s*[\-—–]\s*ImgBB\s*$', caseSensitive: false), '').trim();
    if (cleanedAlbum.isEmpty) {
      cleanedAlbum = 'Unknown Album';
    }
    final host = Uri.parse(url).host.replaceAll('www.', '').replaceAll('m.', '');
    final directory = await _getBaseDirectory(host, cleanedAlbum);
    return directory.path;
  }

  Future<void> addDownload({
    required String url,
    required String folder,
    required String subFolder,
    required String galleryName,
    required String targetDirectoryPath,
    required void Function(double progress) onProgress,
    required void Function(bool success) onComplete,
    String? batchId,
    String? albumName,
  }) async {
    if (_tasks.containsKey(url)) {
      final task = _tasks[url]!;
      if (task.status == DownloadStatus.paused) {
        resumeDownload(url);
      }
      return;
    }

    DownloadTask? task;
    try {
      final nodeId = url.split('/').last;
      String fileName = nodeId;
      final isImgBBPage = _isImgBBPage(url);

      if (!isImgBBPage) {
        if (url.contains('.')) {
          final lastSeg = url.split('/').last;
          if (lastSeg.contains('.')) {
            fileName = lastSeg;
          }
        }
      }

      if (!fileName.contains('.')) {
        fileName = '$fileName.jpg';
      }

      final savePath = p.join(targetDirectoryPath, fileName);
      final cancelToken = CancelToken();

      task = DownloadTask(
        url: url,
        fileName: fileName,
        savePath: savePath,
        targetDirectory: targetDirectoryPath,
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

      _updateTask(url, task);

      if (batchId != null) {
        _galleryTotalCount[batchId] = (_galleryTotalCount[batchId] ?? 0) + 1;
        _galleryNameMap[batchId] = galleryName;
        _galleryDirectoryMap[batchId] = targetDirectoryPath;
      }

      _pendingQueue.add(task);
      _processQueue();
      notifyListeners();
    } catch (e) {
      if (task != null) {
        _updateTask(url, null);
      }
      if (batchId != null) {
        _galleryFailedCount[batchId] = (_galleryFailedCount[batchId] ?? 0) + 1;
      }
      onComplete(false);
      notifyListeners();
    }
  }

  void pauseDownload(String url) {
    final task = _tasks[url];
    if (task != null && (task.status == DownloadStatus.downloading || task.status == DownloadStatus.scraping)) {
      task.cancelToken.cancel('Download paused');
      task.status = DownloadStatus.paused;
      _updateTask(url, task);
    } else if (task != null && task.status == DownloadStatus.queued) {
      task.status = DownloadStatus.paused;
      _updateTask(url, task);
      _pendingQueue.removeWhere((t) => t.url == url);
    }
  }

  void resumeDownload(String url) {
    final task = _tasks[url];
    if (task != null && task.status == DownloadStatus.paused) {
      task.cancelToken = CancelToken();
      task.status = DownloadStatus.queued;
      _updateTask(url, task);
      _pendingQueue.add(task);
      _processQueue();
    }
  }

  void cancelDownload(String url) {
    final task = _tasks[url];
    if (task != null) {
      if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.scraping) {
        task.cancelToken.cancel('Download canceled');
      }
      _updateTask(url, null);
      _pendingQueue.removeWhere((t) => t.url == url);
      notifyListeners();
    }
  }

  void retryFailedDownload(String url) {
    final task = _tasks[url];
    if (task != null && task.status == DownloadStatus.failed) {
      task.status = DownloadStatus.queued;
      task.retryCount = 0;
      task.progress = 0.0;
      task.cancelToken = CancelToken();
      task.errorMessage = null;
      _updateTask(url, task);
      _pendingQueue.add(task);
      _processQueue();
      notifyListeners();
    }
  }

  void removeCompletedDownload(String url) {
    if (_tasks.containsKey(url)) {
      final task = _tasks[url]!;
      if (task.status == DownloadStatus.completed ||
          task.status == DownloadStatus.failed) {
        _updateTask(url, null);
        notifyListeners();
      }
    }
  }

  void clearCompleted() {
    final completedUrls = List<String>.from(_completedDownloads.keys);
    for (final url in completedUrls) {
      _updateTask(url, null);
    }
    notifyListeners();
  }

  void clearFailed() {
    final failedUrls = List<String>.from(_failedDownloads.keys);
    for (final url in failedUrls) {
      _updateTask(url, null);
    }
    notifyListeners();
  }

  void pauseAll() {
    _isPaused = true;
    final activeRunningTasks = _tasks.values
        .where((t) => t.status == DownloadStatus.downloading || t.status == DownloadStatus.scraping)
        .toList();
    for (final task in activeRunningTasks) {
      task.cancelToken.cancel('Paused');
      task.status = DownloadStatus.paused;
      task.cancelToken = CancelToken();
      _updateTask(task.url, task);
    }
    for (final task in _pendingQueue) {
      task.status = DownloadStatus.paused;
      _updateTask(task.url, task);
    }
    _pendingQueue.clear();
    _refreshBatchNotification(isPaused: true);
    notifyListeners();
  }

  void resumeAll() {
    _isPaused = false;
    final pausedTasks = _tasks.values.where((t) => t.status == DownloadStatus.paused).toList();
    for (final task in pausedTasks) {
      task.status = DownloadStatus.queued;
      task.cancelToken = CancelToken();
      _updateTask(task.url, task);
      _pendingQueue.add(task);
    }
    _processQueue();
    _refreshBatchNotification(isPaused: false);
    notifyListeners();
  }

  void cancelAll() {
    _isPaused = false;
    final activeRunningTasks = _tasks.values
        .where((t) => t.status == DownloadStatus.downloading || t.status == DownloadStatus.scraping)
        .toList();
    for (final task in activeRunningTasks) {
      task.cancelToken.cancel('Cancelled');
    }
    _pendingQueue.clear();

    final urlsToCancel = _tasks.entries
        .where((e) =>
            e.value.status == DownloadStatus.downloading ||
            e.value.status == DownloadStatus.queued ||
            e.value.status == DownloadStatus.paused ||
            e.value.status == DownloadStatus.scraping)
        .map((e) => e.key)
        .toList();
    for (final url in urlsToCancel) {
      _updateTask(url, null);
    }

    _galleryTotalCount.clear();
    _galleryCompletedCount.clear();
    _galleryFailedCount.clear();
    _galleryNameMap.clear();
    _galleryDirectoryMap.clear();
    NotificationController.cancelBatchNotification();
    notifyListeners();
  }

  void _processQueue() {
    if (_isPaused) return;
    while (_activeDownloads < maxConcurrentDownloads && _pendingQueue.isNotEmpty) {
      final task = _pendingQueue.removeAt(0);
      _activeDownloads++;
      _scrapeAndDownload(task);
    }
  }

  Future<void> _scrapeAndDownload(DownloadTask task) async {
    try {
      final isImgBBPage = _isImgBBPage(task.url);

      if (isImgBBPage && task.resolvedUrl == null) {
        task.status = DownloadStatus.scraping;
        _updateTask(task.url, task);

        final directUrl = await _scrapeImageLink(task.url);
        if (directUrl == null) {
          task.status = DownloadStatus.failed;
          task.errorMessage = 'Failed to scrape direct image link';
          _updateTask(task.url, task);
          _handleDownloadComplete(task.url, false, task.batchId);
          return;
        }

        final urlcode = task.url.split('/').last;
        final rawFilename = directUrl.split('/').last.split('?').first;
        final nameParts = rawFilename.split('.');
        final extension = nameParts.last;
        final baseName = nameParts.length > 1
            ? nameParts.sublist(0, nameParts.length - 1).join('.')
            : nameParts.first;
        final finalFileName = "$baseName[$urlcode].$extension";
        final finalSavePath = task.targetDirectory != null
            ? p.join(task.targetDirectory!, finalFileName)
            : p.join(p.dirname(task.savePath), finalFileName);

        task.resolvedUrl = directUrl;
        task.fileName = finalFileName;
        task.savePath = finalSavePath;
        task.status = DownloadStatus.downloading;
        _updateTask(task.url, task);
      } else {
        task.status = DownloadStatus.downloading;
        _updateTask(task.url, task);
      }

      final success = await _download(task);
      _handleDownloadComplete(task.url, success, task.batchId);
    } catch (e) {
      debugPrint("Error in _scrapeAndDownload: $e");
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      _updateTask(task.url, task);
      _handleDownloadComplete(task.url, false, task.batchId);
    } finally {
      _activeDownloads--;
      _processQueue();
    }
  }

  Future<String?> _scrapeImageLink(String pageUrl) async {
    try {
      final response = await _dio.get<String>(
        pageUrl,
        options: Options(
          headers: {
            'User-Agent': SettingsService().customUserAgent,
          },
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        final html = response.data.toString();
        return await compute(parseImgBBHtml, html);
      }
      return null;
    } catch (e) {
      debugPrint("Error scraping ImgBB link via Dio: $e");
      return null;
    }
  }

  void _handleDownloadComplete(String url, bool success, String? batchId) {
    final task = _tasks[url];

    if (success) {
      if (task != null) {
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        task.completedTime = DateTime.now();
        _updateTask(url, task);
        
        // Scan the completed download to register it in Android media provider
        ImageViewerService.scanFile(task.savePath);

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
        task.retryCount = task.retryCount + 1;
        task.status = DownloadStatus.queued;
        task.progress = 0.0;
        task.cancelToken = CancelToken();
        _updateTask(url, task);
        _pendingQueue.insert(0, task);
        return;
      }
      if (task != null) {
        task.status = DownloadStatus.failed;
        task.errorMessage =
            'Download failed after ${task.retryCount + 1} attempts';
        _updateTask(url, task);
        if (batchId != null) {
          _galleryFailedCount[batchId] =
              (_galleryFailedCount[batchId] ?? 0) + 1;
          _updateGalleryProgress(batchId, task.galleryName);
        }
        task.onComplete?.call(false);
      }
    }

    notifyListeners();
  }

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
      final folderPath = _galleryDirectoryMap[batchId] ?? '$basePath/$galleryName';

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
      _galleryDirectoryMap.remove(batchId);
    }
  }

  Future<bool> _download(DownloadTask task) async {
    final downloadUrl = task.resolvedUrl ?? task.url;
    final file = File(task.savePath);
    int start = 0;
    bool canResume = false;
    int? totalBytes;

    if (await file.exists()) {
      start = await file.length();
      if (start > 0) {
        try {
          final headResponse = await _downloadDio.head(
            downloadUrl,
            options: Options(
              headers: {
                'User-Agent': SettingsService().customUserAgent,
              },
            ),
          );
          if (headResponse.headers.value('accept-ranges') == 'bytes') {
            canResume = true;
            final totalStr = headResponse.headers.value('content-length');
            if (totalStr != null) {
              totalBytes = int.parse(totalStr);
              if (start >= totalBytes) {
                return true;
              }
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
        'User-Agent': SettingsService().customUserAgent,
      };
      if (canResume && start > 0) {
        headers['Range'] = 'bytes=$start-';
      }

      await _downloadDio.download(
        downloadUrl,
        task.savePath,
        cancelToken: task.cancelToken,
        deleteOnError: false,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final currentProgress = (start + received) / (start + total);
            task.progress = currentProgress;
            task.onProgress?.call(currentProgress);
          }
        },
        options: Options(
          headers: headers,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      return true;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        final liveTask = _tasks[task.url];
        if (liveTask != null && liveTask.status == DownloadStatus.paused) {
          return false;
        }
        return false;
      }
      return false;
    }
  }

  // File system helpers
  String _sanitizeFolderName(String name) {
    return name.replaceAll(RegExp(r'[\\/:\*\?"<>\|]'), '').trim();
  }

  Future<Directory> _getBaseDirectory(String host, String albumName) async {
    final prefs = await SharedPreferences.getInstance();
    final basePath =
        prefs.getString('base_download_path') ?? '/storage/emulated/0/Download';

    final lowerHost = host.toLowerCase();
    String siteFolderName = '';
    bool isImgBB = false;

    if (lowerHost.contains('ragalahari.com') || lowerHost.contains('ragalhari.com')) {
      siteFolderName = 'Ragalahari';
    } else if (lowerHost.contains('idlebrain.com')) {
      siteFolderName = 'IdleBrain';
    } else if (lowerHost.contains('ibb.co') || lowerHost.contains('imgbb.com') || lowerHost.contains('imgbb.co')) {
      siteFolderName = 'IMGbb';
      isImgBB = true;
    } else if (lowerHost.contains('behindwoods.com')) {
      siteFolderName = 'Behindwoods';
    } else if (lowerHost.contains('teluguone.com')) {
      siteFolderName = 'TeluguOne';
    } else {
      siteFolderName = host;
    }

    String pathSegment = '';
    final sanitizedAlbum = _sanitizeFolderName(albumName);

    if (isImgBB) {
      if (sanitizedAlbum.isNotEmpty && sanitizedAlbum != 'Single Image' && sanitizedAlbum != 'ImgBB') {
        pathSegment = p.join('IMGbb', sanitizedAlbum);
      } else {
        pathSegment = 'IMGbb';
      }
    } else {
      final album = sanitizedAlbum.isNotEmpty ? sanitizedAlbum : 'Unknown Album';
      pathSegment = p.join(siteFolderName, album);
    }

    Directory directory;
    if (Platform.isAndroid || basePath != '/storage/emulated/0/Download') {
      directory = Directory(p.join(basePath, pathSegment));
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      directory = Directory(p.join(docDir.path, pathSegment));
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  bool _isImgBBPage(String url) {
    final lower = url.toLowerCase();
    final hasImgBBDomain = lower.contains('ibb.co') || lower.contains('imgbb.com') || lower.contains('imgbb.co');
    final isDirectImg = lower.contains('i.ibb.co');
    return hasImgBBDomain && !isDirectImg;
  }
}

/// Extracts the direct image URL from ImgBB HTML payload.
String? parseImgBBHtml(String html) {
  final regExp = RegExp(
    r'https://i\.ibb\.co/[a-zA-Z0-9]+/[a-zA-Z0-9\-_.]+\.(?:jpg|jpeg|png|gif|webp|bmp|svg)',
    caseSensitive: false,
  );
  final match = regExp.firstMatch(html);
  return match?.group(0);
}
