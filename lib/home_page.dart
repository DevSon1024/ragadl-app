import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'pages/download_manager_page.dart';
import 'package:flutter/services.dart';
import 'pages/celebrity/latest_celebrity.dart';
import 'pages/celebrity/latest_actor_and_actress.dart';
import 'settings/favourite_page.dart';
import 'pages/link_history_page.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final Function({String? url, String? folder, String? title}) onDownloadSelected;
  final VoidCallback openSettings;

  const HomePage({
    super.key,
    required this.onDownloadSelected,
    required this.openSettings,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
   List<Map<String, dynamic>> sections = [
    {'title': 'Latest All Celebrities', 'icon': Icons.star, 'page': const LatestCelebrityPage()},
    {'title': 'Favorites', 'icon': Icons.favorite, 'page': const FavouritePage()},
    {'title': 'Latest Actors', 'icon': Icons.person, 'page': const ActorPage()},
    {'title': 'Latest Actress', 'icon': Icons.person_outline, 'page': const ActressPage()},
  ];

  @override
  void initState() {
    super.initState();
    _loadSectionOrder();
  }

  Future<void> _loadSectionOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final order = prefs.getStringList('section_order');
    if (order != null && order.length == sections.length) {
      List<Map<String, dynamic>> reordered = [];
      for (var title in order) {
        var section = sections.firstWhere((s) => s['title'] == title);
        reordered.add(section);
      }
      if (mounted) {
        setState(() {
          sections = reordered;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ragalahari Downloader',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(
              Icons.history,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LinkHistoryPage()),
              );
              FocusScope.of(context).unfocus();
            },
            tooltip: 'Link History',
          ),
          IconButton(
            icon: Icon(
              Icons.settings,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: widget.openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: sections.length + 2, // +2 for header and footer
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader();
          }
          if (index == sections.length + 1) {
            return _buildFooter();
          }
          final section = sections[index - 1];
          return Card(
            key: ValueKey(section['title']),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            surfaceTintColor: theme.colorScheme.surfaceTint,
            child: ListTile(
              leading: Icon(
                section['icon'],
                color: theme.colorScheme.primary,
              ),
              title: Text(section['title']),
              trailing: Platform.isWindows
                  ? null
                  : Icon(
                Icons.drag_handle,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => section['page']),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (Platform.isWindows)
            GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              child: Container(
                height: 40,
                color: Colors.transparent,
                child: const Center(
                  child: Text(
                    'Drag here to move window',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
          _buildProfileContainer('Welcome to Ragalahari Downloader!', null),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Follow Ragalahari on',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSocialMediaItem(
                context,
                Icons.facebook,
                'Facebook',
                'https://www.facebook.com/ragalahari',
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildSocialMediaItem(
                context,
                Icons.alternate_email,
                'Twitter',
                'https://twitter.com/ragalahari',
                Colors.lightBlue,
              ),
              const SizedBox(height: 12),
              _buildSocialMediaItem(
                context,
                Icons.camera_alt,
                'Instagram',
                'https://www.instagram.com/ragalahari',
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaItem(
      BuildContext context,
      IconData icon,
      String platform,
      String url,
      Color color) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              platform,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContainer(String message, String? imageUrl) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullImagePage(imageUrl: imageUrl),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: 200,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, error, stackTrace) => Container(),
                  ),
                ),
              ),
            if (imageUrl != null && imageUrl.isNotEmpty) const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FullImagePage extends StatefulWidget {
  final String imageUrl;

  const FullImagePage({super.key, required this.imageUrl});

  @override
  _FullImagePageState createState() => _FullImagePageState();
}

class _FullImagePageState extends State<FullImagePage> {
  bool _isDownloading = false;

  Future<void> _downloadImage(String imageUrl) async {
    setState(() => _isDownloading = true);
    try {
      final downloadManager = DownloadManager();
      downloadManager.addDownload(
        url: imageUrl,
        folder: "SingleImages",
        subFolder: DateTime.now().toString().split(' ')[0],
        onProgress: (progress) {},
        onComplete: (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(success
                    ? 'Added to download manager'
                    : 'Failed to add download')));
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to download: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Image'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.imageUrl));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Image URL copied to clipboard')));
            },
          ),
          IconButton(
            icon: _isDownloading
                ? const CircularProgressIndicator()
                : const Icon(Icons.download),
            onPressed: _isDownloading
                ? null
                : () => _downloadImage(widget.imageUrl),
          ),
        ],
      ),
      body: InteractiveViewer(
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
    );
  }
}