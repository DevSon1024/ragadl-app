import 'package:flutter/material.dart';

class DownloadManagerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onClearFailedAndPaused;
  final VoidCallback onCancelAllAndDelete;

  const DownloadManagerAppBar({
    super.key,
    required this.onClearFailedAndPaused,
    required this.onCancelAllAndDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(
        'Download Manager',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep),
          onPressed: onClearFailedAndPaused,
          tooltip: 'Clear Failed & Paused Downloads',
        ),
        IconButton(
          icon: const Icon(Icons.cancel),
          onPressed: onCancelAllAndDelete,
          tooltip: 'Cancel All Downloads and Delete Folders',
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}