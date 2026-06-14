import 'package:dio/dio.dart';

enum DownloadStatus { downloading, paused, completed, failed, queued, scraping }

class DownloadTask {
  final String url;
  final String? resolvedUrl;
  final String fileName;
  final String savePath;
  final String folder;
  final String subFolder;
  final String galleryName;
  // batchId is stored here so it is never lost when the task moves
  // from the queue back into active downloads via _processQueue.
  final String? batchId;
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
    this.resolvedUrl,
    required this.fileName,
    required this.savePath,
    required this.folder,
    required this.subFolder,
    required this.galleryName,
    required this.cancelToken,
    this.batchId,
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
    String? resolvedUrl,
    String? fileName,
    String? savePath,
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
