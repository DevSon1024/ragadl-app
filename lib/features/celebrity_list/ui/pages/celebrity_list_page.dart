import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gallery_links/ui/pages/gallery_links_page.dart';
import '../../logic/celebrity_controller.dart';
import '../../logic/search_controller.dart';
import '../../../../shared/services/favorites_service.dart';
import '../animations/list_animations.dart';
import '../widgets/celebrity_list_view.dart';
import '../widgets/sort_menu.dart';
import '../../../../shared/widgets/search_bar.dart';
import '../widgets/loading_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../widgets/empty_view.dart';

// Note: We avoid importing from downloader to keep dependencies clean, but if DownloadSelectedCallback is needed,
// make sure its typedef is imported where needed. Assuming it's defined elsewhere.
typedef DownloadSelectedCallback = void Function(String, String, dynamic);

class CelebrityListPage extends ConsumerWidget {
  final DownloadSelectedCallback? onDownloadSelected;

  const CelebrityListPage({super.key, this.onDownloadSelected});

  void _showSnackBar(BuildContext context, String message, bool isPositive) {
    final color = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isPositive ? Icons.star_rounded : Icons.star_border_rounded,
              color: isPositive ? Colors.amber : color.onSurface,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor:
            isPositive
                ? Colors.amber.withValues(alpha: 0.9)
                : color.inverseSurface,
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  PageRoute _createPageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, anim, _) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        final offset = Tween(
          begin: const Offset(0.0, 0.05),
          end: Offset.zero,
        ).animate(curved);
        final fade = Tween(begin: 0.0, end: 1.0).animate(curved);
        return SlideTransition(
          position: offset,
          child: FadeTransition(opacity: fade, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: color.primaryContainer.withValues(alpha: 0.25),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Celebrity Profiles',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: const [SortMenu()],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.primaryContainer.withValues(alpha: 0.25),
              color.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            CommonSearchBar(
              hintText: 'Search Celebrities...',
              onChanged: (val) {
                ref.read(searchQueryProvider.notifier).state = val;
              },
            ),
            Expanded(child: _buildContent(context, ref)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final state = ref.watch(celebrityProvider);
    final searchResults = ref.watch(searchProvider);
    final query = ref.watch(searchQueryProvider);

    if (state.isLoading) {
      return const LoadingView(message: 'Loading celebrities...');
    }
    if (state.errorMessage != null) {
      return CommonErrorView(
        error: state.errorMessage!,
        onRetry: () => ref.read(celebrityProvider.notifier).retry(),
      );
    }
    if (query.isNotEmpty) {
      if (searchResults.isEmpty) {
        return const EmptyView(
          title: 'No results found',
          message: 'Try a different name.',
        );
      }
      return FadeSlideWrapper(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: searchResults.length,
          physics: const BouncingScrollPhysics(),
          separatorBuilder:
              (context, index) => Divider(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
          itemBuilder: (context, index) {
            final celeb = searchResults[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              title: Text(
                celeb.name,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  _createPageRoute(
                    GalleryLinksPage(
                      celebrityName: celeb.name,
                      profileUrl: celeb.url,
                      onDownloadSelected: onDownloadSelected,
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    }

    if (state.items.isEmpty) {
      return const EmptyView(
        title: 'No celebrities found',
        message: 'Try adjusting your search or filter options.',
      );
    }

    final favorites = ref.watch(favoritesProvider);

    return FadeSlideWrapper(
      child: CelebrityListView(
        items: state.items,
        hasMore: state.hasMore,
        isFetching: state.isFetching,
        onLoadMore: () => ref.read(celebrityProvider.notifier).fetchNextPage(),
        isFavorite: (url) => favorites.contains(url),
        onFavoriteToggle: (name, url) async {
          HapticFeedback.mediumImpact();
          final isPositive = await ref
              .read(favoritesProvider.notifier)
              .toggleFavorite(name, url);
          if (context.mounted) {
            _showSnackBar(
              context,
              isPositive
                  ? '$name added to favorites'
                  : '$name removed from favorites',
              isPositive,
            );
          }
        },
        onTap: (celeb) {
          Navigator.push(
            context,
            _createPageRoute(
              GalleryLinksPage(
                celebrityName: celeb.name,
                profileUrl: celeb.url,
                onDownloadSelected: onDownloadSelected,
              ),
            ),
          );
        },
      ),
    );
  }
}
