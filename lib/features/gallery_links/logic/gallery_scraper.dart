import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../../../shared/utils/celebrity_utils.dart';
import '../models/scraping_models.dart';
import 'site_parser.dart';

class GalleryScraper {
  final Map<String, String> _headers = headers;
  final List<String> _thumbnailDomains = thumbnailDomains;

  Future<GalleryScrapingResult> fetchGalleryUrls(String profileUrl) async {
    final receivePort = ReceivePort();
    final scrapingData = GalleryScrapingData(
      profileUrl: profileUrl,
      headers: _headers,
      thumbnailDomains: _thumbnailDomains,
    );

    await Isolate.spawn(_fetchUrlsIsolate, <dynamic>[receivePort.sendPort, scrapingData]);
    return await receivePort.first as GalleryScrapingResult;
  }

  Future<GalleryScrapingResult> loadBatchItems(List<String> urls) async {
    final receivePort = ReceivePort();
    final batchData = BatchScrapingData(
      urls: urls,
      headers: _headers,
      thumbnailDomains: _thumbnailDomains,
    );

    await Isolate.spawn(_loadBatchIsolate, <dynamic>[receivePort.sendPort, batchData]);
    return await receivePort.first as GalleryScrapingResult;
  }

  Future<bool> checkGalleryAvailability(String galleryUrl) async {
    try {
      final response = await http.get(Uri.parse(galleryUrl), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;

      final document = html_parser.parse(response.body);
      final images = document.getElementsByTagName('img');
      for (final dom.Element img in images) {
        final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
        if (galleryUrl.toLowerCase().contains('idlebrain.com')) {
          if (src.toLowerCase().contains('/images/th_') || src.toLowerCase().startsWith('images/th_')) {
            return true;
          }
        } else {
          if (_thumbnailDomains.any((String domain) => src.contains(domain))) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _fetchUrlsIsolate(List<dynamic> args) async {
    final SendPort sendPort = args[0] as SendPort;
    final GalleryScrapingData data = args[1] as GalleryScrapingData;

    try {
      final response = await http.get(Uri.parse(data.profileUrl), headers: data.headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        sendPort.send(GalleryScrapingResult(error: 'Failed to load page: ${response.statusCode}'));
        return;
      }

      final document = html_parser.parse(response.body);
      final urls = _extractGalleryLinksIsolate(document, data.profileUrl);
      sendPort.send(GalleryScrapingResult(urls: urls));
    } catch (e) {
      sendPort.send(GalleryScrapingResult(error: 'Failed to fetch URLs: $e'));
    }
  }

  static List<String> _extractGalleryLinksIsolate(dom.Document document, String profileUrl) {
    final parser = ParserFactory.getParser(profileUrl);
    return parser.extractGalleryLinks(document, profileUrl);
  }

  static Future<void> _loadBatchIsolate(List<dynamic> args) async {
    final SendPort sendPort = args[0] as SendPort;
    final BatchScrapingData data = args[1] as BatchScrapingData;

    try {
      final List<GalleryItem> items = <GalleryItem>[];
      const int chunkSize = 5;
      for (int i = 0; i < data.urls.length; i += chunkSize) {
        final int end = (i + chunkSize < data.urls.length) ? i + chunkSize : data.urls.length;
        final List<String> chunk = data.urls.sublist(i, end);
        final List<Future<GalleryItem?>> futures = chunk.map((String url) =>
            _processSingleLinkIsolate(url, data.headers, data.thumbnailDomains)).toList();
        final List<GalleryItem?> results = await Future.wait(futures);
        items.addAll(results.whereType<GalleryItem>());
      }
      sendPort.send(GalleryScrapingResult(items: items));
    } catch (e) {
      sendPort.send(GalleryScrapingResult(error: 'Failed to load batch: $e'));
    }
  }

  static Future<GalleryItem?> _processSingleLinkIsolate(
    String link,
    Map<String, String> headers,
    List<String> thumbnailDomains,
  ) async {
    try {
      final response = await http.get(Uri.parse(link), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final document = html_parser.parse(response.body);
      final parser = ParserFactory.getParser(link);
      
      final title = parser.extractTitle(document, link);
      final thumbnailUrl = parser.extractThumbnail(document, link);
      final pages = parser.getPages(document);
      final date = parser.getDate(document);

      return GalleryItem(
        url: link,
        title: title,
        thumbnailUrl: thumbnailUrl,
        pages: pages,
        date: date,
      );
    } catch (e) {
      return null;
    }
  }
}