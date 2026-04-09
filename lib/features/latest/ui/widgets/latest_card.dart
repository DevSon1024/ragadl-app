import 'package:flutter/material.dart';
import '../../../../shared/widgets/common_celebrity_card.dart';

class LatestCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? date;
  final VoidCallback onTap;
  final VoidCallback onActionPressed;
  final bool isLoadingAction;
  final String actionLabel;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final bool showActionButton;

  const LatestCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.date,
    required this.onTap,
    required this.onActionPressed,
    this.isLoadingAction = false,
    this.actionLabel = 'Show Galleries',
    this.isFavorite = false,
    this.onFavoriteTap,
    this.showActionButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return CommonCelebrityCard.grid(
      imageUrl: imageUrl,
      title: title,
      date: date,
      onTap: onTap,
      onActionPressed: onActionPressed,
      isLoadingAction: isLoadingAction,
      actionLabel: actionLabel,
      isFavorite: isFavorite,
      onFavoriteToggle: onFavoriteTap,
      showActionButton: showActionButton,
    );
  }
}
