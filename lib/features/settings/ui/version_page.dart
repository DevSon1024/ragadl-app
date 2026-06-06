// version_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class VersionPage extends StatelessWidget {
  const VersionPage({super.key});

  Future<Map<String, dynamic>> _fetchLatestRelease() async {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/DevSon1024/ragadl-app/releases/latest'),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load release');
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'App Version',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: color.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchLatestRelease(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final release = snapshot.data!;
            final version = release['tag_name'] ?? 'Unknown';
            final name = release['name'] ?? version;
            final publishedAt = release['published_at'] ?? '';
            final body = release['body'] ?? 'No changelog available.';
            final htmlUrl = release['html_url'] ?? '';

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.primaryContainer,
                          color.secondaryContainer,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.new_releases,
                          size: 48,
                          color: color.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: color.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Released: $publishedAt',
                          style: TextStyle(
                            fontSize: 14,
                            color: color.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Sections
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIntroSection(context),
                        const SizedBox(height: 24),
                        _buildSectionCard(
                          context,
                          icon: Icons.description,
                          title: 'Changelog',
                          content: _buildChangelogContent(context, body),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          context,
                          icon: Icons.link,
                          title: 'Repository Links',
                          content: _buildLinksContent(context, htmlUrl),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          context,
                          icon: Icons.developer_board,
                          title: 'Device Details',
                          content: _buildDeviceDetailsContent(context),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          context,
                          icon: Icons.star_outline_rounded,
                          title: 'Credits & Libraries',
                          content: _buildCreditsContent(context),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildIntroSection(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: color.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: color.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Latest Updates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'View the latest version details and changelog from GitHub.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: color.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required Widget content,
      }) {
    final color = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color.primary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: content,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangelogContent(BuildContext context, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        body,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildLinksContent(BuildContext context, String htmlUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLinkItem(
          context,
          Icons.folder,
          'Releases',
          htmlUrl,
          htmlUrl,
        ),
        const SizedBox(height: 12),
        _buildLinkItem(
          context,
          Icons.code,
          'Repository',
          'View on GitHub',
          'https://github.com/DevSon1024/ragadl-app',
        ),
      ],
    );
  }

  Widget _buildLinkItem(
      BuildContext context,
      IconData icon,
      String label,
      String text,
      String url,
      ) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, String>> _getDeviceDetails() async {
    final deviceInfo = DeviceInfoPlugin();
    final Map<String, String> details = {};
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        details['Device Model'] = androidInfo.model;
        details['Manufacturer'] = androidInfo.manufacturer;
        details['Android Version'] = androidInfo.version.release;
        details['SDK Version'] = androidInfo.version.sdkInt.toString();
        details['Hardware'] = androidInfo.hardware;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        details['Device Name'] = iosInfo.name;
        details['Model'] = iosInfo.model;
        details['System Version'] = iosInfo.systemVersion;
        details['System Name'] = iosInfo.systemName;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        details['Computer Name'] = windowsInfo.computerName;
        details['OS Version'] = windowsInfo.releaseId;
        details['Build Number'] = windowsInfo.buildNumber.toString();
      } else if (Platform.isMacOS) {
        final macosInfo = await deviceInfo.macOsInfo;
        details['Computer Name'] = macosInfo.computerName;
        details['Model'] = macosInfo.model;
        details['OS Version'] = macosInfo.osRelease;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        details['Name'] = linuxInfo.name;
        details['Version'] = linuxInfo.version ?? 'Unknown';
      }
    } catch (e) {
      details['Error'] = 'Failed to load device details: $e';
    }
    return details;
  }

  Widget _buildDeviceDetailsContent(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _getDeviceDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('Failed to load device details');
        }

        final details = snapshot.data!;
        return Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(3),
          },
          children: details.entries.map((entry) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCreditsContent(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final libraries = [
      {'name': 'Flutter SDK', 'desc': 'Core framework for high-performance UI'},
      {'name': 'Flutter Riverpod', 'desc': 'Reactive caching & state management'},
      {'name': 'Dio', 'desc': 'HTTP client with persistent connection pooling'},
      {'name': 'Awesome Notifications', 'desc': 'Rich background progress notifications'},
      {'name': 'Device Info Plus', 'desc': 'Platform hardware & OS identification'},
      {'name': 'Cached Network Image', 'desc': 'Optimized multi-level image caching'},
      {'name': 'Photo View & Extended Image', 'desc': 'Interactive panning, zooming & caching'},
      {'name': 'Shared Preferences', 'desc': 'Persistent local user preferences'},
      {'name': 'Flutter Isolate', 'desc': 'Multi-threaded scraping & CPU offloading'},
      {'name': 'Window Manager', 'desc': 'Desktop window layout customization'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: libraries.map((lib) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 16, color: color.primary),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: color.onSurface,
                    ),
                    children: [
                      TextSpan(
                        text: '${lib['name']}: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: lib['desc'],
                        style: TextStyle(color: color.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}