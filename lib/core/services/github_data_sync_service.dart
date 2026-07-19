import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/celebrity_list/data/celebrity_repository.dart';

class GithubDataSyncService {
  GithubDataSyncService._privateConstructor();
  static final GithubDataSyncService instance =
      GithubDataSyncService._privateConstructor();

  static const String _repoOwner = 'DevSon1024';
  static const String _repoName = 'ragadl-app';
  static const String _branch = 'main';

  static const String _commitsApiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/commits/$_branch?path=assets/data';
  static const String _csvRawUrl =
      'https://raw.githubusercontent.com/$_repoOwner/$_repoName/$_branch/assets/data/Fetched_StarZone_Data.csv';
  static const String _jsonRawUrl =
      'https://raw.githubusercontent.com/$_repoOwner/$_repoName/$_branch/assets/data/Fetched_Albums_StarZone.json';

  static const String _prefLastShaKey = 'github_data_last_sha';
  static const String _prefLastSyncTimeKey = 'github_data_last_sync_time';

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Future<Directory> getDataDirectory() async {
    final saveDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${saveDir.path}/RagalahariData');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> getCsvFile() async {
    final dir = await getDataDirectory();
    return File('${dir.path}/Fetched_StarZone_Data.csv');
  }

  Future<File> getJsonFile() async {
    final dir = await getDataDirectory();
    return File('${dir.path}/Fetched_Albums_StarZone.json');
  }

  Future<bool> localFilesExist() async {
    final csvFile = await getCsvFile();
    final jsonFile = await getJsonFile();
    return (await csvFile.exists()) && (await jsonFile.exists());
  }

  Future<String?> getLastSyncedSha() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefLastShaKey);
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_prefLastSyncTimeKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Checks GitHub for updates and downloads updated CSV/JSON files if needed.
  /// Returns `true` if new data was fetched and updated, `false` otherwise.
  Future<bool> checkForUpdatesAndSync({
    void Function(String log)? onLog,
    bool force = false,
  }) async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      onLog?.call('Checking GitHub for database updates...');
      final hasLocal = await localFilesExist();
      final prefs = await SharedPreferences.getInstance();
      final lastSha = prefs.getString(_prefLastShaKey);

      String? latestSha;
      try {
        final commitResponse = await http
            .get(
              Uri.parse(_commitsApiUrl),
              headers: {
                'Accept': 'application/vnd.github.v3+json',
                'User-Agent': 'RagadlApp',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (commitResponse.statusCode == 200) {
          final body = json.decode(commitResponse.body);
          if (body is List && body.isNotEmpty) {
            latestSha = body[0]['sha'] as String?;
          } else if (body is Map) {
            latestSha = body['sha'] as String?;
          }
        }
      } catch (e) {
        onLog?.call('Could not fetch commit metadata: $e');
      }

      if (!force &&
          hasLocal &&
          latestSha != null &&
          lastSha != null &&
          latestSha == lastSha) {
        onLog?.call('Database is already up to date ($latestSha).');
        _isSyncing = false;
        return false;
      }

      onLog?.call('Downloading latest CSV database from GitHub...');
      final csvResponse = await http
          .get(Uri.parse(_csvRawUrl))
          .timeout(const Duration(seconds: 30));

      if (csvResponse.statusCode != 200) {
        throw Exception(
          'Failed to download CSV from GitHub (HTTP ${csvResponse.statusCode})',
        );
      }

      onLog?.call('Downloading latest JSON album database from GitHub...');
      final jsonResponse = await http
          .get(Uri.parse(_jsonRawUrl))
          .timeout(const Duration(seconds: 30));

      if (jsonResponse.statusCode != 200) {
        throw Exception(
          'Failed to download JSON from GitHub (HTTP ${jsonResponse.statusCode})',
        );
      }

      final csvContent = csvResponse.body;
      final jsonContent = jsonResponse.body;

      // Validate basic format
      if (csvContent.trim().isEmpty || !csvContent.contains(',')) {
        throw Exception('Downloaded CSV content is invalid or empty.');
      }
      try {
        final decodedJson = json.decode(jsonContent);
        if (decodedJson is! Map ||
            (!decodedJson.containsKey('actors') &&
                !decodedJson.containsKey('actresses'))) {
          throw Exception('Downloaded JSON format is missing expected keys.');
        }
      } catch (e) {
        throw Exception('Downloaded JSON is malformed: $e');
      }

      // Write to local disk
      onLog?.call('Saving database files locally...');
      final csvFile = await getCsvFile();
      final jsonFile = await getJsonFile();

      await csvFile.writeAsString(csvContent);
      await jsonFile.writeAsString(jsonContent);

      if (latestSha != null) {
        await prefs.setString(_prefLastShaKey, latestSha);
      }
      await prefs.setInt(
        _prefLastSyncTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      onLog?.call('Reloading application database repository...');
      await CelebrityRepository.instance.reloadSources(force: true);

      onLog?.call('Database successfully updated from GitHub!');
      _isSyncing = false;
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('GithubDataSyncService error: $e\n$stackTrace');
      }
      onLog?.call('Sync error: $e');
      _isSyncing = false;
      return false;
    }
  }
}
