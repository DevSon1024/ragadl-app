import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/utils/celebrity_utils.dart';
import '../../logic/celebrity_controller.dart';

class SortMenu extends ConsumerWidget {
  const SortMenu({super.key});

  PopupMenuItem<SortOption> _buildItem(
    BuildContext context,
    SortOption option,
    String title,
    IconData icon,
    SortOption currentSort,
  ) {
    final color = Theme.of(context).colorScheme;
    final isSelected = currentSort == option;

    return PopupMenuItem<SortOption>(
      value: option,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? color.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? color.primary : color.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color.primary : color.onSurface,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Icon(Icons.check_rounded, size: 18, color: color.primary),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Theme.of(context).colorScheme;
    final currentSort = ref.watch(
      celebrityProvider.select((s) => s.sortOption),
    );

    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: PopupMenuButton<SortOption>(
        icon: Icon(Icons.sort_rounded, color: color.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (SortOption newValue) {
          ref.read(celebrityProvider.notifier).changeSort(newValue);
          HapticFeedback.selectionClick();
        },
        itemBuilder:
            (BuildContext context) => [
              _buildItem(
                context,
                SortOption.az,
                'A-Z',
                Icons.sort_by_alpha_rounded,
                currentSort,
              ),
              _buildItem(
                context,
                SortOption.za,
                'Z-A',
                Icons.sort_by_alpha_rounded,
                currentSort,
              ),
              const PopupMenuDivider(),
              _buildItem(
                context,
                SortOption.celebrityAll,
                'All Celebrities',
                Icons.people_rounded,
                currentSort,
              ),
              _buildItem(
                context,
                SortOption.celebrityActors,
                'Actors',
                Icons.person_rounded,
                currentSort,
              ),
              _buildItem(
                context,
                SortOption.celebrityActresses,
                'Actresses',
                Icons.person_outline_rounded,
                currentSort,
              ),
            ],
      ),
    );
  }
}
