import 'package:flutter/material.dart';
import '../controllers/downloader_controller.dart';
import '../utils/snackbar_helper.dart';

class DownloaderFloatingButton extends StatelessWidget {
  final DownloaderController controller;
  final String? galleryTitle;

  const DownloaderFloatingButton({
    super.key,
    required this.controller,
    this.galleryTitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    if (controller.urlFocusNode.hasFocus) {
      return FloatingActionButton.extended(
        onPressed: () => controller.pasteFromClipboard(
          onPaste: () {
            SnackbarHelper.showModernSnackBar(
              context: context,
              message: 'URL pasted from clipboard',
              icon: Icons.paste_rounded,
            );
          },
        ),
        icon: const Icon(Icons.paste_rounded),
        label: const Text('Paste URL'),
        backgroundColor: color.primary,
        foregroundColor: color.onPrimary,
        elevation: 4,
      );
    }

    return const SizedBox.shrink();
  }
}