import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Illustration
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.primaryContainer.withValues(alpha: 0.4),
                  color.primaryContainer.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.primary.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.cloud_download_outlined,
              size: 56,
              color: color.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ready to Download',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Paste a supported link in the URL field above to begin.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Section header
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: color.outlineVariant.withValues(alpha: 0.4),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'SUPPORTED PORTALS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color.onSurfaceVariant.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: color.outlineVariant.withValues(alpha: 0.4),
                  thickness: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Portal 1: Ragalahari
          _buildPortalCard(
            context,
            title: 'Ragalahari',
            domains: ['ragalahari.com', 'm.ragalahari.com'],
          ),

          const SizedBox(height: 12),

          // Portal 2: Idlebrain
          _buildPortalCard(
            context,
            title: 'Idlebrain',
            domains: ['idlebrain.com'],
          ),

          // Portal 3: IMGbb
          _buildPortalCard(context, title: 'IMGbb', domains: ['imgbb.com']),

          const SizedBox(height: 12),

          // Portal 4: Behindwoods
          _buildPortalCard(
            context,
            title: 'Behindwoods',
            domains: ['behindwoods.com'],
          ),

          const SizedBox(height: 12),

          // Portal 5: TeluguOne
          _buildPortalCard(
            context,
            title: 'TeluguOne',
            domains: ['teluguone.com'],
          ),
        ],
      ),
    );
  }

  Widget _buildPortalCard(
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
        boxShadow: [
          BoxShadow(
            color: color.shadow.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
