import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html show parse;
import '../../celebrity/utils/celebrity_utils.dart';
import '../../celebrity/data/profile_cache_service.dart';
import '../../gallery_links/ui/pages/gallery_links_page.dart';
import '../../celebrity/widgets/celebrity_card.dart';
import '../../downloader/ui/pages/ragadl_page.dart';

class FavouritePage extends StatefulWidget {
  const FavouritePage({super.key});

  @override
  State<FavouritePage> createState() => _FavouritePageState();
}

class _FavouritePageState extends State<FavouritePage> {
  List<FavoriteItem> celebrities = [];
  List<FavoriteItem> galleries = [];
  bool isLoading = true;
  final Set<String> _pendingRemovals = {};
  final Set<String> _loadingGalleryProfiles = {};

  String _getFavoriteId(FavoriteItem item) =>
      '${item.type}_${item.celebrityName}_${item.url}';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritesJson = prefs.getStringList('favorites') ?? [];

    final List<FavoriteItem> allFavorites =
        favoritesJson
            .map(
              (json) => FavoriteItem.fromJson(
                Map<String, String>.from(
                  jsonDecode(json) as Map<String, dynamic>,
                ),
              ),
            )
            .toList();

    setState(() {
      celebrities =
          allFavorites.where((item) => item.type == 'celebrity').toList();
      galleries = allFavorites.where((item) => item.type == 'gallery').toList();
      isLoading = false;
    });
  }

  Future<void> _toggleFavorite(FavoriteItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritesJson = prefs.getStringList('favorites') ?? [];

    final List<FavoriteItem> allFavorites =
        favoritesJson
            .map(
              (json) => FavoriteItem.fromJson(
                Map<String, String>.from(
                  jsonDecode(json) as Map<String, dynamic>,
                ),
              ),
            )
            .toList();

    final isCurrentlyFavorite = allFavorites.any(
      (fav) =>
          fav.type == item.type &&
          fav.url == item.url &&
          fav.celebrityName == item.celebrityName,
    );

    if (isCurrentlyFavorite) {
      allFavorites.removeWhere(
        (fav) =>
            fav.type == item.type &&
            fav.url == item.url &&
            fav.celebrityName == item.celebrityName,
      );
      setState(() {
        _pendingRemovals.add(_getFavoriteId(item));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${item.name} from favorites'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      allFavorites.insert(0, item);
      setState(() {
        _pendingRemovals.remove(_getFavoriteId(item));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${item.name} to favorites'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }

    await prefs.setStringList(
      'favorites',
      allFavorites.map((i) => jsonEncode(i.toJson())).toList(),
    );
  }

  void _navigateToItem(FavoriteItem item) {
    if (item.type == 'celebrity') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => GalleryLinksPage(
                profileUrl: item.url,
                celebrityName: item.name,
                thumbnailUrl: item.thumbnailUrl,
              ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => RagaDL(
                initialUrl: item.url,
                galleryTitle: item.name,
                initialFolder: item.celebrityName ?? '',
              ),
        ),
      );
    }
  }

  Future<void> _fetchAndNavigateToProfileForGallery(FavoriteItem item) async {
    setState(() {
      _loadingGalleryProfiles.add(item.url);
    });

    try {
      String? cachedProfileLink = await ProfileCacheService.getProfileLink(
        item.url,
      );
      if (!mounted) return;
      if (cachedProfileLink != null) {
        setState(() {
          _loadingGalleryProfiles.remove(item.url);
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => GalleryLinksPage(
                  profileUrl: cachedProfileLink,
                  celebrityName: item.celebrityName ?? item.name,
                  thumbnailUrl: item.thumbnailUrl,
                ),
          ),
        );
        return;
      }

      final response = await http.get(Uri.parse(item.url));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final document = html.parse(response.body);
        final breadcrumb = document.querySelector('ul.breadcrumbs');

        if (breadcrumb != null) {
          final links = breadcrumb.querySelectorAll('li a');
          for (var link in links) {
            final href = link.attributes['href'] ?? '';
            if (href.startsWith('https://www.ragalahari.com/stars/profile/')) {
              final name = link.text.trim();
              await ProfileCacheService.saveProfileLink(item.url, href);
              if (!mounted) return;
              setState(() {
                _loadingGalleryProfiles.remove(item.url);
              });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => GalleryLinksPage(
                        profileUrl: href,
                        celebrityName: name,
                        thumbnailUrl: item.thumbnailUrl,
                      ),
                ),
              );
              return;
            }
          }
        }
      }

      setState(() {
        _loadingGalleryProfiles.remove(item.url);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile link not found for this gallery'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loadingGalleryProfiles.remove(item.url);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
    }
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedItem({
    required Widget child,
    required String keyId,
    required int index,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(keyId),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(
        milliseconds: 300 + (index * 50).clamp(0, 500),
      ), // Staggered effect
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Favorites',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
          centerTitle: true,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: theme.colorScheme.primary,
                  ),
                  labelColor: theme.colorScheme.onPrimary,
                  unselectedLabelColor: theme.colorScheme.primary.withValues(alpha: 
                    0.7,
                  ),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  tabs: const [
                    Tab(text: 'Celebrities'),
                    Tab(text: 'Galleries'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // Celebrities Tab
            celebrities.isEmpty
                ? _buildEmptyState(
                  'No celebrities yet',
                  'Your favorite stars will appear here.',
                  Icons.star_border_rounded,
                )
                : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio:
                        0.75, // Better aspect ratio for modern cards
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: celebrities.length,
                  itemBuilder: (context, index) {
                    final item = celebrities[index];
                    return _buildAnimatedItem(
                      keyId: 'celeb_${item.url}',
                      index: index,
                      child: CelebrityCard(
                        imageUrl: item.thumbnailUrl ?? '',
                        title: item.name,
                        date: item.date,
                        onTap: () => _navigateToItem(item),
                        onActionPressed: () => _navigateToItem(item),
                        isLoadingAction: false,
                        actionLabel: 'Show Galleries',
                        isFavorite:
                            !_pendingRemovals.contains(_getFavoriteId(item)),
                        onFavoriteTap: () => _toggleFavorite(item),
                      ),
                    );
                  },
                ),
            // Galleries Tab
            galleries.isEmpty
                ? _buildEmptyState(
                  'No galleries yet',
                  'Your saved photo collections will appear here.',
                  Icons.photo_library_outlined,
                )
                : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio:
                        0.75, // Better aspect ratio for modern cards
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: galleries.length,
                  itemBuilder: (context, index) {
                    final item = galleries[index];
                    return _buildAnimatedItem(
                      keyId: 'gallery_${item.url}',
                      index: index,
                      child: CelebrityCard(
                        imageUrl: item.thumbnailUrl ?? '',
                        title: item.name,
                        date: item.date,
                        onTap: () => _navigateToItem(item),
                        onActionPressed:
                            () => _fetchAndNavigateToProfileForGallery(item),
                        isLoadingAction: _loadingGalleryProfiles.contains(
                          item.url,
                        ),
                        actionLabel: 'Show Galleries',
                        isFavorite:
                            !_pendingRemovals.contains(_getFavoriteId(item)),
                        onFavoriteTap: () => _toggleFavorite(item),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}
