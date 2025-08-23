import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'download_manager_page.dart';
import 'package:ragalahari_downloader/main.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'link_history_page.dart';
import 'package:ragalahari_downloader/permissions.dart';
import '../widgets/grid_utils.dart';

class RagalahariDownloader extends StatefulWidget {
  final String? initialUrl;
  final String? initialFolder;
  final String? galleryTitle;

  const RagalahariDownloader({
    super.key,
    this.initialUrl,
    this.initialFolder,
    this.galleryTitle,
  });

  @override
  _RagalahariDownloaderState createState() => _RagalahariDownloaderState();
}

class _RagalahariDownloaderState extends State<RagalahariDownloader>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _folderFocusNode = FocusNode();

  List<ImageData> imageUrls = [];
  Set<int> selectedImages = {};
  bool isLoading = false;
  bool isDownloading = false;
  bool isSelectionMode = false;
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
    setState(() {});
  }

  @override
  void didUpdateWidget(RagalahariDownloader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != oldWidget.initialUrl ||
        widget.initialFolder != oldWidget.initialFolder) {
      _initializeFields();
    }
  }

  void _initializeFields() {
    if (!_isInitialized ||
        (widget.initialUrl != null && widget.initialUrl != _urlController.text) ||
        (widget.initialFolder != null && widget.initialFolder != _folderController.text)) {
      if (widget.initialUrl != null) {
        _urlController.text = widget.initialUrl!;
      }

      if (widget.initialFolder != null) {
        mainFolderName = widget.initialFolder!;
        _folderController.text = widget.initialFolder!;
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
    _urlFocusNode.dispose();
    _folderFocusNode.dispose();
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      _urlController.clear();
      _folderController.clear();
      imageUrls.clear();
      selectedImages.clear();
      isSelectionMode = false;
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

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      final pastedUrl = clipboardData.text!.trim();
      setState(() {
        _urlController.text = pastedUrl;
      });
    }
  }

  Future<void> _checkPermissions() async {
    bool permissionsGranted = await PermissionHandler.checkStoragePermissions();
    if (!permissionsGranted) {
      permissionsGranted = await PermissionHandler.requestAllPermissions(context);
    }
    if (permissionsGranted) {
      _showSnackBar('Storage permission granted');
    }
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

  Future<void> _saveToHistory(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final historyKey = 'link_history';
    List<String> historyJson = prefs.getStringList(historyKey) ?? [];
    List<LinkHistoryItem> history = historyJson
        .map((json) => LinkHistoryItem.fromJson(jsonDecode(json)))
        .toList();

    final historyItem = LinkHistoryItem(
      url: url,
      celebrityName: mainFolderName,
      galleryTitle: widget.galleryTitle,
      timestamp: DateTime.now(),
    );

    if (!history.any((item) => item.url == url && item.celebrityName == mainFolderName)) {
      history.add(historyItem);
      await prefs.setStringList(
          historyKey, history.map((h) => jsonEncode(h.toJson())).toList());
    }
  }

  Future<void> _processGallery(String baseUrl) async {
    await _saveToHistory(baseUrl);
    try {
      setState(() {
        isLoading = true;
        imageUrls.clear();
        selectedImages.clear();
        isSelectionMode = false;
        downloadsSuccessful = 0;
        downloadsFailed = 0;
        currentPage = 0;
      });
      await _checkPermissions();
      final galleryId = _extractGalleryId(baseUrl);

      if (mainFolderName.isEmpty && _folderController.text.isNotEmpty) {
        mainFolderName = _folderController.text.trim();
      } else if (mainFolderName.isEmpty) {
        mainFolderName = "RagalahariDownloads";
        _folderController.text = mainFolderName;
      }

      subFolderName = "$mainFolderName-$galleryId";
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('base_download_path', '/storage/emulated/0/Download/Ragalahari Downloads');
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

  Future<void> _downloadAllImages() async {
    try {
      setState(() {
        isDownloading = true;
        downloadsSuccessful = 0;
        downloadsFailed = 0;
      });

      final downloadManager = DownloadManager();
      final batchId = DateTime.now().millisecondsSinceEpoch.toString();
      for (int i = 0; i < imageUrls.length; i++) {
        final imageUrl = imageUrls[i].originalUrl;

        downloadManager.addDownload(
          url: imageUrl,
          folder: mainFolderName,
          subFolder: subFolderName,
          batchId: batchId,
          onProgress: (progress) {},
          onComplete: (success) {
            setState(() {
              if (success) {
                downloadsSuccessful++;
              } else {
                downloadsFailed++;
              }
            });
          },
        );
      }

      _showSnackBar('Added ${imageUrls.length} images to download queue');

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DownloadManagerPage()),
      );
    } catch (e) {
      _showSnackBar('Error adding downloads: $e');
    } finally {
      setState(() {
        isDownloading = false;
      });
    }
  }

  Future<void> _downloadSelectedImages() async {
    if (selectedImages.isEmpty) {
      _showSnackBar('No images selected');
      return;
    }

    try {
      setState(() {
        isDownloading = true;
        downloadsSuccessful = 0;
        downloadsFailed = 0;
      });

      final downloadManager = DownloadManager();
      final batchId = DateTime.now().millisecondsSinceEpoch.toString();
      for (int index in selectedImages) {
        final imageUrl = imageUrls[index].originalUrl;

        downloadManager.addDownload(
          url: imageUrl,
          folder: mainFolderName,
          subFolder: subFolderName,
          batchId: batchId,
          onProgress: (progress) {},
          onComplete: (success) {
            setState(() {
              if (success) {
                downloadsSuccessful++;
              } else {
                downloadsFailed++;
              }
            });
          },
        );
      }

      _showSnackBar('Added ${selectedImages.length} images to download queue');

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DownloadManagerPage()),
      );
    } catch (e) {
      _showSnackBar('Error adding downloads: $e');
    } finally {
      setState(() {
        isDownloading = false;
        selectedImages.clear();
        isSelectionMode = false;
      });
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (selectedImages.contains(index)) {
        selectedImages.remove(index);
      } else {
        selectedImages.add(index);
      }
      isSelectionMode = selectedImages.isNotEmpty;
    });
  }

  bool _isValidRagalahariUrl(String url) {
    return url.trim().startsWith('https://www.ragalahari.com');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    print(
        'RagalahariDownloader build, urlFocus: ${_urlFocusNode.hasFocus}, folderFocus: ${_folderFocusNode.hasFocus}');
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Downloader',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      resizeToAvoidBottomInset: true,
      floatingActionButton: Stack(
        children: [
          Visibility(
            visible: _urlFocusNode.hasFocus,
            child: FloatingActionButton(
              onPressed: _pasteFromClipboard,
              tooltip: 'Paste URL from Clipboard',
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.paste),
            ),
          ),
          Visibility(
            visible: imageUrls.isNotEmpty && isSelectionMode && !isLoading && !isDownloading,
            child: FloatingActionButton.extended(
              onPressed: _downloadSelectedImages,
              icon: const Icon(Icons.download_for_offline),
              label: Text('Download ${selectedImages.length}'),
              backgroundColor: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: CustomScrollView(
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
                              mainFolderName =
                              _folderController.text.trim().isEmpty
                                  ? 'RagalahariDownloads'
                                  : _folderController.text.trim();
                            });
                            _showSnackBar('Main Folder Set To: $mainFolderName');
                          },
                        ),
                      ),
                      autofocus: false,
                      enableSuggestions: false,
                      autocorrect: false,
                      keyboardType: TextInputType.text,
                      onTap: () {
                        print('Folder TextField tapped');
                      },
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      controller: _urlController,
                      focusNode: _urlFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Enter Ragalahari Gallery URL',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _urlController.text.isNotEmpty &&
                                !_isValidRagalahariUrl(_urlController.text)
                                ? Colors.red
                                : Theme.of(context).primaryColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _urlController.text.isNotEmpty &&
                                !_isValidRagalahariUrl(_urlController.text)
                                ? Colors.red
                                : Theme.of(context).primaryColor,
                          ),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                        errorText: _urlController.text.isNotEmpty &&
                            !_isValidRagalahariUrl(_urlController.text)
                            ? 'URL must start with https://www.ragalahari.com'
                            : null,
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.content_copy, size: 20),
                                onPressed: () {
                                  if (_urlController.text.isNotEmpty) {
                                    Clipboard.setData(ClipboardData(
                                        text: _urlController.text));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('URL copied to clipboard')),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 4),
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
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8.0),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (isLoading ||
                                    isDownloading ||
                                    mainFolderName.isEmpty)
                                    ? null
                                    : () {
                                  final url = _urlController.text.trim();
                                  if (url.isEmpty) {
                                    _showSnackBar('Please enter a URL');
                                    return;
                                  }
                                  if (!_isValidRagalahariUrl(url)) {
                                    _showSnackBar(
                                        'Invalid URL: Must start with https://www.ragalahari.com');
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
                                onPressed: (isLoading ||
                                    isDownloading ||
                                    imageUrls.isEmpty ||
                                    mainFolderName.isEmpty)
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
                        if (isSelectionMode)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Selected ${selectedImages.length} images',
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
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
                                  : (downloadsSuccessful + downloadsFailed) /
                                  imageUrls.length,
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
                    ? const SliverToBoxAdapter(
                    child: Center(child: Text('No images to display')))
                    : SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: calculateGridColumns(context),
                    crossAxisSpacing: 4.0,
                    mainAxisSpacing: 4.0,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final imageData = imageUrls[index];
                      final isSelected = selectedImages.contains(index);
                      return GestureDetector(
                        onTap: () {
                          if (isSelectionMode) {
                            _toggleSelection(index);
                          } else {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => FullImagePage(
                                  imageUrls: imageUrls,
                                  initialIndex: index,
                                ),
                                transitionsBuilder: (_, anim, __, child) =>
                                    FadeTransition(opacity: anim, child: child),
                                transitionDuration:
                                const Duration(milliseconds: 300),
                              ),
                            );
                          }
                        },
                        onLongPress: () => _toggleSelection(index),
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
                                  placeholder: (context, url) =>
                                      Shimmer.fromColors(
                                        baseColor: Colors.grey[300]!,
                                        highlightColor: Colors.grey[100]!,
                                        child: Container(color: Colors.grey[300]),
                                      ),
                                  errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  color: Colors.blue.withOpacity(0.3),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 30,
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
        ),
      ),
    );
  }
}

class FullImagePage extends StatefulWidget {
  final List<ImageData> imageUrls;
  final int initialIndex;

  const FullImagePage({super.key, required this.imageUrls, required this.initialIndex});

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
      final downloadManager = DownloadManager();
      downloadManager.addDownload(
        url: imageUrl,
        folder: "SingleImages",
        subFolder: DateTime.now().toString().split(' ')[0],
        onProgress: (progress) {},
        onComplete: (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(success
                    ? 'Added to download manager'
                    : 'Failed to add download')));
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to download: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImageData = widget.imageUrls[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Image ${_currentIndex + 1} of ${widget.imageUrls.length}'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: currentImageData.originalUrl));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Image URL copied to clipboard')));
            },
          ),
          IconButton(
            icon: _isDownloading
                ? const CircularProgressIndicator()
                : const Icon(Icons.download),
            onPressed: _isDownloading
                ? null
                : () => _downloadImage(currentImageData.originalUrl),
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
                placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                const Icon(Icons.error),
              ),
            ),
          );
        },
      ),
    );
  }
}