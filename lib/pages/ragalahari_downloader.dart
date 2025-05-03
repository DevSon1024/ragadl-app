import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:html/parser.dart' show parse;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../models/image_data.dart';
import 'dart:math';

class RagalahariDownloader extends StatefulWidget {
  final String? initialUrl;
  final String? initialFolder;
  final String? galleryTitle;

  const RagalahariDownloader({
    Key? key,
    this.initialUrl,
    this.initialFolder,
    this.galleryTitle,
  }) : super(key: key);

  @override
  _RagalahariDownloaderState createState() => _RagalahariDownloaderState();
}

class _RagalahariDownloaderState extends State<RagalahariDownloader> with AutomaticKeepAliveClientMixin {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _folderFocusNode = FocusNode();

  List<ImageData> imageUrls = [];
  bool isLoading = false;
  bool isDownloading = false;
  int downloadsSuccessful = 0;
  int downloadsFailed = 0;
  int currentPage = 0;
  int totalPages = 1;
  String? _error;
  String? _successMessage;
  String mainFolderName = '';
  String subFolderName = '';
  bool _isInitialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _urlFocusNode.addListener(_handleFocusChange);
    _folderFocusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_urlFocusNode.hasFocus || _folderFocusNode.hasFocus) {
      print('RagalahariDownloader TextField gained focus');
    } else {
      print('RagalahariDownloader TextField lost focus');
    }
  }

  @override
  void didUpdateWidget(RagalahariDownloader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if widget params changed and update fields if needed
    if (widget.initialUrl != oldWidget.initialUrl ||
        widget.initialFolder != oldWidget.initialFolder ||
        widget.galleryTitle != oldWidget.galleryTitle) {
      _initializeFields();
    }
  }

  void _initializeFields() {
    if (!_isInitialized ||
        (widget.initialUrl != null && widget.initialUrl != _urlController.text) ||
        (widget.initialFolder != null && widget.initialFolder != mainFolderName) ||
        (widget.galleryTitle != null && widget.galleryTitle != _folderController.text)) {

      if (widget.initialUrl != null) {
        _urlController.text = widget.initialUrl!;
      }

      if (widget.initialFolder != null) {
        mainFolderName = widget.initialFolder!;
        // Use gallery title if available, otherwise use the folder name
        _folderController.text = widget.galleryTitle ?? widget.initialFolder!;
      }

      if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty &&
          widget.initialFolder != null && widget.initialFolder!.isNotEmpty &&
          !_isInitialized) {
        Future.microtask(() {
          _processGallery(widget.initialUrl!);
        });
      }

      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      _urlController.clear();
      _folderController.clear();
      imageUrls.clear();
      mainFolderName = '';
      subFolderName = '';
      downloadsSuccessful = 0;
      downloadsFailed = 0;
      currentPage = 0;
      totalPages = 1;
      _error = null;
      _successMessage = null;
      _isInitialized = false;
    });
    _showSnackBar('All fields and images cleared');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 30) {
        if (!await Permission.manageExternalStorage.isGranted) {
          final status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            _showPermissionDeniedDialog();
          } else {
            _showSnackBar('Storage permission granted');
          }
        }
      } else {
        if (!await Permission.storage.isGranted) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            _showPermissionDeniedDialog();
          } else {
            _showSnackBar('Storage permission granted');
          }
        }
      }
      await Permission.accessMediaLocation.request();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text('This app needs storage permission to download and save images.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  String _extractGalleryId(String url) {
    final RegExp regex = RegExp(r"/(\d+)/");
    final match = regex.firstMatch(url);
    return match?.group(1) ?? url.hashCode.abs().toString();
  }

  String _constructPageUrl(String baseUrl, String galleryId, int index) {
    if (index == 0) return baseUrl;
    return baseUrl.replaceAll(RegExp("$galleryId/?"), "$galleryId/$index/");
  }

  Future<int> _getTotalPages(String url) async {
    try {
      final response = await Dio().get(
        url,
        options: Options(
          headers: {
            'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          },
        ),
      );
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

  void _removeUnwantedDivs(var document) {
    final unwantedHeadings = {"Latest Local Events", "Latest Movie Events", "Latest Starzone"};
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

  List<ImageData> _extractImageUrls(var document) {
    final Set<ImageData> imageDataSet = {};
    for (var img in document.querySelectorAll("img")) {
      final src = img.attributes['src'];
      if (src == null || !src.toLowerCase().endsWith(".jpg") || (!src.startsWith("http") && !src.startsWith("../"))) {
        continue;
      }
      String thumbnailUrl = src.startsWith("http") ? src : "https://www.ragalahari.com/${src.replaceAll("../", "")}";
      String originalUrl =
      src.replaceAll(RegExp(r't(?=\.jpg)', caseSensitive: false), '').startsWith("http")
          ? src.replaceAll(RegExp(r't(?=\.jpg)', caseSensitive: false), '')
          : "https://www.ragalahari.com/${src.replaceAll("../", "").replaceAll(RegExp(r't(?=\.jpg)', caseSensitive: false), '')}";
      imageDataSet.add(ImageData(thumbnailUrl: thumbnailUrl, originalUrl: originalUrl));
    }
    return imageDataSet.toList();
  }

  Future<void> _processGallery(String baseUrl) async {
    try {
      setState(() {
        isLoading = true;
        imageUrls.clear();
        downloadsSuccessful = 0;
        downloadsFailed = 0;
        currentPage = 0;
      });
      await _requestPermissions();
      final galleryId = _extractGalleryId(baseUrl);

      // Make sure we have a main folder name set
      if (mainFolderName.isEmpty && _folderController.text.isNotEmpty) {
        mainFolderName = _folderController.text.trim();
      } else if (mainFolderName.isEmpty) {
        mainFolderName = "RagalahariDownloads";
        _folderController.text = mainFolderName;
      }

      subFolderName = "$mainFolderName-$galleryId";
      totalPages = await _getTotalPages(baseUrl);
      final Set<ImageData> allImageUrls = {};
      for (int i = 0; i < totalPages; i++) {
        setState(() {
          currentPage = i + 1;
        });
        final pageUrl = _constructPageUrl(baseUrl, galleryId, i);
        final response = await Dio().get(
          pageUrl,
          options: Options(
            headers: {
              'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            },
          ),
        );
        if (response.statusCode == 200) {
          final document = parse(response.data);
          _removeUnwantedDivs(document);
          final pageImages = _extractImageUrls(document);
          allImageUrls.addAll(pageImages);
        }
      }
      setState(() {
        imageUrls = allImageUrls.toList();
        isLoading = false;
      });
      _showSnackBar(imageUrls.isEmpty ? 'No images found!' : 'Found ${imageUrls.length} images');
    } catch (e) {
      setState(() {
        isLoading = false;
        _error = 'Error: $e';
      });
      _showSnackBar('Error: $e');
    }
  }

  Future<String> _getDownloadDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    }
    directory ??= await getApplicationDocumentsDirectory();

    // Only use mainFolderName for the directory structure
    final downloadPath = Directory('${directory.path}/Ragalahari Downloads/$mainFolderName');
    if (!await downloadPath.exists()) {
      await downloadPath.create(recursive: true);
    }
    return downloadPath.path;
  }

  Future<void> _downloadAllImages() async {
    try {
      setState(() {
        isDownloading = true;
        downloadsSuccessful = 0;
        downloadsFailed = 0;
      });
      const maxConcurrent = 5;
      for (int i = 0; i < imageUrls.length; i += maxConcurrent) {
        final batch = imageUrls.skip(i).take(maxConcurrent).toList();
        final futures = batch.asMap().entries.map((entry) => _downloadImage(entry.value.originalUrl, i + entry.key + 1)).toList();
        final results = await Future.wait(futures);
        setState(() {
          downloadsSuccessful += results.where((success) => success).length;
          downloadsFailed += results.where((success) => !success).length;
        });
      }
      _showSnackBar('Downloaded $downloadsSuccessful/${imageUrls.length} images');
    } catch (e) {
      _showSnackBar('Error downloading images: $e');
    } finally {
      setState(() {
        isDownloading = false;
      });
    }
  }

  Future<bool> _downloadImage(String url, int index) async {
    try {
      final filename = 'image-$index.jpg';
      final savePath = '${await _getDownloadDirectory()}/$filename';
      if (await File(savePath).exists()) return true;
      final response = await Dio().get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          },
        ),
      );
      await File(savePath).writeAsBytes(response.data);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    print('RagalahariDownloader build, urlFocus: ${_urlFocusNode.hasFocus}, folderFocus: ${_folderFocusNode.hasFocus}');
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _folderController,
                  decoration: InputDecoration(
                    labelText: 'Enter Main Folder Name',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_box_rounded),
                      onPressed: () {
                        setState(() {
                          mainFolderName = _folderController.text.trim().isEmpty ? 'RagalahariDownloads' : _folderController.text.trim();
                        });
                        _showSnackBar('Main Folder Set To: $mainFolderName');
                      },
                    ),
                  ),
                  autofocus: false,
                  enableSuggestions: false, // Disable autofill suggestions
                  autocorrect: false, // Disable autocorrect
                  keyboardType: TextInputType.text, // Explicitly set keyboard type
                  onTap: () {
                    print('Folder TextField tapped');
                  },
                ),
                const SizedBox(height: 8.0),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'Enter Ragalahari Gallery URL',
                    border: const OutlineInputBorder(),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.content_copy, size: 20),
                            onPressed: () {
                              if (_urlController.text.isNotEmpty) {
                                Clipboard.setData(ClipboardData(text: _urlController.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('URL copied to clipboard')),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 4), // Add some space between buttons
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => _urlController.clear(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  autofocus: false,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  onTap: () {
                    print('URL TextField tapped');
                  },
                ),
                const SizedBox(height: 8.0),
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (isLoading || isDownloading || mainFolderName.isEmpty)
                                ? null
                                : () {
                              final url = _urlController.text.trim();
                              if (url.isEmpty) {
                                _showSnackBar('Please enter a URL');
                                return;
                              }
                              _processGallery(url);
                            },
                            icon: const Icon(Icons.search),
                            label: const Text('Fetch Images'),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (isLoading || isDownloading || imageUrls.isEmpty || mainFolderName.isEmpty)
                                ? null
                                : _downloadAllImages,
                            icon: const Icon(Icons.download),
                            label: const Text('Download All'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear All'),
                      ),
                    ),
                  ],
                ),
                if (isLoading || isDownloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: isLoading
                              ? (currentPage / totalPages)
                              : (downloadsSuccessful + downloadsFailed) / imageUrls.length,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLoading
                              ? 'Fetching page $currentPage of $totalPages...'
                              : 'Downloaded: $downloadsSuccessful, Failed: $downloadsFailed',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (_successMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: isLoading
                ? const Center(
              key: ValueKey('loader'),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
                : const SizedBox.shrink(key: ValueKey('grid')),
          ),
        ),
        if (!isLoading)
          SliverPadding(
            padding: const EdgeInsets.all(8.0),
            sliver: imageUrls.isEmpty
                ? const SliverToBoxAdapter(child: Center(child: Text('No images to display')))
                : SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 4.0,
                mainAxisSpacing: 4.0,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final imageData = imageUrls[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => FullImagePage(
                            imageUrls: imageUrls,
                            initialIndex: index,
                          ),
                          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: imageData.originalUrl,
                            child: CachedNetworkImage(
                              imageUrl: imageData.thumbnailUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(color: Colors.grey[300]),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Image ${index + 1}',
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: imageUrls.length,
              ),
            ),
          ),
      ],
    );
  }
}

