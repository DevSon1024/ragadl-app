// lib/features/gallery_links/utils/gallery_utils.dart

class GalleryUtils {
  /// Standard headers required to bypass basic anti-bot protections
  /// when scraping gallery HTML pages.
  static const Map<String, String> scrapingHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  };

  /// List of substrings commonly found in thumbnail URLs.
  /// Used by the scraper to quickly identify valid image sources in the DOM.
  static const List<String> thumbnailDomains = [
    'thumb',
    'thumbs',
    'cdn',
    'images',
    'media',
    'gallery',
    'preview',
  ];

  /// Helper method to extract a clean gallery ID from a URL for searching/filtering
  static String? extractGalleryId(String url) {
    return url.split('/')
        .where((segment) => RegExp(r'^\d+$').hasMatch(segment))
        .firstOrNull;
  }
}