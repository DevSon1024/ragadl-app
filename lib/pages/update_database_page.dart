import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:csv/csv.dart';

class UpdateDatabasePage extends StatefulWidget {
  const UpdateDatabasePage({Key? key}) : super(key: key);

  @override
  State<UpdateDatabasePage> createState() => _UpdateDatabasePageState();
}

class _UpdateDatabasePageState extends State<UpdateDatabasePage> {
  bool _isLoading = false;
  double _progress = 0.0;
  String _statusText = '';
  List<String> _logMessages = [];
  ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
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

  Future<void> _updateDatabase() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _statusText = 'Starting database update...';
      _logMessages = [];
    });

    try {
      List<List<dynamic>> allData = [];
      String alphabet = 'abcdefghijklmnopqrstuvwxyz';

      for (int i = 0; i < alphabet.length; i++) {
        String letter = alphabet[i];
        setState(() {
          _progress = i / alphabet.length;
          _statusText = 'Fetching data for letter: $letter';
        });

        _addLog('Fetching from: https://www.ragalahari.com/$letter/starzonesearch.aspx');
        List<List<dynamic>> letterData = await _fetchLinksFromAlpha(letter);
        allData.addAll(letterData);

        // Small delay to prevent overwhelming the server
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (allData.isNotEmpty) {
        setState(() {
          _statusText = 'Saving data to CSV...';
        });

        await _saveToCsv(allData, 'Fetched_StarZone_Data.csv');

        setState(() {
          _statusText = 'Database updated successfully!';
          _progress = 1.0;
        });
        _addLog('✅ All data saved successfully!');
      } else {
        setState(() {
          _statusText = 'No data fetched.';
        });
        _addLog('No data fetched.');
      }
    } catch (e) {
      setState(() {
        _statusText = 'Error: $e';
      });
      _addLog('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<List<dynamic>>> _fetchLinksFromAlpha(String alphaLetter) async {
    String baseUrl = 'https://www.ragalahari.com/$alphaLetter/starzonesearch.aspx';
    List<List<dynamic>> linksData = [];

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
            linksData.add([name, fullUrl]);
            _addLog('Found: $name');
          }
        }
      } else {
        _addLog('Error fetching $baseUrl: HTTP ${response.statusCode}');
      }
    } catch (e) {
      _addLog('Error fetching $baseUrl: $e');
    }

    return linksData;
  }

  Future<void> _saveToCsv(List<List<dynamic>> data, String filename) async {
    try {
      // Add header row
      List<List<dynamic>> csvData = [
        ['Name', 'URL'],
        ...data
      ];

      String csv = const ListToCsvConverter().convert(csvData);

      // Get the app directory
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String assetsDir = '${appDocDir.path}/assets/data';

      // Create the directory if it doesn't exist
      Directory(assetsDir).createSync(recursive: true);

      // Create and write to the file
      File file = File('$assetsDir/$filename');
      await file.writeAsString(csv);

      _addLog('✅ All data saved to: $assetsDir/$filename');
    } catch (e) {
      _addLog('Error saving CSV: $e');
      throw e;
    }
  }

  void _addLog(String message) {
    setState(() {
      _logMessages.add('${DateTime.now().toString().substring(11, 19)}: $message');
      // Schedule a scroll to bottom after the UI updates
      Future.delayed(Duration.zero, _scrollToBottom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Database'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Database Updater',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This will scrape data from ragalahari.com and update your local database with star names and URLs.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _updateDatabase,
              icon: const Icon(Icons.cloud_download),
              label: Text(_isLoading ? 'Updating...' : 'Update Database'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading || _progress > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              'Log:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logMessages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _logMessages[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}