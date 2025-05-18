import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeConfig extends ChangeNotifier {
  // Helper function to darken a color for dark themes
  Color _darkenColor(Color color, [double amount = 0.3]) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.2, 0.5));
    return hslDark.toColor();
  }

  // Light Themes (unchanged)
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


  // Dark Themes (unified with darkened primary colors)
  static ThemeData defaultDarkTheme = ThemeData(
    primaryColor: const Color(0xFF2E7D32), // Darkened green
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF2E7D32),
      secondary: Color(0xFF4CAF50),
      surface: Color(0xFF424242),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFFFFFFFF),
    ),
    scaffoldBackgroundColor: const Color(0xFF212121),
    brightness: Brightness.dark,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: Color(0xFF424242),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Color(0xFFFFFFFF)),
      bodySmall: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
      titleLarge: TextStyle(fontSize: 20, color: Color(0xFFFFFFFF)),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF2E7D32),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF212121),
      foregroundColor: Color(0xFFFFFFFF),
      elevation: 0,
    ),
  );

  static ThemeData coolDarkTheme = ThemeData(
    primaryColor: const Color(0xFF1565C0), // Darkened blue
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF1565C0),
      secondary: Color(0xFF42A5F5),
      surface: Color(0xFF424242),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFFFFFFFF),
    ),
    scaffoldBackgroundColor: const Color(0xFF212121),
    brightness: Brightness.dark,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: Color(0xFF424242),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Color(0xFFFFFFFF)),
      bodySmall: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
      titleLarge: TextStyle(fontSize: 20, color: Color(0xFFFFFFFF)),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF1565C0),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF212121),
      foregroundColor: Color(0xFFFFFFFF),
      elevation: 0,
    ),
  );

  static ThemeData smoothDarkTheme = ThemeData(
    primaryColor: const Color(0xFFC2185B), // Darkened pink
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFC2185B),
      secondary: Color(0xFFF06292),
      surface: Color(0xFF424242),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFFFFFFFF),
    ),
    scaffoldBackgroundColor: const Color(0xFF212121),
    brightness: Brightness.dark,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: Color(0xFF424242),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Color(0xFFFFFFFF)),
      bodySmall: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
      titleLarge: TextStyle(fontSize: 20, color: Color(0xFFFFFFFF)),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFFC2185B),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF212121),
      foregroundColor: Color(0xFFFFFFFF),
      elevation: 0,
    ),
  );

  static ThemeData vibrantDarkTheme = ThemeData(
    primaryColor: const Color(0xFFF57C00), // Darkened orange
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFF57C00),
      secondary: Color(0xFFFFA726),
      surface: Color(0xFF424242),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFFFFFFFF),
    ),
    scaffoldBackgroundColor: const Color(0xFF212121),
    brightness: Brightness.dark,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: Color(0xFF424242),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Color(0xFFFFFFFF)),
      bodySmall: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
      titleLarge: TextStyle(fontSize: 20, color: Color(0xFFFFFFFF)),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFFF57C00),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF212121),
      foregroundColor: Color(0xFFFFFFFF),
      elevation: 0,
    ),
  );

  static ThemeData calmDarkTheme = ThemeData(
    primaryColor: const Color(0xFF00695C), // Darkened teal
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00695C),
      secondary: Color(0xFF26A69A),
      surface: Color(0xFF424242),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFFFFFFFF),
    ),
    scaffoldBackgroundColor: const Color(0xFF212121),
    brightness: Brightness.dark,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: Color(0xFF424242),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Color(0xFFFFFFFF)),
      bodySmall: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
      titleLarge: TextStyle(fontSize: 20, color: Color(0xFFFFFFFF)),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF00695C),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF212121),
      foregroundColor: Color(0xFFFFFFFF),
      elevation: 0,
    ),
  );


  ThemeMode _currentThemeMode = ThemeMode.system;
  String _currentTheme = 'google'; // Set Google as default theme

  // Add keys for SharedPreferences
  static const String _themeModeKey = 'theme_mode';
  static const String _themeNameKey = 'theme_name';
  int _gridColumns = 2; // Default to 2 columns
  static const String _gridColumnsKey = 'grid_columns';

  ThemeConfig() {
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
    } else {
      _currentTheme = 'google'; // Ensure default is google if no saved theme
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