import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/downloader_controller.dart';
import '../utils/snackbar_helper.dart';
import 'action_buttons.dart';

class ControlsSection extends StatelessWidget {
  final DownloaderController controller;
  final String? galleryTitle;

  const ControlsSection({
    super.key,
    required this.controller,
    this.galleryTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Folder input
          Container(
            decoration: BoxDecoration(
              color: color.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.outline.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: color.shadow.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller.folderController,
              focusNode: controller.folderFocusNode,
              decoration: InputDecoration(
                labelText: 'Main Folder Name',
                hintText: 'Enter folder name for downloads',
                prefixIcon: Icon(Icons.folder_rounded, color: color.primary),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.check_rounded, color: color.primary),
                    onPressed: () {
                      final folderName =
                          controller.folderController.text.trim().isEmpty
                              ? 'RagaDownloads'
                              : controller.folderController.text.trim();
                      controller.setMainFolderName(folderName);
                      HapticFeedback.mediumImpact();
                      SnackbarHelper.showModernSnackBar(
                        context: context,
                        message: 'Folder set to: $folderName',
                        icon: Icons.folder_rounded,
                      );
                    },
                    tooltip: 'Set Main Folder',
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // URL input
          Container(
            decoration: BoxDecoration(
              color: color.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    controller.urlController.text.isNotEmpty &&
                            !controller.downloaderService.isValidRagaUrl(
                              controller.urlController.text,
                            )
                        ? color.error
                        : color.outline.withValues(alpha: 0.2),
                width:
                    controller.urlController.text.isNotEmpty &&
                            !controller.downloaderService.isValidRagaUrl(
                              controller.urlController.text,
                            )
                        ? 2
                        : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.shadow.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller.urlController,
              focusNode: controller.urlFocusNode,
              decoration: InputDecoration(
                labelText: 'Gallery URL',
                hintText: 'https://www.ragalahari.com/...',
                prefixIcon: Icon(
                  Icons.link_rounded,
                  color:
                      controller.urlController.text.isNotEmpty &&
                              !controller.downloaderService.isValidRagaUrl(
                                controller.urlController.text,
                              )
                          ? color.error
                          : color.primary,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.urlController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.content_copy_rounded,
                            color: color.onSurfaceVariant,
                            size: 18,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: controller.urlController.text),
                            );
                            SnackbarHelper.showModernSnackBar(
                              context: context,
                              message: 'URL copied to clipboard',
                              icon: Icons.content_copy_rounded,
                            );
                          },
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: color.onSurfaceVariant,
                          size: 18,
                        ),
                        onPressed: () {
                          controller.urlController.clear();
                          controller.refreshState();
                        },
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                errorText:
                    controller.urlController.text.isNotEmpty &&
                            !controller.downloaderService.isValidRagaUrl(
                              controller.urlController.text,
                            )
                        ? 'URL must start with https://www.ragalahari.com'
                        : null,
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) => controller.refreshState(),
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          ActionButtons(
            controller: controller,
            galleryTitle: galleryTitle,
          ),

          const SizedBox(height: 16),

          if (controller.isSelectionMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: color.primary),
                  const SizedBox(width: 12),
                  Text(
                    '${controller.selectedImages.length} images selected',
                    style: TextStyle(
                      color: color.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => controller.clearSelection(),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
