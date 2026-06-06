import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import '../../downloader/logic/downloader_service.dart';

abstract class SiteParser {
  List<String> extractGalleryLinks(dom.Document document, String profileUrl);
  String extractTitle(dom.Document document, String link);
  String? extractThumbnail(dom.Document document, String link);
  int getPages(dom.Document document);
  DateTime getDate(dom.Document document);
  List<ImageData> extractImageUrls(dom.Document document, String baseUrl);
  String extractGalleryId(String url);
}

class ParserFactory {
  static SiteParser getParser(String url) {
    if (url.toLowerCase().contains('idlebrain.com')) {
      return IdlebrainParser();
    }
    return RagalahariParser();
  }
}

class RagalahariParser implements SiteParser {
  @override
  List<String> extractGalleryLinks(dom.Document document, String profileUrl) {
    final galleriesPanel = document.getElementById('galleries_panel');
    if (galleriesPanel == null) return <String>[];

    return galleriesPanel.getElementsByClassName('galimg')
        .map((dom.Element element) => element.attributes['href'] ?? '')
        .where((String href) => href.isNotEmpty)
        .map((String href) => Uri.parse(profileUrl).resolve(href).toString())
        .toList();
  }

  @override
  String extractTitle(dom.Document document, String link) {
    final titleElement = document.querySelector('h1.gallerytitle') ??
        document.querySelector('.gallerytitle') ??
        document.querySelector('h1');
    if (titleElement != null && titleElement.text.trim().isNotEmpty) {
      return titleElement.text.trim();
    }
    final pathSegments = Uri.parse(link).pathSegments.where((String s) => s.isNotEmpty).toList();
    if (pathSegments.length > 2) {
      return '${pathSegments[pathSegments.length - 2]}-${pathSegments.last.replaceAll(".aspx", "")}';
    }
    return link.split('/').last.replaceAll(".aspx", "");
  }

  @override
  String? extractThumbnail(dom.Document document, String link) {
    final List<String> thumbnailDomains = <String>[
      "media.ragalahari.com",
      "img.ragalahari.com",
      "szcdn.ragalahari.com",
      "starzone.ragalahari.com",
      "imgcdn.ragalahari.com",
    ];
    for (final dom.Element img in document.getElementsByTagName('img')) {
      final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
      if (thumbnailDomains.any((String domain) => src.contains(domain))) return src;
    }
    return null;
  }

  @override
  int getPages(dom.Document document) {
    final pageLinks = document.getElementsByClassName('otherPage');
    if (pageLinks.isEmpty) return 1;
    int maxPage = 1;
    for (final dom.Element element in pageLinks) {
      final val = int.tryParse(element.text.trim()) ?? 1;
      if (val > maxPage) maxPage = val;
    }
    return maxPage;
  }

  @override
  DateTime getDate(dom.Document document) {
    try {
      final dateStr = document.querySelector('.gallerydate time')?.text.trim() ?? '';
      if (dateStr.startsWith('Updated on ')) {
        return DateFormat('MMMM dd, yyyy').parse(dateStr.substring(11));
      }
    } catch (_) {}
    return DateTime.now();
  }

  @override
  List<ImageData> extractImageUrls(dom.Document document, String baseUrl) {
    final Set<ImageData> imageDataSet = <ImageData>{};
    for (final dom.Element img in document.querySelectorAll("img")) {
      final src = img.attributes['src'];
      if (src == null ||
          !src.toLowerCase().endsWith(".jpg") ||
          (!src.startsWith("http") && !src.startsWith("../"))) {
        continue;
      }

      String thumbnailUrl =
          src.startsWith("http")
              ? src
              : "https://www.ragalahari.com/${src.replaceAll("../", "")}";

      String originalUrl = thumbnailUrl.replaceAll(
        RegExp(r't(?=\.jpg)', caseSensitive: false),
        '',
      );

      final parentA = img.parent?.querySelector('a');
      if (parentA != null && parentA.attributes['href'] != null) {
        final href = parentA.attributes['href']!;
        if (href.toLowerCase().endsWith('.jpg')) {
          originalUrl =
              href.startsWith('http') ? href : "https://www.ragalahari.com/$href";
        }
      }

      imageDataSet.add(
        ImageData(thumbnailUrl: thumbnailUrl, originalUrl: originalUrl),
      );
    }
    return imageDataSet.toList();
  }

