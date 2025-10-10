import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ragalahari_downloader_page.dart';

class LinkHistoryItem {
  final String url;
  final String celebrityName;
  final String? galleryTitle;
  final DateTime timestamp;

  LinkHistoryItem({
    required this.url,
    required this.celebrityName,
    this.galleryTitle,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'celebrityName': celebrityName,
    'galleryTitle': galleryTitle,
    'timestamp': timestamp.toIso8601String(),
  };

  factory LinkHistoryItem.fromJson(Map<String, dynamic> json) =>
      LinkHistoryItem(
        url: json['url'],
        celebrityName: json['celebrityName'],
        galleryTitle: json['galleryTitle'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

enum HistorySortOption { newestFirst, oldestFirst }

class LinkHistoryPage extends StatefulWidget {
  const LinkHistoryPage({super.key});

  @override
  State<LinkHistoryPage> createState() => _LinkHistoryPageState();
}

class _LinkHistoryPageState extends State<LinkHistoryPage>
    with TickerProviderStateMixin {
  List<LinkHistoryItem> _history = [];
  List<LinkHistoryItem> _filteredHistory = [];
  HistorySortOption _currentSortOption = HistorySortOption.newestFirst;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadHistory();
    _searchController.addListener(_filterHistory);
  }

  void _initializeAnimations() {
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
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      const historyKey = 'link_history';
      final historyJson = prefs.getStringList(historyKey) ?? [];

      if (mounted) {
        setState(() {
          _history = historyJson
              .map((json) => LinkHistoryItem.fromJson(jsonDecode(json)))
              .toList();
          _filteredHistory = List.from(_history);
          _isLoading = false;
          _sortHistory();
        });

        _fadeController.forward();
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) _slideController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showModernSnackBar('Error loading history: $e', Icons.error_rounded, true);
      }
    }
  }

  Future<void> _removeHistoryItem(LinkHistoryItem item) async {
    // Show confirmation dialog first
    final confirmed = await _showDeleteConfirmation(item);
    if (!confirmed) return;

    HapticFeedback.mediumImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      const historyKey = 'link_history';
      List<String> historyJson = prefs.getStringList(historyKey) ?? [];
      List<LinkHistoryItem> history = historyJson
          .map((json) => LinkHistoryItem.fromJson(jsonDecode(json)))
          .toList();

      history.removeWhere((h) =>
      h.url == item.url &&
          h.celebrityName == item.celebrityName &&
          h.timestamp == item.timestamp);

      await prefs.setStringList(
          historyKey, history.map((h) => jsonEncode(h.toJson())).toList());

      if (mounted) {
        setState(() {
          _history = history;
          _filteredHistory = List.from(_history);
          _sortHistory();
        });

        _showModernSnackBar(
          'Link removed from history',
          Icons.delete_outline_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        _showModernSnackBar(
          'Failed to remove link: $e',
          Icons.error_rounded,
          true,
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation(LinkHistoryItem item) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove from History',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to remove this link?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.celebrityName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (item.galleryTitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.galleryTitle!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _showModernSnackBar(String message, IconData icon, [bool isError = false]) {
    if (!mounted) return;
    final color = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              color: isError ? color.onError : color.onInverseSurface,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? color.error : color.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(milliseconds: isError ? 4000 : 2500),
      ),
    );
  }

  String _truncateUrl(String url) {
    final RegExp regex = RegExp(r'/\d+/');
    final match = regex.firstMatch(url);
    if (match != null) {
      return url.substring(0, match.end) + '...';
    }
    return url.length > 50 ? url.substring(0, 50) + '...' : url;
  }

  String? _extractGalleryId(String url) {
    final RegExp regex = RegExp(r'/(\d+)/');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      final hours = dateTime.hour;
      final minutes = dateTime.minute;
      final period = hours >= 12 ? 'PM' : 'AM';
      final displayHour = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
      return 'Today at $displayHour:${minutes.toString().padLeft(2, '0')} $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _sortHistory() {
    setState(() {
      _filteredHistory = List.from(_history);
      final query = _searchController.text.toLowerCase();

      if (query.isNotEmpty) {
        _filteredHistory = _filteredHistory
            .where((item) =>
        item.celebrityName.toLowerCase().contains(query) ||
            (item.galleryTitle?.toLowerCase().contains(query) ?? false) ||
            (_extractGalleryId(item.url)?.contains(query) ?? false))
            .toList();
      }

      switch (_currentSortOption) {
        case HistorySortOption.newestFirst:
          _filteredHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          break;
        case HistorySortOption.oldestFirst:
          _filteredHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          break;
      }
    });
  }

  void _filterHistory() {
    _sortHistory();
    HapticFeedback.selectionClick();
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear All History',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to clear all link history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('link_history');
      setState(() {
        _history.clear();
        _filteredHistory.clear();
      });
      _showModernSnackBar('All history cleared', Icons.clear_all_rounded);
    }
  }

  PageRoute _createModernPageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.03);
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
        'Link History',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: color.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: PopupMenuButton<HistorySortOption>(
            icon: Icon(Icons.sort_rounded, color: color.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (HistorySortOption newValue) {
              setState(() {
                _currentSortOption = newValue;
                _sortHistory();
              });
              HapticFeedback.selectionClick();
            },
            itemBuilder: (BuildContext context) => [
              _buildPopupMenuItem(
                HistorySortOption.newestFirst,
                'Newest First',
                Icons.arrow_downward_rounded,
                color,
                theme,
              ),
              _buildPopupMenuItem(
                HistorySortOption.oldestFirst,
                'Oldest First',
                Icons.arrow_upward_rounded,
                color,
                theme,
              ),
            ],
          ),
        ),
        if (_history.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.clear_all_rounded, color: color.error),
              onPressed: _clearAllHistory,
              tooltip: 'Clear All History',
            ),
          ),
      ],
    );
  }

  PopupMenuItem<HistorySortOption> _buildPopupMenuItem(
      HistorySortOption option,
      String title,
      IconData icon,
      ColorScheme color,
      ThemeData theme,
      ) {
    final isSelected = _currentSortOption == option;

    return PopupMenuItem<HistorySortOption>(
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
          decoration: InputDecoration(
            hintText: 'Search by name, title, or gallery ID...',
            hintStyle: TextStyle(color: color.onSurfaceVariant),
            prefixIcon: Icon(Icons.search_rounded, color: color.onSurfaceVariant),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
              icon: Icon(Icons.clear_rounded, color: color.onSurfaceVariant),
              onPressed: () {
                _searchController.clear();
                _filterHistory();
                HapticFeedback.lightImpact();
              },
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (value) {
            setState(() {});
            _filterHistory();
          },
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme color) {
    if (_isLoading) {
      return _buildLoadingState(color);
    }

    if (_filteredHistory.isEmpty) {
      return _buildEmptyState(theme, color);
    }

    return _buildHistoryList(theme, color);
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
            'Loading history...',
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
              child: Icon(
                _searchController.text.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.history_rounded,
                size: 64,
                color: color.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No matching history found'
                  : 'No link history yet',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try adjusting your search terms.'
                  : 'Visit gallery pages to build your history.',
              style: theme.textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme, ColorScheme color) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RefreshIndicator(
          onRefresh: _loadHistory,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 100, top: 8),
            physics: const BouncingScrollPhysics(),
            itemCount: _filteredHistory.length,
            itemBuilder: (context, index) {
              final item = _filteredHistory[index];
              return AnimatedContainer(
                duration: Duration(milliseconds: 100 + (index * 50)),
                child: _HistoryCard(
                  item: item,
                  theme: theme,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      _createModernPageRoute(
                        RagalahariDownloader(
                          initialUrl: item.url,
                          initialFolder: item.celebrityName,
                          galleryTitle: item.galleryTitle,
                        ),
                      ),
                    );
                  },
                  onDelete: () => _removeHistoryItem(item),
                  formatDateTime: _formatDateTime,
                  extractGalleryId: _extractGalleryId,
                  truncateUrl: _truncateUrl,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final LinkHistoryItem item;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDateTime;
  final String? Function(String) extractGalleryId;
  final String Function(String) truncateUrl;

  const _HistoryCard({
    required this.item,
    required this.theme,
    required this.onTap,
    required this.onDelete,
    required this.formatDateTime,
    required this.extractGalleryId,
    required this.truncateUrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = theme.colorScheme;
    final galleryId = extractGalleryId(item.url);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: color.surface,
        elevation: 1,
        shadowColor: color.shadow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon container
                Container(
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
                    Icons.link_rounded,
                    color: color.primary,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.galleryTitle ?? truncateUrl(item.url),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.primaryContainer.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.celebrityName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: color.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (galleryId != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.surfaceVariant.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ID: $galleryId',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: color.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDateTime(item.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Container(
                  decoration: BoxDecoration(
                    color: color.errorContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: color.error, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Remove from history',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}