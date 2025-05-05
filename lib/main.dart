import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pages/ragalahari_downloader.dart';
import 'pages/history_page.dart';
import 'pages/download_manager_page.dart';
import 'pages/celebrity_list_page.dart';
import 'pages/settings_sidebar.dart';
import 'theme_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeConfig(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfig>(
      builder: (context, themeConfig, child) => MaterialApp(
        title: 'Ragalahari Downloader',
        debugShowCheckedModeBanner: false,
        theme: ThemeConfig.lightTheme,
        darkTheme: ThemeConfig.darkTheme,
        themeMode: themeConfig.currentThemeMode,
        home: const MainScreen(),
      ),
    );
  }
}

// Rest of the main.dart remains unchanged
class MainScreen extends StatefulWidget {
  final String? initialUrl;
  final String? initialFolder;
  final String? galleryTitle;

  const MainScreen({
    Key? key,
    this.initialUrl,
    this.initialFolder,
    this.galleryTitle,
  }) : super(key: key);

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
      FocusScope.of(context).unfocus();
      print('Unfocused on app start');
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
        appBar: AppBar(
          title: const Text('Ragalahari Downloader'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
                FocusScope.of(context).unfocus();
              },
            ),
          ],
        ),
        endDrawer: const SettingsSidebar(),
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
            const HomePage(),
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
          notchMargin: 8.0,
          color: Theme.of(context).primaryColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home, 'Home'),
              _buildNavItem(1, Icons.person, 'Celebrity'),
              const SizedBox(width: 48),
              _buildNavItem(3, Icons.download, 'Downloads'),
              _buildNavItem(4, Icons.history, 'History'),
            ],
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
          child: const Icon(Icons.add),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

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
      Color color,
      ) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'Welcome to Ragalahari Downloader',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Browse celebrities or tap the + button to download images',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Follow Ragalahari on',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildSocialMediaItem(
                      context,
                      Icons.facebook,
                      'Facebook',
                      'https://www.facebook.com/ragalahari',
                      Colors.blue,
                    ),
                    _buildSocialMediaItem(
                      context,
                      Icons.alternate_email,
                      'Twitter',
                      'https://twitter.com/ragalahari',
                      Colors.lightBlue,
                    ),
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
    );
  }
}