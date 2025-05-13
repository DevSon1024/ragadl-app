import 'package:flutter/material.dart';
import '../pages/celebrity_list_page.dart';

class NavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final DownloadSelectedCallback? onDownloadSelected;

  const NavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onDownloadSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Theme.of(context).primaryColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, 0, Icons.home, 'Home'),
          _buildNavItem(context, 1, Icons.person, 'Celebrity'),
          const SizedBox(width: 48),
          _buildNavItem(context, 3, Icons.download, 'Downloads'),
          _buildNavItem(context, 4, Icons.history, 'History'),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final bool isSelected = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
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

class NavigationFAB extends StatelessWidget {
  final bool isDownloaderSelected;
  final VoidCallback onPressed;

  const NavigationFAB({
    super.key,
    required this.isDownloaderSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: isDownloaderSelected
          ? Theme.of(context).colorScheme.secondary
          : Theme.of(context).primaryColor,
      onPressed: onPressed,
      child: const Icon(Icons.add),
    );
  }
}

class CelebrityNavItem {
  final String name;
  final String url;

  CelebrityNavItem({required this.name, required this.url});
}

// Main navigation wrapper
class MainNavigationWrapper extends StatefulWidget {
  final List<Widget> screens;
  final DownloadSelectedCallback? onDownloadSelected;

  const MainNavigationWrapper({
    super.key,
    required this.screens,
    this.onDownloadSelected,
  });

  @override
  _MainNavigationWrapperState createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _changePage(int index) {
    setState(() {
      _currentIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: widget.screens,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: NavigationBar(
        currentIndex: _currentIndex,
        onTap: _changePage,
        onDownloadSelected: widget.onDownloadSelected,
      ),
      floatingActionButton: NavigationFAB(
        isDownloaderSelected: _currentIndex == 2,
        onPressed: () => _changePage(2),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}