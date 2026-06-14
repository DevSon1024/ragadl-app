import 'package:flutter/material.dart';
import '../controllers/download_manager_controller.dart';
import 'download_item.dart';
import 'empty_state.dart';

class RunningDownloadsTab extends StatelessWidget {
  final DownloadManagerController controller;

  const RunningDownloadsTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final runningTasks = {
      ...controller.runningDownloads,
      ...controller.pausedDownloads,
    };

    if (runningTasks.isEmpty) {
      return const DownloadManagerEmptyState(
        icon: Icons.download_done_rounded,
        title: 'No active downloads',
        subtitle: 'Downloads in progress will appear here',
      );
    }

    return ListView.builder(
      itemCount: runningTasks.length,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      itemBuilder: (_, index) {
        final task = runningTasks.values.elementAt(index);
        return RunningDownloadItem(
          task: task,
          onPause: () => controller.pauseDownload(task.url),
          onResume: () => controller.resumeDownload(task.url),
          onCancel: () => controller.cancelDownload(task.url),
        );
      },
    );
  }
}
