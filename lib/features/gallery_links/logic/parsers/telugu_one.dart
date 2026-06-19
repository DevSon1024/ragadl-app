import 'package:html/dom.dart' as dom;
import 'site_parser.dart';
import '../../../downloader/logic/downloader_service.dart';

/// Parser for teluguone.com galleries.
///
/// TeluguOne stores images under the path `/photos/uploadsExt/uploads/`.
/// Preview (thumbnail) images have a `_small` suffix before the extension,
/// e.g. `Rakul_Preet_Singh_Images9_small.jpg`.
/// The full-resolution original is obtained by stripping `_small` from the
/// filename, e.g. `Rakul_Preet_Singh_Images9.jpg`.
///
/// URL pattern for a gallery page:
///   https://www.teluguone.com/photos/gallery/<actor-slug>-photos-<id>.html
class TeluguOneParser implements SiteParser {
  // ---------------------------------------------------------------------------
  // Gallery index — extracts individual gallery page links from a profile/actor
  // listing page.
  // ---------------------------------------------------------------------------
  @override
  List<String> extractGalleryLinks(dom.Document document, String profileUrl) {
    final Set<String> links = <String>{};
    for (final dom.Element a in document.getElementsByTagName('a')) {
      final href = a.attributes['href'];
      if (href == null || href.isEmpty) continue;
      final resolved = Uri.parse(profileUrl).resolve(href).toString();
      // Gallery pages follow the pattern /photos/gallery/…
      if (resolved.contains('teluguone.com') &&
          resolved.contains('/photos/') &&
          resolved.endsWith('.html') &&
          resolved != profileUrl) {
        links.add(resolved);
      }
    }
    return links.toList();
  }

  // ---------------------------------------------------------------------------
  // Title
  // ---------------------------------------------------------------------------
  @override
  String extractTitle(dom.Document document, String link) {
    final titleElement = document.querySelector('h1') ??
        document.querySelector('h2') ??
        document.querySelector('title');
    if (titleElement != null && titleElement.text.trim().isNotEmpty) {
      return titleElement.text.trim();
    }
    // Fallback: derive title from URL slug
    final pathSegments =
        Uri.parse(link).pathSegments.where((s) => s.isNotEmpty).toList();
    if (pathSegments.isNotEmpty) {
      return pathSegments.last
          .replaceAll('.html', '')
          .replaceAll('-', ' ')
          .trim();
    }
    return link.split('/').last.replaceAll('.html', '');
  }

