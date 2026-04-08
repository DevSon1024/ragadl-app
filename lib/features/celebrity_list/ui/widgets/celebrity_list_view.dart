import 'package:flutter/material.dart';
import '../../data/models/celebrity_model.dart';
import 'celebrity_card.dart';

class CelebrityListView extends StatelessWidget {
  final List<CelebrityModel> items;
  final bool hasMore;
  final bool isFetching;
  final VoidCallback onLoadMore;
  final Function(CelebrityModel) onTap;
  final Function(String, String) onFavoriteToggle;
  final bool Function(String) isFavorite;

  const CelebrityListView({
    super.key,
    required this.items,
    required this.hasMore,
    required this.isFetching,
    required this.onLoadMore,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.isFavorite,
  });

  @override
  Widget build(BuildContext context) {
      final color = Theme.of(context).colorScheme;
      final itemCount = items.length + (hasMore ? 1 : 0);

      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 100.0, top: 8),
        physics: const BouncingScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: isFetching
                    ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(color.primary))
                    : FilledButton.tonalIcon(
                        onPressed: onLoadMore,
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('Load More Celebrities'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
              ),
            );
          }

          final celebrity = items[index];

          return AnimatedContainer(
            duration: Duration(milliseconds: 100 + ((index % 10) * 20)),
            child: CelebrityCard(
              celebrity: celebrity,
              isFavorite: isFavorite(celebrity.url),
              onTap: () => onTap(celebrity),
              onFavoriteToggle: () => onFavoriteToggle(celebrity.name, celebrity.url),
            ),
          );
        },
      );
  }
}
