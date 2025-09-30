// Headers for HTTP requests
final Map<String, String> headers = {
  'User-Agent':
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
  'Accept':
  'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
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