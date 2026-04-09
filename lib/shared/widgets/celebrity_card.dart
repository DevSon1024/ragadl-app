import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum CelebrityCardStyle { grid, list }

class CommonCelebrityCard extends StatelessWidget {
  final CelebrityCardStyle style;

  // Shared
  final String title;
  final VoidCallback onTap;
  final bool? isFavorite;
  final VoidCallback? onFavoriteToggle;

  // Grid specific
  final String? imageUrl;
  final String? date;
  final VoidCallback? onActionPressed;
  final bool isLoadingAction;
  final String actionLabel;
  final bool showActionButton;

  const CommonCelebrityCard.grid({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    required this.onActionPressed,
    this.date,
    this.isFavorite,
    this.onFavoriteToggle,
    this.isLoadingAction = false,
    this.actionLabel = 'Show Galleries',
    this.showActionButton = true,
  })  : style = CelebrityCardStyle.grid;

  const CommonCelebrityCard.list({
    super.key,
    required this.title,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.isFavorite,
  })  : style = CelebrityCardStyle.list,
        imageUrl = null,
        date = null,
        onActionPressed = null,
        isLoadingAction = false,
        actionLabel = '',
        showActionButton = false;

  @override
  Widget build(BuildContext context) {
    if (style == CelebrityCardStyle.grid) {
      return _buildGridStyle(context);
    } else {
      return _buildListStyle(context);
    }
  }

  Widget _buildGridStyle(BuildContext context) {
    return Card(
      elevation: 6,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.4, 0.65, 1.0],
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (date != null && date!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      date!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (showActionButton &&
                      actionLabel.toLowerCase() != 'remove') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoadingAction ? null : onActionPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: isLoadingAction
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                actionLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Sleek favorite icon button top right
            if (onFavoriteToggle != null)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    iconSize: 20,
                    icon: Icon(
                      (isFavorite ?? false)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color:
                          (isFavorite ?? false) ? Colors.amber : Colors.white,
                    ),
                    onPressed: onFavoriteToggle,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListStyle(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final isFav = isFavorite ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color:
            isFav ? color.primaryContainer.withValues(alpha: 0.3) : color.surface,
        elevation: isFav ? 4 : 1,
        shadowColor:
            isFav ? color.primary.withValues(alpha: 0.2) : color.shadow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isFav
                  ? Border.all(color: color.primary.withValues(alpha: 0.2))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.primary.withValues(alpha: 0.1),
                        color.primary.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(Icons.person_rounded, color: color.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (isFav)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              'Favorite',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isFav
                        ? Colors.amber.withValues(alpha: 0.1)
                        : color.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isFav ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFav ? Colors.amber : color.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: onFavoriteToggle,
                    tooltip:
                        isFav ? 'Remove from favorites' : 'Add to favorites',
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: color.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