class FullImagePage extends StatefulWidget {
  final List<ImageData> imageUrls;
  final int initialIndex;

  const FullImagePage({Key? key, required this.imageUrls, required this.initialIndex}) : super(key: key);

  @override
  _FullImagePageState createState() => _FullImagePageState();
}

class _FullImagePageState extends State<FullImagePage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;
  final List<TransformationController> _transformationControllers = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    for (int i = 0; i < widget.imageUrls.length; i++) {
      _transformationControllers.add(TransformationController());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _transformationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _downloadImage(String imageUrl) async {
    setState(() => _isDownloading = true);
    try {
      final directory = await _getDownloadDirectory();
      final filename = imageUrl.split('/').last;
      final savePath = '$directory/$filename';
      final saveDir = Directory(directory);
      if (!await saveDir.exists()) await saveDir.create(recursive: true);
      final response = await Dio().get(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          },
        ),
      );
      if (response.statusCode == 200) {
        await File(savePath).writeAsBytes(response.data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded $filename')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<String> _getDownloadDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download/Ragalahari Downloads');
      if (!await directory.exists()) directory = await getExternalStorageDirectory();
    }
    return (directory ?? await getApplicationDocumentsDirectory()).path;
  }

  @override
  Widget build(BuildContext context) {
    final currentImageData = widget.imageUrls[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Image ${_currentIndex + 1} of ${widget.imageUrls.length}'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: currentImageData.originalUrl));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image URL copied to clipboard')));
            },
          ),
          IconButton(
            icon: _isDownloading ? const CircularProgressIndicator() : const Icon(Icons.download),
            onPressed: _isDownloading ? null : () => _downloadImage(currentImageData.originalUrl),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final imageData = widget.imageUrls[index];
          return InteractiveViewer(
            transformationController: _transformationControllers[index],
            minScale: 0.1,
            maxScale: 4.0,
            child: Hero(
              tag: imageData.originalUrl,
              child: CachedNetworkImage(
                imageUrl: imageData.originalUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          );
        },
      ),
    );
  }
}