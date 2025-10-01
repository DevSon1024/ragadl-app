import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CelebrityImageCache {
  static final CelebrityImageCache _instance = CelebrityImageCache._internal();
  factory CelebrityImageCache() => _instance;
  CelebrityImageCache._internal();

  final Map<String, String> _memoryCache = {};
  static const String _cacheKey = 'celebrity_image_cache';

  /// Initialize and load cached images from persistent storage
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cacheKey);

    if (cachedJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        _memoryCache.addAll(Map<String, String>.from(decoded));
      } catch (e) {
        print('Error loading image cache: $e');
      }
    }
  }

  /// Get image URL from cache or fetch it
  Future<String?> getImageUrl(String profileUrl) async {
    // Check memory cache first
    if (_memoryCache.containsKey(profileUrl)) {
      return _memoryCache[profileUrl];
    }

    // Fetch and cache the image URL
    final imageUrl = await _fetchImageUrl(profileUrl);
    if (imageUrl != null) {
      await _cacheImageUrl(profileUrl, imageUrl);
    }

    return imageUrl;
  }

  /// Fetch image URL by scraping the profile page
  Future<String?> _fetchImageUrl(String profileUrl) async {
    try {
      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);

        // Find the image element with id="_pagecontent_profileImg"
        final imgElement = document.getElementById('_pagecontent_profileImg');

        if (imgElement != null) {
          final imageUrl = imgElement.attributes['src'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            // Ensure URL is absolute
            if (imageUrl.startsWith('http')) {
              return imageUrl;
            } else if (imageUrl.startsWith('/')) {
              return 'https://www.ragalahari.com$imageUrl';
            } else {
              return 'https://www.ragalahari.com/$imageUrl';
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching image for $profileUrl: $e');
    }

    return null;
  }

  /// Cache image URL in both memory and persistent storage
  Future<void> _cacheImageUrl(String profileUrl, String imageUrl) async {
    _memoryCache[profileUrl] = imageUrl;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_memoryCache));
    } catch (e) {
      print('Error saving image cache: $e');
    }
  }

  /// Check if an image URL is cached
  bool isCached(String profileUrl) {
    return _memoryCache.containsKey(profileUrl);
  }

  /// Clear all cached images
  Future<void> clearCache() async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  /// Preload images for a list of profile URLs (optional optimization)
  Future<void> preloadImages(List<String> profileUrls) async {
    for (final url in profileUrls) {
      if (!_memoryCache.containsKey(url)) {
        await getImageUrl(url);
      }
    }
  }
}