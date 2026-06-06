import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../../../../shared/utils/celebrity_utils.dart';

class GalleryCard extends StatelessWidget {
  final String url;
  final GalleryItem? item;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleFavorite;

  const GalleryCard({
    super.key,
    required this.url,
    required this.item,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (item == null) {
      return RepaintBoundary(child: _buildPlaceholder(theme));
    }

    return RepaintBoundary(
      child: Card(
        elevation: 6,
        shadowColor: Colors.black26,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(theme),
              _buildGradientOverlay(),
              _buildContent(),
              _buildFavoriteButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Shimmer.fromColors(
        baseColor: theme.colorScheme.surfaceContainerHighest,
        highlightColor: theme.colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: double.infinity, color: Colors.grey),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 120, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(ThemeData theme) {
    if (item?.thumbnailUrl != null && item!.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        item!.thumbnailUrl!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.errorContainer,
          child: Icon(Icons.broken_image, size: 60, color: theme.colorScheme.onErrorContainer),
        ),
      );
    }
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.image_not_supported, size: 60, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildGradientOverlay() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.85)],
          stops: const [0.4, 0.65, 1.0],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item!.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text('${item!.pages} Page(s)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  DateFormat('MMM dd, yyyy').format(item!.date),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton() {
    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        color: Colors.black.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          iconSize: 20,
          icon: Icon(isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: isFavorite ? Colors.amber : Colors.white),
          onPressed: onToggleFavorite,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }
}