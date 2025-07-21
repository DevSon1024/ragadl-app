import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final bool isLoading;
  final bool isDownloading;
  final bool hasImages;
  final String mainFolderName;
  final VoidCallback onFetchImages;
  final VoidCallback onDownloadAll;
  final VoidCallback onClearAll;
  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback onDownloadSelected;

  const ActionButtons({
    super.key,
    required this.isLoading,
    required this.isDownloading,
    required this.hasImages,
    required this.mainFolderName,
    required this.onFetchImages,
    required this.onDownloadAll,
    required this.onClearAll,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.onDownloadSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (isLoading || isDownloading || mainFolderName.isEmpty)
                    ? null
                    : onFetchImages,
                icon: const Icon(Icons.search),
                label: const Text('Fetch Images'),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (isLoading || isDownloading || !hasImages || mainFolderName.isEmpty)
                    ? null
                    : onDownloadAll,
                icon: const Icon(Icons.download),
                label: const Text('Download All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onClearAll,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear All'),
          ),
        ),
        if (isSelectionMode)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Selected $selectedCount images',
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
      ],
    );
  }
}