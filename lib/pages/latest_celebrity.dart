import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html show parse;
import 'package:html/dom.dart' as html;
import 'package:shimmer/shimmer.dart';
import 'ragalahari_downloader.dart'; // Import RagalahariDownloader
import '../screens/ragalahari_downloader_screen.dart';

class LatestCelebrityPage extends StatefulWidget {
  const LatestCelebrityPage({Key? key}) : super(key: key);

  @override
  _LatestCelebrityPageState createState() => _LatestCelebrityPageState();
}

class _LatestCelebrityPageState extends State<LatestCelebrityPage> {
  final String baseUrl = 'https://www.ragalahari.com';
  final String targetUrl = 'https://www.ragalahari.com/starzone.aspx';
  List<Map<String, String>> celebrityList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStarzoneLinks();
  }

  Future<void> fetchStarzoneLinks() async {
    try {
      final response = await http.get(Uri.parse(targetUrl));
      if (response.statusCode == 200) {
        final document = html.parse(response.body);
        final columns = document.getElementsByClassName('column');

        List<Map<String, String>> tempList = [];

        for (var col in columns) {
          final aTag = col.querySelector('a.galimg');
          final imgTag = aTag?.querySelector('img');
          final h5Tag = col.querySelector('h5.galleryname a.galleryname');
          final h6Tag = col.querySelector('h6.gallerydate');

          final imgSrc = imgTag?.attributes['src'] ?? '';
          if (!imgSrc.endsWith('thumb.jpg')) continue;

          final partialUrl = aTag?.attributes['href'] ?? '';
          final fullUrl = partialUrl.startsWith('/') ? baseUrl + partialUrl : partialUrl;
          final galleryTitle = h5Tag?.text.trim() ?? '';
          final galleryDate = h6Tag?.text.trim() ?? '';

          tempList.add({
            'url': fullUrl,
            'img': imgSrc,
            'title': galleryTitle,
            'date': galleryDate,
            'name': '' // Placeholder, fetched on tap
          });
        }

        setState(() {
          celebrityList = tempList;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> fetchCelebrityName(int index) async {
    final item = celebrityList[index];
    final url = item['url']!;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = html.parse(response.body);
        final breadcrumb = document.querySelector('ul.breadcrumbs');
        if (breadcrumb != null) {
          final links = breadcrumb.querySelectorAll('li a');
          for (var link in links) {
            final href = link.attributes['href'] ?? '';
            if (href.startsWith('https://www.ragalahari.com/stars/profile/')) {
              final name = link.text.trim();
              setState(() {
                celebrityList[index]['name'] = name;
              });
              // Navigate to RagalahariDownloader with only URL and name
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RagalahariDownloaderScreen(
                    initialUrl: url,
                    initialFolder: name,
                  ),
                ),
              );
              break;
            }
          }
        }
      }
    } catch (e) {
      print('Detail fetch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Latest Celebrities')),
      body: isLoading
          ? Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.7,
          ),
          itemCount: 6, // Show 6 skeleton items
          itemBuilder: (context, index) {
            return Card(
              elevation: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 100,
                          height: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 120,
                          height: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.7,
        ),
        itemCount: celebrityList.length,
        itemBuilder: (context, index) {
          final item = celebrityList[index];
          return GestureDetector(
            onTap: () => fetchCelebrityName(index),
            child: Card(
              elevation: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Image.network(
                      item['img'] ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['date'] ?? '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['name']!.isEmpty ? 'Tap to Load Name' : item['name']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}