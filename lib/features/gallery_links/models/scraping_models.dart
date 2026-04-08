// lib/features/gallery_links/models/scraping_models.dart

// 1. IMPORT the original GalleryItem from your celebrity utils
import '../../celebrity/utils/celebrity_utils.dart';

// DO NOT define "class GalleryItem" in this file!
// We are only using the one imported above.

// Data class for passing data to isolate
class GalleryScrapingData {
  final String profileUrl;
  final Map<String, String> headers;
  final List<String> thumbnailDomains;

  GalleryScrapingData({
    required this.profileUrl,
    required this.headers,
    required this.thumbnailDomains,
  });
}

// Data class for batch scraping
class BatchScrapingData {
  final List<String> urls;
  final Map<String, String> headers;
  final List<String> thumbnailDomains;

  BatchScrapingData({
    required this.urls,
    required this.headers,
    required this.thumbnailDomains,
  });
}

// Data class for isolate results
class GalleryScrapingResult {
  final List<String>? urls;
  final List<GalleryItem>? items; // This now safely uses the imported GalleryItem
  final String? error;

  GalleryScrapingResult({
    this.urls,
    this.items,
    this.error
  });
}