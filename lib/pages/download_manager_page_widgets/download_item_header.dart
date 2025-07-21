import 'package:flutter/material.dart';
import '../download_manager_page.dart';

class DownloadItemHeader extends StatelessWidget {
  final DownloadTask task;

  const DownloadItemHeader({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _buildStatusChip(task.status),
      ],
    );
  }

  Widget _buildStatusChip(DownloadStatus status) {
    String label;
    Color color;

    switch (status) {
      case DownloadStatus.downloading:
        label = 'Downloading';
        color = Colors.blue;
        break;
      case DownloadStatus.paused:
        label = 'Paused';
        color = Colors.orange;
        break;
      case DownloadStatus.completed:
        label = 'Completed';
        color = Colors.green;
        break;
      case DownloadStatus.failed:
        label = 'Failed';
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}