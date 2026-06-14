import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/settings_service.dart';

class UiSettingsPage extends ConsumerWidget {
  const UiSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final settings = ref.watch(settingsServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UI & Customization'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Grid Layout Section
          _buildSectionHeader(context, 'Gallery Grid Layout'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grid Column Count',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the number of image columns displayed in the scraper grid.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: SegmentedButton<int>(
                      segments: const <ButtonSegment<int>>[
                        ButtonSegment<int>(
                          value: 2,
                          label: Text('2 Col'),
                          icon: Icon(Icons.grid_view_rounded),
                        ),
                        ButtonSegment<int>(
                          value: 3,
                          label: Text('3 Col'),
                          icon: Icon(Icons.grid_on_rounded),
                        ),
                        ButtonSegment<int>(
                          value: 4,
                          label: Text('4 Col'),
                          icon: Icon(Icons.apps_rounded),
                        ),
                      ],
                      selected: <int>{settings.gridColumns},
                      onSelectionChanged: (Set<int> newSelection) {
                        ref
                            .read(settingsServiceProvider.notifier)
                            .setGridColumns(newSelection.first);
                      },
                      showSelectedIcon: false,
                    ),
                  ),
                ],
              ),
            ),
          ),


          // Themes & Cleanups Section
          _buildSectionHeader(context, 'Preferences'),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'AMOLED Black Theme',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Uses pure black background in dark mode to save OLED battery.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.amoledBlack,
                  onChanged: (val) {
                    ref
                        .read(settingsServiceProvider.notifier)
                        .setAmoledBlack(val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text(
                    'Auto Clear Completed',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Automatically clears successful items from history lists.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.autoClearCompleted,
                  onChanged: (val) {
                    ref
                        .read(settingsServiceProvider.notifier)
                        .setAutoClearCompleted(val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
