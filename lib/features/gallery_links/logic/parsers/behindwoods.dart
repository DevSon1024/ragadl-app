import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import '../../../../core/services/dio_client.dart';
import '../../../downloader/logic/downloader_service.dart';
import 'site_parser.dart';

class BehindwoodsScraper {
  bool looksLikeGalleryImage(String url) {
    final u = url.toLowerCase();
    final extRegex = RegExp(r'\.(jpg|jpeg|png|webp)(\?.*)?$', caseSensitive: false);
    if (!extRegex.hasMatch(u)) {
      return false;
    }
    const badKeywords = [
      'logo', 'banner', 'icon', 'sprite', 'spacer', 'ads', 'adserver',
      'gpt', 'google', 'doubleclick', 'button', 'btn', 'creative',
      'header', 'footer', 'template', 'design', 'behindwoodsglobe', 'bw-3d',
      'bw-gold', 'bw_gold', 'play-icon', 'favicon', 'loading', 'share',
      'social', 'facebook', 'twitter', 'youtube', 'instagram', 'prev', 'next',
      '/images/behindwoods', 'behindwoods.png', 'behindwoods.jpg', 'behindwoods-logo',
      'bw-logo', 'bwlogo', 'ic_launcher', 'ic_', 'launcher', '/images/app/', '/app/'
    ];
    if (badKeywords.any((keyword) => u.contains(keyword))) {
      return false;
    }
    return true;
  }

  String getThumbnailUrl(String originalUrl) {
    try {
      final uri = Uri.parse(originalUrl);
      final segments = List<String>.from(uri.pathSegments);
      if (segments.isNotEmpty) {
        final last = segments.last;
        segments[segments.length - 1] = 'thumbnails';
        segments.add(last);
        return uri.replace(pathSegments: segments).toString();
      }
    } catch (_) {}
    return originalUrl;
  }

  String normalizeUrl(String baseUrl, String maybeUrl) {
    if (maybeUrl.isEmpty) {
      return '';
    }
    try {
      final cleaned = maybeUrl.trim().replaceAll(r'\/', '/');
      return Uri.parse(baseUrl).resolve(cleaned).toString();
    } catch (_) {
      return '';
    }
  }

  List<String> buildRangeUrls(String startUrl, int fromNum, int toNum) {
    if (fromNum > toNum) {
      throw ArgumentError("'from' number cannot be greater than 'to' number");
    }
    final regex = RegExp(r'(.+?-)(\d+)(\.html)$', caseSensitive: false);
    final match = regex.firstMatch(startUrl);
    if (match == null) {
      throw ArgumentError("Could not detect numeric page pattern in URL");
    }
    final prefix = match.group(1)!;
    final suffix = match.group(3)!;
    
    final List<String> urls = [];
    for (int n = fromNum; n <= toNum; n++) {
      urls.add('$prefix$n$suffix');
    }
    return urls;
  }

  List<String> extractImagesFromHtml(String html, String pageUrl) {
    final document = html_parser.parse(html);
    final Set<String> found = {};
    const attrsToCheck = ["src", "data-src", "data-lazy", "data-original", "content", "href"];
    
    for (final element in document.querySelectorAll('*')) {
      for (final attr in attrsToCheck) {
        final val = element.attributes[attr];
        if (val != null && val.isNotEmpty) {
          final full = normalizeUrl(pageUrl, val);
          if (looksLikeGalleryImage(full)) {
            found.add(full);
          }
        }
      }
    }
    
    final regexes = [
      RegExp(r'''https?://[^"']+\.(?:jpg|jpeg|png|webp)(?:\?[^"']*)?''', caseSensitive: false),
      RegExp(r'''//[^"']+\.(?:jpg|jpeg|png|webp)(?:\?[^"']*)?''', caseSensitive: false),
      RegExp(r'''/[^"']+\.(?:jpg|jpeg|png|webp)(?:\?[^"']*)?''', caseSensitive: false),
      RegExp(r'''["']([^"']+\.(?:jpg|jpeg|png|webp)(?:\?[^"']*)?)["']''', caseSensitive: false),
    ];
    
    for (final reg in regexes) {
      final matches = reg.allMatches(html);
      for (final m in matches) {
        final matchedText = m.groupCount > 0 ? m.group(1) : m.group(0);
        if (matchedText != null && matchedText.isNotEmpty) {
          final full = normalizeUrl(pageUrl, matchedText);
          if (looksLikeGalleryImage(full)) {
            found.add(full);
          }
        }
      }
    }
    
    final sorted = found.toList()..sort();
    return sorted;
  }

