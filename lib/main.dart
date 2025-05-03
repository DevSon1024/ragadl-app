import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'navbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ragalahari Downloader',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        primaryColor: Colors.green,
        brightness: Brightness.light,
        cardTheme: CardTheme(
          elevation: 4,
          margin: EdgeInsets.all(8),
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainNavigationScreen(),
    );
  }
}