  // ---------------------------------------------------------------------------
  // Thumbnail for gallery card
  // ---------------------------------------------------------------------------
  @override
  String? extractThumbnail(dom.Document document, String link) {
    for (final dom.Element img in document.getElementsByTagName('img')) {
      final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
      if (src.contains('/photos/uploadsExt/uploads/')) {
        return src.startsWith('http')
            ? src
            : Uri.parse(link).resolve(src).toString();
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Pagination — TeluguOne galleries are single-page so always return 1.
  // ---------------------------------------------------------------------------
  @override
  int getPages(dom.Document document) => 1;

  // ---------------------------------------------------------------------------
  // Date — not reliably available; return now as fallback.
  // ---------------------------------------------------------------------------
  @override
  DateTime getDate(dom.Document document) => DateTime.now();

  // ---------------------------------------------------------------------------
  // Image extraction — core logic.
  //
  // Strategy (mirrors memo.py):
  //   1. Find every absolute URL matching a JPG/JPEG/PNG/WEBP image.
  //   2. Keep only URLs under `/photos/uploadsExt/uploads/`.
  //   3. Exclude noise paths: `/photos/assets/images/` and `/home_images/`.
  //   4. Thumbnail URL is the raw URL (may contain `_small`).
  //   5. Original URL is derived by removing `_small` before the extension.
  // ---------------------------------------------------------------------------
  @override
  List<ImageData> extractImageUrls(dom.Document document, String baseUrl) {
    final Set<ImageData> imageDataSet = <ImageData>{};

    // Collect from <img src> and <img data-src>
    for (final dom.Element img in document.querySelectorAll('img')) {
      final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
      final imageData = _processImageSrc(src, baseUrl);
      if (imageData != null) imageDataSet.add(imageData);
    }

    // Also collect from <a href> that point directly to images (some galleries
    // wrap thumbnails inside anchor tags with the full-res URL as href).
    for (final dom.Element a in document.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      final lower = href.toLowerCase();
      if ((lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.png') ||
              lower.endsWith('.webp')) &&
          href.contains('/photos/uploadsExt/uploads/') &&
          !href.contains('/photos/assets/images/') &&
          !href.contains('/home_images/')) {
        final resolved = href.startsWith('http')
            ? href
            : Uri.parse(baseUrl).resolve(href).toString();
        // When the anchor itself is a full-res link, both urls are the same.
        final originalUrl = _removeSmallSuffix(resolved);
        imageDataSet.add(
          ImageData(thumbnailUrl: resolved, originalUrl: originalUrl),
        );
      }
    }

    return imageDataSet.toList();
  }

  // ---------------------------------------------------------------------------
  // Gallery ID — use numeric segment from URL, or fallback to hash.
  // ---------------------------------------------------------------------------
  @override
  String extractGalleryId(String url) {
    // e.g. …-photos-12345.html  →  12345
    final numericMatch = RegExp(r'-(\d+)\.html$').firstMatch(url);
    if (numericMatch != null) return numericMatch.group(1)!;

    final uri = Uri.tryParse(url);
    if (uri != null) {
      final segments =
          uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        return segments.last.replaceAll('.html', '');
      }
    }
    return url.hashCode.abs().toString();
  }

  // ---------------------------------------------------------------------------
  // Page URL construction — single page, always return baseUrl.
  // ---------------------------------------------------------------------------
  @override
  String constructPageUrl(String baseUrl, String galleryId, int index) =>
      baseUrl;

  // ---------------------------------------------------------------------------
  // Folder naming
  // ---------------------------------------------------------------------------
  @override
  String get defaultMainFolderName => 'TeluguOneDownloads';

  @override
  String? suggestFolderName(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final segments =
          uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        // Strip the numeric id and ".html" to produce a clean folder name
        final slug = segments.last
            .replaceAll('.html', '')
            .replaceAll(RegExp(r'-\d+$'), '')
            .trim();
        if (slug.isNotEmpty) return slug;
      }
    } catch (_) {}
    return null;
  }

  @override
  String getSubFolderName(String mainFolderName, String galleryId) {
    if (mainFolderName == galleryId) return mainFolderName;
    return '$mainFolderName-$galleryId';
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Resolves [src] against [baseUrl] and returns an [ImageData] if it passes
  /// the TeluguOne image filter, otherwise returns null.
  ImageData? _processImageSrc(String src, String baseUrl) {
    if (src.isEmpty) return null;
    final lower = src.toLowerCase();

    // Must be an image file
    if (!lower.endsWith('.jpg') &&
        !lower.endsWith('.jpeg') &&
        !lower.endsWith('.png') &&
        !lower.endsWith('.webp')) {
      return null;
    }

    // Must be under the uploads path
    if (!src.contains('/photos/uploadsExt/uploads/')) return null;

    // Exclude noise paths
    if (src.contains('/photos/assets/images/')) return null;
    if (src.contains('/home_images/')) return null;

    final thumbnailUrl = src.startsWith('http')
        ? src
        : Uri.parse(baseUrl).resolve(src).toString();

    final originalUrl = _removeSmallSuffix(thumbnailUrl);

    return ImageData(thumbnailUrl: thumbnailUrl, originalUrl: originalUrl);
  }

  /// Removes the `_small` suffix that TeluguOne appends to preview images.
  ///
  /// `…/Image9_small.jpg`  →  `…/Image9.jpg`
  /// `…/Image9_small.jpeg` →  `…/Image9.jpeg`
  /// URLs without `_small` are returned unchanged.
  String _removeSmallSuffix(String url) {
    return url.replaceAllMapped(
      RegExp(r'_small(\.[a-zA-Z]+)$', caseSensitive: false),
      (match) => match.group(1)!,
    );
  }
}
