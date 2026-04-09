import 'package:flutter/material.dart';

class CommonErrorView extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  final bool isSection;

  const CommonErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.isSection = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    if (isSection) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.errorContainer.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.error.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: _buildContent(context, true),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _buildContent(context, false),
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context, bool asSection) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    
    return [
      if (asSection) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.error.withValues(alpha: 0.1),
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
      ] else ...[
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color.errorContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: color.error,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Oops! Something went wrong',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
      ],
      Text(
        error,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: asSection ? color.onErrorContainer : color.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
      if (onRetry != null) ...[
        SizedBox(height: asSection ? 16 : 24),
        asSection
          ? OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            )
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
      ]
    ];
  }
}
