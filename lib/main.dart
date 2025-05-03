import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/ragalahari_downloader.dart';
import 'pages/history_page.dart';
import 'pages/download_manager_page.dart';
import 'pages/celebrity_list_page.dart';
import 'pages/settings_sidebar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ragalahari Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: Colors.green,
        brightness: Brightness.light,
        cardTheme: const CardTheme(
          elevation: 4,
          margin: EdgeInsets.all(8),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: Colors.green,
        brightness: Brightness.dark,
        cardTheme: const CardTheme(
          elevation: 4,
          margin: EdgeInsets.all(8),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
    );
  }
}

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

  // Using PageController for smooth transitions between pages
  final PageController _pageController = PageController();

  // Controllers to pass around the app
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();

  // Track navigation state
  String? currentUrl;
  String? currentFolder;
  String? currentGalleryTitle;

  @override
  void initState() {
    super.initState();
    // Initialize with any provided navigation parameters
    currentUrl = widget.initialUrl;
    currentFolder = widget.initialFolder;
    currentGalleryTitle = widget.galleryTitle;

    // Initialize folder controller if provided
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

  // Handle back button presses
  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      // If not on home page, navigate to home page
      setState(() {
        _selectedIndex = 0;
        _pageController.jumpToPage(0);
        FocusScope.of(context).unfocus();
      });
      return false;
    } else {
      // If on home page, ask to exit
      return _showExitConfirmationDialog();
    }
  }

  // Exit confirmation dialog
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

  // Handle navigation to the downloader page with parameters
  void _navigateToDownloader({String? url, String? folder, String? title}) {
    setState(() {
      currentUrl = url;
      currentFolder = folder;
      currentGalleryTitle = title;
      _selectedIndex = 2; // Index of the downloader page
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
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
                FocusScope.of(context).unfocus(); // Unfocus when opening settings
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
              // Home button
              _buildNavItem(0, Icons.home, 'Home'),
              // Celebrity button
              _buildNavItem(1, Icons.person, 'Celebrity'),
              // Empty space for FAB
              const SizedBox(width: 48),
              // Downloads button
              _buildNavItem(3, Icons.download, 'Downloads'),
              // History button
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

// Home page - Initially blank as requested
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

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
        ],
      ),
    );
  }
}