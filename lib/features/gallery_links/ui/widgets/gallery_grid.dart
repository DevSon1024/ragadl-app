import 'package:flutter/material.dart';
import 'package:ragadl/shared/widgets/grid_utils.dart';
import '../controllers/gallery_links_controller.dart';
import 'gallery_card.dart';

class GalleryGrid extends StatelessWidget {
  final GalleryLinksController controller;
  final Function(String url, String title) onTapCard;

  const GalleryGrid({
    super.key,
    required this.controller,
    required this.onTapCard,
  });

  @override
  Widget build(BuildContext context) {
    final urls = controller.currentPageUrls;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: calculateGridColumns(context), // From your shared utils
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: urls.length,
      itemBuilder: (context, index) {
        final url = urls[index];
        final item = controller.loadedItems[url];

        return _buildAnimatedItem(
          keyId: url,
          index: index,
          child: GalleryCard(
            url: url,
            item: item,
            isFavorite: controller.isGalleryFavorite(url),
            onTap: item != null ? () => onTapCard(item.url, item.title) : () {},
            onLongPress: item != null ? () => controller.toggleGalleryFavorite(item) : () {},
            onToggleFavorite: item != null ? () => controller.toggleGalleryFavorite(item) : () {},
          ),
        );
      },
    );
  }

  Widget _buildAnimatedItem({required Widget child, required String keyId, required int index}) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(keyId),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }
}