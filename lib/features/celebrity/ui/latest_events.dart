import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html show parse;
import 'package:shimmer/shimmer.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../downloader/ui/pages/ragadl_page.dart';
import '../data/profile_cache_service.dart';
import '../../gallery_links/ui/pages/gallery_links_page.dart';
import '../widgets/celebrity_card.dart';

class LatestEventsPage extends StatefulWidget {
  const LatestEventsPage({super.key});

  @override
  _LatestEventsPageState createState() => _LatestEventsPageState();
}

class _LatestEventsPageState extends State<LatestEventsPage> {
  final String baseUrl = 'https://www.ragalahari.com';
  final String targetUrl = 'https://www.ragalahari.com/functions.aspx';
  List<Map<String, String>> celebrityList = [];
  bool isLoading = true;
  Map<int, bool> loadingProfileLinks = {};

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
            if (href.startsWith('https://www.ragalahari.com/stars/profile/') ||
                href.startsWith('https://www.ragalahari.com/localevents/') ||
                href.startsWith('https://www.ragalahari.com/functions/')) {
              // For events, sometimes there is no profile, just the event page itself
              // But if there is a profile/category link, we use it.
              // For now, let's just use the title as the name if strictly needed.
              // But RagaDL expects a "folder name".

              // Use the event title as the folder name
              final name = item['title'] ?? link.text.trim();
              setState(() {
                celebrityList[index]['name'] = name;
                celebrityList[index]['profileLink'] = href;
              });

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RagaDL(initialUrl: url, initialFolder: name),
                ),
              );
              return;
            }
          }
        }
        // Fallback if no specific breadcrumb link is suitable
        final name = item['title'] ?? 'Event';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RagaDL(initialUrl: url, initialFolder: name),
          ),
        );
      }
    } catch (e) {
      print('Detail fetch error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load details: $e')));
    }
  }

  Future<void> fetchAndNavigateToProfile(int index) async {
    // For Events, "Profile" might mean looking for more events in the same category
    // or just opening the event gallery directly.
    // Given the user wants it "same as latest actors", we'll try to find a parent category/profile.

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

      if (cachedProfileLink != null) {
        // just navigate
        _navigateToGalleryLinks(
          cachedProfileLink,
          item['title'] ?? 'Event', // Use title as name for events
          thumbnailUrl: item['img'],
        );
        setState(() {
          loadingProfileLinks[index] = false;
        });
        return;
      }

      final response = await http.get(Uri.parse(galleryUrl));
      if (response.statusCode == 200) {
        final document = html.parse(response.body);
        final breadcrumb = document.querySelector('ul.breadcrumbs');

        if (breadcrumb != null) {
          final links = breadcrumb.querySelectorAll('li a');
          // Try to find a meaningful parent category.
          // Often for functions it might be "Audio Release", "Pre Release", etc.
          for (var link in links) {
            final href = link.attributes['href'] ?? '';
            // Logic to decide which link isn't just "Home" or "Functions"
            if (href != '/' && !href.toLowerCase().endsWith('functions.aspx')) {
              // This is likely the specific movie or event category
              // Use the event title itself as the folder name as per user request
              final name = item['title'] ?? link.text.trim();

              setState(() {
                celebrityList[index]['name'] = name;
                celebrityList[index]['profileLink'] = href;
                loadingProfileLinks[index] = false;
              });

              await ProfileCacheService.saveProfileLink(galleryUrl, href);

              _navigateToGalleryLinks(href, name, thumbnailUrl: item['img']);
              return;
            }
          }
        }
      }

      // If no parent found, maybe just stay or show error?
      // Or usually just open the gallery itself if "Show Galleries" is clicked?
      // Let's assume we want to show *related* galleries if possible, if not, maybe just the gallery.
      // But GalleryLinksPage expects a profile URL.

      setState(() {
        loadingProfileLinks[index] = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No related events found')));
    } catch (e) {
      setState(() {
        loadingProfileLinks[index] = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    }
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
                      'Latest Functions',
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
                                    alignment: Alignment.topCenter,
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
                        "All Events",
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
                          actionLabel: 'Related Events',
                          showActionButton: false,
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
            'Latest Functions',
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
              childAspectRatio: 0.55,
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
