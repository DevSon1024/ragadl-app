import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
// import '../screens/ragalahari_downloader_screen.dart';
import 'ragalahari_downloader.dart';

class LinkHistoryItem {
  final String url;
  final String celebrityName;
  final String? galleryTitle;
  final DateTime timestamp;

  LinkHistoryItem({
    required this.url,
    required this.celebrityName,
    this.galleryTitle,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'celebrityName': celebrityName,
    'galleryTitle': galleryTitle,
    'timestamp': timestamp.toIso8601String(),
  };

  factory LinkHistoryItem.fromJson(Map<String, dynamic> json) => LinkHistoryItem(
    url: json['url'],
    celebrityName: json['celebrityName'],
    galleryTitle: json['galleryTitle'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

enum HistorySortOption { newestFirst, oldestFirst }

class LinkHistoryPage extends StatefulWidget {
  const LinkHistoryPage({super.key});

  @override
  _LinkHistoryPageState createState() => _LinkHistoryPageState();
}

class _LinkHistoryPageState extends State<LinkHistoryPage> {
  List<LinkHistoryItem> _history = [];
  List<LinkHistoryItem> _filteredHistory = [];
  HistorySortOption _currentSortOption = HistorySortOption.newestFirst;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(_filterHistory);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyKey = 'link_history';
    final historyJson = prefs.getStringList(historyKey) ?? [];
    setState(() {
      _history = historyJson
          .map((json) => LinkHistoryItem.fromJson(jsonDecode(json)))
          .toList();
      _filteredHistory = List.from(_history);
      _sortHistory();
    });
  }

  Future<void> _removeHistoryItem(LinkHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final historyKey = 'link_history';
    List<String> historyJson = prefs.getStringList(historyKey) ?? [];
    List<LinkHistoryItem> history = historyJson
        .map((json) => LinkHistoryItem.fromJson(jsonDecode(json)))
        .toList();

    history.removeWhere((h) =>
    h.url == item.url &&
        h.celebrityName == item.celebrityName &&
        h.timestamp == item.timestamp);
    await prefs.setStringList(
        historyKey, history.map((h) => jsonEncode(h.toJson())).toList());

    setState(() {
      _history = history;
      _filteredHistory = List.from(_history);
      _sortHistory();
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link removed from history')));
  }

  String _truncateUrl(String url) {
    final RegExp regex = RegExp(r'/\d+/');
    final match = regex.firstMatch(url);
    if (match != null) {
      return url.substring(0, match.end) + '...';
    }
    return url.length > 50 ? url.substring(0, 50) + '...' : url;
  }

  String? _extractGalleryId(String url) {
    final RegExp regex = RegExp(r'/(\d+)/');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  void _sortHistory() {
    setState(() {
      _filteredHistory = List.from(_history);

      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        _filteredHistory = _filteredHistory
            .where((item) =>
        item.celebrityName.toLowerCase().contains(query) ||
            (item.galleryTitle?.toLowerCase().contains(query) ?? false) ||
            (_extractGalleryId(item.url)?.contains(query) ?? false))
            .toList();
      }

      switch (_currentSortOption) {
        case HistorySortOption.newestFirst:
          _filteredHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          break;
        case HistorySortOption.oldestFirst:
          _filteredHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          break;
      }
    });
  }

  void _filterHistory() {
    _sortHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link History'),
        actions: [
          DropdownButton<HistorySortOption>(
            value: _currentSortOption,
            icon: const Icon(Icons.sort),
            onChanged: (HistorySortOption? newValue) {
              if (newValue != null) {
                setState(() {
                  _currentSortOption = newValue;
                  _sortHistory();
                });
              }
            },
            items: const [
              DropdownMenuItem(
                value: HistorySortOption.newestFirst,
                child: Text('Newest First'),
              ),
              DropdownMenuItem(
                value: HistorySortOption.oldestFirst,
                child: Text('Oldest First'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, title, or gallery ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterHistory();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                filled: true,
              ),
              onChanged: (value) => _filterHistory(),
            ),
          ),
        ),
      ),
      body: _filteredHistory.isEmpty
          ? const Center(child: Text('No link history found'))
          : ListView.builder(
        itemCount: _filteredHistory.length,
        itemBuilder: (context, index) {
          final item = _filteredHistory[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text(
                item.galleryTitle ?? _truncateUrl(item.url),
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                  'Celebrity: ${item.celebrityName} • ${item.timestamp.toString().split('.')[0]}'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RagalahariDownloader(
                      initialUrl: item.url,
                      initialFolder: item.celebrityName,
                      galleryTitle: item.galleryTitle,
                    ),
                  ),
                );
              },
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _removeHistoryItem(item),
                tooltip: 'Remove from history',
              ),
            ),
          );
        },
      ),
    );
  }
}