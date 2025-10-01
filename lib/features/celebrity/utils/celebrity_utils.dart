import 'dart:math';

// List of User-Agent strings for rotation
final List<String> userAgents = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
];

final Random _random = Random();

// Function to get a random User-Agent
String getRandomUserAgent() {
  return userAgents[_random.nextInt(userAgents.length)];
}

// Function to get headers with a random User-Agent
Map<String, String> getHeaders() {
  return {
    'User-Agent': getRandomUserAgent(),
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Connection': 'keep-alive',
    'Accept-Encoding': 'gzip, deflate, br',
    'DNT': '1',
    'Upgrade-Insecure-Requests': '1',
  };
}

// Legacy static headers (deprecated - use getHeaders() instead)
@Deprecated('Use getHeaders() for dynamic User-Agent rotation')
final Map<String, String> headers = {
  'User-Agent': getRandomUserAgent(),
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.5',
  'Connection': 'keep-alive',
};

// Domain patterns for thumbnail detection
final List<String> thumbnailDomains = [
  "media.ragalahari.com",
  "img.ragalahari.com",
  "szcdn.ragalahari.com",
  "starzone.ragalahari.com",
  "imgcdn.ragalahari.com",
];

// Enums for sorting
enum SortOption {
  az,
  za,
  celebrityAll,
  celebrityActors,
  celebrityActresses,
}

enum CategoryOption { all, actors, actresses }

class GalleryItem {
  final String url;
  final String title;
  final String? thumbnailUrl;
  final int pages;
  final DateTime date;

  GalleryItem({
    required this.url,
    required this.title,
    this.thumbnailUrl,
    required this.pages,
    required this.date,
  });
}

class FavoriteItem {
  final String type;
  final String name;
  final String url;
  final String? thumbnailUrl;
  final String? celebrityName;

  FavoriteItem({
    required this.type,
    required this.name,
    required this.url,
    this.thumbnailUrl,
    this.celebrityName,
  });

  Map<String, String> toJson() => {
    'type': type,
    'name': name,
    'url': url,
    'thumbnailUrl': thumbnailUrl ?? '',
    'celebrityName': celebrityName ?? '',
  };

  factory FavoriteItem.fromJson(Map<String, String> json) => FavoriteItem(
    type: json['type']!,
    name: json['name']!,
    url: json['url']!,
    thumbnailUrl: json['thumbnailUrl']!.isEmpty ? null : json['thumbnailUrl'],
    celebrityName:
    json['celebrityName']!.isEmpty ? null : json['celebrityName'],
  );
}

typedef DownloadSelectedCallback = void Function(
    String url, String folder, String? galleryTitle);