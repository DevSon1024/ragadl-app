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
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  memCacheWidth: 600,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  width: double.infinity,
                  placeholder:
                      (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (date != null && date!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    date!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
                if (showActionButton) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isLoadingAction ? null : onActionPressed,
                      icon:
                          isLoadingAction
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.grid_view, size: 18),
                      label: Text(
                        isLoadingAction ? 'Loading...' : actionLabel,
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
