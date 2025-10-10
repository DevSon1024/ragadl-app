import 'dart:isolate';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ragalahari_downloader/core/permissions.dart';
import '../ui/download_manager_page.dart';
import '../ui/link_history_page.dart';

// User agents for rotation
const List<String> userAgents = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
];

/// Data model for image information
class ImageData {
  final String thumbnailUrl;
  final String originalUrl;

  ImageData({
    required this.thumbnailUrl,
    required this.originalUrl,
  });

  Map<String, dynamic> toJson() => {
    'thumbnailUrl': thumbnailUrl,
    'originalUrl': originalUrl,
  };

  factory ImageData.fromJson(Map<String, dynamic> json) => ImageData(
    thumbnailUrl: json['thumbnailUrl'],
    originalUrl: json['originalUrl'],
  );
}

/// Main service class for downloader logic
class DownloaderService {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;

  /// Extract gallery ID from URL
  String extractGalleryId(String url) {
    final RegExp regex = RegExp(r"/(\d+)/");
    final match = regex.firstMatch(url);
    return match?.group(1) ?? url.hashCode.abs().toString();
  }

  /// Construct page URL for pagination
  String constructPageUrl(String baseUrl, String galleryId, int index) {
    if (index == 0) return baseUrl;
    return baseUrl.replaceAll(RegExp("$galleryId/?"), "$galleryId/$index/");
  }

  /// Validate Ragalahari URL
  bool isValidRagalahariUrl(String url) {
    return url.trim().startsWith('https://www.ragalahari.com');
  }

  /// Check and request storage permissions
  Future<bool> checkAndRequestPermissions() async {
    bool permissionsGranted = await PermissionHandler.checkStoragePermissions();
    if (!permissionsGranted) {
      // Note: context is needed here, will be passed from UI
      return false;
    }
    return permissionsGranted;
  }

  /// Save URL to history
  Future<void> saveToHistory({
    required String url,
    required String celebrityName,
    String? galleryTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    const historyKey = 'link_history';
    List<String> historyJson = prefs.getStringList(historyKey) ?? [];
    List<LinkHistoryItem> history = historyJson
        .map((json) => LinkHistoryItem.fromJson(jsonDecode(json)))
        .toList();

    final historyItem = LinkHistoryItem(
      url: url,
      celebrityName: celebrityName,
      galleryTitle: galleryTitle,
      timestamp: DateTime.now(),
    );

    if (!history.any((item) =>
    item.url == url && item.celebrityName == celebrityName)) {
      history.add(historyItem);
      await prefs.setStringList(
          historyKey, history.map((h) => jsonEncode(h.toJson())).toList());
    }
  }

  /// Set base download path in SharedPreferences
  Future<void> setBaseDownloadPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_download_path', path);
  }

  /// Process gallery and extract images
  Future<void> processGallery({
    required String baseUrl,
    required Function(Map<String, dynamic>) onMessage,
  }) async {
    // Kill existing isolate if any
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();

    // Create new isolate
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _processGalleryIsolate,
      _receivePort!.sendPort,
    );

