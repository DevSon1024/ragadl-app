import 'package:flutter/material.dart';
import 'package:ragalahari_downloader/widgets/theme_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  final String key = "theme";
  ThemeMode _themeMode = ThemeMode.system;
  late SharedPreferences _prefs;

  ThemeMode get themeMode => _themeMode;

  ThemeNotifier() {
    _loadFromPrefs();
  }

  void _loadFromPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final themeIndex = _prefs.getInt(key) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  void _saveToPrefs(ThemeMode themeMode) {
    _prefs.setInt(key, themeMode.index);
  }

  void setThemeMode(ThemeMode themeMode) {
    if (_themeMode == themeMode) return;

    _themeMode = themeMode;
    _saveToPrefs(themeMode);
    notifyListeners();
  }

  ThemeData getThemeData({bool isDark = false}) {
    if (isDark) {
      return ThemeConfig.darkTheme;
    } else {
      return ThemeConfig.lightTheme;
    }
  }
}