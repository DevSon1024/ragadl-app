import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

// Helper function to parse data in an isolate
Future<Map<String, dynamic>> _parseCelebritiesIsolate(String csvData) async {
  final lines = csvData.split('\n');
  final celebrities = lines
      .skip(1)
      .where((line) => line.trim().isNotEmpty && line.contains(','))
      .map((line) {
    final parts = line.split(',');
    if (parts.length >= 2) {
      return {'name': parts[0].trim(), 'url': parts[1].trim()};
    }
    return {'name': 'Unknown', 'url': ''};
  })
      .where((celebrity) => celebrity['name']!.isNotEmpty)
      .toList();
  return {'celebrities': celebrities};
}

class CelebrityRepository {
  // Step 1: Create a private constructor and a static instance (Singleton)
  CelebrityRepository._privateConstructor();
  static final CelebrityRepository instance =
  CelebrityRepository._privateConstructor();

  // Step 2: Create variables to cache the data
  List<Map<String, String>> _celebrities = [];
  Set<String> _actorUrls = {};
  Set<String> _actressUrls = {};
  bool _isDataLoaded = false;

  // Step 3: Create public getters to access the cached data
  List<Map<String, String>> get celebrities => _celebrities;
  Set<String> get actorUrls => _actorUrls;
  Set<String> get actressUrls => _actressUrls;
  bool get isDataLoaded => _isDataLoaded;

  // Step 4: Create a method to load data ONLY if it's not already loaded
  Future<void> loadCelebrities() async {
    // If data is already in the cache, do nothing.
    if (_isDataLoaded) {
      return;
    }

    try {
      // Load the CSV and JSON data from assets
      final csvString =
      await rootBundle.loadString('assets/data/Fetched_StarZone_Data.csv');
      final jsonString = await rootBundle
          .loadString('assets/data/Fetched_Albums_StarZone.json');

      // Use compute to parse the heavy CSV file in the background
      final celebrityData = await compute(_parseCelebritiesIsolate, csvString);
      final loadedCelebrities = List<Map<String, String>>.from(
          celebrityData['celebrities'] as List);

      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final loadedActors = (jsonData['actors'] as List<dynamic>)
          .map((e) => e['URL'] as String)
          .toSet();
      final loadedActresses = (jsonData['actresses'] as List<dynamic>)
          .map((e) => e['URL'] as String)
          .toSet();

      // Cache the loaded data in the class variables
      _celebrities = loadedCelebrities;
      _actorUrls = loadedActors;
      _actressUrls = loadedActresses;
      _isDataLoaded = true; // Mark data as loaded
    } catch (e) {
      // Handle potential errors during loading
      debugPrint("Error loading celebrity data: $e");
      // Re-throw the error so the UI can display a message
      rethrow;
    }
  }
}