  Future<List<ImageData>> scrapeRange(
    String startUrl,
    int from,
    int to, {
    void Function(int pagesScraped, int totalPages)? onProgress,
  }) async {
    final pageUrls = buildRangeUrls(startUrl, from, to);
    final totalPages = pageUrls.length;
    final Set<String> allImageUrls = {};
    final dio = DioClient().dio;
    const chunkSize = 5;
    
    int pagesScraped = 0;
    for (int i = 0; i < totalPages; i += chunkSize) {
      final end = (i + chunkSize < totalPages) ? i + chunkSize : totalPages;
      final chunk = pageUrls.sublist(i, end);
      
      final futures = chunk.map((pageUrl) async {
        try {
          final response = await dio.get<String>(
            pageUrl,
            options: Options(
              headers: {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
                "Referer": "https://www.behindwoods.com/",
              },
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
            ),
          );
          if (response.statusCode == 200 && response.data != null) {
            final imgs = extractImagesFromHtml(response.data!, pageUrl);
            return imgs;
          }
        } catch (_) {}
        return <String>[];
      }).toList();
      
      final chunkResults = await Future.wait(futures);
      for (final imgs in chunkResults) {
        allImageUrls.addAll(imgs);
      }
      
      pagesScraped += chunk.length;
      if (onProgress != null) {
        onProgress(pagesScraped, totalPages);
      }
    }
    
    return allImageUrls.map((url) {
      return ImageData(thumbnailUrl: getThumbnailUrl(url), originalUrl: url);
    }).toList();
  }

  static String getFolderNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        return segments[segments.length - 2];
      }
    } catch (_) {}
    return "BehindwoodsDownloads";
  }
}

class BehindwoodsParser implements SiteParser {
  @override
  List<String> extractGalleryLinks(dom.Document document, String profileUrl) {
    return [];
  }

  @override
  String extractTitle(dom.Document document, String link) {
    final titleElement = document.querySelector('title') ??
        document.querySelector('h1') ??
        document.querySelector('h2');
    if (titleElement != null && titleElement.text.trim().isNotEmpty) {
      return titleElement.text.trim();
    }
    return BehindwoodsScraper.getFolderNameFromUrl(link);
  }

  @override
  String? extractThumbnail(dom.Document document, String link) {
    return null;
  }

  @override
  int getPages(dom.Document document) {
    return 1;
  }

  @override
  DateTime getDate(dom.Document document) {
    return DateTime.now();
  }

  @override
  List<ImageData> extractImageUrls(dom.Document document, String baseUrl) {
    final scraper = BehindwoodsScraper();
    final imgs = scraper.extractImagesFromHtml(document.outerHtml, baseUrl);
    return imgs.map((u) => ImageData(thumbnailUrl: scraper.getThumbnailUrl(u), originalUrl: u)).toList();
  }

  @override
  String extractGalleryId(String url) {
    return BehindwoodsScraper.getFolderNameFromUrl(url);
  }

  @override
  String constructPageUrl(String baseUrl, String galleryId, int index) {
    return baseUrl;
  }

  @override
  String get defaultMainFolderName => 'BehindwoodsDownloads';

  @override
  String? suggestFolderName(String url) {
    return BehindwoodsScraper.getFolderNameFromUrl(url);
  }

  @override
  String getSubFolderName(String mainFolderName, String galleryId) {
    if (mainFolderName == galleryId) {
      return mainFolderName;
    }
    return '$mainFolderName-$galleryId';
  }
}
