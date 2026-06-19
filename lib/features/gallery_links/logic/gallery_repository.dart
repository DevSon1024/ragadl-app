import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gallery_scraper.dart';
import '../models/scraping_models.dart';

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepository(GalleryScraper());
});

class GalleryRepository {
  final GalleryScraper _scraper;

  GalleryRepository(this._scraper);

  Future<GalleryScrapingResult> fetchGalleryUrls(String profileUrl) {
    return _scraper.fetchGalleryUrls(profileUrl);
  }

  Future<GalleryScrapingResult> loadBatchItems(List<String> urls) {
    return _scraper.loadBatchItems(urls);
  }

  Future<bool> checkGalleryAvailability(String galleryUrl) {
    return _scraper.checkGalleryAvailability(galleryUrl);
  }
}
