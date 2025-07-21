import 'package:flutter/material.dart';
import '../download_manager_page.dart';

class DownloadProgressBar extends StatelessWidget {
  final DownloadTask task;

  const DownloadProgressBar({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: task.progress,
      backgroundColor: Colors.grey[200],
      valueColor: AlwaysStoppedAnimation<Color>(
        _getColorForStatus(task.status),
      ),
    );
  }

  Color _getColorForStatus(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
    }
  }
}