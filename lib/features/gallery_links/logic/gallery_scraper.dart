import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../../../shared/utils/celebrity_utils.dart';
import '../../../core/services/dio_client.dart';
import '../models/scraping_models.dart';
import 'parsers/site_parser.dart';

class GalleryScraper {
  final Map<String, String> _headers = headers;
  final List<String> _thumbnailDomains = thumbnailDomains;

  Future<GalleryScrapingResult> fetchGalleryUrls(String profileUrl) async {
    final scrapingData = GalleryScrapingData(
      profileUrl: profileUrl,
      headers: _headers,
      thumbnailDomains: _thumbnailDomains,
    );

    final result = await Isolate.run(() => _fetchUrlsIsolate(scrapingData));
    if (result.error != null) {
      throw Exception(result.error);
    }
    return result;
  }

  Future<GalleryScrapingResult> loadBatchItems(List<String> urls) async {
    final batchData = BatchScrapingData(
      urls: urls,
      headers: _headers,
      thumbnailDomains: _thumbnailDomains,
    );

    return await Isolate.run(() => _loadBatchIsolate(batchData));
  }

  Future<bool> checkGalleryAvailability(String galleryUrl) async {
    try {
      final response = await DioClient().dio.get<String>(
        galleryUrl,
        options: Options(
          headers: _headers,
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      if (response.statusCode != 200 || response.data == null) return false;

      final document = html_parser.parse(response.data!);
      final images = document.getElementsByTagName('img');
      for (final dom.Element img in images) {
        final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
        if (_thumbnailDomains.any((String domain) => src.contains(domain))) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<GalleryScrapingResult> _fetchUrlsIsolate(GalleryScrapingData data) async {
    try {
      final response = await DioClient().dio.get<String>(
        data.profileUrl,
        options: Options(
          headers: data.headers,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return GalleryScrapingResult(error: 'Failed to load page: ${response.statusCode}');
      }

      final document = html_parser.parse(response.data!);
      final urls = _extractGalleryLinksIsolate(document, data.profileUrl);
      return GalleryScrapingResult(urls: urls);
    } on DioException catch (de) {
      if (de.type == DioExceptionType.connectionTimeout ||
          de.type == DioExceptionType.receiveTimeout ||
          de.type == DioExceptionType.sendTimeout ||
          de.type == DioExceptionType.connectionError) {
        return GalleryScrapingResult(error: 'Slow internet connection. Please try again.');
      } else {
        return GalleryScrapingResult(error: 'Network error: ${de.message}');
      }
    } catch (e) {
      return GalleryScrapingResult(error: 'Failed to fetch URLs: $e');
    }
  }

  static List<String> _extractGalleryLinksIsolate(dom.Document document, String profileUrl) {
    final parser = ParserFactory.getParser(profileUrl);
    return parser.extractGalleryLinks(document, profileUrl);
  }

  static Future<GalleryScrapingResult> _loadBatchIsolate(BatchScrapingData data) async {
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
      return GalleryScrapingResult(items: items);
    } catch (e) {
      return GalleryScrapingResult(error: 'Failed to load batch: $e');
    }
  }

  static Future<GalleryItem?> _processSingleLinkIsolate(
    String link,
    Map<String, String> headers,
    List<String> thumbnailDomains,
  ) async {
    try {
      final response = await DioClient().dio.get<String>(
        link,
        options: Options(
          headers: headers,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      if (response.statusCode != 200 || response.data == null) return null;

      final document = html_parser.parse(response.data!);
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
    } on DioException catch (_) {
      return null;
    } catch (e) {
      return null;
    }
  }
}