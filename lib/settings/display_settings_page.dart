import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/theme_notifier.dart';

class DisplaySettingsPage extends StatelessWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme Mode',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              value: ThemeMode.system,
              groupValue: themeNotifier.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeNotifier.setThemeMode(value);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: themeNotifier.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeNotifier.setThemeMode(value);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: themeNotifier.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeNotifier.setThemeMode(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}