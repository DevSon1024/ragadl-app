import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeConfig extends ChangeNotifier {
  // Light Themes
  static ThemeData defaultTheme = ThemeData(
    primarySwatch: Colors.green,
    primaryColor: Colors.green,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: HSLColor.fromColor(Colors.green).withLightness(0.95).toColor(), // Fainted green
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
      bodySmall: TextStyle(fontSize: 14, color: Colors.black54),
      titleLarge: TextStyle(fontSize: 20, color: Colors.black87),
    ),
    iconTheme: const IconThemeData(
      color: Colors.green,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
    ),
  );

  static ThemeData cleanWhiteTheme = ThemeData(
    primarySwatch: Colors.grey,
    primaryColor: const Color(0xFF757575), // Neutral grey for accents
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white, // Clean white background
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: Color(0xFFF5F5F5), // Light grey for containers
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
      bodySmall: TextStyle(fontSize: 14, color: Colors.black54),
      titleLarge: TextStyle(fontSize: 20, color: Colors.black87),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF757575), // Neutral grey for icons
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
    ),
  );

  static ThemeData smoothTheme = ThemeData(
    primarySwatch: Colors.pink,
    primaryColor: Colors.pinkAccent,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: HSLColor.fromColor(Colors.pinkAccent).withLightness(0.95).toColor(), // Fainted pink
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
      bodySmall: TextStyle(fontSize: 14, color: Colors.black54),
      titleLarge: TextStyle(fontSize: 20, color: Colors.black87),
    ),
    iconTheme: const IconThemeData(
      color: Colors.pinkAccent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
    ),
  );

  static ThemeData vibrantTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.orange,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: HSLColor.fromColor(Colors.orange).withLightness(0.95).toColor(), // Fainted orange
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
      bodySmall: TextStyle(fontSize: 14, color: Colors.black54),
      titleLarge: TextStyle(fontSize: 20, color: Colors.black87),
    ),
    iconTheme: const IconThemeData(
      color: Colors.orange,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
    ),
  );

  static ThemeData calmTheme = ThemeData(
    primarySwatch: Colors.teal,
    primaryColor: Colors.teal,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: HSLColor.fromColor(Colors.teal).withLightness(0.95).toColor(), // Fainted teal
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
      bodySmall: TextStyle(fontSize: 14, color: Colors.black54),
      titleLarge: TextStyle(fontSize: 20, color: Colors.black87),
    ),
    iconTheme: const IconThemeData(
      color: Colors.teal,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
    ),
  );

  static ThemeData whiteTheme = ThemeData(
    primarySwatch: Colors.blue,
    primaryColor: const Color(0xFF2196F3),
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: const CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: Color(0xFFE3F2FD), // Fainted blue
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
      bodySmall: TextStyle(fontSize: 14, color: Colors.black54),
      titleLarge: TextStyle(fontSize: 20, color: Colors.black87),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF2196F3),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
    ),
  );

  // Dark Themes
  static ThemeData defaultDarkTheme = ThemeData(
    primaryColor: const Color(0xFF2E7D32),
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
    cardTheme: CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: HSLColor.fromColor(const Color(0xFF2E7D32)).withLightness(0.3).toColor(), // Darkened green for containers
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

  static ThemeData cleanWhiteDarkTheme = ThemeData(
    primaryColor: const Color(0xFF616161),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF616161),
      secondary: Color(0xFF9E9E9E),
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
      color: Color(0xFF616161),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF212121),
      foregroundColor: Color(0xFFFFFFFF),
      elevation: 0,
    ),
  );

  static ThemeData smoothDarkTheme = ThemeData(
    primaryColor: const Color(0xFFC2185B),
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
    cardTheme: CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: HSLColor.fromColor(const Color(0xFFC2185B)).withLightness(0.3).toColor(), // Darkened pink for containers
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
    primaryColor: const Color(0xFFF57C00),
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
    cardTheme: CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: HSLColor.fromColor(const Color(0xFFF57C00)).withLightness(0.3).toColor(), // Darkened orange for containers
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
    primaryColor: const Color(0xFF00695C),
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
    cardTheme: CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: HSLColor.fromColor(const Color(0xFF00695C)).withLightness(0.3).toColor(), // Darkened teal for containers
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

  static ThemeData whiteDarkTheme = ThemeData(
    primaryColor: const Color(0xFF1976D2),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF1976D2),
      secondary: Color(0xFF42A5F5),
      surface: Color(0xFF424242),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFFFFFFFF),
    ),
    scaffoldBackgroundColor: const Color(0xFF212121),
    brightness: Brightness.dark,
    cardTheme: CardTheme(
      elevation: 4,
      margin: EdgeInsets.all(8),
      color: const Color(0xFF616161),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: Color(0xFFFFFFFF)),
      bodySmall: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
      titleLarge: TextStyle(fontSize: 20, color: Color(0xFFFFFFFF)),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF1976D2),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF212121),
      foregroundColor: Color(0xFFFFFFFF),
      elevation: 0,
    ),
  );

  ThemeMode _currentThemeMode = ThemeMode.system;
  String _currentTheme = 'default'; // Set default theme

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
      _currentTheme = 'default'; // Ensure default theme if no saved theme
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
    _saveTheme();
    notifyListeners();
  }

  void setTheme(String themeName) {
    _currentTheme = themeName;
    _saveTheme();
    notifyListeners();
  }

  ThemeData get lightTheme {
    switch (_currentTheme) {
      case 'cleanWhite':
        return cleanWhiteTheme;
      case 'smooth':
        return smoothTheme;
      case 'vibrant':
        return vibrantTheme;
      case 'calm':
        return calmTheme;
      case 'white':
        return whiteTheme;
      default:
        return defaultTheme;
    }
  }

  ThemeData get darkTheme {
    switch (_currentTheme) {
      case 'cleanWhite':
        return cleanWhiteDarkTheme;
      case 'smooth':
        return smoothDarkTheme;
      case 'vibrant':
        return vibrantDarkTheme;
      case 'calm':
        return calmDarkTheme;
      case 'white':
        return whiteDarkTheme;
      default:
        return defaultDarkTheme;
    }
  }
}