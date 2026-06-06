import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../download_manager/logic/download_manager.dart';

/// Riverpod provider for the DownloadManagerController.
final downloadManagerControllerProvider =
    ChangeNotifierProvider<DownloadManagerController>((ref) {
      final controller = DownloadManagerController();
      ref.onDispose(controller.dispose);
      return controller;
    });

class DownloadManagerController extends ChangeNotifier {
  DownloadManagerController() {
    _manager.addListener(_onManagerChanged);
  }

  final DownloadManager _manager = DownloadManager();

  void _onManagerChanged() {
    notifyListeners();
  }

  // Exposed state (read-only views)
  Map<String, DownloadTask> get runningDownloads => _manager.runningDownloads;
  Map<String, DownloadTask> get failedDownloads => _manager.failedDownloads;
  Map<String, DownloadTask> get completedDownloads =>
      _manager.completedDownloads;
  Map<String, DownloadTask> get pausedDownloads => _manager.pausedDownloads;
  int get maxConcurrentDownloads => _manager.maxConcurrentDownloads;

  // Delegated actions
  void pauseDownload(String url) {
    _manager.pauseDownload(url);
  }

  void resumeDownload(String url) {
    _manager.resumeDownload(url);
  }

  void cancelDownload(String url) {
    _manager.cancelDownload(url);
  }

  void retryFailedDownload(String url) {
    _manager.retryFailedDownload(url);
  }

  void removeCompletedDownload(String url) {
    _manager.removeCompletedDownload(url);
  }

  void clearCompleted() {
    _manager.clearCompleted();
  }

  void clearFailed() {
    _manager.clearFailed();
  }

  void pauseAll() {
    _manager.pauseAll();
  }

  void resumeAll() {
    _manager.resumeAll();
  }

  void cancelAll() {
    _manager.cancelAll();
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    await _manager.setMaxConcurrentDownloads(count);
  }

  // Lifecycle

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    super.dispose();
  }
}
