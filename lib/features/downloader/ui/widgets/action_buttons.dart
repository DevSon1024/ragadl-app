import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/downloader_controller.dart';
import '../utils/snackbar_helper.dart';

class ActionButtons extends StatelessWidget {
  final DownloaderController controller;
  final String? galleryTitle;

  const ActionButtons({
    super.key,
    required this.controller,
    this.galleryTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    (controller.isLoading || controller.isDownloading || controller.mainFolderName.isEmpty)
                        ? null
                        : () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final url = controller.urlController.text.trim();
                          if (url.isEmpty) {
                            SnackbarHelper.showModernSnackBar(
                              context: context,
                              message: 'Please enter a URL',
                              icon: Icons.warning_rounded,
                              isError: true,
                            );
                            return;
                          }
                          if (!controller.downloaderService.isValidUrl(url)) {
                            SnackbarHelper.showModernSnackBar(
                              context: context,
                              message: 'Invalid URL: Must be a Ragalahari, Idlebrain, or Behindwoods gallery URL',
                              icon: Icons.error_rounded,
                              isError: true,
                            );
                            return;
                          }
                          HapticFeedback.mediumImpact();
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
                        },
                icon: const Icon(Icons.search_rounded),
                label: const Text('Fetch Images'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    (controller.isLoading ||
                            controller.isDownloading ||
                            controller.imageUrls.isEmpty ||
                            controller.mainFolderName.isEmpty)
                        ? null
                        : () {
                          HapticFeedback.mediumImpact();
                          controller.downloadAllImages(
                            galleryTitle: galleryTitle,
                            onResult: (success, message) {
                              SnackbarHelper.showModernSnackBar(
                                context: context,
                                message: message,
                                icon: success ? Icons.download_for_offline_rounded : Icons.error_rounded,
                                isError: !success,
                              );
                            },
                          );
                        },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download All'),
                style: FilledButton.styleFrom(
                  backgroundColor: color.secondary,
                  foregroundColor: color.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => controller.clearAll(
              onClearCompleted: () {
                SnackbarHelper.showModernSnackBar(
                  context: context,
                  message: 'All fields and images cleared',
                  icon: Icons.delete_sweep_rounded,
                );
              },
            ),
            icon: const Icon(Icons.delete_sweep_rounded),
            label: const Text('Clear All'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
