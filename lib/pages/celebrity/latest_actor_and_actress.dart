import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html show parse;
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ragalahari_downloader/widgets/grid_utils.dart';
import '../ragalahari_downloader.dart';

class ActorPage extends StatefulWidget {
  const ActorPage({super.key});

  @override
  _ActorPageState createState() => _ActorPageState();
}

class _ActorPageState extends State<ActorPage> {
  final String baseUrl = 'https://www.ragalahari.com';
  final String targetUrl = 'https://www.ragalahari.com/actor/starzone.aspx';
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
          final fullUrl =
          partialUrl.startsWith('/') ? baseUrl + partialUrl : partialUrl;
          final galleryTitle = h5Tag?.text.trim() ?? '';
          final galleryDate = h6Tag?.text.trim() ?? '';

          tempList.add({
            'url': fullUrl,
            'img': imgSrc,
            'title': galleryTitle,
            'date': galleryDate,
            'name': '',
          });
        }

        setState(() {
          celebrityList = tempList;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoading = false;
      });
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RagalahariDownloader(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load celebrity name: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Latest Actors')),
      body: isLoading
          ? GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: calculateGridColumns(context),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.7,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Card(
              elevation: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.grey[300],
                      width: double.infinity,
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
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 80,
                          height: 12,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 100,
                          height: 14,
                          color: Colors.grey[300],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      )
          : GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: calculateGridColumns(context),
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
                    child: CachedNetworkImage(
                      imageUrl: item['img'] ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) =>
                      const Icon(Icons.error),
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
                          item['name']!.isEmpty
                              ? 'Tap to Load Name'
                              : item['name']!,
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

class ActressPage extends StatefulWidget {
  const ActressPage({super.key});

  @override
  _ActressPageState createState() => _ActressPageState();
}

class _ActressPageState extends State<ActressPage> {
  final String baseUrl = 'https://www.ragalahari.com';
  final String targetUrl = 'https://www.ragalahari.com/actress/starzone.aspx';
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
          final fullUrl =
          partialUrl.startsWith('/') ? baseUrl + partialUrl : partialUrl;
          final galleryTitle = h5Tag?.text.trim() ?? '';
          final galleryDate = h6Tag?.text.trim() ?? '';

          tempList.add({
            'url': fullUrl,
            'img': imgSrc,
            'title': galleryTitle,
            'date': galleryDate,
            'name': '',
          });
        }

        setState(() {
          celebrityList = tempList;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoading = false;
      });
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RagalahariDownloader(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load celebrity name: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Latest Actresses')),
      body: isLoading
          ? GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: calculateGridColumns(context),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.7,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Card(
              elevation: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.grey[300],
                      width: double.infinity,
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
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 80,
                          height: 12,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 100,
                          height: 14,
                          color: Colors.grey[300],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      )
          : GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: calculateGridColumns(context),
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
                    child: CachedNetworkImage(
                      imageUrl: item['img'] ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) =>
                      const Icon(Icons.error),
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
                          item['name']!.isEmpty
                              ? 'Tap to Load Name'
                              : item['name']!,
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