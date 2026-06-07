import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'site_parser.dart';
import '../../downloader/logic/downloader_service.dart';

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
    _removeUnwantedDivs(document);
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

  @override
  String constructPageUrl(String baseUrl, String galleryId, int index) {
    if (index == 0) return baseUrl;
    return baseUrl.replaceAll(RegExp("$galleryId/?"), "$galleryId/$index/");
  }

  @override
  String get defaultMainFolderName => 'RagaDownloads';

  @override
  String? suggestFolderName(String url) => null;

  @override
  String getSubFolderName(String mainFolderName, String galleryId) {
    return '$mainFolderName-$galleryId';
  }

  void _removeUnwantedDivs(dom.Document document) {
    final unwantedHeadings = <String>{
      "Latest Local Events",
      "Latest Movie Events",
      "Latest Starzone",
    };

    for (final dom.Element div in document.querySelectorAll("div#btmlatest")) {
      final h4 = div.querySelector("h4");
      if (h4 != null && unwantedHeadings.contains(h4.text.trim())) {
        div.remove();
      }
    }

    for (final String badId in <String>["taboolaandnews", "news_panel"]) {
      final div = document.querySelector("div#$badId");
      div?.remove();
    }
  }
}
