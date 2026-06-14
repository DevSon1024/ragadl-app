import 'package:html/dom.dart' as dom;
import 'site_parser.dart';
import '../../downloader/logic/downloader_service.dart';

class ImgBBParser implements SiteParser {
  @override
  List<String> extractGalleryLinks(dom.Document document, String profileUrl) => [];

  @override
  String extractTitle(dom.Document document, String link) {
    return 'ImgBB Gallery';
  }

  @override
  String? extractThumbnail(dom.Document document, String link) => null;

  @override
  int getPages(dom.Document document) => 1;

  @override
  DateTime getDate(dom.Document document) => DateTime.now();

  @override
  List<ImageData> extractImageUrls(dom.Document document, String baseUrl) => [];

  @override
  String extractGalleryId(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (uri.pathSegments.isNotEmpty) {
        // Look for the last non-empty segment
        final segment = uri.pathSegments.lastWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );
        if (segment.isNotEmpty) return segment;
      }
    } catch (_) {}
    return 'imgbb';
  }

  @override
  String constructPageUrl(String baseUrl, String galleryId, int index) => baseUrl;

  @override
  String get defaultMainFolderName => 'ImgBB';

  @override
  String? suggestFolderName(String url) {
    try {
      final uri = Uri.parse(url.trim());
      if (uri.pathSegments.isNotEmpty) {
        final segment = uri.pathSegments.lastWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );
        if (segment.isNotEmpty) return segment;
      }
    } catch (_) {}
    return 'ImgBB';
  }

  @override
  String getSubFolderName(String mainFolderName, String galleryId) {
    return '$mainFolderName-$galleryId';
  }
}
