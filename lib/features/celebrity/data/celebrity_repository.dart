import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../utils/celebrity_utils.dart';

// Data holder used by list page (only name + url)
typedef CelebrityRow = Map<String, String>;

class CelebrityRepository {
  CelebrityRepository._privateConstructor();
  static final CelebrityRepository instance =
  CelebrityRepository._privateConstructor();

  // Raw sources (lazy-loaded)
  List<String> _csvLines = const [];
  Set<String> _actorUrls = {};
  Set<String> _actressUrls = {};
  bool _sourcesLoaded = false;

  // Precomputed sorted and filtered indices
  List<int>? _sortedAZ;
  List<int>? _sortedZA;
  List<int>? _actorsSortedAZ;
  List<int>? _actressesSortedAZ;
  List<int>? _actorsSortedZA;
  List<int>? _actressesSortedZA;

  // Accessors for filters already used by UI
  Set<String> get actorUrls => _actorUrls;
  Set<String> get actressUrls => _actressUrls;

  // Number of data lines (excluding header)
  int get totalCount => _csvLines.isEmpty ? 0 : (_csvLines.length - 1);

  // Load only the sources (no full parse of all rows)
  Future<void> loadSources() async {
    if (_sourcesLoaded) return;
    // Load CSV and JSON once
    final csvString =
    await rootBundle.loadString('assets/data/Fetched_StarZone_Data.csv');
    final jsonString = await rootBundle
        .loadString('assets/data/Fetched_Albums_StarZone.json');

    _csvLines = csvString.split('\n');
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
    _actorUrls =
        (jsonData['actors'] as List).map((e) => (e['URL'] as String).trim()).toSet();
    _actressUrls = (jsonData['actresses'] as List)
        .map((e) => (e['URL'] as String).trim())
        .toSet();

    _sourcesLoaded = true;
  }

  // Build sorted and filtered indices lazily in a background isolate
  Future<void> _ensureSortedAndFilteredIndices() async {
    if (_sortedAZ != null) return;
    final indices = List<int>.generate(totalCount, (i) => i + 1); // skip header at 0
    final result = await compute(_sortAndFilterIndices, {
      'lines': _csvLines,
      'indices': indices,
      'actorUrls': _actorUrls,
      'actressUrls': _actressUrls,
    });
    _sortedAZ = result['az'] as List<int>;
    _sortedZA = result['za'] as List<int>;
    _actorsSortedAZ = result['actors_az'] as List<int>;
    _actressesSortedAZ = result['actresses_az'] as List<int>;
    _actorsSortedZA = result['actors_za'] as List<int>;
    _actressesSortedZA = result['actresses_za'] as List<int>;
  }

  // Fetch a page slice; sorting and category filters are applied here
  Future<List<CelebrityRow>> fetchPage({
    required int offset,
    required int limit,
    required SortOption sort,
  }) async {
    await loadSources();
    await _ensureSortedAndFilteredIndices();

    List<int> selectedIndices;
    switch (sort) {
      case SortOption.az:
        selectedIndices = _sortedAZ!;
        break;
      case SortOption.za:
        selectedIndices = _sortedZA!;
        break;
      case SortOption.celebrityActors:
        selectedIndices = _actorsSortedAZ!;
        break;
      case SortOption.celebrityActresses:
        selectedIndices = _actressesSortedAZ!;
        break;
      case SortOption.celebrityAll:
      default:
        selectedIndices = _sortedAZ!;
        break;
    }

    // Slice bounds
    if (offset >= selectedIndices.length) return const [];
    final end = (offset + limit).clamp(0, selectedIndices.length);
    final slice = selectedIndices.sublist(offset, end);

    // Parse only the slice in a background isolate
    final rows =
    await compute(_parseSlice, {'lines': _csvLines, 'indices': slice});

    return rows;
  }

  // Search on-demand across entire source; returns limited matches
  Future<List<CelebrityRow>> searchByName({
    required String query,
    required int limit,
    required CategoryOption category,
  }) async {
    await loadSources();
    if (query.trim().isEmpty) return const [];
    final q = query.toLowerCase().trim();
    // Use isolate for full-source scan, return early when limit reached
    final rows = await compute(_searchCsv, {
      'lines': _csvLines,
      'q': q,
      'limit': limit,
    });

    // Category filter after match to minimize work inside isolate
    return rows.where((row) {
      final url = row['url'] ?? '';
      switch (category) {
        case CategoryOption.actors:
          return _actorUrls.contains(url);
        case CategoryOption.actresses:
          return _actressUrls.contains(url);
        case CategoryOption.all:
        default:
          return true;
      }
    }).toList();
  }
}

// ===== Isolate helpers =====

// Sort and filter by name globally and return AZ/ZA index lists for all categories
Map<String, List<int>> _sortAndFilterIndices(Map args) {
  final lines = (args['lines'] as List).cast<String>();
  final indices = (args['indices'] as List).cast<int>();
  final actorUrls = (args['actorUrls'] as Set).cast<String>();
  final actressUrls = (args['actressUrls'] as Set).cast<String>();

  int cmpName(int i, int j) {
    final a = _extractName(lines[i]);
    final b = _extractName(lines[j]);
    return a.compareTo(b);
  }

  final az = [...indices]..sort(cmpName);

  final actorsAz = az.where((index) {
    final line = lines[index];
    final parts = line.split(',');
    return parts.length >= 2 && actorUrls.contains(parts[1].trim());
  }).toList();

  final actressesAz = az.where((index) {
    final line = lines[index];
    final parts = line.split(',');
    return parts.length >= 2 && actressUrls.contains(parts[1].trim());
  }).toList();

  return {
    'az': az,
    'za': [...az].reversed.toList(),
    'actors_az': actorsAz,
    'actresses_az': actressesAz,
    'actors_za': [...actorsAz].reversed.toList(),
    'actresses_za': [...actressesAz].reversed.toList(),
  };
}

// Parse a set of line indices from the CSV into rows
List<CelebrityRow> _parseSlice(Map args) {
  final lines = (args['lines'] as List).cast<String>();
  final indices = (args['indices'] as List).cast<int>();
  final List<CelebrityRow> out = [];
  for (final idx in indices) {
    if (idx < 0 || idx >= lines.length) continue;
    final line = lines[idx];
    final parts = line.split(',');
    if (parts.length >= 2) {
      final name = parts[0].trim();
      final url = parts[1].trim();
      if (name.isNotEmpty) {
        out.add({'name': name, 'url': url});
      }
    }
  }
  return out;
}

// Search across all lines by name contains
List<CelebrityRow> _searchCsv(Map args) {
  final lines = (args['lines'] as List).cast<String>();
  final q = args['q'] as String;
  final limit = args['limit'] as int;
  final List<CelebrityRow> out = [];
  for (var i = 1; i < lines.length; i++) {
    // skip header
    final line = lines[i];
    final parts = line.split(',');
    if (parts.length >= 2) {
      final name = parts[0].trim();
      final url = parts[1].trim();
      if (name.isNotEmpty && name.toLowerCase().contains(q)) {
        out.add({'name': name, 'url': url});
        if (out.length >= limit) break;
      }
    }
  }
  return out;
}

// Lightweight name extractor (first column)
String _extractName(String line) {
  final comma = line.indexOf(',');
  if (comma <= 0) return line.trim();
  return line.substring(0, comma).trim();
}