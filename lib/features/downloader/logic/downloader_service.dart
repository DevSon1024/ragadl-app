import 'dart:isolate';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ragadl/core/permissions.dart';
import 'package:ragadl/core/services/notification_controller.dart';
import 'package:ragadl/core/services/dio_client.dart';
import '../../download_manager/logic/download_manager.dart';
import '../ui/pages/link_history_page.dart';
import '../../gallery_links/logic/site_parser.dart';

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

  ImageData({required this.thumbnailUrl, required this.originalUrl});

  Map<String, dynamic> toJson() => {
    'thumbnailUrl': thumbnailUrl,
    'originalUrl': originalUrl,
  };

  factory ImageData.fromJson(Map<String, dynamic> json) => ImageData(
    thumbnailUrl: json['thumbnailUrl'],
    originalUrl: json['originalUrl'],
  );
}

// Main service class for downloader logic
class DownloaderService {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;

  /// Extract gallery ID from URL
  String extractGalleryId(String url) {
    final parser = ParserFactory.getParser(url);
    return parser.extractGalleryId(url);
  }

  /// Construct page URL for pagination
  String constructPageUrl(String baseUrl, String galleryId, int index) {
    final parser = ParserFactory.getParser(baseUrl);
    return parser.constructPageUrl(baseUrl, galleryId, index);
  }

