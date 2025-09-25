import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/ragalahari_downloader.dart';
import 'pages/history/history_page.dart';
import 'pages/download_manager_page.dart';
import 'pages/celebrity/celebrity_list_page.dart';
import 'settings_page.dart';
import 'widgets/theme_config.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'permissions.dart';
import 'home_page.dart';

import 'dart:io' show Platform;

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