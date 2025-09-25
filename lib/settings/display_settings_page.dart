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
                          value: themeConfig.currentThemeMode == ThemeMode.system,
                          onChanged: (value) {
                            themeConfig.setThemeMode(
                                value ? ThemeMode.system : ThemeMode.light);
                          },
                          activeColor: theme.colorScheme.primary,
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Dark Mode',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color:
                            themeConfig.currentThemeMode == ThemeMode.system
                                ? theme.colorScheme.onSurface
                                .withOpacity(0.5)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: Switch(
                          value: themeConfig.currentThemeMode == ThemeMode.dark,
                          onChanged:
                          themeConfig.currentThemeMode == ThemeMode.system
                              ? null
                              : (value) {
                            themeConfig.setThemeMode(
                                value ? ThemeMode.dark : ThemeMode.light);
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
                builder: (context, themeConfig, child) => GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: colorOptions.length,
                  itemBuilder: (context, index) {
                    return _buildThemeTile(
                      context,
                      colorLabels[index],
                      colorOptions[index],
                      themeConfig,
                      index: index,
                      isSelected: themeConfig.primaryColor == colorOptions[index],
                    );
                  },
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
        required int index,
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
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          themeConfig.setColorIndex(index);
        },
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: ListTile(
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
        ),
      ),
    );
  }
}