  bool isValidUrl(String url) {
    try {
      final uri = Uri.tryParse(url.trim());
      if (uri == null || !uri.hasScheme) return false;
      return ParserFactory.isSupported(url);
    } catch (_) {
      return false;
    }
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
    List<LinkHistoryItem> history =
        historyJson
            .map((json) => LinkHistoryItem.fromJson(jsonDecode(json)))
            .toList();

    final historyItem = LinkHistoryItem(
      url: url,
      celebrityName: celebrityName,
      galleryTitle: galleryTitle,
      timestamp: DateTime.now(),
    );

    if (!history.any(
      (item) => item.url == url && item.celebrityName == celebrityName,
    )) {
      history.add(historyItem);
      await prefs.setStringList(
        historyKey,
        history.map((h) => jsonEncode(h.toJson())).toList(),
      );
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
      final total = imageUrls.length;

      int successCount = 0;
      int failureCount = 0;

      await NotificationController.showBatchProgress(
        completed: 0,
        total: total,
        galleryName: galleryName,
      );

      final targetDirectoryPath = imageUrls.isNotEmpty
          ? await downloadManager.getResolvedTargetDirectory(
              url: imageUrls.first.originalUrl,
              galleryName: galleryName,
              albumName: galleryName,
            )
          : '';

      for (int i = 0; i < imageUrls.length; i++) {
        final imageUrl = imageUrls[i].originalUrl;
        downloadManager.addDownload(
          url: imageUrl,
          folder: mainFolderName,
          subFolder: subFolderName,
          galleryName: galleryName,
          targetDirectoryPath: targetDirectoryPath,
          batchId: batchId,
          albumName: galleryName,
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
        'totalAdded': total,
        'successCount': successCount,
        'failureCount': failureCount,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
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
      return {'success': false, 'error': 'No images selected'};
    }

    try {
      final downloadManager = DownloadManager();
      final batchId = DateTime.now().millisecondsSinceEpoch.toString();
      final galleryName = galleryTitle ?? mainFolderName;
      final total = selectedIndices.length;

      int successCount = 0;
      int failureCount = 0;

      await NotificationController.showBatchProgress(
        completed: 0,
        total: total,
        galleryName: galleryName,
      );

      final targetDirectoryPath = selectedIndices.isNotEmpty
          ? await downloadManager.getResolvedTargetDirectory(
              url: imageUrls[selectedIndices.first].originalUrl,
              galleryName: galleryName,
              albumName: galleryName,
            )
          : '';

      for (int index in selectedIndices) {
        final imageUrl = imageUrls[index].originalUrl;
        downloadManager.addDownload(
          url: imageUrl,
          folder: mainFolderName,
          subFolder: subFolderName,
          galleryName: galleryName,
          targetDirectoryPath: targetDirectoryPath,
          batchId: batchId,
          albumName: galleryName,
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
        'totalAdded': total,
        'successCount': successCount,
        'failureCount': failureCount,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
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

      final targetDirectoryPath = await downloadManager.getResolvedTargetDirectory(
        url: imageUrl,
        galleryName: galleryTitle ?? 'Single Image',
        albumName: galleryTitle ?? 'Single Image',
      );

      downloadManager.addDownload(
        url: imageUrl,
        folder: folderName,
        subFolder: subFolder,
        galleryName: galleryTitle ?? 'Single Image',
        targetDirectoryPath: targetDirectoryPath,
        albumName: galleryTitle ?? 'Single Image',
        onProgress: (progress) {},
        onComplete: (success) {},
      );

      return {'success': true, 'message': 'Added to download manager'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Dispose resources
  void dispose() {
    stopProcessing();
  }
}

// ISOLATE FUNCTIONS (Background Processing)

/// Isolate entry point for gallery processing
void _processGalleryIsolate(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) async {
    final String baseUrl = message['baseUrl'];
    final SendPort replyPort = message['replyPort'];

    try {
      final dio = DioClient().dio;
      final galleryId = _extractGalleryIdIsolate(baseUrl);

      // Get total pages
      final totalPages = await _getTotalPages(dio, baseUrl);
      final Set<ImageData> allImageUrls = {};

      const int batchSize = 5;
      for (int i = 0; i < totalPages; i += batchSize) {
        final end = min(i + batchSize, totalPages);
        final batchFutures = <Future>[];

        for (int j = i; j < end; j++) {
          batchFutures.add(_processPage(dio, baseUrl, galleryId, j, replyPort));
        }

        await Future.wait(batchFutures);
        replyPort.send({
          'type': 'progress',
          'currentPage': end,
          'totalPages': totalPages,
        });
      }

      replyPort.send({'type': 'result', 'images': allImageUrls.toList()});
    } catch (e) {
      replyPort.send({'type': 'error', 'error': e.toString()});
    }
  });
}

/// Get total number of pages in gallery
Future<int> _getTotalPages(Dio dio, String url) async {
  try {
    final parser = ParserFactory.getParser(url);
    final headers = <String, String>{
      'User-Agent': userAgents[Random().nextInt(userAgents.length)],
    };
    final response = await dio.get<String>(url, options: Options(headers: headers));

    if (response.statusCode == 200 && response.data != null) {
      final document = parse(response.data!);
      return parser.getPages(document);
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
    final headers = <String, String>{
      'User-Agent': userAgents[Random().nextInt(userAgents.length)],
    };
    final response = await dio.get<String>(pageUrl, options: Options(headers: headers));

    if (response.statusCode == 200 && response.data != null) {
      final document = parse(response.data!);
      final pageImages = _extractImageUrls(document, pageUrl);
      replyPort.send({'type': 'images', 'images': pageImages});
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
      replyPort.send({'type': 'error', 'page': index, 'error': e.toString()});
    }
  }
}

// HELPER FUNCTIONS (HTML Parsing & URL Processing)

/// Extract gallery ID from URL (isolate version)
String _extractGalleryIdIsolate(String url) {
  final parser = ParserFactory.getParser(url);
  return parser.extractGalleryId(url);
}

/// Construct page URL for pagination (isolate version)
String _constructPageUrlIsolate(String baseUrl, String galleryId, int index) {
  final parser = ParserFactory.getParser(baseUrl);
  return parser.constructPageUrl(baseUrl, galleryId, index);
}

/// Extract image URLs from HTML document
List<ImageData> _extractImageUrls(dom.Document document, String baseUrl) {
  final parser = ParserFactory.getParser(baseUrl);
  return parser.extractImageUrls(document, baseUrl);
}
