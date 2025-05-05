import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_config.dart';

class DisplaySettingsPage extends StatelessWidget {
  const DisplaySettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Settings'),
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
            // Theme toggle switch
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
              'Theme Options',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Theme selection containers
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildThemeContainer(
                  context,
                  'Default',
                  Colors.green,
                  isSelected: Theme.of(context).primaryColor == Colors.green,
                ),
                _buildThemeContainer(
                  context,
                  'Cool Theme',
                  Colors.blue,
                  isSelected: false,
                ),
                _buildThemeContainer(
                  context,
                  'Purple Theme',
                  Colors.purple,
                  isSelected: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeContainer(
      BuildContext context,
      String themeName,
      Color color, {
        bool isSelected = false,
      }) {
    return InkWell(
      onTap: () {
        // Future implementation for theme switching
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.1),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              themeName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}