import 'package:http/http.dart' as http;
import '../utils/latest_parser.dart';
import '../models/latest_item.dart';

class LatestScraperService {
  Future<List<LatestItem>> fetchStarzoneLinks(String targetUrl) async {
    final response = await http.get(Uri.parse(targetUrl));
    if (response.statusCode == 200) {
      return LatestParser.parseHtml(response.body);
    }
    throw Exception('Failed to load data');
  }
}
