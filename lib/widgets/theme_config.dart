import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeConfig extends ChangeNotifier {
  // Light Themes with Material 3 Color Schemes
  static ThemeData natureTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.light,
      primary: Colors.green[700],
      secondary: Colors.green[300],
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onSurface: Colors.black87,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.green[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        letterSpacing: 0.15,
      ),
    ),
  );

  static ThemeData saffronTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepOrange,
      brightness: Brightness.light,
      primary: Colors.deepOrange[700],
      secondary: Colors.deepOrange[300],
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onSurface: Colors.black87,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.deepOrange[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        letterSpacing: 0.15,
      ),
    ),
  );

  static ThemeData smoothTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.pink,
      brightness: Brightness.light,
      primary: Colors.pink[700],
      secondary: Colors.pink[300],
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onSurface: Colors.black87,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.pink[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        letterSpacing: 0.15,
      ),
    ),
  );

  static ThemeData vibrantTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.orange,
      brightness: Brightness.light,
      primary: Colors.orange[700],
      secondary: Colors.orange[300],
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onSurface: Colors.black87,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.orange[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        letterSpacing: 0.15,
      ),
    ),
  );

  static ThemeData calmTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.light,
      primary: Colors.teal[700],
      secondary: Colors.teal[300],
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onSurface: Colors.black87,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.teal[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        letterSpacing: 0.15,
      ),
    ),
  );

  static ThemeData whiteTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
      primary: Colors.blue[700],
      secondary: Colors.blue[300],
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onSurface: Colors.black87,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.blue[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        letterSpacing: 0.15,
      ),
    ),
  );

  // Dark Themes with Material 3 Color Schemes
  static ThemeData natureDarkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.dark,
      primary: Colors.green[900],
      secondary: Colors.green[700],
      surface: Colors.grey[900],
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey[900],
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.grey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.green[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.grey,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.grey,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.15,
      ),
    ),
  );

  static ThemeData saffronDarkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepOrange,
      brightness: Brightness.dark,
      primary: Colors.deepOrange[900],
      secondary: Colors.deepOrange[700],
      surface: Colors.grey[900],
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey[900],
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.grey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.deepOrange[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.grey,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.grey,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.15,
      ),
    ),
  );

  static ThemeData smoothDarkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.pink,
      brightness: Brightness.dark,
      primary: Colors.pink[900],
      secondary: Colors.pink[700],
      surface: Colors.grey[900],
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey[900],
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.grey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.pink[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.grey,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.grey,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.15,
      ),
    ),
  );

  static ThemeData vibrantDarkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.orange,
      brightness: Brightness.dark,
      primary: Colors.orange[900],
      secondary: Colors.orange[700],
      surface: Colors.grey[900],
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey[900],
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.grey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.orange[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.grey,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.grey,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.15,
      ),
    ),
  );

  static ThemeData calmDarkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
      primary: Colors.teal[900],
      secondary: Colors.teal[700],
      surface: Colors.grey[900],
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey[900],
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.grey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.teal[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.grey,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.grey,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.15,
      ),
    ),
  );

  static ThemeData whiteDarkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
      primary: Colors.blue[900],
      secondary: Colors.blue[700],
      surface: Colors.grey[900],
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey[900],
    cardTheme: const CardThemeData(
      elevation: 2,
      margin: EdgeInsets.all(8),
      surfaceTintColor: Colors.grey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25),
    ),
    iconTheme: IconThemeData(
      color: Colors.blue[700],
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.grey,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.grey,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.15,
      ),
    ),
  );

  ThemeMode _currentThemeMode = ThemeMode.light;
  bool _useSystemTheme = true;
  String _currentTheme = 'white';
  static const String _themeModeKey = 'theme_mode';
  static const String _themeNameKey = 'theme_name';
  static const String _useSystemThemeKey = 'use_system_theme';
  static const String _gridColumnsKey = 'grid_columns';
  int _gridColumns = 2;

  ThemeConfig() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey);
    if (themeModeIndex != null) {
      _currentThemeMode = ThemeMode.values[themeModeIndex];
    }
    final useSystem = prefs.getBool(_useSystemThemeKey);
    if (useSystem != null) {
      _useSystemTheme = useSystem;
    }
    final themeName = prefs.getString(_themeNameKey);
    if (themeName != null) {
      _currentTheme = themeName;
    } else {
      _currentTheme = 'white';
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
    await prefs.setBool(_useSystemThemeKey, _useSystemTheme);
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

  ThemeMode get currentThemeMode => _useSystemTheme ? ThemeMode.system : _currentThemeMode;
  String get currentTheme => _currentTheme;
  bool get useSystemTheme => _useSystemTheme;

  void toggleTheme() {
    _currentThemeMode = _currentThemeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme();
    notifyListeners();
  }

  void setUseSystemTheme(bool value) {
    _useSystemTheme = value;
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
      case 'nature':
        return natureTheme;
      case 'saffron':
        return saffronTheme;
      case 'smooth':
        return smoothTheme;
      case 'vibrant':
        return vibrantTheme;
      case 'calm':
        return calmTheme;
      case 'white':
        return whiteTheme;
      default:
        return whiteTheme;
    }
  }

  ThemeData get darkTheme {
    switch (_currentTheme) {
      case 'nature':
        return natureDarkTheme;
      case 'saffron':
        return saffronDarkTheme;
      case 'smooth':
        return smoothDarkTheme;
      case 'vibrant':
        return vibrantDarkTheme;
      case 'calm':
        return calmDarkTheme;
      case 'white':
        return whiteDarkTheme;
      default:
        return whiteDarkTheme;
    }
  }
}