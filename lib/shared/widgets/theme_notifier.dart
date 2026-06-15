import 'package:flutter/material.dart';
import 'package:ragadl/shared/widgets/theme_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  final String key = "theme";
  final String colorKey = "primary_color";
  
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = ThemeConfig.colorPalettes[0];
  late SharedPreferences _prefs;

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;

  ThemeNotifier() {
    _loadFromPrefs();
  }

  void _loadFromPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final themeIndex = _prefs.getInt(key) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];

    final colorValue = _prefs.getInt(colorKey);
    if (colorValue != null) {
      _primaryColor = Color(colorValue);
    }
    notifyListeners();
  }

  void _saveToPrefs(ThemeMode themeMode) {
    _prefs.setInt(key, themeMode.index);
  }

  void _saveColorToPrefs(Color color) {
    _prefs.setInt(colorKey, color.toARGB32());
  }

  void setThemeMode(ThemeMode themeMode) {
    if (_themeMode == themeMode) return;

    _themeMode = themeMode;
    _saveToPrefs(themeMode);
    notifyListeners();
  }

  void setPrimaryColor(Color color) {
    if (_primaryColor == color) return;

    _primaryColor = color;
    _saveColorToPrefs(color);
    notifyListeners();
  }

  ThemeData getThemeData({bool isDark = false, bool amoledBlack = false}) {
    if (isDark) {
      return ThemeConfig.getDarkTheme(_primaryColor, amoledBlack: amoledBlack);
    } else {
      return ThemeConfig.getLightTheme(_primaryColor);
    }
  }
}