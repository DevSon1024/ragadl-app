import 'package:flutter/material.dart';
import '../controllers/download_manager_controller.dart';
import 'download_item.dart';
import 'empty_state.dart';

class FailedDownloadsTab extends StatelessWidget {
  final DownloadManagerController controller;

  const FailedDownloadsTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final failedTasks = controller.failedDownloads;

    if (failedTasks.isEmpty) {
      return const DownloadManagerEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No failed downloads',
        subtitle: 'Failed downloads will appear here',
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
                onPressed: controller.clearFailed,
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
            itemBuilder: (_, index) {
              final task = failedTasks.values.elementAt(index);
              return FailedDownloadItem(
                task: task,
                onRetry: () => controller.retryFailedDownload(task.url),
                onRemove: () => controller.removeCompletedDownload(task.url),
              );
            },
          ),
        ),
      ],
    );
  }
}
