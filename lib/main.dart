import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/downloader/ui/pages/ragadl_page.dart';
import 'features/history/ui/history_page.dart';
import 'features/download_manager/download_manager_page.dart';
import 'features/settings/ui/settings_page.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'core/permissions.dart';
import 'core/services/notification_controller.dart';
import 'shared/widgets/theme_notifier.dart';
import 'features/settings/logic/settings_service.dart';
import 'features/settings/logic/terms_acceptance_provider.dart';
import 'features/settings/ui/terms_of_use_dialog.dart';

final themeNotifierProvider = ChangeNotifierProvider<ThemeNotifier>((ref) {
  return ThemeNotifier();
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Increase ImageCache size
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      500 * 1024 * 1024; // 500 MB
  PaintingBinding.instance.imageCache.maximumSize = 2000; // 2000 images

  await AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'download_channel',
      channelName: 'Download Notifications',
      channelDescription: 'Notifications for download status',
      defaultColor: Colors.green,
      ledColor: Colors.white,
      importance: NotificationImportance.High,
      channelShowBadge: true,
    ),
  ], debug: true);

  AwesomeNotifications().setListeners(
    onActionReceivedMethod: NotificationController.onActionReceivedMethod,
  );

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowManager.instance.setMinimumSize(const Size(800, 600));
    WindowManager.instance.setTitle('RagaDL');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.watch(themeNotifierProvider);
    final settings = ref.watch(settingsServiceProvider);
    return MaterialApp(
      title: 'RagaDL',
      theme: themeNotifier.getThemeData(),
      darkTheme: themeNotifier.getThemeData(isDark: true, amoledBlack: settings.amoledBlack),
      themeMode: themeNotifier.themeMode,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with TickerProviderStateMixin {
  bool _termsDialogShowing = false;
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _navAnimationController;
  late Animation<double> _navSlideAnimation;

  final List<NavigationItem> _navItems = [
    NavigationItem(
      icon: Icons.download_for_offline_outlined,
      activeIcon: Icons.download_for_offline_rounded,
      label: 'Downloader',
    ),
    NavigationItem(
      icon: Icons.download_outlined,
      activeIcon: Icons.download_rounded,
      label: 'Downloads',
    ),
    NavigationItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
      label: 'History',
    ),
    NavigationItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final termsState = ref.read(termsAcceptanceProvider);
      termsState.whenOrNull(
        data: (accepted) {
          if (accepted) {
            PermissionHandler.requestFirstRunPermissions(context);
          } else {
            _showTermsDialog();
          }
        },
      );
    });
  }

  void _showTermsDialog() {
    if (_termsDialogShowing) return;
    _termsDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: TermsOfUseDialog(
            onAccept: () async {
              await ref.read(termsAcceptanceProvider.notifier).acceptTerms();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
              _termsDialogShowing = false;
            },
          ),
        );
      },
    );
  }

  void _initializeControllers() {
    _pageController = PageController();

    _navAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _navSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _navAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Start navigation animation
    _navAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _navAnimationController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    if (_selectedIndex == index) return;

    // Haptic feedback for better UX
    HapticFeedback.lightImpact();

    setState(() {
      _selectedIndex = index;
    });

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }

    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(termsAcceptanceProvider, (previous, next) {
      next.whenOrNull(
        data: (accepted) {
          if (!accepted) {
            _showTermsDialog();
          } else {
            PermissionHandler.requestFirstRunPermissions(context);
          }
        },
      );
    });

    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          RagaDLPage(),
          DownloadManagerPage(),
          HistoryPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _navSlideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _navSlideAnimation.value) * 100),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 1),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 80,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildModernNavItem(0),
                        _buildModernNavItem(1),
                        _buildModernNavItem(2),
                        _buildModernNavItem(3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernNavItem(int index) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onNavItemTapped(index),
            borderRadius: BorderRadius.circular(16),
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.all(isSelected ? 8 : 6),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: isSelected ? 26 : 24,
                      color:
                          isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: isSelected ? 12 : 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color:
                          isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    child: Text(item.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
