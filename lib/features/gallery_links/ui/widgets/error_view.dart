// lib/features/gallery_links/ui/widgets/error_view.dart
import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  final String error;

  const ErrorView({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              error,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}