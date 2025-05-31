import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'pages/ragalahari_downloader.dart';
import 'pages/history/history_page.dart';
import 'pages/download_manager_page.dart';
import 'pages/celebrity/celebrity_list_page.dart';
import 'settings_page.dart'; // Updated import
import 'pages/celebrity/latest_celebrity.dart';
import 'pages/celebrity/latest_actor_and_actress.dart';
import 'settings/favourite_page.dart';
import 'pages/link_history_page.dart';
import 'widgets/theme_config.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'permissions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'download_channel',
        channelName: 'Download Notifications',
        channelDescription: 'Notifications for download status',
        defaultColor: Colors.green,
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
      ),
    ],
    debug: true,
  );

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowManager.instance.setMinimumSize(const Size(800, 600));
    WindowManager.instance.setTitle('Ragalahari Downloader');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeConfig(),
      child: const MyApp(),
    ),
  );
}

class ImageData {
  final String thumbnailUrl;
  final String originalUrl;

  ImageData({required this.thumbnailUrl, required this.originalUrl});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfig>(
      builder: (context, themeConfig, child) => MaterialApp(
        title: 'Ragalahari Downloader',
        debugShowCheckedModeBanner: false,
        theme: themeConfig.lightTheme.copyWith(
          appBarTheme: AppBarTheme(
            backgroundColor: themeConfig.lightTheme.colorScheme.surface,
            surfaceTintColor: themeConfig.lightTheme.colorScheme.surfaceTint,
            elevation: 2,
          ),
          scaffoldBackgroundColor: themeConfig.lightTheme.colorScheme.surface,
        ),
        darkTheme: themeConfig.darkTheme.copyWith(
          appBarTheme: AppBarTheme(
            backgroundColor: themeConfig.darkTheme.colorScheme.surface,
            surfaceTintColor: themeConfig.darkTheme.colorScheme.surfaceTint,
            elevation: 2,
          ),
          scaffoldBackgroundColor: themeConfig.darkTheme.colorScheme.surface,
        ),
        themeMode: themeConfig.currentThemeMode,
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String? initialUrl;
  final String? initialFolder;
  final String? galleryTitle;

  const MainScreen({
    super.key,
    this.initialUrl,
    this.initialFolder,
    this.galleryTitle,
  });

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageController _pageController = PageController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();
  String? currentUrl;
  String? currentFolder;
  String? currentGalleryTitle;

  @override
  void initState() {
    super.initState();
    currentUrl = widget.initialUrl;
    currentFolder = widget.initialFolder;
    currentGalleryTitle = widget.galleryTitle;
    if (widget.initialFolder != null) {
      _folderController.text = widget.initialFolder!;
      if (widget.galleryTitle != null) {
        _folderController.text += "/${widget.galleryTitle!.replaceAll("-", " ")}";
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionHandler.requestFirstRunPermissions(context);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _urlController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
        _pageController.jumpToPage(0);
        FocusScope.of(context).unfocus();
      });
      return false;
    } else {
      return _showExitConfirmationDialog();
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Do you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _navigateToDownloader({String? url, String? folder, String? title}) {
    setState(() {
      currentUrl = url;
      currentFolder = folder;
      currentGalleryTitle = title;
      _selectedIndex = 2;
      _pageController.jumpToPage(2);
      FocusScope.of(context).unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        extendBody: true,
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
              FocusScope.of(context).unfocus();
            });
          },
          children: [
            HomePage(
              onDownloadSelected: _navigateToDownloader,
              openSettings: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
                FocusScope.of(context).unfocus();
              },
            ),
            CelebrityListPage(
              onDownloadSelected: (url, folder, title) {
                _navigateToDownloader(url: url, folder: folder, title: title);
              },
            ),
            RagalahariDownloader(
              initialUrl: currentUrl,
              initialFolder: currentFolder,
              galleryTitle: currentGalleryTitle,
            ),
            const DownloadManagerPage(),
            const HistoryPage(),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 10.0,
          color: Theme.of(context).primaryColor,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 56.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home, Icons.home_outlined, 'Home'),
                _buildNavItem(1, Icons.person, Icons.person_outlined, 'Celebrity'),
                const SizedBox(width: 40),
                _buildNavItem(3, Icons.download, Icons.download_outlined, 'Downloads'),
                _buildNavItem(4, Icons.history, Icons.history_outlined, 'History'),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: _selectedIndex == 2
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).primaryColor,
          onPressed: () {
            setState(() {
              _selectedIndex = 2;
              _pageController.jumpToPage(2);
              FocusScope.of(context).unfocus();
            });
          },
          shape: const CircleBorder(),
          elevation: 4,
          child: Icon(
            Icons.download_for_offline_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 50.0,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildNavItem(int index, IconData filledIcon, IconData outlinedIcon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _pageController.jumpToPage(index);
            FocusScope.of(context).unfocus();
          });
        },
        borderRadius: BorderRadius.circular(50),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlinedIcon,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              size: 28,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    {'title': 'Actors', 'icon': Icons.person, 'page': const ActorPage()},
    {'title': 'Actress', 'icon': Icons.person_outline, 'page': const ActressPage()},
  ];

  String _websiteStatus = 'Checking...';
  Color _statusColor = Colors.grey;
  int? _statusCode;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadSectionOrder();
    _checkWebsiteStatus();
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
      setState(() {
        sections = reordered;
      });
    }
  }

  Future<void> _saveSectionOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final order = sections.map((s) => s['title'] as String).toList();
    await prefs.setStringList('section_order', order);
  }

  Future<void> _checkWebsiteStatus() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _websiteStatus = 'Checking...';
      _statusColor = Colors.grey;
    });

    try {
      final response = await http.get(Uri.parse('https://www.ragalahari.com/')).timeout(const Duration(seconds: 5));
      setState(() {
        _statusCode = response.statusCode;
        switch (_statusCode) {
          case 200:
            _websiteStatus = 'Website is Online';
            _statusColor = Colors.green;
            break;
          case 404:
            _websiteStatus = 'Page Not Found (404)';
            _statusColor = Colors.red;
            break;
          case 502:
            _websiteStatus = 'Bad Gateway (502)';
            _statusColor = Colors.red;
            break;
          case 410:
            _websiteStatus = 'Gone (410)';
            _statusColor = Colors.red;
            break;
          default:
            _websiteStatus = 'Error (Code: ${_statusCode})';
            _statusColor = Colors.red;
        }
      });
    } catch (e) {
      setState(() {
        _websiteStatus = 'Failed to Connect';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80.0),
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      surfaceTintColor: theme.colorScheme.surfaceTint,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _statusCode == 200 ? Icons.check_circle : Icons.error,
                              color: _statusColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _websiteStatus,
                                style: TextStyle(
                                  color: _statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _isChecking ? null : _checkWebsiteStatus,
                              child: Icon(
                                Icons.refresh,
                                color: _isChecking
                                    ? Colors.grey
                                    : theme.colorScheme.primary,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final section = sections.removeAt(oldIndex);
                    sections.insert(newIndex, section);
                    _saveSectionOrder();
                  });
                },
                proxyDecorator: (child, index, animation) {
                  return Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: child,
                    ),
                  );
                },
                children: sections.map((section) {
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
                      onLongPress: Platform.isWindows
                          ? () {
                        setState(() {});
                      }
                          : null,
                    ),
                  );
                }).toList(),
              ),
              Container(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}