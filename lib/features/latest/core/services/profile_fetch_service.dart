import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html show parse;
import 'package:flutter/material.dart';
import '../../../downloader/ui/pages/ragadl_page.dart';
import '../../../celebrity/data/profile_cache_service.dart';
import '../../../gallery_links/ui/pages/gallery_links_page.dart';
import '../models/latest_item.dart';

class ProfileFetchService {
  static String? extractCelebrityNameFromUrl(String profileUrl) {
    try {
      final urlParts = profileUrl.split('/');
      if (urlParts.isNotEmpty) {
        final lastPart = urlParts.last.replaceAll('.aspx', '');
        final nameParts = lastPart.split('-');
        return nameParts
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' ');
      }
    } catch (e) {
      debugPrint('Error extracting celebrity name: $e');
    }
    return null;
  }

  static void navigateToGalleryLinks(
    BuildContext context,
    String profileLink,
    String celebrityName, {
    String? thumbnailUrl,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryLinksPage(
          profileUrl: profileLink,
          celebrityName: celebrityName,
          thumbnailUrl: thumbnailUrl,
        ),
      ),
    );
  }

  static Future<void> fetchCelebrityName(
    BuildContext context,
    LatestItem item,
    void Function(String name, String href) onUpdate,
  ) async {
    try {
      final response = await http.get(Uri.parse(item.url));
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
              
              final linkText = link.text.trim();
              final name = (linkText.isEmpty || linkText.toLowerCase() == 'home') ? item.title : linkText;
              
              onUpdate(name, href);

              await ProfileCacheService.saveProfileLink(item.url, href);

              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RagaDL(initialUrl: item.url, initialFolder: name),
                ),
              );
              return;
            }
          }
        }
        
        if (!context.mounted) return;
        final name = item.title.isNotEmpty ? item.title : 'Event';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RagaDL(initialUrl: item.url, initialFolder: name),
          ),
        );
      }
    } catch (e) {
      debugPrint('Detail fetch error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load details: $e')),
      );
    }
  }

  static Future<void> fetchAndNavigateToProfile(
    BuildContext context,
    LatestItem item,
    void Function() onStart,
    void Function(String? name, String? href) onFinish,
  ) async {
    onStart();

    try {
      String? cachedProfileLink = await ProfileCacheService.getProfileLink(item.url);

      if (cachedProfileLink != null) {
        String? celebrityName = extractCelebrityNameFromUrl(cachedProfileLink);
        
        if (celebrityName == null || celebrityName.isEmpty) {
            celebrityName = item.title.isNotEmpty ? item.title : 'Event';
        }

        onFinish(celebrityName, cachedProfileLink);

        if (celebrityName.isNotEmpty) {
          if (!context.mounted) return;
          navigateToGalleryLinks(
            context,
            cachedProfileLink,
            celebrityName,
            thumbnailUrl: item.image,
          );
        }
        return;
      }

      final response = await http.get(Uri.parse(item.url));
      if (response.statusCode == 200) {
        final document = html.parse(response.body);
        final breadcrumb = document.querySelector('ul.breadcrumbs');

        if (breadcrumb != null) {
          final links = breadcrumb.querySelectorAll('li a');
          for (var link in links) {
            final href = link.attributes['href'] ?? '';
            if (href.startsWith('https://www.ragalahari.com/stars/profile/')) {
              
              final linkText = link.text.trim();
              final name = (linkText.isEmpty || linkText.toLowerCase() == 'home') ? item.title : linkText;

              onFinish(name, href);

              await ProfileCacheService.saveProfileLink(item.url, href);

              if (!context.mounted) return;
              navigateToGalleryLinks(context, href, name, thumbnailUrl: item.image);
              return;
            }
          }
        }
      }

      if (!context.mounted) return;
      onFinish(null, null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile link not found')),
      );
    } catch (e) {
      onFinish(null, null);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load: $e')),
      );
    }
  }
}
