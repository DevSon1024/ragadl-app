import 'package:flutter/material.dart';

class CustomProgressIndicator extends StatelessWidget {
  final bool isLoading;
  final bool isDownloading;
  final int currentPage;
  final int totalPages;
  final int downloadsSuccessful;
  final int downloadsFailed;
  final int totalImages;
  final String? successMessage;
  final String? error;

  const CustomProgressIndicator({
    super.key,
    required this.isLoading,
    required this.isDownloading,
    required this.currentPage,
    required this.totalPages,
    required this.downloadsSuccessful,
    required this.downloadsFailed,
    required this.totalImages,
    this.successMessage,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isLoading || isDownloading)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: isLoading
                      ? (currentPage / totalPages)
                      : (downloadsSuccessful + downloadsFailed) / totalImages,
                ),
                const SizedBox(height: 4),
                Text(
                  isLoading
                      ? 'Fetching page $currentPage of $totalPages...'
                      : 'Downloaded: $downloadsSuccessful, Failed: $downloadsFailed',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        if (successMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              successMessage!,
              style: const TextStyle(color: Colors.green),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }
}