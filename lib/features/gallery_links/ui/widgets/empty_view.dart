// lib/features/gallery_links/ui/widgets/empty_view.dart
import 'package:flutter/material.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No galleries found',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}