import 'package:flutter/material.dart';
import '../controllers/downloader_controller.dart';
import '../utils/snackbar_helper.dart';

class ErrorSection extends StatelessWidget {
  final DownloaderController controller;
  final String? galleryTitle;

  const ErrorSection({
    super.key,
    required this.controller,
    this.galleryTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final error = controller.error ?? 'Unknown error';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.errorContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.error.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_rounded, color: color.error, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color.onErrorContainer,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              controller.clearError();
              final url = controller.urlController.text.trim();
              if (url.isNotEmpty && controller.downloaderService.isValidRagaUrl(url)) {
                controller.processGallery(
                  baseUrl: url,
                  galleryTitle: galleryTitle,
                  context: context,
                  showSnackBar: (msg, icon, {isError = false}) {
                    SnackbarHelper.showModernSnackBar(
                      context: context,
                      message: msg,
                      icon: icon,
                      isError: isError,
                    );
                  },
                );
              }
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}