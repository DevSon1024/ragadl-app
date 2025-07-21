import 'package:flutter/material.dart';
import '../download_manager_page.dart';
import 'download_item_header.dart';
import 'download_progress_bar.dart';
import 'download_action_buttons.dart';
import 'package:flutter/services.dart';

class DownloadItemCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback? onRemove;
  final VoidCallback? onRedownload;

  const DownloadItemCard({
    super.key,
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    this.onRemove,
    this.onRedownload,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        if (task.status == DownloadStatus.failed || task.status == DownloadStatus.paused) {
          Clipboard.setData(ClipboardData(text: task.url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image URL copied to clipboard')),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DownloadItemHeader(task: task),
              const SizedBox(height: 8),
              DownloadProgressBar(task: task),
              const SizedBox(height: 4),
              DownloadActionButtons(
                task: task,
                onPause: onPause,
                onResume: onResume,
                onCancel: onCancel,
                onRemove: onRemove,
                onRedownload: onRedownload,
              ),
            ],
          ),
        ),
      ),
    );
  }
}