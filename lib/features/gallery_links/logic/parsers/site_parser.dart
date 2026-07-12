import 'package:html/dom.dart' as dom;
import '../../../downloader/logic/downloader_service.dart';
import 'idlebrain.dart';
import 'ragalahari.dart';
import 'behindwoods.dart';
import 'imgbb.dart';
import 'telugu_one.dart';

export 'idlebrain.dart';
export 'ragalahari.dart';
export 'behindwoods.dart';
export 'imgbb.dart';
export 'telugu_one.dart';

abstract class SiteParser {
  List<String> extractGalleryLinks(dom.Document document, String profileUrl);
  String extractTitle(dom.Document document, String link);
  String? extractThumbnail(dom.Document document, String link);
  int getPages(dom.Document document);
  DateTime getDate(dom.Document document);
  List<ImageData> extractImageUrls(dom.Document document, String baseUrl);
  String extractGalleryId(String url);
  
  // New methods for site-specific customization
  String constructPageUrl(String baseUrl, String galleryId, int index);
  String get defaultMainFolderName;
  String? suggestFolderName(String url);
  String getSubFolderName(String mainFolderName, String galleryId);
}

class ParserFactory {
  static const List<String> supportedDomains = [
    'idlebrain.com',
    'ragalahari.com',
    'ragalhari.com',
    'behindwoods.com',
    'ibb.co',
    'imgbb.com',
    'imgbb.co',
    'teluguone.com',
  ];

  static bool isSupported(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.isNotEmpty && supportedDomains.any((domain) => lowerUrl.contains(domain));
  }

  static SiteParser getParser(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('idlebrain.com')) {
      return IdlebrainParser();
    }
    if (lowerUrl.contains('behindwoods.com')) {
      return BehindwoodsParser();
    }
    if (lowerUrl.contains('ibb.co') ||
        lowerUrl.contains('imgbb.com') ||
        lowerUrl.contains('imgbb.co')) {
      return ImgBBParser();
    }
    if (lowerUrl.contains('teluguone.com')) {
      return TeluguOneParser();
    }
    return RagalahariParser();
  }
}
