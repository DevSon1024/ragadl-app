import 'package:html/dom.dart' as dom;
import 'site_parser.dart';
import '../../../downloader/logic/downloader_service.dart';

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

  @override
  String constructPageUrl(String baseUrl, String galleryId, int index) {
    return baseUrl;
  }

  @override
  String get defaultMainFolderName => 'IdlebrainDownloads';

  @override
  String? suggestFolderName(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final segments = uri.pathSegments.where((String s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        final last = segments.last.toLowerCase();
        if (last == 'index.html' || last.endsWith('.html')) {
          return segments[segments.length - 2];
        }
        return segments.last;
      }
    } catch (_) {}
    return null;
  }

  @override
  String getSubFolderName(String mainFolderName, String galleryId) {
    if (mainFolderName == galleryId) {
      return mainFolderName;
    }
    return '$mainFolderName-$galleryId';
  }
}
