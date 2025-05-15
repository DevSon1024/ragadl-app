import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeConfig extends ChangeNotifier {
  static ThemeData defaultTheme = ThemeData(
    primarySwatch: Colors.green,
    primaryColor: Colors.green,
    brightness: Brightness.light,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );

  static ThemeData defaultDarkTheme = ThemeData(
    primarySwatch: Colors.green,
    primaryColor: Colors.green,
    brightness: Brightness.dark,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );

  static ThemeData coolTheme = ThemeData(
    primarySwatch: Colors.blue,
    primaryColor: Colors.blue,
    brightness: Brightness.light,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );

  static ThemeData coolDarkTheme = ThemeData(
    primarySwatch: Colors.blue,
    primaryColor: Colors.blue,
    brightness: Brightness.dark,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );

  static ThemeData smoothTheme = ThemeData(
    primarySwatch: Colors.pink,
    primaryColor: Colors.pinkAccent,
    brightness: Brightness.light,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );

  static ThemeData smoothDarkTheme = ThemeData(
    primarySwatch: Colors.pink,
    primaryColor: Colors.pinkAccent,
    brightness: Brightness.dark,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );

  static ThemeData vibrantTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.orange,
    brightness: Brightness.light,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );

  static ThemeData vibrantDarkTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.orange,
    brightness: Brightness.dark,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );

  static ThemeData calmTheme = ThemeData(
    primarySwatch: Colors.teal,
    primaryColor: Colors.teal,
    brightness: Brightness.light,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );

  static ThemeData calmDarkTheme = ThemeData(
    primarySwatch: Colors.teal,
    primaryColor: Colors.teal,
    brightness: Brightness.dark,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );

  ThemeMode _currentThemeMode = ThemeMode.system;
  String _currentTheme = 'default'; // Track the selected theme

  // Add keys for SharedPreferences
  static const String _themeModeKey = 'theme_mode';
  static const String _themeNameKey = 'theme_name';
  int _gridColumns = 2; // Default to 2 columns
  static const String _gridColumnsKey = 'grid_columns';

  ThemeConfig(){
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey);
    if (themeModeIndex != null) {
      _currentThemeMode = ThemeMode.values[themeModeIndex];
    }
    final themeName = prefs.getString(_themeNameKey);
    if (themeName != null) {
      _currentTheme = themeName;
    }
    final gridCols = prefs.getInt(_gridColumnsKey);
    if (gridCols != null) {
      _gridColumns = gridCols;
    }
    notifyListeners();
  }

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, _currentThemeMode.index);
    await prefs.setString(_themeNameKey, _currentTheme);
    await prefs.setInt(_gridColumnsKey, _gridColumns);
  }

  int get gridColumns => _gridColumns;

  void setGridColumns(int columns) {
    if ([1, 2, 3].contains(columns)) {
      _gridColumns = columns;
      _saveTheme();
      notifyListeners();
    }
  }

  ThemeMode get currentThemeMode => _currentThemeMode;
  String get currentTheme => _currentTheme;

  void toggleTheme() {
    _currentThemeMode = _currentThemeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme(); // Persist the change
    notifyListeners();
  }

  void setTheme(String themeName) {
    _currentTheme = themeName;
    _saveTheme(); // Persist the change
    notifyListeners();
  }

  ThemeData get lightTheme {
    switch (_currentTheme) {
      case 'cool':
        return coolTheme;
      case 'smooth':
        return smoothTheme;
      case 'vibrant':
        return vibrantTheme;
      case 'calm':
        return calmTheme;
      default:
        return defaultTheme;
    }
  }

  ThemeData get darkTheme {
    switch (_currentTheme) {
      case 'cool':
        return coolDarkTheme;
      case 'smooth':
        return smoothDarkTheme;
      case 'vibrant':
        return vibrantDarkTheme;
      case 'calm':
        return calmDarkTheme;
      default:
        return defaultDarkTheme;
    }
  }
}