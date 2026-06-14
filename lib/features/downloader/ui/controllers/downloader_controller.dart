import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ragadl/core/permissions.dart';
import '../../logic/downloader_service.dart';
import '../../../gallery_links/logic/site_parser.dart';

final downloaderControllerProvider =
    ChangeNotifierProvider.autoDispose<DownloaderController>((ref) {
      final service = DownloaderService();
      final controller = DownloaderController(service);
      ref.onDispose(() {
        controller.dispose();
      });
      return controller;
    });

class DownloaderController extends ChangeNotifier {
  final DownloaderService downloaderService;

  bool get isBehindwoodsLink =>
      urlController.text.trim().toLowerCase().contains('behindwoods.com');

  bool get isImgBB =>
      urlController.text.trim().toLowerCase().contains('ibb.co');

  DownloaderController(this.downloaderService) {
    urlFocusNode.addListener(_handleFocusChange);
    folderFocusNode.addListener(_handleFocusChange);
    urlController.addListener(_handleUrlChange);
  }

  // Focus nodes & controllers
  final TextEditingController urlController = TextEditingController();
  final TextEditingController folderController = TextEditingController();
  final TextEditingController startPageController = TextEditingController();
  final TextEditingController endPageController = TextEditingController();
  final FocusNode urlFocusNode = FocusNode();
  final FocusNode folderFocusNode = FocusNode();

  // State
  List<ImageData> imageUrls = [];
  Set<int> selectedImages = {};
  bool isLoading = false;
  bool isDownloading = false;
  bool isSelectionMode = false;
  int downloadsSuccessful = 0;
  int downloadsFailed = 0;
  int currentPage = 0;
  int totalPages = 1;
  String? error;
  String? successMessage;
  String mainFolderName = '';
  String subFolderName = '';
  bool isInitialized = false;
  bool showBehindwoodsInfo = false;
  String? albumTitle;
  int imgbbPage = 1;
  bool hasMorePages = false;
  bool isLoadMoreLoading = false;
  String? nextPageUrl;

  @override
  void dispose() {
    urlController.removeListener(_handleUrlChange);
    urlFocusNode.removeListener(_handleFocusChange);
    folderFocusNode.removeListener(_handleFocusChange);
    urlController.dispose();
    folderController.dispose();
    startPageController.dispose();
    endPageController.dispose();
    urlFocusNode.dispose();
    folderFocusNode.dispose();
    downloaderService.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    notifyListeners();
    HapticFeedback.lightImpact();
  }

  void _handleUrlChange() {
    final url = urlController.text.trim();
    if (url.isNotEmpty && ParserFactory.isSupported(url)) {
      final parser = ParserFactory.getParser(url);
      final folderName = parser.suggestFolderName(url);
      if (folderName != null &&
          folderName.isNotEmpty &&
          folderController.text != folderName) {
        folderController.text = folderName;
        mainFolderName = folderName;
        notifyListeners();
      }
    }
  }

  void initializeFields({
    String? initialUrl,
    String? initialFolder,
    required Future<void> Function(String) processGallery,
  }) {
    if (!isInitialized ||
        (initialUrl != null && initialUrl != urlController.text) ||
        (initialFolder != null && initialFolder != folderController.text)) {
      if (initialUrl != null) {
        urlController.text = initialUrl;
      }

      if (initialFolder != null) {
        mainFolderName = initialFolder;
        folderController.text = initialFolder;
      }

      if (initialUrl != null &&
          initialUrl.isNotEmpty &&
          initialFolder != null &&
          initialFolder.isNotEmpty &&
          !isInitialized) {
        Future.microtask(() {
          processGallery(initialUrl);
        });
      }
      isInitialized = true;
      notifyListeners();
    }
  }

