import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

enum DownloadStatus { downloading, paused, completed, failed, queued, scraping }

class DownloadTask extends ChangeNotifier {
  final String url;

  String? _resolvedUrl;
  String? get resolvedUrl => _resolvedUrl;
  set resolvedUrl(String? value) {
    if (_resolvedUrl != value) {
      _resolvedUrl = value;
      notifyListeners();
    }
  }

  String _fileName;
  String get fileName => _fileName;
  set fileName(String value) {
    if (_fileName != value) {
      _fileName = value;
      notifyListeners();
    }
  }

  String _savePath;
  String get savePath => _savePath;
  set savePath(String value) {
    if (_savePath != value) {
      _savePath = value;
      notifyListeners();
    }
  }

  final String? targetDirectory;
  final String folder;
  final String subFolder;
  final String galleryName;
  // batchId is stored here so it is never lost when the task moves
  // from the queue back into active downloads via _processQueue.
  final String? batchId;

  CancelToken _cancelToken;
  CancelToken get cancelToken => _cancelToken;
  set cancelToken(CancelToken value) {
    _cancelToken = value;
    notifyListeners();
  }

  double _progress;
  double get progress => _progress;
  set progress(double value) {
    if (_progress != value) {
      _progress = value;
      notifyListeners();
    }
  }

  DownloadStatus _status;
  DownloadStatus get status => _status;
  set status(DownloadStatus value) {
    if (_status != value) {
      _status = value;
      notifyListeners();
    }
  }

  int _retryCount;
  int get retryCount => _retryCount;
  set retryCount(int value) {
    if (_retryCount != value) {
      _retryCount = value;
      notifyListeners();
    }
  }

  final void Function(double)? onProgress;
  final void Function(bool)? onComplete;
  final DateTime addedTime;

  DateTime? _completedTime;
  DateTime? get completedTime => _completedTime;
  set completedTime(DateTime? value) {
    if (_completedTime != value) {
      _completedTime = value;
      notifyListeners();
    }
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  set errorMessage(String? value) {
    if (_errorMessage != value) {
      _errorMessage = value;
      notifyListeners();
    }
  }

  DownloadTask({
    required this.url,
    String? resolvedUrl,
    required String fileName,
    required String savePath,
    this.targetDirectory,
    required this.folder,
    required this.subFolder,
    required this.galleryName,
    required CancelToken cancelToken,
    this.batchId,
    double progress = 0.0,
    DownloadStatus status = DownloadStatus.queued,
    int retryCount = 0,
    this.onProgress,
    this.onComplete,
    DateTime? addedTime,
    DateTime? completedTime,
    String? errorMessage,
  })  : _resolvedUrl = resolvedUrl,
        _fileName = fileName,
        _savePath = savePath,
        _cancelToken = cancelToken,
        _progress = progress,
        _status = status,
        _retryCount = retryCount,
        addedTime = addedTime ?? DateTime.now(),
        _completedTime = completedTime,
        _errorMessage = errorMessage;

  DownloadTask copyWith({
    String? url,
    String? resolvedUrl,
    String? fileName,
    String? savePath,
    String? targetDirectory,
    String? folder,
    String? subFolder,
    String? galleryName,
    String? batchId,
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
      resolvedUrl: resolvedUrl ?? this.resolvedUrl,
      fileName: fileName ?? this.fileName,
      savePath: savePath ?? this.savePath,
      targetDirectory: targetDirectory ?? this.targetDirectory,
      folder: folder ?? this.folder,
      subFolder: subFolder ?? this.subFolder,
      galleryName: galleryName ?? this.galleryName,
      batchId: batchId ?? this.batchId,
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
