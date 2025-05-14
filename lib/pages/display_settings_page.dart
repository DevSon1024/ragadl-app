import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_config.dart';

class DisplaySettingsPage extends StatelessWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Display Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<ThemeConfig>(
              builder: (context, themeConfig, child) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dark Mode',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Switch(
                    value: themeConfig.currentThemeMode == ThemeMode.dark,
                    onChanged: (value) {
                      themeConfig.toggleTheme();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Grid View Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<ThemeConfig>(
              builder: (context, themeConfig, child) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grid Columns',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  DropdownButton<int>(
                    value: themeConfig.gridColumns,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Full Width')),
                      DropdownMenuItem(value: 2, child: Text('2 Columns')),
                      DropdownMenuItem(value: 3, child: Text('3 Columns')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        themeConfig.setGridColumns(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Theme Options',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<ThemeConfig>(
                builder: (context, themeConfig, child) => ListView(
                  children: [
                    _buildThemeContainer(
                      context,
                      'Default Theme',
                      Colors.green,
                      themeConfig,
                      themeName: 'default',
                      isSelected: themeConfig.currentTheme == 'default',
                    ),
                    _buildThemeContainer(
                      context,
                      'Cool Theme',
                      Colors.blue,
                      themeConfig,
                      themeName: 'cool',
                      isSelected: themeConfig.currentTheme == 'cool',
                    ),
                    _buildThemeContainer(
                      context,
                      'Smooth Theme',
                      Colors.pinkAccent,
                      themeConfig,
                      themeName: 'smooth',
                      isSelected: themeConfig.currentTheme == 'smooth',
                    ),
                    _buildThemeContainer(
                      context,
                      'Vibrant Theme',
                      Colors.orange,
                      themeConfig,
                      themeName: 'vibrant',
                      isSelected: themeConfig.currentTheme == 'vibrant',
                    ),
                    _buildThemeContainer(
                      context,
                      'Calm Theme',
                      Colors.teal,
                      themeConfig,
                      themeName: 'calm',
                      isSelected: themeConfig.currentTheme == 'calm',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeContainer(
      BuildContext context,
      String displayName,
      Color color,
      ThemeConfig themeConfig, {
        required String themeName,
        bool isSelected = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          themeConfig.setTheme(themeName.toLowerCase());
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.grey,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}