  void setMainFolderName(String name) {
    mainFolderName = name;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void clearAll({required void Function() onClearCompleted}) {
    urlController.clear();
    folderController.clear();
    startPageController.clear();
    endPageController.clear();
    imageUrls.clear();
    selectedImages.clear();
    isSelectionMode = false;
    mainFolderName = '';
    subFolderName = '';
    downloadsSuccessful = 0;
    downloadsFailed = 0;
    currentPage = 0;
    totalPages = 1;
    error = null;
    successMessage = null;
    isInitialized = false;
    showBehindwoodsInfo = false;
    albumTitle = null;
    imgbbPage = 1;
    hasMorePages = false;
    isLoadMoreLoading = false;
    nextPageUrl = null;
    notifyListeners();

    HapticFeedback.mediumImpact();
    onClearCompleted();
  }

  void clearSelection() {
    selectedImages.clear();
    isSelectionMode = false;
    notifyListeners();
  }

  void toggleBehindwoodsInfo() {
    showBehindwoodsInfo = !showBehindwoodsInfo;
    notifyListeners();
  }

  Future<void> pasteFromClipboard({required void Function() onPaste}) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      final pastedUrl = clipboardData.text!.trim();
      urlController.text = pastedUrl;
      notifyListeners();
      HapticFeedback.mediumImpact();
      onPaste();
    }
  }

  Future<bool> checkPermissions(BuildContext context) async {
    bool permissionsGranted = await PermissionHandler.checkStoragePermissions();
    if (!permissionsGranted) {
      if (!context.mounted) return false;
      permissionsGranted = await PermissionHandler.requestAllPermissions(
        context,
      );
    }
    return permissionsGranted;
  }

  Future<void> processGallery({
    required String baseUrl,
    required String? galleryTitle,
    required BuildContext context,
    required void Function(String message, IconData icon, {bool isError})
    showSnackBar,
    bool isLoadMore = false,
  }) async {
    final isImgBB = baseUrl.toLowerCase().contains('ibb.co');

    if (isImgBB) {
      if (!isLoadMore) {
        isLoading = true;
        isLoadMoreLoading = false;
        imgbbPage = 1;
        hasMorePages = false;
        nextPageUrl = null;
        imageUrls.clear();
        selectedImages.clear();
        isSelectionMode = false;
        downloadsSuccessful = 0;
        downloadsFailed = 0;
        currentPage = 0;
        totalPages = 1;
        error = null;
      } else {
        isLoadMoreLoading = true;
        imgbbPage++;
      }
      notifyListeners();

      if (!context.mounted) return;
      final permissionsGranted = await checkPermissions(context);
      if (!context.mounted) return;
      if (permissionsGranted) {
        showSnackBar(
          'Storage permission granted',
          Icons.check_circle_rounded,
          isError: false,
        );
      }

      final parser = ParserFactory.getParser(baseUrl);
      if (mainFolderName.isEmpty && folderController.text.isNotEmpty) {
        mainFolderName = folderController.text.trim();
      } else if (mainFolderName.isEmpty) {
        mainFolderName = parser.defaultMainFolderName;
        folderController.text = mainFolderName;
      }
      final galleryId = parser.extractGalleryId(baseUrl);
      subFolderName = parser.getSubFolderName(mainFolderName, galleryId);

      await downloaderService.setBaseDownloadPath(
        '/storage/emulated/0/Download/RagaDL Downloads',
      );

      final isAlbum = baseUrl.contains('/album/');
      if (isAlbum) {
        HeadlessInAppWebView? headlessWebView;
        try {
          final completer = Completer<Map<dynamic, dynamic>?>();
          final targetUrl = (isLoadMore && nextPageUrl != null) ? nextPageUrl! : baseUrl;

          headlessWebView = HeadlessInAppWebView(
            onWebViewCreated: (controller) async {
              try {
                await controller.loadUrl(urlRequest: URLRequest(url: WebUri(targetUrl)));
              } catch (_) {
                if (!completer.isCompleted) completer.complete(null);
              }
            },
            onLoadStop: (controller, url) async {
              try {
                if (!isLoadMore) {
                  final titleResult = await controller.evaluateJavascript(
                    source: "document.title.split(' - ')[0].trim() || 'Unknown Album'",
                  );
                  if (titleResult is String) {
                    albumTitle = titleResult;
                  }
                }

                await controller.evaluateJavascript(source: '''
                  (async () => {
                    const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
                    let lastHeight = 0; let newHeight = document.body.scrollHeight;
                    while (lastHeight !== newHeight) {
                      window.scrollTo(0, document.body.scrollHeight);
                      await delay(800); lastHeight = newHeight; newHeight = document.body.scrollHeight;
                    }
                  })();
                ''');

                await Future.delayed(const Duration(seconds: 3));

                final result = await controller.evaluateJavascript(source: '''
                  (() => {
                    const nextBtn = document.querySelector('[data-pagination="next"]') || document.querySelector('.pagination-next a') || document.querySelector('.btn-load-more');
                    const nextUrl = nextBtn ? nextBtn.href : null;
                    const images = Array.from(document.querySelectorAll('a.image-container.--media')).map(a => {
                      const img = a.querySelector('img');
                      return { pageUrl: a.href, thumbnailUrl: img ? img.src : '' };
                    });
                    return { "nextUrl": nextUrl, "images": images };
                  })()
                ''');

                if (!completer.isCompleted) {
                  completer.complete(result is Map ? result : null);
                }
              } catch (e) {
                if (!completer.isCompleted) completer.completeError(e);
              }
            },
            onReceivedError: (controller, request, error) {
              if (!completer.isCompleted) completer.complete(null);
            },
          );

          await headlessWebView.run();

          final result = await completer.future.timeout(
            const Duration(seconds: 45),
            onTimeout: () => null,
          );

          if (result != null) {
            final imagesList = result['images'] is List ? result['images'] as List : [];
            final nextUrl = result['nextUrl'] is String ? result['nextUrl'] as String : null;

            final newImages = imagesList
                .where((item) => item is Map && item['pageUrl'] != null)
                .map((item) {
                  final map = item as Map;
                  return ImageData(
                    thumbnailUrl: map['thumbnailUrl'] ?? '',
                    originalUrl: map['pageUrl'] ?? '',
                  );
                })
                .toList();

            int addedCount = 0;
            if (isLoadMore) {
              for (final img in newImages) {
                final isDuplicate = imageUrls.any((existing) => existing.originalUrl == img.originalUrl);
                if (!isDuplicate) {
                  imageUrls.add(img);
                  addedCount++;
                }
              }
            } else {
              imageUrls = newImages;
              addedCount = newImages.length;
            }
            nextPageUrl = nextUrl;
            hasMorePages = nextPageUrl != null;
            isLoading = false;
            isLoadMoreLoading = false;
            notifyListeners();
            showSnackBar(
              isLoadMore 
                  ? 'Loaded $addedCount new images'
                  : 'Found ${imageUrls.length} images in ImgBB album',
              Icons.photo_library_rounded,
            );
          } else {
            isLoading = false;
            isLoadMoreLoading = false;
            error = 'No images found in this ImgBB album.';
            notifyListeners();
            showSnackBar(
              'No images found in this album',
              Icons.warning_rounded,
              isError: true,
            );
          }
        } catch (e) {
          isLoading = false;
          isLoadMoreLoading = false;
          error = e.toString();
          notifyListeners();
          showSnackBar('Scraping failed: $e', Icons.error_rounded, isError: true);
        } finally {
          try {
            await headlessWebView?.dispose();
          } catch (_) {}
        }
      } else {
        // Single ImgBB page URL
        HeadlessInAppWebView? headlessWebView;
        try {
          final completer = Completer<String?>();
          headlessWebView = HeadlessInAppWebView(
            onWebViewCreated: (controller) async {
              try {
                await controller.loadUrl(urlRequest: URLRequest(url: WebUri(baseUrl)));
              } catch (_) {
                if (!completer.isCompleted) completer.complete(null);
              }
            },
            onLoadStop: (controller, url) async {
              try {
                await Future.delayed(const Duration(seconds: 3));
                final html = await controller.getHtml();
                if (html != null) {
                  final regExp = RegExp(
                    r'https://i\.ibb\.co/[a-zA-Z0-9]+/[a-zA-Z0-9\-_.]+\.(?:jpg|jpeg|png|gif|webp|bmp|svg)',
                    caseSensitive: false,
                  );
                  final match = regExp.firstMatch(html);
                  if (!completer.isCompleted) {
                    completer.complete(match?.group(0));
                  }
                } else {
                  if (!completer.isCompleted) completer.complete(null);
                }
              } catch (e) {
                if (!completer.isCompleted) completer.completeError(e);
              }
            },
            onReceivedError: (controller, request, error) {
              if (!completer.isCompleted) completer.complete(null);
            },
          );

          await headlessWebView.run();

          final directUrl = await completer.future.timeout(
            const Duration(seconds: 15),
            onTimeout: () => null,
          );

          if (directUrl != null) {
            imageUrls = [
              ImageData(
                thumbnailUrl: directUrl,
                originalUrl: baseUrl,
              )
            ];
            isLoading = false;
            notifyListeners();
            showSnackBar(
              'Found 1 image',
              Icons.photo_rounded,
            );
          } else {
            isLoading = false;
            error = 'Failed to load single image link.';
            notifyListeners();
            showSnackBar(
              'Failed to find image on page',
              Icons.warning_rounded,
              isError: true,
            );
          }
        } catch (e) {
          isLoading = false;
          error = e.toString();
          notifyListeners();
          showSnackBar('Failed to load image: $e', Icons.error_rounded, isError: true);
        } finally {
          try {
            await headlessWebView?.dispose();
          } catch (_) {}
        }
      }
      return;
    }

    await downloaderService.saveToHistory(
      url: baseUrl,
      celebrityName: mainFolderName,
      galleryTitle: galleryTitle,
    );

    isLoading = true;
    imageUrls.clear();
    selectedImages.clear();
    isSelectionMode = false;
    downloadsSuccessful = 0;
    downloadsFailed = 0;
    currentPage = 0;
    totalPages = 1;
    error = null;
    notifyListeners();

    if (!context.mounted) return;
    final permissionsGranted = await checkPermissions(context);
    if (!context.mounted) return;
    if (permissionsGranted) {
      showSnackBar(
        'Storage permission granted',
        Icons.check_circle_rounded,
        isError: false,
      );
    }

    final parser = ParserFactory.getParser(baseUrl);
    if (mainFolderName.isEmpty && folderController.text.isNotEmpty) {
      mainFolderName = folderController.text.trim();
    } else if (mainFolderName.isEmpty) {
      mainFolderName = parser.defaultMainFolderName;
      folderController.text = mainFolderName;
    }

    final galleryId = parser.extractGalleryId(baseUrl);
    subFolderName = parser.getSubFolderName(mainFolderName, galleryId);

    await downloaderService.setBaseDownloadPath(
      '/storage/emulated/0/Download/RagaDL Downloads',
    );

    if (isBehindwoodsLink) {
      final startVal = int.tryParse(startPageController.text.trim());
      final endVal = int.tryParse(endPageController.text.trim());
      if (startVal == null ||
          endVal == null ||
          startVal <= 0 ||
          endVal <= 0 ||
          startVal > endVal) {
        isLoading = false;
        notifyListeners();
        showSnackBar(
          'Please enter a valid page range (Start Image <= End Image)',
          Icons.warning_rounded,
          isError: true,
        );
        return;
      }

      try {
        final scraper = BehindwoodsScraper();
        final results = await scraper.scrapeRange(
          baseUrl,
          startVal,
          endVal,
          onProgress: (scraped, total) {
            currentPage = scraped;
            totalPages = total;
            notifyListeners();
          },
        );
        imageUrls.addAll(results);
        isLoading = false;
        notifyListeners();
        showSnackBar(
          imageUrls.isEmpty
              ? 'No images found!'
              : 'Found ${imageUrls.length} images',
          imageUrls.isEmpty
              ? Icons.search_off_rounded
              : Icons.photo_library_rounded,
        );
      } catch (e) {
        isLoading = false;
        error = e.toString();
        notifyListeners();
        showSnackBar('Error: $e', Icons.error_rounded, isError: true);
      }
      return;
    }

    downloaderService.processGallery(
      baseUrl: baseUrl,
      onMessage: (data) {
        if (data['type'] == 'progress') {
          currentPage = data['currentPage'];
          totalPages = data['totalPages'];
          notifyListeners();
        } else if (data['type'] == 'images') {
          imageUrls.addAll(data['images']);
          notifyListeners();
        } else if (data['type'] == 'result') {
          isLoading = false;
          notifyListeners();
          showSnackBar(
            imageUrls.isEmpty
                ? 'No images found!'
                : 'Found ${imageUrls.length} images',
            imageUrls.isEmpty
                ? Icons.search_off_rounded
                : Icons.photo_library_rounded,
          );
        } else if (data['type'] == 'error' ||
            data['type'] == 'dio_error' ||
            data['type'] == 'page_error') {
          final errorMsg =
              data['type'] == 'dio_error'
                  ? 'Network error on page ${data['page']}: ${data['error']}'
                  : data['type'] == 'page_error'
                  ? 'Page ${data['page']} failed with status ${data['status']}'
                  : data['error'];
          isLoading = false;
          error = errorMsg;
          notifyListeners();
          showSnackBar('Error: $errorMsg', Icons.error_rounded, isError: true);
        }
      },
    );
  }

  Future<void> downloadAllImages({
    required String? galleryTitle,
    required void Function(bool success, String message) onResult,
  }) async {
    isDownloading = true;
    downloadsSuccessful = 0;
    downloadsFailed = 0;
    notifyListeners();

    final result = await downloaderService.downloadAllImages(
      imageUrls: imageUrls,
      mainFolderName: mainFolderName,
      subFolderName: subFolderName,
      galleryTitle: galleryTitle ?? albumTitle,
    );

    isDownloading = false;
    notifyListeners();

    if (result['success']) {
      onResult(true, 'Added ${result['totalAdded']} images to download queue');
    } else {
      onResult(false, 'Error adding downloads: ${result['error']}');
    }
  }

  Future<void> downloadSelectedImages({
    required String? galleryTitle,
    required void Function(bool success, String message) onResult,
  }) async {
    if (selectedImages.isEmpty) {
      onResult(false, 'No images selected');
      return;
    }

    isDownloading = true;
    downloadsSuccessful = 0;
    downloadsFailed = 0;
    notifyListeners();

    final result = await downloaderService.downloadSelectedImages(
      imageUrls: imageUrls,
      selectedIndices: selectedImages,
      mainFolderName: mainFolderName,
      subFolderName: subFolderName,
      galleryTitle: galleryTitle ?? albumTitle,
    );

    isDownloading = false;
    if (result['success']) {
      selectedImages.clear();
      isSelectionMode = false;
    }
    notifyListeners();

    if (result['success']) {
      onResult(true, 'Added ${result['totalAdded']} images to download queue');
    } else {
      onResult(false, 'Error: ${result['error']}');
    }
  }

  void toggleSelection(int index) {
    if (selectedImages.contains(index)) {
      selectedImages.remove(index);
    } else {
      selectedImages.add(index);
    }
    isSelectionMode = selectedImages.isNotEmpty;
    notifyListeners();
    HapticFeedback.selectionClick();
  }

  void toggleSelectAll() {
    if (selectedImages.length == imageUrls.length) {
      selectedImages.clear();
      isSelectionMode = false;
    } else {
      selectedImages.clear();
      selectedImages.addAll(Iterable<int>.generate(imageUrls.length));
      isSelectionMode = true;
    }
    notifyListeners();
    HapticFeedback.selectionClick();
  }

  // Force rebuilds (used dynamically from UI where required)
  void refreshState() => notifyListeners();
}
