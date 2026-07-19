import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/github_data_sync_service.dart';
import '../../celebrity_list/data/celebrity_repository.dart';

class UpdateDatabasePage extends StatefulWidget {
  final bool startUpdateOnLoad;
  const UpdateDatabasePage({super.key, this.startUpdateOnLoad = false});

  @override
  State<UpdateDatabasePage> createState() => _UpdateDatabasePageState();
}

class _UpdateDatabasePageState extends State<UpdateDatabasePage> {
  bool _isLoading = false;
  double _progress = 0.0;
  String _statusText = '';
  List<String> _logMessages = [];
  final ScrollController _scrollController = ScrollController();
  String _updateFrequency = 'Every 24 Hours';
  Timer? _updateTimer;
  String _lastUpdateText = 'Never';

  int _csvLinesCount = 0;
  int _csvEntriesCount = 0;
  int _jsonLinesCount = 0;
  int _jsonEntriesCount = 0;
  int _actorsCount = 0;
  int _actressesCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadLastUpdateTime();
    _loadDatabaseStats();
    _startAutoUpdate();
    if (widget.startUpdateOnLoad) {
      _runUpdate();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadDatabaseStats() async {
    final repo = CelebrityRepository.instance;
    await repo.loadSources();

    final syncService = GithubDataSyncService.instance;
    final csvFile = await syncService.getCsvFile();
    final jsonFile = await syncService.getJsonFile();

    int csvLines = 0;
    int jsonLines = 0;

    if (await csvFile.exists()) {
      final content = await csvFile.readAsString();
      csvLines = content.split('\n').length;
    }
    if (await jsonFile.exists()) {
      final content = await jsonFile.readAsString();
      jsonLines = content.split('\n').length;
    }

    final csvEntries = repo.totalCount;
    final actors = repo.actorUrls.length;
    final actresses = repo.actressUrls.length;

    if (mounted) {
      setState(() {
        _csvLinesCount = csvLines;
        _csvEntriesCount = csvEntries;
        _jsonLinesCount = jsonLines;
        _actorsCount = actors;
        _actressesCount = actresses;
        _jsonEntriesCount = actors + actresses;
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadLastUpdateTime() async {
    final syncService = GithubDataSyncService.instance;
    final lastTime = await syncService.getLastSyncTime();
    final sha = await syncService.getLastSyncedSha();
    if (lastTime != null) {
      final duration = DateTime.now().difference(lastTime);
      String timeAgo;
      if (duration.inDays > 30) {
        timeAgo = '${duration.inDays ~/ 30} month${(duration.inDays ~/ 30) > 1 ? 's' : ''} ago';
      } else if (duration.inDays > 0) {
        timeAgo = '${duration.inDays} day${duration.inDays > 1 ? 's' : ''} ago';
      } else if (duration.inHours > 0) {
        timeAgo = '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''} ago';
      } else {
        timeAgo = '${duration.inMinutes} min${duration.inMinutes > 1 ? 's' : ''} ago';
      }
      setState(() {
        _lastUpdateText = sha != null ? '$timeAgo (SHA: ${sha.substring(0, sha.length > 7 ? 7 : sha.length)})' : timeAgo;
      });
    }
  }

  void _startAutoUpdate() {
    _updateTimer?.cancel();
    Duration interval;
    switch (_updateFrequency) {
      case 'Every Week':
        interval = const Duration(days: 7);
        break;
      case 'Every Month':
        interval = const Duration(days: 30);
        break;
      default:
        interval = const Duration(hours: 24);
    }
    _updateTimer = Timer.periodic(interval, (_) => _runUpdate(isBackground: true));
  }

  Future<void> _runUpdate({bool isBackground = false}) async {
    if (_isLoading) return;

    if (!isBackground) {
      setState(() {
        _isLoading = true;
        _progress = 0.1;
        _statusText = 'Starting GitHub Database Sync...';
        _logMessages = [];
      });
    }

    final updated = await GithubDataSyncService.instance.checkForUpdatesAndSync(
      onLog: (logMsg) {
        if (!isBackground) {
          _addLog(logMsg);
          setState(() {
            _progress = (_progress + 0.2).clamp(0.1, 0.95);
          });
        }
      },
      force: true,
    );

    if (!isBackground) {
      setState(() {
        _progress = 1.0;
        _isLoading = false;
        _statusText = updated
            ? 'Database updated successfully from GitHub!'
            : 'Database check complete.';
      });
    }
    await _loadLastUpdateTime();
    await _loadDatabaseStats();
  }

  void _addLog(String message) {
    setState(() {
      _logMessages.add('${DateTime.now().toString().substring(11, 19)}: $message');
      Future.delayed(Duration.zero, _scrollToBottom);
    });
  }

  Widget _buildStatRow(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Update Database',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surfaceTint,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Database Updater',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Click on "Update Database" to fetch the latest dataset directly from GitHub.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              surfaceTintColor: theme.colorScheme.surfaceTint,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Database Statistics',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingStats)
                      const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                    else ...[
                      _buildStatRow(
                        theme,
                        label: 'Celebrity Data',
                        value: '$_csvLinesCount lines ($_csvEntriesCount celebrities)',
                        icon: Icons.person_search_outlined,
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        theme,
                        label: 'Category Data',
                        value: '$_jsonLinesCount lines ($_jsonEntriesCount items)',
                        icon: Icons.category_outlined,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 26.0),
                        child: Text(
                          '• Actors: $_actorsCount  |  • Actresses: $_actressesCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              surfaceTintColor: theme.colorScheme.surfaceTint,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text('Auto-update: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: _updateFrequency,
                      items: ['Every 24 Hours', 'Every Week', 'Every Month']
                          .map((String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                          .toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _updateFrequency = newValue;
                          });
                          _startAutoUpdate();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: $_lastUpdateText',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _runUpdate(),
              icon: const Icon(Icons.cloud_download),
              label: Text(_isLoading ? 'Updating...' : 'Update Database'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading || _progress > 0)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                surfaceTintColor: theme.colorScheme.surfaceTint,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Log:',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                surfaceTintColor: theme.colorScheme.surfaceTint,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _logMessages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          _logMessages[index],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}