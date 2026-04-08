import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/controllers/download_manager_controller.dart';
import 'ui/widgets/running_tab.dart';
import 'ui/widgets/failed_tab.dart';
import 'ui/widgets/completed_tab.dart';

// Re-export so callers (downloader_service, notification_controller)
// that still use this path continue to find DownloadManager.
export 'logic/download_manager.dart';

class DownloadManagerPage extends ConsumerStatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  ConsumerState<DownloadManagerPage> createState() =>
      _DownloadManagerPageState();
}

class _DownloadManagerPageState extends ConsumerState<DownloadManagerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showConcurrentDownloadsDialog(
    BuildContext context,
    DownloadManagerController controller,
  ) async {
    int currentValue = controller.maxConcurrentDownloads;

    await showDialog<void>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: const Text('Concurrent Downloads'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select how many downloads can run simultaneously',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Threads: $currentValue',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('$currentValue at once'),
                      ],
                    ),
                    Slider(
                      value: currentValue.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: currentValue.toString(),
                      onChanged: (v) {
                        setDialogState(() => currentValue = v.toInt());
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      currentValue <= 3
                          ? 'Light Load – Recommended for slower connections'
                          : currentValue <= 6
                          ? 'Moderate Load – Balanced performance'
                          : 'Heavy Load – For fast connections only',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      await controller.setMaxConcurrentDownloads(currentValue);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Concurrent downloads set to $currentValue',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Apply'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(downloadManagerControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Download Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.downloading_rounded),
              text:
                  'Running (${controller.runningDownloads.length + controller.pausedDownloads.length})',
            ),
            Tab(
              icon: const Icon(Icons.error_rounded),
              text: 'Failed (${controller.failedDownloads.length})',
            ),
            Tab(
              icon: const Icon(Icons.check_circle_rounded),
              text: 'Completed (${controller.completedDownloads.length})',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Concurrent Downloads Settings',
            onPressed:
                () => _showConcurrentDownloadsDialog(context, controller),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RunningDownloadsTab(controller: controller),
          FailedDownloadsTab(controller: controller),
          CompletedDownloadsTab(controller: controller),
        ],
      ),
    );
  }
}
