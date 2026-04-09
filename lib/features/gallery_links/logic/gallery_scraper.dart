import 'dart:isolate';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import '../../../shared/utils/celebrity_utils.dart';
import '../models/scraping_models.dart';

class GalleryScraper {
  // Using global constants assuming they were imported from celebrity_utils.dart
  final Map<String, String> _headers = headers;
  final List<String> _thumbnailDomains = thumbnailDomains;

  Future<GalleryScrapingResult> fetchGalleryUrls(String profileUrl) async {
    final receivePort = ReceivePort();
    final scrapingData = GalleryScrapingData(
      profileUrl: profileUrl,
      headers: _headers,
      thumbnailDomains: _thumbnailDomains,
    );

    await Isolate.spawn(_fetchUrlsIsolate, [receivePort.sendPort, scrapingData]);
    return await receivePort.first as GalleryScrapingResult;
  }

  Future<GalleryScrapingResult> loadBatchItems(List<String> urls) async {
    final receivePort = ReceivePort();
    final batchData = BatchScrapingData(
      urls: urls,
      headers: _headers,
      thumbnailDomains: _thumbnailDomains,
    );

    await Isolate.spawn(_loadBatchIsolate, [receivePort.sendPort, batchData]);
    return await receivePort.first as GalleryScrapingResult;
  }

  Future<bool> checkGalleryAvailability(String galleryUrl) async {
    try {
      final response = await http.get(Uri.parse(galleryUrl), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;

      final document = html_parser.parse(response.body);
      final images = document.getElementsByTagName('img');
      for (final img in images) {
        final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
        if (_thumbnailDomains.any((domain) => src.contains(domain))) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _fetchUrlsIsolate(List<dynamic> args) async {
    final SendPort sendPort = args[0];
    final GalleryScrapingData data = args[1];

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
    final galleriesPanel = document.getElementById('galleries_panel');
    if (galleriesPanel == null) return [];

    return galleriesPanel.getElementsByClassName('galimg')
        .map((element) => element.attributes['href'] ?? '')
        .where((href) => href.isNotEmpty)
        .map((href) => Uri.parse(profileUrl).resolve(href).toString())
        .toList();
  }

  static Future<void> _loadBatchIsolate(List<dynamic> args) async {
    final SendPort sendPort = args[0];
    final BatchScrapingData data = args[1];

    try {
      final futures = data.urls.map((url) =>
          _processSingleLinkIsolate(url, data.headers, data.thumbnailDomains)).toList();
      final results = await Future.wait(futures);
      final items = results.whereType<GalleryItem>().toList();
      sendPort.send(GalleryScrapingResult(items: items));
    } catch (e) {
      sendPort.send(GalleryScrapingResult(error: 'Failed to load batch: $e'));
    }
  }

  static Future<GalleryItem?> _processSingleLinkIsolate(String link, Map<String, String> headers, List<String> thumbnailDomains) async {
    try {
      final response = await http.get(Uri.parse(link), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final document = html_parser.parse(response.body);
      String title = _extractTitle(document, link);
      String? thumbnailUrl = _extractThumbnail(document, thumbnailDomains);
      final (pages, date) = await _getGalleryInfoIsolate(link, headers);

      return GalleryItem(url: link, title: title, thumbnailUrl: thumbnailUrl, pages: pages, date: date);
    } catch (e) {
      return null;
    }
  }

  static String _extractTitle(dom.Document document, String link) {
    final titleElement = document.querySelector('h1.gallerytitle') ??
        document.querySelector('.gallerytitle') ??
        document.querySelector('h1');
    if (titleElement != null && titleElement.text.trim().isNotEmpty) {
      return titleElement.text.trim();
    }
    final pathSegments = Uri.parse(link).pathSegments.where((s) => s.isNotEmpty).toList();
    if (pathSegments.length > 2) {
      return '${pathSegments[pathSegments.length - 2]}-${pathSegments.last.replaceAll(".aspx", "")}';
    }
    return link.split('/').last.replaceAll(".aspx", "");
  }

  static String? _extractThumbnail(dom.Document document, List<String> thumbnailDomains) {
    for (final img in document.getElementsByTagName('img')) {
      final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
      if (thumbnailDomains.any((domain) => src.contains(domain))) return src;
    }
    return null;
  }

  static Future<(int, DateTime)> _getGalleryInfoIsolate(String url, Map<String, String> headers) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return (1, DateTime(1900));

      final document = html_parser.parse(response.body);
      final pageLinks = document.getElementsByClassName('otherPage');
      final lastPage = pageLinks.isEmpty ? 1 : pageLinks.map((e) => int.tryParse(e.text.trim()) ?? 1).reduce(max);
      final dateStr = document.querySelector('.gallerydate time')?.text.trim() ?? '';
      final date = dateStr.startsWith('Updated on ') ? DateFormat('MMMM dd, yyyy').parse(dateStr.substring(11)) : DateTime.now();

      return (lastPage, date);
    } catch (e) {
      return (1, DateTime(1900));
    }
  }
}