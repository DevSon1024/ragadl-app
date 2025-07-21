import 'package:flutter/material.dart';

class DownloaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DownloaderAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(
        'Downloader',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}