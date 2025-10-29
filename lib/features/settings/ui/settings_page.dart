// Modified settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ragadl/main.dart';
import 'display_settings_page.dart';
import 'storage_settings.dart';
import 'notification_settings_page.dart';
import 'privacy_policy_page.dart';
import 'contact_us_page.dart';
import 'package:ragadl/features/settings/ui/update_database_page.dart';
import 'version_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          _buildSettingsSection(
            context,
            title: 'General',
            children: [
              _buildSettingsItem(
                context,
                icon: Icons.display_settings,
                title: 'Display',
                subtitle: 'Theme, font size, etc.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DisplaySettingsPage(),
                    ),
                  );
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.storage,
                title: 'Storage',
                subtitle: 'Manage downloads and cache',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoragePage(),
                    ),
                  );
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Notification preferences',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          // _buildSettingsSection(
          //   context,
          //   title: 'na kcData',
            // children: [
              // _buildSettingsItem(
              //   context,
              //   icon: Icons.update,
              //   title: 'Update Database',
              //   subtitle: 'Fetch the latest celebrity data',
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (_) => const UpdateDatabasePage(),
              //       ),
              //     );
              //   },
              // ),
            // ],
          // ),
          _buildSettingsSection(
            context,
            title: 'About',
            children: [
              _buildSettingsItem(
                context,
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.contact_mail,
                title: 'Contact Us',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ContactUsPage(),
                    ),
                  );
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: 'Latest updates and changelog',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VersionPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context,
      {required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            surfaceTintColor: theme.colorScheme.surfaceTint,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        String? subtitle,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}