import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../controllers/download_manager_controller.dart';
import 'download_item.dart';
import 'empty_state.dart';

class CompletedDownloadsTab extends StatelessWidget {
  final DownloadManagerController controller;

  const CompletedDownloadsTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final completedTasks =
        controller.completedDownloads.values.toList()
          ..sort(
            (a, b) => (b.completedTime ?? DateTime.now()).compareTo(
              a.completedTime ?? DateTime.now(),
            ),
          );

    if (completedTasks.isEmpty) {
      return const DownloadManagerEmptyState(
        icon: Icons.history_rounded,
        title: 'No completed downloads',
        subtitle: 'Completed downloads history will appear here',
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
                onPressed: controller.clearCompleted,
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
            itemBuilder: (_, index) {
              final task = completedTasks[index];
              return CompletedDownloadItem(
                task: task,
                onTap: () async {
                  final result = await OpenFile.open(task.savePath);
                  if (result.type != ResultType.done && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not open file: ${result.message}'),
                      ),
                    );
                  }
                },
                onRemove: () => controller.removeCompletedDownload(task.url),
              );
            },
          ),
        ),
      ],
    );
  }
}
