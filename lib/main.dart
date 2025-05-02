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
import 'history_page.dart';
import 'download_manager_page.dart';
import 'celebrity_list_page.dart';
import 'models/image_data.dart';
import 'package:http/http.dart' as http;
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ragalahari Downloader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const RagalahariDownloader(),
    );
  }
}

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

class _RagalahariDownloaderState extends State<RagalahariDownloader> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();
  final TextEditingController _startPageController = TextEditingController();
  final TextEditingController _endPageController = TextEditingController();

  final List<String> validDomains = [
    "media.ragalahari.com",
    "img.ragalahari.com",
    "szcdn.ragalahari.com",
    "starzone.ragalahari.com",
    "imgcdn.ragalahari.com",
  ];

  List<ImageData> imageUrls = [];
  bool isLoading = false;
  bool isDownloading = false;
  bool _isScraping = false;
  int downloadsSuccessful = 0;
  int downloadsFailed = 0;
  int currentPage = 0;
  int totalPages = 1;
  String? _error;
  String? _successMessage;
  String mainFolderName = '';
  String subFolderName = '';
  int _totalPages = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();

    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      if (widget.galleryTitle != null && widget.initialFolder != null) {
        _folderController.text = '${widget.initialFolder!}/${widget.galleryTitle!.replaceAll("-", " ")}';
      }
    }
    if (widget.initialFolder != null) {
      _folderController.text = widget.initialFolder!;
      mainFolderName = widget.initialFolder!;
    }

    _analyzeUrl();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _folderController.dispose();
    _startPageController.dispose();
    _endPageController.dispose();
    super.dispose();
  }

  // Clear all fields and images
  void _clearAll() {
    setState(() {
      _urlController.clear();
      _folderController.clear();
      _startPageController.clear();
      _endPageController.clear();
      imageUrls.clear();
      mainFolderName = '';
      subFolderName = '';
      downloadsSuccessful = 0;
      downloadsFailed = 0;
      currentPage = 0;
      totalPages = 1;
      _totalPages = 0;
      _error = null;
      _successMessage = null;
    });
    _showSnackBar('All fields and images cleared');
  }

  // Analyze URL to get page count
  Future<void> _analyzeUrl() async {
    if (_urlController.text.isEmpty) return;

    final Map<String, String> headers = {
      'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    };

    setState(() {
      isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final url = _urlController.text.trim();
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final document = parse(response.body);
        final pageLinks = document.getElementsByClassName('otherPage');
        final lastPage = pageLinks.isEmpty
            ? 1
            : pageLinks.map((e) => int.tryParse(e.text.trim()) ?? 1).reduce(max);

        setState(() {
          _totalPages = lastPage;
          _startPageController.text = '1';
          _endPageController.text = lastPage.toString();
          isLoading = false;
          _successMessage = 'Gallery has $lastPage pages';
        });
      } else {
        setState(() {
          isLoading = false;
          _error = 'Failed to load page: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        _error = 'Error analyzing URL: $e';
      });
    }
  }


  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 30) {
        if (!await Permission.manageExternalStorage.isGranted) {
          final status = await Permission.manageExternalStorage.request();
          if (status.isGranted) {
            _showSnackBar('Storage permission granted');
          } else {
            _showPermissionDeniedDialog();
          }
        }
      } else {
        if (!await Permission.storage.isGranted) {
          final status = await Permission.storage.request();
          if (status.isGranted) {
            _showSnackBar('Storage permission granted');
          } else {
            _showPermissionDeniedDialog();
          }
        }
      }

      await Permission.accessMediaLocation.request();
    }
  }

  void _showPermissionDeniedDialog() {
    _showSnackBar('Storage permission denied. App may not work correctly.');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
          'This app needs storage permission to download and save works correctly.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _extractGalleryId(String url) {
    final RegExp regex = RegExp(r"/(\d+)/");
    final match = regex.firstMatch(url);
    if (match != null) {
      return match.group(1)!;
    }
    return url.hashCode.abs().toString();
  }

  String _constructPageUrl(String baseUrl, String galleryId, int index) {
    if (index == 0) {
      return baseUrl;
    }
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
            .map((e) => e.text)
            .where((text) => int.tryParse(text) != null)
            .map((text) => int.parse(text))
            .toList();

        return pages.isEmpty ? 1 : pages.reduce((max, page) => max > page ? max : page);
      }
      return 1;
    } catch (e) {
      print("Error getting total pages: $e");
      return 1;
    }
  }

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
      if (div != null) {
        div.remove();
      }
    }
  }

  List<ImageData> _extractImageUrls(var document) {
    final Set<ImageData> imageDataSet = {};

    for (var img in document.querySelectorAll("img")) {
      final src = img.attributes['src'];
      if (src == null) continue;
      if (!src.toLowerCase().endsWith(".jpg")) continue;
      if (!src.startsWith("http") && !src.startsWith("../")) continue;

      String thumbnailUrl = src;
      if (!thumbnailUrl.startsWith("http")) {
        thumbnailUrl = "https://www.ragalahari.com/${thumbnailUrl.replaceAll("../", "")}";
      }

      String originalUrl = src.replaceAll(RegExp(r't(?=\.jpg)', caseSensitive: false), '');
      if (!originalUrl.startsWith("http")) {
        originalUrl = "https://www.ragalahari.com/${originalUrl.replaceAll("../", "")}";
      }

      imageDataSet.add(ImageData(
        thumbnailUrl: thumbnailUrl,
        originalUrl: originalUrl,
      ));
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

      final galleryId = _extractGalleryId(baseUrl);
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

      if (imageUrls.isEmpty) {
        _showSnackBar('No images found!');
      } else {
        _showSnackBar('Found ${imageUrls.length} images');
      }
    } catch (e) {
      print("Error processing gallery: $e");
      _showSnackBar('Error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String> _getDownloadDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      try {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } catch (e) {
        directory = await getExternalStorageDirectory();
      }

      if (directory == null) {
        directory = await getApplicationDocumentsDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final downloadPath = Directory('${directory.path}/Ragalahari Downloads/$mainFolderName/$subFolderName');
    try {
      if (!await downloadPath.exists()) {
        await downloadPath.create(recursive: true);
      }
    } catch (e) {
      print("Error creating directory: $e");
      if (Platform.isAndroid) {
        final simpleDownloadPath = Directory('${directory.path}/RagalahariDownloads');
        if (!await simpleDownloadPath.exists()) {
          await simpleDownloadPath.create(recursive: true);
        }
        return simpleDownloadPath.path;
      }
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

      final futures = <Future<bool>>[];
      const maxConcurrent = 5;

      for (int i = 0; i < imageUrls.length; i += maxConcurrent) {
        final batch = imageUrls.skip(i).take(maxConcurrent).toList();
        futures.clear();

        for (int j = 0; j < batch.length; j++) {
          futures.add(_downloadImage(batch[j].originalUrl, i + j + 1));
        }

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
      print('Saving image to: $savePath');

      if (await File(savePath).exists()) {
        print('File already exists: $filename');
        return true;
      }

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
      print('Error downloading image $url: $e');
      return false;
    }
  }

  Widget _buildImageGrid() {
    if (imageUrls.isEmpty) {
      return const Center(
        child: Text('No images to display'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final url = _urlController.text.trim();
        if (url.isNotEmpty) {
          await _processGallery(url);
        }
      },
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(8.0),
        itemCount: imageUrls.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
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
                  transitionsBuilder: (_, anim, __, child) {
                    return FadeTransition(
                      opacity: anim,
                      child: child,
                    );
                  },
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
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (ModalRoute.of(context)?.isFirst ?? false) {
          return await _confirmExit();
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ragalahari Downloader'),
          automaticallyImplyLeading: false,
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              ),
            ),
          ],
        ),
        endDrawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Text('Ragalahari Options',
                    style: TextStyle(color: Colors.white, fontSize: 20)),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('History'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HistoryPage(),
                      maintainState: false,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Downloads'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DownloadManagerPage(),
                      maintainState: false,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Celebrities'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CelebrityListPage(),
                      maintainState: false,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Exit'),
                onTap: () async {
                  Navigator.pop(context);
                  if (await _confirmExit()) {
                    SystemNavigator.pop();
                  }
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _folderController,
                decoration: InputDecoration(
                  labelText: 'Enter main folder name',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {
                      setState(() {
                        mainFolderName = _folderController.text.trim();
                        if (mainFolderName.isEmpty) {
                          mainFolderName = 'RagalahariDownloads';
                        }
                      });
                      _showSnackBar('Main folder set to: $mainFolderName');
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'Enter Ragalahari Gallery URL',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _urlController.clear(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
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
                ],
              ),
            ),
            if (isLoading || isDownloading)
              Padding(
                padding: const EdgeInsets.all(8.0),
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
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: isLoading
                    ? const Center(
                  key: ValueKey('loader'),
                  child: CircularProgressIndicator(),
                )
                    : Container(
                  key: const ValueKey('grid'),
                  child: _buildImageGrid(),
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

  const FullImagePage({
    Key? key,
    required this.imageUrls,
    required this.initialIndex,
  }) : super(key: key);

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
    setState(() {
      _isDownloading = true;
    });

    try {
      final directory = await _getDownloadDirectory();
      final filename = imageUrl.split('/').last;
      final savePath = '$directory/$filename';

      final saveDir = Directory(directory);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

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
        final file = File(savePath);
        await file.writeAsBytes(response.data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloaded $filename')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<String> _getDownloadDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      try {
        directory = Directory('/storage/emulated/0/Download/Ragalahari Downloads');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } catch (e) {
        directory = await getExternalStorageDirectory();
      }

      if (directory == null) {
        directory = await getApplicationDocumentsDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    return directory.path;
  }

  @override
  Widget build(BuildContext context) {
    final currentImageData = widget.imageUrls[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Image ${_currentIndex + 1} of ${widget.imageUrls.length}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: currentImageData.originalUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image URL copied to clipboard')),
              );
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
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          );
        },
      ),
    );
  }
}