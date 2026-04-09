import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CelebrityCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? date;
  final VoidCallback onTap;
  final VoidCallback onActionPressed;
  final bool isLoadingAction;
  final String actionLabel;
  final bool showActionButton;

  final bool? isFavorite;
  final VoidCallback? onFavoriteTap;

  const CelebrityCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.date,
    required this.onTap,
    required this.onActionPressed,
    this.isLoadingAction = false,
    this.actionLabel = 'Show Galleries',
    this.showActionButton = true,
    this.isFavorite,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
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
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              placeholder:
                  (context, url) => const Center(
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
                        child:
                            isLoadingAction
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
            if (onFavoriteTap != null)
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
                    onPressed: onFavoriteTap,
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
}
