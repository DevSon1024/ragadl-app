import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ragadl/core/permissions.dart';
import '../../logic/downloader_service.dart';

final downloaderControllerProvider = ChangeNotifierProvider.autoDispose<DownloaderController>((ref) {
  final service = DownloaderService();
  final controller = DownloaderController(service);
  ref.onDispose(() {
    controller.dispose();
  });
  return controller;
});

class DownloaderController extends ChangeNotifier {
  final DownloaderService downloaderService;

  DownloaderController(this.downloaderService) {
    urlFocusNode.addListener(_handleFocusChange);
    folderFocusNode.addListener(_handleFocusChange);
    urlController.addListener(_handleUrlChange);
  }

  // Focus nodes & controllers
  final TextEditingController urlController = TextEditingController();
  final TextEditingController folderController = TextEditingController();
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

  @override
  void dispose() {
    urlController.removeListener(_handleUrlChange);
    urlFocusNode.removeListener(_handleFocusChange);
    folderFocusNode.removeListener(_handleFocusChange);
    urlController.dispose();
    folderController.dispose();
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
    if (url.isNotEmpty && url.toLowerCase().contains('idlebrain.com')) {
      final folderName = _extractIdlebrainFolderName(url);
      if (folderName != null && folderName.isNotEmpty && folderController.text != folderName) {
        folderController.text = folderName;
        mainFolderName = folderName;
        notifyListeners();
      }
    }
  }

  String? _extractIdlebrainFolderName(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final segments = uri.pathSegments.where((String s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        final last = segments.last.toLowerCase();
        if (last == 'index.html' || last.endsWith('.html')) {
          return segments[segments.length - 2];
        }
        return segments.last;
      }
    } catch (_) {}
    return null;
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
    notifyListeners();

    HapticFeedback.mediumImpact();
    onClearCompleted();
  }

  void clearSelection() {
    selectedImages.clear();
    isSelectionMode = false;
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
      permissionsGranted = await PermissionHandler.requestAllPermissions(context);
    }
    return permissionsGranted;
  }

  Future<void> processGallery({
    required String baseUrl,
    required String? galleryTitle,
    required BuildContext context,
    required void Function(String message, IconData icon, {bool isError}) showSnackBar,
  }) async {
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

    final permissionsGranted = await checkPermissions(context);
    if (!context.mounted) return;
    if (permissionsGranted) {
      showSnackBar('Storage permission granted', Icons.check_circle_rounded, isError: false);
    }

    if (mainFolderName.isEmpty && folderController.text.isNotEmpty) {
      mainFolderName = folderController.text.trim();
    } else if (mainFolderName.isEmpty) {
      mainFolderName = baseUrl.contains('idlebrain.com') ? "IdlebrainDownloads" : "RagaDownloads";
      folderController.text = mainFolderName;
    }

    if (baseUrl.contains('idlebrain.com')) {
      final galleryId = downloaderService.extractGalleryId(baseUrl);
      if (mainFolderName == galleryId) {
        subFolderName = mainFolderName;
      } else {
        subFolderName = "$mainFolderName-$galleryId";
      }
    } else {
      subFolderName = "$mainFolderName-${downloaderService.extractGalleryId(baseUrl)}";
    }

    await downloaderService.setBaseDownloadPath('/storage/emulated/0/Download/RagaDL Downloads');

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
            imageUrls.isEmpty ? 'No images found!' : 'Found ${imageUrls.length} images',
            imageUrls.isEmpty ? Icons.search_off_rounded : Icons.photo_library_rounded,
          );
        } else if (data['type'] == 'error' || data['type'] == 'dio_error' || data['type'] == 'page_error') {
          final errorMsg = data['type'] == 'dio_error'
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
      galleryTitle: galleryTitle,
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
      galleryTitle: galleryTitle,
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

  // Force rebuilds (used dynamically from UI where required)
  void refreshState() => notifyListeners();
}
