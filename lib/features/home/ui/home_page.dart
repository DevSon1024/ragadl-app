import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../celebrity/ui/latest_actor_and_actress.dart';
import '../../celebrity/ui/latest_celebrity.dart';
import '../../downloader/ui/download_manager_page.dart';
import '../../downloader/ui/link_history_page.dart';
import '../../settings/ui/favourite_page.dart';

class HomePage extends StatefulWidget {
  final Function({String? url, String? folder, String? title}) onDownloadSelected;
  final VoidCallback openSettings;

  const HomePage({
    super.key,
    required this.onDownloadSelected,
    required this.openSettings,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Keep the same sections but present them with a more modern UI.
  List<Map<String, dynamic>> sections = [
    {
      'title': 'Latest All Celebrities',
      'icon': Icons.star_rounded,
      'page': const LatestCelebrityPage()
    },
    {'title': 'Favorites', 'icon': Icons.favorite_rounded, 'page': const FavouritePage()},
    {'title': 'Latest Actors', 'icon': Icons.person_rounded, 'page': const ActorPage()},
    {'title': 'Latest Actress', 'icon': Icons.person_outline_rounded, 'page': const ActressPage()},
  ];

  @override
  void initState() {
    super.initState();
    _loadSectionOrder();
  }

  Future<void> _loadSectionOrder() async {
    // Loading a saved order if present to respect existing behavior.
    try {
      final prefs = await SharedPreferences.getInstance();
      final order = prefs.getStringList('section_order');
      if (order != null && order.length == sections.length) {
        final reordered = <Map<String, dynamic>>[];
        for (final title in order) {
          final section = sections.firstWhere((s) => s['title'] == title, orElse: () => sections.first);
          reordered.add(section);
        }
        if (mounted) {
          setState(() => sections = reordered);
        }
      }
    } catch (_) {
      // Ignore ordering errors to keep UI resilient.
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(_ModernPageRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: color.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Ragalahari Downloader',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Link History',
            icon: Icon(Icons.history_rounded, color: color.onSurface),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkHistoryPage()));
              FocusScope.of(context).unfocus();
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_rounded, color: color.onSurface),
            onPressed: widget.openSettings,
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.primaryContainer.withOpacity(0.25),
              color.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: true,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildHeroHeader(context),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildQuickActions(context),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Explore',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              // Sections grid/list
              ...sections.map((section) => _SectionCard(
                title: section['title'] as String,
                icon: section['icon'] as IconData,
                onTap: () => _openPage(section['page'] as Widget),
              )),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.primary.withOpacity(0.90),
              color.primary.withOpacity(0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.primary.withOpacity(0.25),
              blurRadius: 18,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Subtle decorative overlay dots
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.onPrimary.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              left: -16,
              bottom: -16,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.onPrimary.withOpacity(0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (Platform.isWindows)
                    GestureDetector(
                      onPanStart: (_) => windowManager.startDragging(),
                      child: Container(
                        height: 32,
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: Text(
                          'Drag here to move window',
                          style: TextStyle(color: color.onPrimary.withOpacity(0.7)),
                        ),
                      ),
                    ),
                  Text(
                    'Welcome to Ragalahari Downloader',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color.onPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse celebrities, actors, and more—then jump into downloads anytime.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color.onPrimary.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HeroChip(
                        icon: Icons.file_download_rounded,
                        label: 'Download Manager',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DownloadManagerPage()),
                          );
                        },
                        foreground: color.onPrimary,
                        background: color.onPrimary.withOpacity(0.10),
                      ),
                      _HeroChip(
                        icon: Icons.history_rounded,
                        label: 'Link History',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LinkHistoryPage()),
                          );
                        },
                        foreground: color.onPrimary,
                        background: color.onPrimary.withOpacity(0.10),
                      ),
                      _HeroChip(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        onTap: widget.openSettings,
                        foreground: color.onPrimary,
                        background: color.onPrimary.withOpacity(0.10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return _Glass(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.lightbulb_rounded, color: color.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tip: Use Link History to quickly re‑open recent downloads.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LinkHistoryPage()),
                );
              },
              icon: const Icon(Icons.history_rounded),
              label: const Text('Open'),
            )
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: color.surface,
        elevation: 2,
        shadowColor: color.shadow.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.primary.withOpacity(0.12),
                        color.primary.withOpacity(0.22),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, color: color.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color foreground;
  final Color background;

  const _HeroChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      elevation: 0,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;

  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.outline.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: color.shadow.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: child,
    );
  }
}

class _ModernPageRoute extends PageRouteBuilder {
  _ModernPageRoute(Widget page)
      : super(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

// Image viewer remains available as in the original file with minor polish options if desired.
class FullImagePage extends StatefulWidget {
  final String imageUrl;
  const FullImagePage({super.key, required this.imageUrl});

  @override
  State<FullImagePage> createState() => _FullImagePageState();
}

class _FullImagePageState extends State<FullImagePage> {
  bool _isDownloading = false;

  Future<void> _downloadImage(String imageUrl) async {
    setState(() => _isDownloading = true);
    try {
      // Assuming a DownloadManager exists as in your project context.
      final downloadManager = DownloadManager();
      downloadManager.addDownload(
        url: imageUrl,
        folder: "SingleImages",
        subFolder: DateTime.now().toString().split(' ')[0],
        onProgress: (progress) {},
        onComplete: (success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Added to download manager' : 'Failed to add download'),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Image'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Copy URL',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.imageUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image URL copied to clipboard')),
              );
            },
          ),
          IconButton(
            tooltip: 'Download',
            icon: _isDownloading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded),
            onPressed: _isDownloading ? null : () => _downloadImage(widget.imageUrl),
          ),
        ],
      ),
      body: Container(
        color: color.surface,
        child: InteractiveViewer(
          minScale: 0.1,
          maxScale: 4.0,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        ),
      ),
    );
  }
}

// Stub for DownloadManager to satisfy analyzer if not in scope here.
// Remove this if your project already has the class imported properly.
class DownloadManager {
  void addDownload({
    required String url,
    required String folder,
    required String subFolder,
    required void Function(double) onProgress,
    required void Function(bool) onComplete,
  }) {
    // Implemented in your project.
  }
}