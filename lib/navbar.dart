import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ragalahari_downloader.dart';
import 'history_page.dart';
import 'download_manager_page.dart';
import 'celebrity_list_page.dart';

class MainNavigationScreen extends StatefulWidget {
  final String? initialUrl;
  final String? initialFolder;
  final String? galleryTitle;

  const MainNavigationScreen({
    Key? key,
    this.initialUrl,
    this.initialFolder,
    this.galleryTitle,
  }) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late List<Widget> _pages;
  final PageController _pageController = PageController();
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    // Initialize pages with the correct parameters
    _updatePages();
  }

  void _updatePages() {
    _pages = [
      RagalahariDownloader(
        initialUrl: widget.initialUrl,
        initialFolder: widget.initialFolder,
        galleryTitle: widget.galleryTitle,
      ),
      const CelebrityListPage(
        onDownloadSelected: null, // We'll handle this in the build method
      ),
      const DownloadsPage(),
      const HistoryPage(),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Handle back button presses throughout the app
  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      // If not on home page, navigate to home page
      setState(() {
        _currentIndex = 0;
        _pageController.jumpToPage(0);
      });
      return false;
    } else {
      // If on home page, exit immediately
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Use directly created widgets to ensure proper parameter passing
            RagalahariDownloader(
              initialUrl: widget.initialUrl,
              initialFolder: widget.initialFolder,
              galleryTitle: widget.galleryTitle,
            ),
            CelebrityListPage(
              onDownloadSelected: (url, folder, title) {
                // Navigate to downloader page with params
                setState(() {
                  _currentIndex = 0;
                  _pageController.jumpToPage(0);
                });
                // Use delayed navigation to ensure proper state update
                Future.delayed(Duration.zero, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MainNavigationScreen(
                        initialUrl: url,
                        initialFolder: folder,
                        galleryTitle: title,
                      ),
                    ),
                  );
                });
              },
            ),
            const DownloadsPage(),
            const HistoryPage(),
          ],
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20.0),
              topRight: Radius.circular(20.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
                _pageController.jumpToPage(index);
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Celebrity',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.download),
                label: 'Downloads',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'History',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Unchanged DownloadsPage
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Active Downloads',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DownloadManagerPage(),
                  ),
                );
              },
              child: const Text('View Active Downloads'),
            ),
            const SizedBox(height: 16),
            const Text(
              'No active downloads',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}