import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html show parse;
import 'package:shimmer/shimmer.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../downloader/ui/pages/ragadl_page.dart';
import '../data/profile_cache_service.dart';
import '../../gallery_links_page/gallery_links_page.dart';
import '../widgets/celebrity_card.dart';

class LatestCelebrityPage extends StatefulWidget {
  const LatestCelebrityPage({super.key});

  @override
  _LatestCelebrityPageState createState() => _LatestCelebrityPageState();
}

class _LatestCelebrityPageState extends State<LatestCelebrityPage> {
  final String baseUrl = 'https://www.ragalahari.com';
  final String targetUrl = 'https://www.ragalahari.com/starzone.aspx';
  List<Map<String, String>> celebrityList = [];
  bool isLoading = true;
  Map<int, bool> loadingProfileLinks = {};
  Set<String> favoriteUrls = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    fetchStarzoneLinks();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritesJson = prefs.getStringList('favorites') ?? [];
    Set<String> urls = {};
    for (var jsonStr in favoritesJson) {
      final map = jsonDecode(jsonStr);
      if (map['type'] == 'gallery') {
        urls.add((map['url'] as String?) ?? '');
      }
    }
    if (mounted) {
      setState(() {
        favoriteUrls = urls;
      });
    }
  }

  Future<void> _toggleFavorite(int index) async {
    final item = celebrityList[index];
    final url = item['url']!;
    final fallbackName =
        (item['name'] != null && item['name']!.isNotEmpty)
            ? item['name']!
            : (item['title'] ?? 'Unknown');

    final prefs = await SharedPreferences.getInstance();
    final List<String> favoritesJson = prefs.getStringList('favorites') ?? [];
    List<dynamic> allFavorites =
        favoritesJson.map((json) => jsonDecode(json)).toList();

    final isFavorite = favoriteUrls.contains(url);

    if (isFavorite) {
      allFavorites.removeWhere(
        (fav) => fav['type'] == 'gallery' && fav['url'] == url,
      );
      setState(() {
        favoriteUrls.remove(url);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $fallbackName from favorites'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final newItem = {
        'type': 'gallery',
        'name': fallbackName,
        'url': url,
        'thumbnailUrl': item['img'],
        'celebrityName': fallbackName,
        'date': item['date'] ?? '',
      };
      allFavorites.insert(0, newItem);
      setState(() {
        favoriteUrls.add(url);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $fallbackName to favorites'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    await prefs.setStringList(
      'favorites',
      allFavorites.map((i) => jsonEncode(i)).toList(),
    );
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
            'profileLink': '',
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
                celebrityList[index]['profileLink'] = href;
              });

              // Cache the profile link
              await ProfileCacheService.saveProfileLink(url, href);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RagaDL(initialUrl: url, initialFolder: name),
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

  Future<void> fetchAndNavigateToProfile(int index) async {
    final item = celebrityList[index];
    final galleryUrl = item['url']!;

    setState(() {
      loadingProfileLinks[index] = true;
    });

    try {
      // Check cache first
      String? cachedProfileLink = await ProfileCacheService.getProfileLink(
        galleryUrl,
      );
      String? celebrityName;

      if (cachedProfileLink != null) {
        // Extract name from cached profile link
        celebrityName = _extractCelebrityNameFromUrl(cachedProfileLink);

        setState(() {
          celebrityList[index]['profileLink'] = cachedProfileLink;
          celebrityList[index]['name'] = celebrityName ?? 'Unknown';
          loadingProfileLinks[index] = false;
        });

        if (celebrityName != null) {
          _navigateToGalleryLinks(
            cachedProfileLink,
            celebrityName,
            thumbnailUrl: item['img'],
          );
          return;
        }
      }

      // Fetch from web if not cached
      final response = await http.get(Uri.parse(galleryUrl));
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
                celebrityList[index]['profileLink'] = href;
                loadingProfileLinks[index] = false;
              });

              // Cache the profile link
              await ProfileCacheService.saveProfileLink(galleryUrl, href);

              _navigateToGalleryLinks(href, name, thumbnailUrl: item['img']);
              return;
            }
          }
        }
      }

      setState(() {
        loadingProfileLinks[index] = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile link not found')));
    } catch (e) {
      setState(() {
        loadingProfileLinks[index] = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    }
  }

  String? _extractCelebrityNameFromUrl(String profileUrl) {
    try {
      // Extract from URL: https://www.ragalahari.com/stars/profile/97688/ashika-ranganath.aspx
      final urlParts = profileUrl.split('/');
      if (urlParts.isNotEmpty) {
        final lastPart = urlParts.last.replaceAll('.aspx', '');
        final nameParts = lastPart.split('-');
        // Convert hyphenated name to proper case
        return nameParts
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' ');
      }
    } catch (e) {
      print('Error extracting celebrity name: $e');
    }
    return null;
  }

  void _navigateToGalleryLinks(
    String profileLink,
    String celebrityName, {
    String? thumbnailUrl,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => GalleryLinksPage(
              profileUrl: profileLink,
              celebrityName: celebrityName,
              thumbnailUrl: thumbnailUrl,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body:
          isLoading
              ? _buildShimmerContent()
              : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: Text(
                      'Latest Celebrities',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    floating: true,
                    snap: true,
                  ),
                  // Featured Carousel (Top 5 items)
                  if (celebrityList.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 24),
                        child: CarouselSlider.builder(
                          itemCount:
                              celebrityList.length > 5
                                  ? 5
                                  : celebrityList.length,
                          options: CarouselOptions(
                            height: MediaQuery.of(context).size.height * 0.25,
                            autoPlay: true,
                            enlargeCenterPage: true,
                            viewportFraction: 0.9,
                            aspectRatio: 16 / 9,
                            autoPlayCurve: Curves.fastOutSlowIn,
                            enableInfiniteScroll: true,
                            autoPlayAnimationDuration: const Duration(
                              milliseconds: 800,
                            ),
                          ),
                          itemBuilder: (context, index, realIndex) {
                            final item = celebrityList[index];
                            return GestureDetector(
                              onTap: () => fetchCelebrityName(index),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  image: DecorationImage(
                                    image: CachedNetworkImageProvider(
                                      item['img'] ?? '',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    item['title'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Section Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        "All Updates",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Grid View
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.55,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = celebrityList[index];
                        final isLoadingProfile =
                            loadingProfileLinks[index] ?? false;

                        return CelebrityCard(
                          imageUrl: item['img'] ?? '',
                          title: item['title'] ?? '',
                          date: item['date'],
                          onTap: () => fetchCelebrityName(index),
                          onActionPressed:
                              () => fetchAndNavigateToProfile(index),
                          isLoadingAction: isLoadingProfile,
                          actionLabel: 'Show Galleries',
                          isFavorite: favoriteUrls.contains(item['url']),
                          onFavoriteTap: () => _toggleFavorite(index),
                        );
                      }, childCount: celebrityList.length),
                    ),
                  ),

                  // Bottom Padding
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
    );
  }

  Widget _buildShimmerContent() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text(
            'Latest Celebrities',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          floating: true,
          snap: true,
        ),
        // Shimmer Carousel
        SliverToBoxAdapter(
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.25,
              margin: const EdgeInsets.only(top: 16, bottom: 24),
              child: CarouselSlider.builder(
                itemCount: 3,
                options: CarouselOptions(
                  height: MediaQuery.of(context).size.height * 0.25,
                  enlargeCenterPage: true,
                  viewportFraction: 0.9,
                  aspectRatio: 16 / 9,
                  autoPlay: false,
                ),
                itemBuilder: (context, index, realIndex) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Shimmer Grid
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 16, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Container(
                              width: 60,
                              height: 12,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Container(height: 32, color: Colors.grey[300]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: 6),
          ),
        ),
      ],
    );
  }
}
