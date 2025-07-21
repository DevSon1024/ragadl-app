import 'package:flutter/material.dart';
import '../download_manager_page.dart';

class DownloadActionButtons extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback? onRemove;
  final VoidCallback? onRedownload;

  const DownloadActionButtons({
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${(task.progress * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onRemove,
              tooltip: 'Remove from list',
              iconSize: 20,
            ),
            if (task.status == DownloadStatus.failed)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => onRedownload?.call(),
                tooltip: 'Retry download',
                iconSize: 20,
              ),
            if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.paused)
              IconButton(
                icon: Icon(
                  task.status == DownloadStatus.paused ? Icons.play_arrow : Icons.pause,
                ),
                onPressed: task.status == DownloadStatus.paused ? onResume : onPause,
                tooltip: task.status == DownloadStatus.paused ? 'Resume' : 'Pause',
                iconSize: 20,
              ),
            if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.paused)
              IconButton(
                icon: const Icon(Icons.cancel),
                onPressed: onCancel,
                tooltip: 'Cancel',
                iconSize: 20,
              ),
          ],
        ),
      ],
    );
  }
}