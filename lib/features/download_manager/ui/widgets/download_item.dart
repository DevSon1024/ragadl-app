import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/download_task.dart';

// Running download item
class RunningDownloadItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const RunningDownloadItem({
    super.key,
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: task,
      builder: (context, _) {
        final color = Theme.of(context).colorScheme;
        final isPaused = task.status == DownloadStatus.paused;
        final isQueued = task.status == DownloadStatus.queued;
        final isScraping = task.status == DownloadStatus.scraping;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${task.folder}/${task.subFolder}',
                            style: TextStyle(
                              fontSize: 12,
                              color: color.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(status: task.status),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (isQueued || isScraping) ? null : task.progress,
                  backgroundColor: color.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    isPaused
                        ? Colors.orange
                        : isQueued
                        ? Colors.blue[300]
                        : isScraping
                        ? Colors.teal
                        : Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isQueued
                          ? 'Queued...'
                          : isScraping
                              ? 'Scraping...'
                              : task.status == DownloadStatus.downloading
                                  ? 'Downloading (${(task.progress * 100).toStringAsFixed(1)}%)'
                                  : '${(task.progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 12, color: color.onSurfaceVariant),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isQueued) ...[
                          IconButton(
                            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                            onPressed: isPaused ? onResume : onPause,
                            tooltip: isPaused ? 'Resume' : 'Pause',
                            iconSize: 20,
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: onCancel,
                          tooltip: 'Cancel',
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Failed download item
class FailedDownloadItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  const FailedDownloadItem({
    super.key,
    required this.task,
    required this.onRetry,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        if (task.status == DownloadStatus.failed) {
          Clipboard.setData(ClipboardData(text: task.url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copied to clipboard.'),
            ),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.error, color: Colors.red),
        ),
        title: Text(
          task.fileName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${task.folder}/${task.subFolder}'),
            if (task.errorMessage != null)
              Text(
                task.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRetry,
              tooltip: 'Retry',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onRemove,
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    ),
  );
}
}

// Completed download item
class CompletedDownloadItem extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const CompletedDownloadItem({
    super.key,
    required this.task,
    required this.onTap,
    required this.onRemove,
  });

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.check_circle, color: Colors.green),
        ),
        title: Text(
          task.fileName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.savePath, style: const TextStyle(fontSize: 11)),
            Text(
              _formatTime(task.completedTime),
              style: TextStyle(fontSize: 10, color: color.onSurfaceVariant),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemove,
          tooltip: 'Remove from history',
        ),
        onTap: onTap,
      ),
    );
  }
}

// Private status chip (shared internal helper)
class _StatusChip extends StatelessWidget {
  final DownloadStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, chipColor) = switch (status) {
      DownloadStatus.downloading => ('Downloading', Colors.blue),
      DownloadStatus.paused => ('Paused', Colors.orange),
      DownloadStatus.queued => ('Queued', Colors.grey),
      DownloadStatus.scraping => ('Scraping', Colors.teal),
      _ => ('Unknown', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
