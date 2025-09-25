import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Defines a list of selectable primary colors for the theme.
const List<Color> colorOptions = [
  Colors.deepPurple,
  Colors.blue,
  Colors.teal,
  Colors.green,
  Colors.orange,
  Colors.pink,
  Colors.red,
];

// Defines a list of color labels corresponding to the colorOptions.
const List<String> colorLabels = [
  'Deep Purple',
  'Blue',
  'Teal',
  'Green',
  'Orange',
  'Pink',
  'Red',
];

/// A class that manages the application's theme configuration.
///
/// It handles theme mode (light/dark/system), primary color selection,
/// and persists these settings using SharedPreferences.
class ThemeConfig with ChangeNotifier {
  ThemeMode _themeMode;
  int _colorIndex;

  // Keys for storing theme preferences in SharedPreferences.
  static const String _themeModeKey = 'themeMode';
  static const String _colorIndexKey = 'colorIndex';

  /// Initializes the ThemeConfig with default values.
  ThemeConfig()
      : _themeMode = ThemeMode.system,
        _colorIndex = 0 {
    _loadPreferences();
  }

  // Getters for the current theme mode and color.
  ThemeMode get currentThemeMode => _themeMode;
  Color get primaryColor => colorOptions[_colorIndex];

  // ThemeData definitions for light and dark themes.
  ThemeData get lightTheme => _buildTheme(Brightness.light);
  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  /// Builds the ThemeData based on the selected primary color and brightness.
  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: brightness,
      // You can add more customizations here
    );
  }

  /// Sets the theme mode and notifies listeners.
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _savePreferences();
    notifyListeners();
  }

  /// Sets the primary color by its index in the colorOptions list.
  void setColorIndex(int index) {
    if (index >= 0 && index < colorOptions.length) {
      _colorIndex = index;
      _savePreferences();
      notifyListeners();
    }
  }

  /// Loads the saved theme preferences from SharedPreferences.
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeModeIndex];
    _colorIndex = prefs.getInt(_colorIndexKey) ?? 0;
    notifyListeners();
  }

  /// Saves the current theme preferences to SharedPreferences.
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_themeModeKey, _themeMode.index);
    prefs.setInt(_colorIndexKey, _colorIndex);
  }
}