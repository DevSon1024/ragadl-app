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
                            !controller.downloaderService.isValidUrl(
                              controller.urlController.text,
                            )
                        ? color.error
                        : color.outline.withValues(alpha: 0.2),
                width:
                    controller.urlController.text.isNotEmpty &&
                            !controller.downloaderService.isValidUrl(
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
                hintText: 'Enter gallery URL',
                prefixIcon: Icon(
                  Icons.link_rounded,
                  color:
                      controller.urlController.text.isNotEmpty &&
                              !controller.downloaderService.isValidUrl(
                                controller.urlController.text,
                              )
                          ? color.error
                          : color.primary,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.urlController.text.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
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
                              ClipboardData(
                                text: controller.urlController.text,
                              ),
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
                          color: color.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
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
                    ] else
                      Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.content_paste_rounded,
                            color: color.primary,
                            size: 18,
                          ),
                          onPressed: () {
                            controller.pasteFromClipboard(
                              onPaste: () {
                                SnackbarHelper.showModernSnackBar(
                                  context: context,
                                  message: 'URL pasted from clipboard',
                                  icon: Icons.paste_rounded,
                                );
                              },
                            );
                          },
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: 'Paste URL',
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
                            !controller.downloaderService.isValidUrl(
                              controller.urlController.text,
                            )
                        ? 'Enter a valid Ragalahari, Idlebrain, Behindwoods, or TeluguOne URL'
                        : null,
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) => controller.refreshState(),
            ),
          ),

          // Page Range input for Behindwoods
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child:
                controller.isBehindwoodsLink
                    ? Column(
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: color.outline.withValues(alpha: 0.2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.shadow.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: controller.startPageController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Start Image',
                                    labelStyle: TextStyle(
                                      fontSize: 13,
                                      color: color.onSurfaceVariant,
                                    ),
                                    hintText: 'e.g. 1',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                controller.showBehindwoodsInfo
                                    ? Icons.info_rounded
                                    : Icons.info_outline_rounded,
                                color: color.secondary,
                              ),
                              onPressed: () {
                                controller.toggleBehindwoodsInfo();
                                HapticFeedback.lightImpact();
                              },
                              tooltip: 'Scraping Info',
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: color.outline.withValues(alpha: 0.2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.shadow.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: controller.endPageController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'End Image',
                                    labelStyle: TextStyle(
                                      fontSize: 13,
                                      color: color.onSurfaceVariant,
                                    ),
                                    hintText: 'e.g. 10',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (controller.showBehindwoodsInfo) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.secondaryContainer.withValues(
                                alpha: 0.4,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color.secondary.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: color.secondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "We have added range input as it is required for the limitation of downloads as per user need instead of downloading all images because, as we know, Rakul Preet's page has almost 2500+ images in it, and if we direct download images without locking the range, it will be a heavy load on the device and internet data as well. Please download images in batches instead of all at once.",
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: color.onSecondaryContainer,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    )
                    : const SizedBox.shrink(),
          ),

          const SizedBox(height: 20),

          // Action buttons
          ActionButtons(controller: controller, galleryTitle: galleryTitle),
        ],
      ),
    );
  }

  static void showSupportedPortalsBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: color.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supported Portals',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'RagaDL supports downloading galleries from the following portals:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _buildSheetPortalItem(
                context,
                title: 'Ragalahari',
                domains: ['ragalahari.com', 'm.ragalahari.com'],
              ),
              const SizedBox(height: 12),
              _buildSheetPortalItem(
                context,
                title: 'Idlebrain',
                domains: ['idlebrain.com'],
              ),
              const SizedBox(height: 12),
              _buildSheetPortalItem(
                context,
                title: 'IMGbb',
                domains: ['imgbb.com'],
              ),
              const SizedBox(height: 12),
              _buildSheetPortalItem(
                context,
                title: 'Behindwoods',
                domains: ['behindwoods.com'],
              ),
              const SizedBox(height: 12),
              _buildSheetPortalItem(
                context,
                title: 'TeluguOne',
                domains: ['teluguone.com'],
              ),
            ],
          ),
        ),
      );
    },
  );
}

  static Widget _buildSheetPortalItem(
    BuildContext context, {
    required String title,
    required List<String> domains,
  }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Wrap(
            spacing: 6,
            children:
                domains.map((domain) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      domain,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}
