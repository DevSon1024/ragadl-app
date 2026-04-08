import 'package:flutter/material.dart';
import '../controllers/downloader_controller.dart';

class LoadingSection extends StatelessWidget {
  final DownloaderController controller;

  const LoadingSection({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final currentPage = controller.currentPage;
    final totalPages = controller.totalPages;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: color.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(color.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Fetching page $currentPage of $totalPages...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalPages > 0 ? (currentPage / totalPages) : null,
            backgroundColor: color.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color.primary),
          ),
        ],
      ),
    );
  }
}