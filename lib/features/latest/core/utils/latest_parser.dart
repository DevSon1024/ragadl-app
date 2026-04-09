import 'package:html/parser.dart' as html show parse;
import '../models/latest_item.dart';

class LatestParser {
  static const String baseUrl = 'https://www.ragalahari.com';

  static List<LatestItem> parseHtml(String htmlString) {
    final document = html.parse(htmlString);
    final columns = document.getElementsByClassName('column');

    List<LatestItem> tempList = [];

    for (var col in columns) {
      final aTag = col.querySelector('a.galimg');
      final imgTag = aTag?.querySelector('img');
      final h5Tag = col.querySelector('h5.galleryname a.galleryname');
      final h6Tag = col.querySelector('h6.gallerydate');

      final imgSrc = imgTag?.attributes['src'] ?? '';
      if (!imgSrc.endsWith('thumb.jpg')) continue;

      final partialUrl = aTag?.attributes['href'] ?? '';
      String fullUrl;
      if (partialUrl.startsWith('http')) {
        fullUrl = partialUrl;
      } else if (partialUrl.startsWith('/')) {
        fullUrl = baseUrl + partialUrl;
      } else {
        fullUrl = '$baseUrl/$partialUrl';
      }
      final galleryTitle = h5Tag?.text.trim() ?? '';
      final galleryDate = h6Tag?.text.trim() ?? '';

      tempList.add(LatestItem(
        url: fullUrl,
        image: imgSrc,
        title: galleryTitle,
        date: galleryDate,
        name: '',
        profileLink: '',
      ));
    }

    return tempList;
  }
}