  @override
  String extractGalleryId(String url) {
    final RegExp regex = RegExp(r"/(\d+)/");
    final match = regex.firstMatch(url);
    return match?.group(1) ?? url.hashCode.abs().toString();
  }
}

class IdlebrainParser implements SiteParser {
  @override
  List<String> extractGalleryLinks(dom.Document document, String profileUrl) {
    final Set<String> links = <String>{};
    for (final dom.Element a in document.getElementsByTagName('a')) {
      final href = a.attributes['href'];
      if (href != null && href.isNotEmpty) {
        final resolved = Uri.parse(profileUrl).resolve(href).toString();
        if (resolved.contains('/photogallery/') &&
            resolved.endsWith('.html') &&
            !resolved.contains('/pages/image') &&
            resolved != profileUrl) {
          links.add(resolved);
        }
      }
    }
    return links.toList();
  }

  @override
  String extractTitle(dom.Document document, String link) {
    final titleElement = document.querySelector('title') ??
        document.querySelector('h1') ??
        document.querySelector('h2');
    if (titleElement != null && titleElement.text.trim().isNotEmpty) {
      return titleElement.text.trim();
    }
    final pathSegments = Uri.parse(link).pathSegments.where((String s) => s.isNotEmpty).toList();
    if (pathSegments.length >= 2) {
      return pathSegments[pathSegments.length - 2];
    }
    return link.split('/').last.replaceAll(".html", "");
  }

  @override
  String? extractThumbnail(dom.Document document, String link) {
    for (final dom.Element img in document.getElementsByTagName('img')) {
      final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
      if (src.toLowerCase().contains('/images/th_') || src.toLowerCase().startsWith('images/th_')) {
        return Uri.parse(link).resolve(src).toString();
      }
    }
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
    final Set<ImageData> imageDataSet = <ImageData>{};
    
    for (final dom.Element img in document.querySelectorAll('td.thumbnail_image img')) {
      final src = img.attributes['src'];
      if (src != null && src.isNotEmpty) {
        final resolvedUrl = Uri.parse(baseUrl).resolve(src).toString();
        final originalUrl = _transformUrl(resolvedUrl);
        imageDataSet.add(ImageData(thumbnailUrl: resolvedUrl, originalUrl: originalUrl));
      }
    }
    
    if (imageDataSet.isEmpty) {
      for (final dom.Element img in document.querySelectorAll('img')) {
        final src = img.attributes['src'];
        if (src != null && src.isNotEmpty) {
          final srcLower = src.toLowerCase();
          if (srcLower.contains('/images/th_') || srcLower.contains('images/th_')) {
            final resolvedUrl = Uri.parse(baseUrl).resolve(src).toString();
            final originalUrl = _transformUrl(resolvedUrl);
            imageDataSet.add(ImageData(thumbnailUrl: resolvedUrl, originalUrl: originalUrl));
          }
        }
      }
    }
    
    if (imageDataSet.isEmpty) {
      for (final dom.Element a in document.querySelectorAll('a')) {
        final href = a.attributes['href'];
        if (href != null && href.isNotEmpty && href.contains('/pages/image')) {
          final img = a.querySelector('img');
          final src = img?.attributes['src'];
          if (src != null && src.isNotEmpty) {
            final resolvedUrl = Uri.parse(baseUrl).resolve(src).toString();
            final originalUrl = _transformUrl(resolvedUrl);
            imageDataSet.add(ImageData(thumbnailUrl: resolvedUrl, originalUrl: originalUrl));
          }
        }
      }
    }
    
    return imageDataSet.toList();
  }

  String _transformUrl(String thumbnailUrl) {
    final uri = Uri.tryParse(thumbnailUrl);
    if (uri == null) return thumbnailUrl;
    final segments = List<String>.from(uri.pathSegments);
    if (segments.isNotEmpty) {
      final last = segments.last;
      if (last.toLowerCase().startsWith('th_')) {
        segments[segments.length - 1] = last.substring(3);
      }
    }
    return uri.replace(pathSegments: segments).toString();
  }

  @override
  String extractGalleryId(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final segments = uri.pathSegments.where((String s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        if (segments.last.toLowerCase() == 'index.html' || segments.last.toLowerCase().endsWith('.html')) {
          return segments[segments.length - 2];
        }
        return segments.last;
      }
    }
    return url.hashCode.abs().toString();
  }
}
