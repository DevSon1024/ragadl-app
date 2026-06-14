import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Riverpod provider for SettingsService
final settingsServiceProvider = ChangeNotifierProvider<SettingsService>((ref) {
  return SettingsService();
});

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() => _instance;

  SettingsService._internal() {
    _loadFromPrefs();
  }

  late SharedPreferences _prefs;
  bool _initialized = false;

  int _concurrentDownloads = 2;
  String _customUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  int _maxRetries = 3;
  int _gridColumns = 3;
  bool _amoledBlack = false;
  bool _autoClearCompleted = false;

  int get concurrentDownloads => _concurrentDownloads;
  String get customUserAgent => _customUserAgent;
  int get maxRetries => _maxRetries;
  int get gridColumns => _gridColumns;
  bool get amoledBlack => _amoledBlack;
  bool get autoClearCompleted => _autoClearCompleted;
  bool get initialized => _initialized;

  Future<void> _loadFromPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _concurrentDownloads = _prefs.getInt('settings_concurrent_downloads') ?? 2;
      _customUserAgent = _prefs.getString('settings_custom_user_agent') ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
      _maxRetries = _prefs.getInt('settings_max_retries') ?? 3;
      _gridColumns = _prefs.getInt('settings_grid_columns') ?? 3;
      _amoledBlack = _prefs.getBool('settings_amoled_black') ?? false;
      _autoClearCompleted = _prefs.getBool('settings_auto_clear_completed') ?? false;
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings from SharedPreferences: $e');
    }
  }

  Future<void> setConcurrentDownloads(int val) async {
    if (val < 1 || val > 5) return;
    _concurrentDownloads = val;
    await _prefs.setInt('settings_concurrent_downloads', val);
    notifyListeners();
  }

  Future<void> setCustomUserAgent(String val) async {
    if (val.trim().isEmpty) return;
    _customUserAgent = val.trim();
    await _prefs.setString('settings_custom_user_agent', _customUserAgent);
    notifyListeners();
  }

  Future<void> setMaxRetries(int val) async {
    if (val < 0 || val > 10) return;
    _maxRetries = val;
    await _prefs.setInt('settings_max_retries', val);
    notifyListeners();
  }

  Future<void> setGridColumns(int val) async {
    if (val < 2 || val > 4) return;
    _gridColumns = val;
    await _prefs.setInt('settings_grid_columns', val);
    notifyListeners();
  }

  Future<void> setAmoledBlack(bool val) async {
    _amoledBlack = val;
    await _prefs.setBool('settings_amoled_black', val);
    notifyListeners();
  }

  Future<void> setAutoClearCompleted(bool val) async {
    _autoClearCompleted = val;
    await _prefs.setBool('settings_auto_clear_completed', val);
    notifyListeners();
  }
}
