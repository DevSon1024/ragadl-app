import 'dart:async';
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
    _startRefreshTimer();
  }

  final DownloadManager _manager = DownloadManager();
  Timer? _refreshTimer;

  // Exposed state (read-only views)
  Map<String, DownloadTask> get runningDownloads => _manager.runningDownloads;
  Map<String, DownloadTask> get failedDownloads => _manager.failedDownloads;
  Map<String, DownloadTask> get completedDownloads =>
      _manager.completedDownloads;
  Map<String, DownloadTask> get pausedDownloads => _manager.pausedDownloads;
  int get maxConcurrentDownloads => _manager.maxConcurrentDownloads;

  // Timer-based refresh (replaces Future.delayed loop)

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  // Delegated actions
  void pauseDownload(String url) {
    _manager.pauseDownload(url);
    notifyListeners();
  }

  void resumeDownload(String url) {
    _manager.resumeDownload(url);
    notifyListeners();
  }

  void cancelDownload(String url) {
    _manager.cancelDownload(url);
    notifyListeners();
  }

  void retryFailedDownload(String url) {
    _manager.retryFailedDownload(url);
    notifyListeners();
  }

  void removeCompletedDownload(String url) {
    _manager.removeCompletedDownload(url);
    notifyListeners();
  }

  void clearCompleted() {
    _manager.clearCompleted();
    notifyListeners();
  }

  void clearFailed() {
    _manager.clearFailed();
    notifyListeners();
  }

  void pauseAll() {
    _manager.pauseAll();
    notifyListeners();
  }

  void resumeAll() {
    _manager.resumeAll();
    notifyListeners();
  }

  void cancelAll() {
    _manager.cancelAll();
    notifyListeners();
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    await _manager.setMaxConcurrentDownloads(count);
    notifyListeners();
  }

  // Lifecycle

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
