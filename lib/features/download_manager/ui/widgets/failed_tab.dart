import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView.builder(
        itemCount: failedTasks.length,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
        itemBuilder: (_, index) {
          final task = failedTasks.values.elementAt(index);
          return FailedDownloadItem(
            task: task,
            onRetry: () => controller.retryFailedDownload(task.url),
            onRemove: () => controller.removeCompletedDownload(task.url),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final failedTasksList = failedTasks.values;
          final joinedUrls = failedTasksList.map((t) => t.url).join('\n');
          Clipboard.setData(ClipboardData(text: joinedUrls));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied ${failedTasksList.length} failed links to clipboard.'),
            ),
          );
        },
        icon: const Icon(Icons.copy_all_rounded),
        label: const Text('Copy All Failed'),
      ),
    );
  }
}
