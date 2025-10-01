import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ragalahari_downloader/features/celebrity/data/celebrity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/celebrity_utils.dart';
import 'gallery_links_page.dart';
import '../../downloader/ui/ragalahari_downloader.dart';
import '../utils/celebrity_image_cache.dart';

class CelebrityListPage extends StatefulWidget {
  final DownloadSelectedCallback? onDownloadSelected;

  const CelebrityListPage({super.key, this.onDownloadSelected});

  @override
  State<CelebrityListPage> createState() => _CelebrityListPageState();
}

class _CelebrityListPageState extends State<CelebrityListPage>
    with TickerProviderStateMixin {
  final CelebrityRepository _repository = CelebrityRepository.instance;
  final CelebrityImageCache _imageCache = CelebrityImageCache();
  List<Map<String, String>> _filteredCelebrities = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  SortOption _currentSortOption = SortOption.az;
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadSortOption();
    _initializeData();
    _searchController.addListener(_filterCelebrities);
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      await _imageCache.initialize();
      await _repository.loadCelebrities();
      if (mounted) {
        setState(() {
          _filteredCelebrities = List.from(_repository.celebrities);
          _isLoading = false;
          _sortCelebrities();
        });

        _fadeController.forward();
        await Future.delayed(const Duration(milliseconds: 100));
        _slideController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load celebrities. Please try again.';
        });
      }
    }
  }

  Future<void> _loadSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSortOption = prefs.getString('sortOption');
    if (savedSortOption != null) {
      setState(() {
        _currentSortOption = SortOption.values.firstWhere(
              (option) => option.toString() == savedSortOption,
          orElse: () => SortOption.az,
        );
      });
    }
  }

  Future<void> _saveSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sortOption', _currentSortOption.toString());
  }

  void _sortCelebrities() {
    setState(() {
      _filteredCelebrities = List.from(_repository.celebrities);

      // Apply category filters
      switch (_currentSortOption) {
        case SortOption.celebrityActors:
          _filteredCelebrities = _filteredCelebrities
              .where((celebrity) => _repository.actorUrls.contains(celebrity['url']))
              .toList();
          break;
        case SortOption.celebrityActresses:
          _filteredCelebrities = _filteredCelebrities
              .where((celebrity) => _repository.actressUrls.contains(celebrity['url']))
              .toList();
          break;
        case SortOption.celebrityAll:
        case SortOption.az:
        case SortOption.za:
          break;
      }

      // Apply search filter
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        _filteredCelebrities = _filteredCelebrities
            .where((celebrity) => celebrity['name']!.toLowerCase().contains(query))
            .toList();
      }

      // Apply sorting
      switch (_currentSortOption) {
        case SortOption.az:
        case SortOption.celebrityAll:
        case SortOption.celebrityActors:
        case SortOption.celebrityActresses:
          _filteredCelebrities.sort((a, b) => a['name']!.compareTo(b['name']!));
          break;
        case SortOption.za:
          _filteredCelebrities.sort((a, b) => b['name']!.compareTo(a['name']!));
          break;
      }
    });
  }

  void _filterCelebrities() {
    _sortCelebrities();
    HapticFeedback.selectionClick();
  }

  void _handleDownloadPress(String celebrityName) {
    HapticFeedback.mediumImpact();
    if (widget.onDownloadSelected != null) {
      widget.onDownloadSelected!('', celebrityName, null);
    } else {
      Navigator.push(
        context,
        _createPageRoute(RagalahariDownloader(initialFolder: celebrityName)),
      );
    }
  }

  Future<void> _toggleCelebrityFavorite(String name, String url) async {
    HapticFeedback.mediumImpact();

    final prefs = await SharedPreferences.getInstance();
    const favoriteKey = 'favorites';
    final favoritesJson = prefs.getStringList(favoriteKey) ?? <String>[];

    List<FavoriteItem> favorites = favoritesJson
        .map((json) => FavoriteItem.fromJson(
      Map<String, String>.from(jsonDecode(json) as Map),
    ))
        .toList();

    final favoriteItem = FavoriteItem(type: 'celebrity', name: name, url: url);
    final isFavorite = favorites.any((item) =>
    item.type == 'celebrity' && item.name == name && item.url == url);

    if (isFavorite) {
      favorites.removeWhere((item) =>
      item.type == 'celebrity' && item.name == name && item.url == url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _createModernSnackBar('$name removed from favorites', false),
        );
      }
    } else {
      favorites.add(favoriteItem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _createModernSnackBar('$name added to favorites', true),
        );
      }
    }

    await prefs.setStringList(
      favoriteKey,
      favorites.map((item) => jsonEncode(item.toJson())).toList(),
    );
    setState(() {});
  }

  Future<bool> _isCelebrityFavorite(String name, String url) async {
    final prefs = await SharedPreferences.getInstance();
    const favoriteKey = 'favorites';
    final favoritesJson = prefs.getStringList(favoriteKey) ?? <String>[];

    final favorites = favoritesJson
        .map((json) => FavoriteItem.fromJson(
      Map<String, String>.from(jsonDecode(json) as Map),
    ))
        .toList();

    return favorites.any((item) =>
    item.type == 'celebrity' && item.name == name && item.url == url);
  }

  SnackBar _createModernSnackBar(String message, bool isPositive) {
    final color = Theme.of(context).colorScheme;
    return SnackBar(
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
      backgroundColor: isPositive ? Colors.amber.withOpacity(0.9) : color.inverseSurface,
      duration: const Duration(milliseconds: 2000),
    );
  }

  PageRoute _createPageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.05);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
        final offsetAnimation = tween.animate(curvedAnimation);

        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      backgroundColor: color.surface,
      appBar: _buildModernAppBar(theme, color),
      body: Column(
        children: [
          _buildSearchSection(theme, color),
          Expanded(child: _buildContent(theme, color)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(ThemeData theme, ColorScheme color) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: color.surface,
      surfaceTintColor: color.surfaceTint,
      title: const Text(
        'Celebrity Profiles',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: PopupMenuButton<SortOption>(
            icon: Icon(Icons.sort_rounded, color: color.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (SortOption newValue) {
              setState(() {
                _currentSortOption = newValue;
                _saveSortOption();
                _sortCelebrities();
              });
              HapticFeedback.selectionClick();
            },
            itemBuilder: (BuildContext context) => [
              _buildPopupMenuItem(SortOption.az, 'A-Z', Icons.sort_by_alpha_rounded),
              _buildPopupMenuItem(SortOption.za, 'Z-A', Icons.sort_by_alpha_rounded),
              const PopupMenuDivider(),
              _buildPopupMenuItem(SortOption.celebrityAll, 'All Celebrities', Icons.people_rounded),
              _buildPopupMenuItem(SortOption.celebrityActors, 'Actors', Icons.person_rounded),
              _buildPopupMenuItem(SortOption.celebrityActresses, 'Actresses', Icons.person_outline_rounded),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem<SortOption> _buildPopupMenuItem(SortOption option, String title, IconData icon) {
    final color = Theme.of(context).colorScheme;
    final isSelected = _currentSortOption == option;

    return PopupMenuItem<SortOption>(
      value: option,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? color.primary.withOpacity(0.1) : Colors.transparent,
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

  Widget _buildSearchSection(ThemeData theme, ColorScheme color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: color.surface,
        boxShadow: [
          BoxShadow(
            color: color.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color.surfaceContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.outline.withOpacity(0.1)),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Search celebrities...',
            hintStyle: TextStyle(color: color.onSurfaceVariant),
            prefixIcon: Icon(Icons.search_rounded, color: color.onSurfaceVariant),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
              icon: Icon(Icons.clear_rounded, color: color.onSurfaceVariant),
              onPressed: () {
                _searchController.clear();
                _searchFocusNode.unfocus();
                _filterCelebrities();
                HapticFeedback.lightImpact();
              },
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (value) {
            setState(() {});
            _filterCelebrities();
          },
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme color) {
    if (_isLoading) {
      return _buildLoadingState(color);
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme, color);
    }

    if (_filteredCelebrities.isEmpty) {
      return _buildEmptyState(theme, color);
    }

    return _buildCelebrityList(theme, color);
  }

  Widget _buildLoadingState(ColorScheme color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(color.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading celebrities...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.errorContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 64, color: color.error),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializeData();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.surfaceVariant.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded, size: 64, color: color.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              'No celebrities found',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filter options.',
              style: theme.textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrityList(ThemeData theme, ColorScheme color) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 100.0, top: 8),
          physics: const BouncingScrollPhysics(),
          itemCount: _filteredCelebrities.length,
          itemBuilder: (context, index) {
            final celebrity = _filteredCelebrities[index];
            return AnimatedContainer(
              duration: Duration(milliseconds: 100 + (index * 50)),
              child: FutureBuilder<bool>(
                future: _isCelebrityFavorite(celebrity['name']!, celebrity['url']!),
                builder: (context, snapshot) {
                  final isFavorite = snapshot.data ?? false;
                  return _CelebrityCard(
                    celebrity: celebrity,
                    isFavorite: isFavorite,
                    theme: theme,
                    imageCache: _imageCache,
                    onTap: () => Navigator.push(
                      context,
                      _createPageRoute(
                        GalleryLinksPage(
                          celebrityName: celebrity['name']!,
                          profileUrl: celebrity['url']!,
                          onDownloadSelected: widget.onDownloadSelected,
                        ),
                      ),
                    ),
                    onFavoriteToggle: () => _toggleCelebrityFavorite(
                      celebrity['name']!,
                      celebrity['url']!,
                    ),
                    onDownloadPress: () => _handleDownloadPress(celebrity['name']!),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CelebrityCard extends StatelessWidget {
  final Map<String, String> celebrity;
  final bool isFavorite;
  final ThemeData theme;
  final CelebrityImageCache imageCache;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDownloadPress;

  const _CelebrityCard({
    required this.celebrity,
    required this.isFavorite,
    required this.theme,
    required this.imageCache,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onDownloadPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isFavorite ? color.primaryContainer.withOpacity(0.3) : color
            .surface,
        elevation: isFavorite ? 4 : 1,
        shadowColor: isFavorite ? color.primary.withOpacity(0.2) : color.shadow
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isFavorite ? Border.all(
                  color: color.primary.withOpacity(0.2)) : null,
            ),
            child: Row(
              children: [
                // Celebrity avatar with image
                _buildCelebrityAvatar(color),

                const SizedBox(width: 16),

                // Celebrity name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        celebrity['name'] ?? 'Unknown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (isFavorite)
                        Row(
                          children: [
                            Icon(Icons.star_rounded, size: 14,
                                color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              'Favorite',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Favorite button
                    Container(
                      decoration: BoxDecoration(
                        color: isFavorite
                            ? Colors.amber.withOpacity(0.1)
                            : color.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.star_rounded : Icons
                              .star_border_rounded,
                          color: isFavorite ? Colors.amber : color
                              .onSurfaceVariant,
                          size: 20,
                        ),
                        onPressed: onFavoriteToggle,
                        tooltip: isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Download button (commented out as per original)
                    Container(
                      decoration: BoxDecoration(
                        color: color.primaryContainer.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrityAvatar(ColorScheme color) {
    final profileUrl = celebrity['url'];

    if (profileUrl == null || profileUrl.isEmpty) {
      return _buildPlaceholderAvatar(color);
    }

    return FutureBuilder<String?>(
      future: imageCache.getImageUrl(profileUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show shimmer loading effect
          return _buildShimmerAvatar(color);
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildPlaceholderAvatar(color);
        }

        // Display cached network image
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: snapshot.data!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildShimmerAvatar(color),
            errorWidget: (context, url, error) =>
                _buildPlaceholderAvatar(color),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderAvatar(ColorScheme color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.primary.withOpacity(0.1),
            color.primary.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.person_rounded,
        color: color.primary,
        size: 28,
      ),
    );
  }

  Widget _buildShimmerAvatar(ColorScheme color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
                color.primary.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }
}