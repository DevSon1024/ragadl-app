import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/theme_config.dart';

class DisplaySettingsPage extends StatelessWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Settings'),
        centerTitle: true,
        titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Theme Settings Section
              Text(
                'Theme',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Consumer<ThemeConfig>(
                  builder: (context, themeConfig, child) => Column(
                    children: [
                      ListTile(
                        title: Text(
                          'Use System Theme',
                          style: theme.textTheme.bodyLarge,
                        ),
                        trailing: Switch(
                          value: themeConfig.useSystemTheme,
                          onChanged: (value) {
                            themeConfig.setUseSystemTheme(value);
                          },
                          activeColor: theme.colorScheme.primary,
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Dark Mode',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: themeConfig.useSystemTheme
                                ? theme.colorScheme.onSurface.withOpacity(0.5)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: Switch(
                          value: themeConfig.currentThemeMode == ThemeMode.dark,
                          onChanged: themeConfig.useSystemTheme
                              ? null
                              : (value) {
                            themeConfig.toggleTheme();
                          },
                          activeColor: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Theme Options Section
              Text(
                'Theme Options',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Consumer<ThemeConfig>(
                builder: (context, themeConfig, child) => Column(
                  children: [
                    _buildThemeTile(
                      context,
                      'Cool Theme',
                      Colors.blue[700]!,
                      themeConfig,
                      themeName: 'white',
                      isSelected: themeConfig.currentTheme == 'white',
                    ),
                    _buildThemeTile(
                      context,
                      'Saffron Theme',
                      Colors.deepOrange[700]!,
                      themeConfig,
                      themeName: 'saffron',
                      isSelected: themeConfig.currentTheme == 'saffron',
                    ),
                    _buildThemeTile(
                      context,
                      'Nature Theme',
                      Colors.green[700]!,
                      themeConfig,
                      themeName: 'nature',
                      isSelected: themeConfig.currentTheme == 'nature',
                    ),
                    _buildThemeTile(
                      context,
                      'Smooth Theme',
                      Colors.pink[700]!,
                      themeConfig,
                      themeName: 'smooth',
                      isSelected: themeConfig.currentTheme == 'smooth',
                    ),
                    _buildThemeTile(
                      context,
                      'Vibrant Theme',
                      Colors.orange[700]!,
                      themeConfig,
                      themeName: 'vibrant',
                      isSelected: themeConfig.currentTheme == 'vibrant',
                    ),
                    _buildThemeTile(
                      context,
                      'Calm Theme',
                      Colors.teal[700]!,
                      themeConfig,
                      themeName: 'calm',
                      isSelected: themeConfig.currentTheme == 'calm',
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

  Widget _buildThemeTile(
      BuildContext context,
      String displayName,
      Color color,
      ThemeConfig themeConfig, {
        required String themeName,
        bool isSelected = false,
      }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          themeConfig.setTheme(themeName);
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          displayName,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: color)
            : null,
      ),
    );
  }
}