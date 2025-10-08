// celebrity_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../utils/celebrity_utils.dart';

// Data holder used by list page (only name + url)
typedef CelebrityRow = Map<String, String>;

class CelebrityRepository {
  CelebrityRepository._privateConstructor();
  static final CelebrityRepository instance = CelebrityRepository._privateConstructor();

  // Raw sources (lazy-loaded)
  List<String> _csvLines = const [];
  Set<String> _actorUrls = {};
  Set<String> _actressUrls = {};
  bool _sourcesLoaded = false;

  // Optional precomputed sorted indices (built lazily on first use)
  List<int>? _sortedAZ;
  List<int>? _sortedZA;

  // Accessors for filters already used by UI
  Set<String> get actorUrls => _actorUrls;
  Set<String> get actressUrls => _actressUrls;

  // Number of data lines (excluding header)
  int get totalCount => _csvLines.isEmpty ? 0 : (_csvLines.length - 1);

  // Load only the sources (no full parse of all rows)
  Future<void> loadSources() async {
    if (_sourcesLoaded) return;
    // Load CSV and JSON once
    final csvString = await rootBundle.loadString('assets/data/Fetched_StarZone_Data.csv');
    final jsonString = await rootBundle.loadString('assets/data/Fetched_Albums_StarZone.json');

    _csvLines = csvString.split('\n');
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
    _actorUrls = (jsonData['actors'] as List).map((e) => (e['URL'] as String).trim()).toSet();
    _actressUrls = (jsonData['actresses'] as List).map((e) => (e['URL'] as String).trim()).toSet();

    _sourcesLoaded = true;
  }

  // Build sorted indices lazily in a background isolate (global A–Z and Z–A cross-page)
  Future<void> _ensureSortedIndices() async {
    if (_sortedAZ != null && _sortedZA != null) return;
    final indices = List<int>.generate(totalCount, (i) => i + 1); // skip header at 0
    final result = await compute(_sortIndicesByName, {'lines': _csvLines, 'indices': indices});
    _sortedAZ = result['az'] as List<int>;
    _sortedZA = result['za'] as List<int>;
  }

  // Fetch a page slice; sorting and category filters are applied here
  Future<List<CelebrityRow>> fetchPage({
    required int offset,
    required int limit,
    required SortOption sort,
    required CategoryOption category,
  }) async {
    await loadSources();
    // Choose index space (straight lines vs lazy-sorted)
    List<int> selected;
    if (sort == SortOption.az || sort == SortOption.za) {
      await _ensureSortedIndices();
      selected = sort == SortOption.az ? _sortedAZ! : _sortedZA!;
    } else {
      selected = List<int>.generate(totalCount, (i) => i + 1);
    }

    // Slice bounds
    if (offset >= selected.length) return const [];
    final end = (offset + limit).clamp(0, selected.length);
    final slice = selected.sublist(offset, end);

    // Parse only the slice in a background isolate
    final rows = await compute(_parseSlice, {'lines': _csvLines, 'indices': slice});

    // Apply category filtering by URL set (in-memory check is cheap)
    final filtered = rows.where((row) {
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

    return filtered;
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

// Sort by name globally and return AZ/ZA index lists
Map<String, List<int>> _sortIndicesByName(Map args) {
  final lines = (args['lines'] as List).cast<String>();
  final indices = (args['indices'] as List).cast<int>();
  int cmpName(int i, int j) {
    final a = _extractName(lines[i]);
    final b = _extractName(lines[j]);
    return a.compareTo(b);
  }
  final az = [...indices]..sort(cmpName);
  final za = [...az].reversed.toList();
  return {'az': az, 'za': za};
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
  for (var i = 1; i < lines.length; i++) { // skip header
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
