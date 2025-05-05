import 'package:flutter/material.dart';

class ThemeConfig extends ChangeNotifier {
  static ThemeData lightTheme = ThemeData(
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

  static ThemeData darkTheme = ThemeData(
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

  ThemeMode _currentThemeMode = ThemeMode.system;

  ThemeMode get currentThemeMode => _currentThemeMode;

  void toggleTheme() {
    _currentThemeMode =
    _currentThemeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}