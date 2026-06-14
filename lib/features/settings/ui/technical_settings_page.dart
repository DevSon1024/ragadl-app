import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/settings_service.dart';

class TechnicalSettingsPage extends ConsumerStatefulWidget {
  const TechnicalSettingsPage({super.key});

  @override
  ConsumerState<TechnicalSettingsPage> createState() => _TechnicalSettingsPageState();
}

class _TechnicalSettingsPageState extends ConsumerState<TechnicalSettingsPage> {
  late TextEditingController _uaController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _uaController = TextEditingController(text: settings.customUserAgent);
  }

  @override
  void dispose() {
    _uaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final settings = ref.watch(settingsServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Technical Settings'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // User Agent Section
            _buildSectionHeader(context, 'Network Scraper'),
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
                      'Custom User-Agent',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Defines the identity sent to host domains to bypass bot detection blocks.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _uaController,
                      maxLines: 3,
                      minLines: 2,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        hintText: 'Enter Custom User-Agent',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () {
                            ref
                                .read(settingsServiceProvider.notifier)
                                .setCustomUserAgent(_uaController.text);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('User-Agent updated successfully.'),
                              ),
                            );
                          },
                          tooltip: 'Save User-Agent',
                        ),
                      ),
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Concurrency Section
            _buildSectionHeader(context, 'Task Queue limits'),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Concurrent Downloads',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${settings.concurrentDownloads} Active',
                            style: TextStyle(
                              color: color.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Controls how many background downloads run concurrently.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: settings.concurrentDownloads.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: settings.concurrentDownloads.toString(),
                      onChanged: (val) {
                        ref
                            .read(settingsServiceProvider.notifier)
                            .setConcurrentDownloads(val.toInt());
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: color.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Higher numbers may trigger anti-bot bans (403 errors). Recommended: 2',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: color.error,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Retries Section
            _buildSectionHeader(context, 'Retry Configuration'),
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
                      'Maximum Download Retries',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The number of times a failing background task attempts to redownload before marking itself failed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: settings.maxRetries,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: List.generate(6, (index) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text('$index attempts'),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(settingsServiceProvider.notifier)
                              .setMaxRetries(val);
                        }
                      },
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