    _receivePort!.listen((data) {
      if (data is SendPort) {
        _sendPort = data;
        _sendPort?.send({
          'baseUrl': baseUrl,
          'replyPort': _receivePort!.sendPort,
        });
      } else {
        onMessage(data);
      }
    });
  }

  /// Stop the current processing
  void stopProcessing() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _receivePort = null;
    _sendPort = null;
  }

  /// Download all images
  Future<Map<String, dynamic>> downloadAllImages({
    required List<ImageData> imageUrls,
    required String mainFolderName,
    required String subFolderName,
    String? galleryTitle,
  }) async {
    try {
      final downloadManager = DownloadManager();
      final batchId = DateTime.now().millisecondsSinceEpoch.toString();
      final galleryName = galleryTitle ?? mainFolderName;

      int successCount = 0;
      int failureCount = 0;

      for (int i = 0; i < imageUrls.length; i++) {
        final imageUrl = imageUrls[i].originalUrl;
        downloadManager.addDownload(
          url: imageUrl,
          folder: mainFolderName,
          subFolder: subFolderName,
          galleryName: galleryName,
          batchId: batchId,
          onProgress: (progress) {},
          onComplete: (success) {
            if (success) {
              successCount++;
            } else {
              failureCount++;
            }
          },
        );
      }

      return {
        'success': true,
        'totalAdded': imageUrls.length,
        'successCount': successCount,
        'failureCount': failureCount,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Download selected images
  Future<Map<String, dynamic>> downloadSelectedImages({
    required List<ImageData> imageUrls,
    required Set<int> selectedIndices,
    required String mainFolderName,
    required String subFolderName,
    String? galleryTitle,
  }) async {
    if (selectedIndices.isEmpty) {
      return {
        'success': false,
        'error': 'No images selected',
      };
    }

    try {
      final downloadManager = DownloadManager();
      final batchId = DateTime.now().millisecondsSinceEpoch.toString();
      final galleryName = galleryTitle ?? mainFolderName;

      int successCount = 0;
      int failureCount = 0;

      for (int index in selectedIndices) {
        final imageUrl = imageUrls[index].originalUrl;
        downloadManager.addDownload(
          url: imageUrl,
          folder: mainFolderName,
          subFolder: subFolderName,
          galleryName: galleryName,
          batchId: batchId,
          onProgress: (progress) {},
          onComplete: (success) {
            if (success) {
              successCount++;
            } else {
              failureCount++;
            }
          },
        );
      }

      return {
        'success': true,
        'totalAdded': selectedIndices.length,
        'successCount': successCount,
        'failureCount': failureCount,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Download single image
  Future<Map<String, dynamic>> downloadSingleImage({
    required String imageUrl,
    String? folder,
    String? galleryTitle,
  }) async {
    try {
      final downloadManager = DownloadManager();
      final folderName = folder ?? 'SingleImages';
      final subFolder = DateTime.now().toString().split(' ')[0];

      bool downloadSuccess = false;

      downloadManager.addDownload(
        url: imageUrl,
        folder: folderName,
        subFolder: subFolder,
        galleryName: galleryTitle ?? 'Single Image',
        onProgress: (progress) {},
        onComplete: (success) {
          downloadSuccess = success;
        },
      );

      return {
        'success': true,
        'message': 'Added to download manager',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Dispose resources
  void dispose() {
    stopProcessing();
  }
}

// ============================================================================
// ISOLATE FUNCTIONS (Background Processing)
// ============================================================================

/// Isolate entry point for gallery processing
void _processGalleryIsolate(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) async {
    final String baseUrl = message['baseUrl'];
    final SendPort replyPort = message['replyPort'];

    try {
      final dio = Dio();
      final galleryId = _extractGalleryIdIsolate(baseUrl);

      // Get total pages
      final totalPages = await _getTotalPages(dio, baseUrl);
      final Set<ImageData> allImageUrls = {};

      const int batchSize = 5;
      for (int i = 0; i < totalPages; i += batchSize) {
        final end = min(i + batchSize, totalPages);
        final batchFutures = <Future>[];

        for (int j = i; j < end; j++) {
          batchFutures.add(
            _processPage(dio, baseUrl, galleryId, j, replyPort),
          );
        }

        await Future.wait(batchFutures);
        replyPort.send({
          'type': 'progress',
          'currentPage': end,
          'totalPages': totalPages,
        });
      }

      replyPort.send({
        'type': 'result',
        'images': allImageUrls.toList(),
      });
    } catch (e) {
      replyPort.send({
        'type': 'error',
        'error': e.toString(),
      });
    }
  });
}

/// Get total number of pages in gallery
Future<int> _getTotalPages(Dio dio, String url) async {
  try {
    final headers = {
      'User-Agent': userAgents[Random().nextInt(userAgents.length)]
    };
    final response = await dio.get(url, options: Options(headers: headers));

    if (response.statusCode == 200) {
      final document = parse(response.data);
      final pageLinks = document.querySelectorAll("a.otherPage");
      final pages = pageLinks
          .map((e) => int.tryParse(e.text))
          .where((page) => page != null)
          .cast<int>()
          .toList();
      return pages.isEmpty ? 1 : pages.reduce(max);
    }
    return 1;
  } catch (e) {
    return 1;
  }
}

/// Process a single page
Future<void> _processPage(
    Dio dio,
    String baseUrl,
    String galleryId,
    int index,
    SendPort replyPort,
    ) async {
  try {
    final pageUrl = _constructPageUrlIsolate(baseUrl, galleryId, index);
    final headers = {
      'User-Agent': userAgents[Random().nextInt(userAgents.length)]
    };
    final response = await dio.get(pageUrl, options: Options(headers: headers));

    if (response.statusCode == 200) {
      final document = parse(response.data);
      _removeUnwantedDivs(document);
      final pageImages = _extractImageUrls(document);
      replyPort.send({
        'type': 'images',
        'images': pageImages,
      });
    } else {
      replyPort.send({
        'type': 'page_error',
        'page': index,
        'status': response.statusCode,
      });
    }
  } catch (e) {
    if (e is DioException) {
      replyPort.send({
        'type': 'dio_error',
        'page': index,
        'error': e.message,
        'statusCode': e.response?.statusCode,
      });
    } else {
      replyPort.send({
        'type': 'error',
        'page': index,
        'error': e.toString(),
      });
    }
  }
}

// ============================================================================
// HELPER FUNCTIONS (HTML Parsing & URL Processing)
// ============================================================================

/// Extract gallery ID from URL (isolate version)
String _extractGalleryIdIsolate(String url) {
  final RegExp regex = RegExp(r"/(\d+)/");
  final match = regex.firstMatch(url);
  return match?.group(1) ?? url.hashCode.abs().toString();
}

/// Construct page URL for pagination (isolate version)
String _constructPageUrlIsolate(String baseUrl, String galleryId, int index) {
  if (index == 0) return baseUrl;
  return baseUrl.replaceAll(RegExp("$galleryId/?"), "$galleryId/$index/");
}

/// Remove unwanted divs from HTML document
void _removeUnwantedDivs(var document) {
  final unwantedHeadings = {
    "Latest Local Events",
    "Latest Movie Events",
    "Latest Starzone"
  };

  for (var div in document.querySelectorAll("div#btmlatest")) {
    var h4 = div.querySelector("h4");
    if (h4 != null && unwantedHeadings.contains(h4.text.trim())) {
      div.remove();
    }
  }

  for (var badId in ["taboolaandnews", "news_panel"]) {
    var div = document.querySelector("div#$badId");
    div?.remove();
  }
}

/// Extract image URLs from HTML document
List<ImageData> _extractImageUrls(var document) {
  final Set<ImageData> imageDataSet = {};

  for (var img in document.querySelectorAll("img")) {
    final src = img.attributes['src'];
    if (src == null ||
        !src.toLowerCase().endsWith(".jpg") ||
        (!src.startsWith("http") && !src.startsWith("../"))) {
      continue;
    }

    String thumbnailUrl = src.startsWith("http")
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
        originalUrl = href.startsWith('http')
            ? href
            : "https://www.ragalahari.com/$href";
      }
    }

    imageDataSet.add(ImageData(
      thumbnailUrl: thumbnailUrl,
      originalUrl: originalUrl,
    ));
  }

  return imageDataSet.toList();
}