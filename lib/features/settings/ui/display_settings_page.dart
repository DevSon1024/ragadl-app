import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ragadl/shared/widgets/theme_config.dart';
import '../../../main.dart';
import '../logic/settings_service.dart';

class DisplaySettingsPage extends ConsumerWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.watch(themeNotifierProvider);
    final settings = ref.watch(settingsServiceProvider);
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Live Preview Mockup Section
          Text(
            'Live Preview',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color.primary,
            ),
          ),
          const SizedBox(height: 12),
          _ThemePreview(
            themeMode: themeNotifier.themeMode,
            primaryColor: themeNotifier.primaryColor,
            amoledBlack: settings.amoledBlack,
            gridColumns: settings.gridColumns,
          ),
          const SizedBox(height: 28),

          // Theme Mode Section
          Text(
            'Theme Mode',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color.primary,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.phone_android_rounded),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_rounded),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_rounded),
              ),
            ],
            selected: <ThemeMode>{themeNotifier.themeMode},
            onSelectionChanged: (Set<ThemeMode> newSelection) {
              ref.read(themeNotifierProvider.notifier).setThemeMode(newSelection.first);
            },
            showSelectedIcon: false,
          ),

          // AMOLED Switch Tile (Visible only when dark mode is active or system is dark)
          if (themeNotifier.themeMode == ThemeMode.dark ||
              (themeNotifier.themeMode == ThemeMode.system &&
                  MediaQuery.of(context).platformBrightness == Brightness.dark)) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text(
                  'AMOLED Black Theme',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Uses pure black backgrounds in dark mode to save OLED battery.',
                  style: TextStyle(fontSize: 12),
                ),
                value: settings.amoledBlack,
                onChanged: (val) {
                  ref.read(settingsServiceProvider.notifier).setAmoledBlack(val);
                },
              ),
            ),
          ],
          
          const SizedBox(height: 28),

          // Grid Columns Section
          Text(
            'Grid Column Count',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the number of image columns displayed in the downloader grid.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(
                value: 2,
                label: Text('2 Columns'),
                icon: Icon(Icons.grid_view_rounded),
              ),
              ButtonSegment<int>(
                value: 3,
                label: Text('3 Columns'),
                icon: Icon(Icons.grid_on_rounded),
              ),
              ButtonSegment<int>(
                value: 4,
                label: Text('4 Columns'),
                icon: Icon(Icons.apps_rounded),
              ),
            ],
            selected: <int>{settings.gridColumns},
            onSelectionChanged: (Set<int> newSelection) {
              ref.read(settingsServiceProvider.notifier).setGridColumns(newSelection.first);
            },
            showSelectedIcon: false,
          ),
          
          const SizedBox(height: 28),

          // Accent Color Section
          Text(
            'Accent Color',
            style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Personalize the app colors with one of our curated palettes',
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: color.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: ThemeConfig.colorPalettes.length,
            itemBuilder: (context, index) {
              final paletteColor = ThemeConfig.colorPalettes[index];
              final isSelected = themeNotifier.primaryColor.toARGB32() == paletteColor.toARGB32();
              final iconColor = paletteColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

              // Generate a preview Scheme from seed on the fly to show secondary colors
              final dynamicScheme = ColorScheme.fromSeed(
                seedColor: paletteColor,
                brightness: Theme.of(context).brightness,
              );

              return GestureDetector(
                onTap: () {
                  ref.read(themeNotifierProvider.notifier).setPrimaryColor(paletteColor);
                },
                child: AnimatedScale(
                  scale: isSelected ? 1.02 : 0.98,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                            ? paletteColor 
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                        width: isSelected ? 2.5 : 1,
                      ),
                      color: isSelected
                          ? paletteColor.withValues(alpha: 0.04)
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        // Main circle
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: paletteColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: paletteColor.withValues(alpha: 0.3),
                                blurRadius: isSelected ? 8 : 2,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: iconColor,
                                  size: 18,
                                )
                              : null,
                        ),
                        const Spacer(),
                        // Color Name
                        Text(
                          _getColorName(paletteColor),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? paletteColor : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Dynamic Palette mini-bars
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8).copyWith(bottom: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(height: 6, color: dynamicScheme.primary),
                                ),
                                Expanded(
                                  child: Container(height: 6, color: dynamicScheme.primaryContainer),
                                ),
                                Expanded(
                                  child: Container(height: 6, color: dynamicScheme.secondary),
                                ),
                                Expanded(
                                  child: Container(height: 6, color: dynamicScheme.secondaryContainer),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getColorName(Color color) {
    if (color == const Color(0xFF6A5AE0)) return 'Default';
    if (color == const Color(0xFF2196F3)) return 'Ocean';
    if (color == const Color(0xFF4CAF50)) return 'Forest';
    if (color == const Color(0xFFF44336)) return 'Sunset';
    if (color == const Color(0xFFFFC107)) return 'Amber';
    if (color == const Color(0xFF00BCD4)) return 'Teal';
    if (color == const Color(0xFFFF5722)) return 'Orange';
    if (color == const Color(0xFF9C27B0)) return 'Plum';
    return 'Custom';
  }
}

class _ThemePreview extends StatelessWidget {
  final ThemeMode themeMode;
  final Color primaryColor;
  final bool amoledBlack;
  final int gridColumns;

  const _ThemePreview({
    required this.themeMode,
    required this.primaryColor,
    required this.amoledBlack,
    required this.gridColumns,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final bgColor = isDark
        ? (amoledBlack ? Colors.black : const Color(0xFF100E14))
        : const Color(0xFFF8F8FA);

    final cardBg = isDark
        ? (amoledBlack ? const Color(0xFF121212) : const Color(0xFF1C1B1F))
        : Colors.white;

    final onSurfaceColor = isDark ? const Color(0xFFE6E1E5) : const Color(0xFF1D1B20);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 180,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            // Mini AppBar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: primaryColor.withValues(alpha: 0.15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.download_for_offline_rounded, size: 18, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'RagaDL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: onSurfaceColor,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.settings, size: 16, color: onSurfaceColor.withValues(alpha: 0.6)),
                ],
              ),
            ),
            // Mini Content (Grid of columns)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview Gallery',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceColor.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridColumns,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: gridColumns,
                        itemBuilder: (context, index) {
                          final isFirst = index == 0;
                          return Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isFirst ? primaryColor : borderColor,
                                width: isFirst ? 1.5 : 1,
                              ),
                            ),
                            child: isFirst
                                ? Center(
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: primaryColor,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Mini Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Icon(Icons.home_rounded, size: 16, color: primaryColor),
                  Icon(Icons.person, size: 16, color: onSurfaceColor.withValues(alpha: 0.4)),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor,
                    ),
                    child: const Icon(Icons.download_rounded, size: 12, color: Colors.white),
                  ),
                  Icon(Icons.history, size: 16, color: onSurfaceColor.withValues(alpha: 0.4)),
                  Icon(Icons.settings, size: 16, color: onSurfaceColor.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}