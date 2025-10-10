import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_isolate/flutter_isolate.dart';

// Helper function to be executed in an isolate for updating the database.
void _updateDatabaseIsolate(SendPort sendPort) async {
  List<Map<String, String>> actorsData = [];
  List<Map<String, String>> actressesData = [];
  List<List<dynamic>> newCsvData = [];
  const alphabet = 'abcdefghijklmnopqrstuvwxyz';

  try {
    // Reading existing names from CSV to avoid duplicates.
    List<String> existingNames = await _readExistingNames('Fetched_StarZone_Data.csv');

    for (int i = 0; i < alphabet.length; i++) {
      String letter = alphabet[i];
      // Sending progress back to the main thread.
      sendPort.send({'type': 'progress', 'value': i / alphabet.length});

      // Fetching data for actors and actresses concurrently.
      var actorDataFuture = _fetchLinksFromAlpha(letter, 'actor');
      var actressDataFuture = _fetchLinksFromAlpha(letter, 'actress');
      var results = await Future.wait([actorDataFuture, actressDataFuture]);
      var actorData = results[0];
      var actressData = results[1];

      actorsData.addAll(actorData);
      actressesData.addAll(actressData);

      for (var data in [...actorData, ...actressData]) {
        String name = data['Name']!;
        if (!existingNames.contains(name)) {
          newCsvData.add([name, data['URL']]);
          sendPort.send({'type': 'log', 'value': '$name Added'});
        }
      }
      await Future.delayed(const Duration(milliseconds: 300)); // To avoid overwhelming the server.
    }

    if (newCsvData.isNotEmpty) {
      sendPort.send({'type': 'log', 'value': 'Saving data to CSV and JSON...'});

      Directory saveDir = await getApplicationDocumentsDirectory();
      String dirPath = '${saveDir.path}/RagalahariData';
      Directory(dirPath).createSync(recursive: true);

      // Save CSV
      String csvFilePath = '$dirPath/Fetched_StarZone_Data.csv';
      File csvFile = File(csvFilePath);
      List<List<dynamic>> existingCsvData = [];
      if (await csvFile.exists()) {
        String csvContent = await csvFile.readAsString();
        existingCsvData = const CsvToListConverter().convert(csvContent);
      }
      List<List<dynamic>> csvData = [
        ['Name', 'URL'],
        ...existingCsvData.skip(1),
        ...newCsvData,
      ];
      String csv = const ListToCsvConverter().convert(csvData);
      await csvFile.writeAsString(csv);

      // Save JSON
      String jsonFilePath = '$dirPath/Fetched_Albums_StarZone.json';
      File jsonFile = File(jsonFilePath);
      Map<String, dynamic> jsonData = {
        'actors': actorsData,
        'actresses': actressesData,
      };
      await jsonFile.writeAsString(json.encode(jsonData));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastUpdateTimestamp', DateTime.now().millisecondsSinceEpoch);

      sendPort.send({'type': 'done', 'value': 'Database updated successfully!'});
    } else {
      sendPort.send({'type': 'done', 'value': 'No new data to add.'});
    }
  } catch (e) {
    sendPort.send({'type': 'error', 'value': 'Error: $e'});
  }
}

// Helper function to read existing names from the CSV file.
Future<List<String>> _readExistingNames(String filename) async {
  try {
    Directory saveDir = await getApplicationDocumentsDirectory();
    String dirPath = '${saveDir.path}/RagalahariData';
    String filePath = '$dirPath/$filename';
    Directory(dirPath).createSync(recursive: true);
    File file = File(filePath);
    if (await file.exists()) {
      String csvContent = await file.readAsString();
      List<List<dynamic>> csvData = const CsvToListConverter().convert(csvContent);
      return csvData.skip(1).map((row) => row[0].toString()).toList();
    }
    return [];
  } catch (e) {
    return [];
  }
}

// Helper function to fetch links from a given alphabet letter and category.
Future<List<Map<String, String>>> _fetchLinksFromAlpha(String alphaLetter, String category) async {
  String baseUrl = 'https://www.ragalahari.com/$category/$alphaLetter/starzonesearch.aspx';
  List<Map<String, String>> linksData = [];

  try {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      var aTags = document.querySelectorAll('a.galleryname#lnknav');
      for (var aTag in aTags) {
        String? href = aTag.attributes['href'];
        String name = aTag.text.trim();
        if (href != null && href.isNotEmpty && name.isNotEmpty) {
          String fullUrl = 'https://www.ragalahari.com$href';
          linksData.add({'Name': name, 'URL': fullUrl});
        }
      }
    }
  } catch (e) {
    // Errors will be caught and sent back to the main thread from the isolate.
  }
  return linksData;
}

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
  FlutterIsolate? _isolate;
  ReceivePort? _receivePort;

  @override
  void initState() {
    super.initState();
    _loadLastUpdateTime();
    _startAutoUpdate();
    if (widget.startUpdateOnLoad) {
      _runUpdate();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _updateTimer?.cancel();
    _isolate?.kill();
    _receivePort?.close();
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

  Future<void> _loadLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getInt('lastUpdateTimestamp');
    if (lastUpdate != null) {
      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      final duration = DateTime.now().difference(lastUpdateTime);
      setState(() {
        if (duration.inDays > 30) {
          _lastUpdateText = '${duration.inDays ~/ 30} month${(duration.inDays ~/ 30) > 1 ? 's' : ''} ago';
        } else if (duration.inDays > 0) {
          _lastUpdateText = '${duration.inDays} day${duration.inDays > 1 ? 's' : ''} ago';
        } else {
          _lastUpdateText = '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''} ago';
        }
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
        _progress = 0.0;
        _statusText = 'Starting update...';
        _logMessages = [];
      });
    }

    _receivePort = ReceivePort();
    _isolate = await FlutterIsolate.spawn(_updateDatabaseIsolate, _receivePort!.sendPort);

    _receivePort!.listen((message) {
      final type = message['type'];
      final value = message['value'];

      if (!isBackground) {
        if (type == 'progress') {
          setState(() {
            _progress = value;
            _statusText = 'Fetching data...';
          });
        } else if (type == 'log') {
          _addLog(value);
        } else if (type == 'done' || type == 'error') {
          setState(() {
            _statusText = value;
            _isLoading = false;
            if (type == 'done') _progress = 1.0;
          });
          _loadLastUpdateTime();
          _isolate?.kill();
          _receivePort?.close();
        }
      } else {
        // Handle background completion if needed (e.g., show a notification)
        if (type == 'done' || type == 'error') {
          _loadLastUpdateTime();
          _isolate?.kill();
          _receivePort?.close();
        }
      }
    });
  }

  void _addLog(String message) {
    setState(() {
      _logMessages.add('${DateTime.now().toString().substring(11, 19)}: $message');
      Future.delayed(Duration.zero, _scrollToBottom);
    });
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
              'Click on "Update Database" to add newly added celebrities to your app.',
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