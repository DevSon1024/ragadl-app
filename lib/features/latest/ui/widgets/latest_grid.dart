import 'package:flutter/material.dart';
import '../../core/models/latest_item.dart';
import 'latest_card.dart';

class LatestGrid extends StatelessWidget {
  final List<LatestItem> items;
  final Map<int, bool> loadingProfileLinks;
  final Set<String> favoriteUrls;
  final void Function(int) onTap;
  final void Function(int) onActionPressed;
  final void Function(int) onFavoriteTap;
  final String actionLabel;
  final bool showActionButton;

  const LatestGrid({
    super.key,
    required this.items,
    required this.loadingProfileLinks,
    required this.favoriteUrls,
    required this.onTap,
    required this.onActionPressed,
    required this.onFavoriteTap,
    this.actionLabel = 'Show Galleries',
    this.showActionButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.55,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          final isLoadingProfile = loadingProfileLinks[index] ?? false;

          return LatestCard(
            imageUrl: item.image,
            title: item.title,
            date: item.date,
            onTap: () => onTap(index),
            onActionPressed: () => onActionPressed(index),
            isLoadingAction: isLoadingProfile,
            actionLabel: actionLabel,
            isFavorite: favoriteUrls.contains(item.url),
            onFavoriteTap: () => onFavoriteTap(index),
            showActionButton: showActionButton,
          );
        }, childCount: items.length),
      ),
    );
  }
}
