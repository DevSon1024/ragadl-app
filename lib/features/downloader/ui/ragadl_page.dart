import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../logic/downloader_service.dart';
import 'download_manager_page.dart';
import 'link_history_page.dart';
import '../../../shared/widgets/grid_utils.dart';
import 'package:ragadl/core/permissions.dart';

class RagaDL extends StatefulWidget {
  final String? initialUrl;
  final String? initialFolder;
  final String? galleryTitle;

  const RagaDL({
    super.key,
    this.initialUrl,
    this.initialFolder,
    this.galleryTitle,
  });

  @override
  State<RagaDL> createState() => _RagadlState();
}

class _RagadlState extends State<RagaDL>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  // Controllers
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _folderFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Service
  late DownloaderService _downloaderService;

  // State variables
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

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _downloaderService = DownloaderService();
    _initializeAnimations();
    _initializeFields();
    _urlFocusNode.addListener(_handleFocusChange);
    _folderFocusNode.addListener(_handleFocusChange);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  void _handleFocusChange() {
    setState(() {});
    HapticFeedback.lightImpact();
  }

  @override
  void didUpdateWidget(RagaDL oldWidget) {
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

      if (widget.initialUrl != null &&
          widget.initialUrl!.isNotEmpty &&
          widget.initialFolder != null &&
          widget.initialFolder!.isNotEmpty &&
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
    _scrollController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _downloaderService.dispose();
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

    HapticFeedback.mediumImpact();
    _showModernSnackBar('All fields and images cleared', Icons.clear_all_rounded);
  }

  void _showModernSnackBar(String message, IconData icon, [bool isError = false]) {
    if (!mounted) return;
    final color = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: isError ? color.onError : color.onInverseSurface, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: isError ? color.error : color.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(milliseconds: isError ? 4000 : 2500),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      final pastedUrl = clipboardData.text!.trim();
      setState(() {
        _urlController.text = pastedUrl;
      });
      HapticFeedback.mediumImpact();
      _showModernSnackBar('URL pasted from clipboard', Icons.paste_rounded);
    }
  }

  Future<void> _checkPermissions() async {
    bool permissionsGranted = await PermissionHandler.checkStoragePermissions();
    if (!permissionsGranted) {
      permissionsGranted = await PermissionHandler.requestAllPermissions(context);
    }
    if (permissionsGranted) {
      _showModernSnackBar('Storage permission granted', Icons.check_circle_rounded);
    }
  }

  Future<void> _processGallery(String baseUrl) async {
    // Save to history
    await _downloaderService.saveToHistory(
      url: baseUrl,
      celebrityName: mainFolderName,
      galleryTitle: widget.galleryTitle,
    );

    setState(() {
      isLoading = true;
      imageUrls.clear();
      selectedImages.clear();
      isSelectionMode = false;
      downloadsSuccessful = 0;
      downloadsFailed = 0;
      currentPage = 0;
      totalPages = 1;
      _error = null;
    });

    await _checkPermissions();

    if (mainFolderName.isEmpty && _folderController.text.isNotEmpty) {
      mainFolderName = _folderController.text.trim();
    } else if (mainFolderName.isEmpty) {
      mainFolderName = "RagaDownloads";
      _folderController.text = mainFolderName;
    }

    subFolderName = "$mainFolderName-${_downloaderService.extractGalleryId(baseUrl)}";

    await _downloaderService.setBaseDownloadPath(
      '/storage/emulated/0/Download/RagaDL Downloads',
    );

    // Process gallery
    _downloaderService.processGallery(
      baseUrl: baseUrl,
      onMessage: (data) {
        if (data['type'] == 'progress') {
          setState(() {
            currentPage = data['currentPage'];
            totalPages = data['totalPages'];
          });
        } else if (data['type'] == 'images') {
          setState(() {
            imageUrls.addAll(data['images']);
          });
        } else if (data['type'] == 'result') {
          setState(() {
            isLoading = false;
          });
          _showModernSnackBar(
            imageUrls.isEmpty ? 'No images found!' : 'Found ${imageUrls.length} images',
            imageUrls.isEmpty ? Icons.search_off_rounded : Icons.photo_library_rounded,
          );
        } else if (data['type'] == 'error' || data['type'] == 'dio_error' || data['type'] == 'page_error') {
          final errorMsg = data['type'] == 'dio_error'
              ? 'Network error on page ${data['page']}: ${data['error']}'
              : data['type'] == 'page_error'
              ? 'Page ${data['page']} failed with status ${data['status']}'
              : data['error'];
          setState(() {
            isLoading = false;
            _error = errorMsg;
          });
          _showModernSnackBar('Error: $errorMsg', Icons.error_rounded, true);
        }
      },
    );
  }

  Future<void> _downloadAllImages() async {
    setState(() {
      isDownloading = true;
      downloadsSuccessful = 0;
      downloadsFailed = 0;
    });

    final result = await _downloaderService.downloadAllImages(
      imageUrls: imageUrls,
      mainFolderName: mainFolderName,
      subFolderName: subFolderName,
      galleryTitle: widget.galleryTitle,
    );

    setState(() {
      isDownloading = false;
    });

    if (result['success']) {
      _showModernSnackBar(
        'Added ${result['totalAdded']} images to download queue',
        Icons.download_for_offline_rounded,
      );
      Navigator.push(
        context,
        _createModernPageRoute(const DownloadManagerPage()),
      );
    } else {
      _showModernSnackBar(
        'Error adding downloads: ${result['error']}',
        Icons.error_rounded,
        true,
      );
    }
  }

  Future<void> _downloadSelectedImages() async {
    if (selectedImages.isEmpty) {
      _showModernSnackBar('No images selected', Icons.warning_rounded, true);
      return;
    }

    setState(() {
      isDownloading = true;
      downloadsSuccessful = 0;
      downloadsFailed = 0;
    });

    final result = await _downloaderService.downloadSelectedImages(
      imageUrls: imageUrls,
      selectedIndices: selectedImages,
      mainFolderName: mainFolderName,
      subFolderName: subFolderName,
      galleryTitle: widget.galleryTitle,
    );

    setState(() {
      isDownloading = false;
      if (result['success']) {
        selectedImages.clear();
        isSelectionMode = false;
      }
    });

    if (result['success']) {
      _showModernSnackBar(
        'Added ${result['totalAdded']} images to download queue',
        Icons.download_for_offline_rounded,
      );
      Navigator.push(
        context,
        _createModernPageRoute(const DownloadManagerPage()),
      );
    } else {
      _showModernSnackBar(
        'Error: ${result['error']}',
        Icons.error_rounded,
        true,
      );
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
    HapticFeedback.selectionClick();
  }

  PageRoute _createModernPageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.03);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
        final offsetAnimation = tween.animate(curvedAnimation);
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      backgroundColor: color.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: color.surface,
        surfaceTintColor: color.surfaceTint,
        title: const Text(
          'Gallery Downloader',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.history_rounded, color: color.primary),
              onPressed: () {
                Navigator.push(context, _createModernPageRoute(const LinkHistoryPage()));
              },
              tooltip: 'Link History',
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(color),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildControlsSection(theme, color)),
              if (isLoading) SliverToBoxAdapter(child: _buildLoadingSection(theme, color)),
              if (_error != null) SliverToBoxAdapter(child: _buildErrorSection(theme, color)),
              if (!isLoading && imageUrls.isNotEmpty) _buildImageGrid(theme, color),
              if (!isLoading && imageUrls.isEmpty && !isLoading)
                SliverToBoxAdapter(child: _buildEmptyState(theme, color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton(ColorScheme color) {
    if (_urlFocusNode.hasFocus) {
      return FloatingActionButton.extended(
        onPressed: _pasteFromClipboard,
        icon: const Icon(Icons.paste_rounded),
        label: const Text('Paste URL'),
        backgroundColor: color.primary,
        foregroundColor: color.onPrimary,
        elevation: 4,
      );
    }

    if (imageUrls.isNotEmpty && isSelectionMode && !isLoading && !isDownloading) {
      return FloatingActionButton.extended(
        onPressed: _downloadSelectedImages,
        icon: const Icon(Icons.download_for_offline_rounded),
        label: Text('Download ${selectedImages.length}'),
        backgroundColor: color.primary,
        foregroundColor: color.onPrimary,
        elevation: 4,
      );
    }

    return null;
  }

  Widget _buildControlsSection(ThemeData theme, ColorScheme color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Folder input
          Container(
            decoration: BoxDecoration(
              color: color.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.outline.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: color.shadow.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _folderController,
              focusNode: _folderFocusNode,
              decoration: InputDecoration(
                labelText: 'Main Folder Name',
                hintText: 'Enter folder name for downloads',
                prefixIcon: Icon(Icons.folder_rounded, color: color.primary),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.primaryContainer.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.check_rounded, color: color.primary),
                    onPressed: () {
                      setState(() {
                        mainFolderName = _folderController.text.trim().isEmpty
                            ? 'RagaDownloads'
                            : _folderController.text.trim();
                      });
                      HapticFeedback.mediumImpact();
                      _showModernSnackBar('Folder set to: $mainFolderName', Icons.folder_rounded);
                    },
                    tooltip: 'Set Main Folder',
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // URL input
          Container(
            decoration: BoxDecoration(
              color: color.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _urlController.text.isNotEmpty &&
                    !_downloaderService.isValidRagaUrl(_urlController.text)
                    ? color.error
                    : color.outline.withOpacity(0.2),
                width: _urlController.text.isNotEmpty &&
                    !_downloaderService.isValidRagaUrl(_urlController.text)
                    ? 2
                    : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.shadow.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              decoration: InputDecoration(
                labelText: 'Gallery URL',
                hintText: 'https://www.ragalahari.com/...',
                prefixIcon: Icon(
                  Icons.link_rounded,
                  color: _urlController.text.isNotEmpty &&
                      !_downloaderService.isValidRagaUrl(_urlController.text)
                      ? color.error
                      : color.primary,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_urlController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.content_copy_rounded, color: color.onSurfaceVariant, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _urlController.text));
                            _showModernSnackBar('URL copied to clipboard', Icons.content_copy_rounded);
                          },
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.clear_rounded, color: color.onSurfaceVariant, size: 18),
                        onPressed: () => _urlController.clear(),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                errorText: _urlController.text.isNotEmpty &&
                    !_downloaderService.isValidRagaUrl(_urlController.text)
                    ? 'URL must start with https://www.ragalahari.com'
                    : null,
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) => setState(() {}),
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          _buildActionButtons(theme, color),

          const SizedBox(height: 16),

          if (isSelectionMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: color.primary),
                  const SizedBox(width: 12),
                  Text(
                    '${selectedImages.length} images selected',
                    style: TextStyle(
                      color: color.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedImages.clear();
                        isSelectionMode = false;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, ColorScheme color) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: (isLoading || isDownloading || mainFolderName.isEmpty) ? null : () {
                  final url = _urlController.text.trim();
                  if (url.isEmpty) {
                    _showModernSnackBar('Please enter a URL', Icons.warning_rounded, true);
                    return;
                  }
                  if (!_downloaderService.isValidRagaUrl(url)) {
                    _showModernSnackBar('Invalid URL: Must start with https://www.ragalahari.com', Icons.error_rounded, true);
                    return;
                  }
                  HapticFeedback.mediumImpact();
                  _processGallery(url);
                },
                icon: const Icon(Icons.search_rounded),
                label: const Text('Fetch Images'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: (isLoading || isDownloading || imageUrls.isEmpty || mainFolderName.isEmpty) ? null : () {
                  HapticFeedback.mediumImpact();
                  _downloadAllImages();
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download All'),
                style: FilledButton.styleFrom(
                  backgroundColor: color.secondary,
                  foregroundColor: color.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.clear_all_rounded),
            label: const Text('Clear All'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSection(ThemeData theme, ColorScheme color) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: color.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(color.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Fetching page $currentPage of $totalPages...',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalPages > 0 ? (currentPage / totalPages) : null,
            backgroundColor: color.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(ThemeData theme, ColorScheme color) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.errorContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.error.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_rounded, color: color.error, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: color.onErrorContainer),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _error = null;
              });
              final url = _urlController.text.trim();
              if (url.isNotEmpty && _downloaderService.isValidRagaUrl(url)) {
                _processGallery(url);
              }
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme color) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.surfaceVariant.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.photo_library_outlined, size: 64, color: color.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text(
            'No images to display',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a gallery URL and tap "Fetch Images" to begin downloading.',
            style: theme.textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(ThemeData theme, ColorScheme color) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: calculateGridColumns(context),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final imageData = imageUrls[index];
            final isSelected = selectedImages.contains(index);

            return ImageGridItem(
              imageData: imageData,
              index: index,
              isSelected: isSelected,
              onTap: () {
                if (isSelectionMode) {
                  _toggleSelection(index);
                } else {
                  Navigator.push(
                    context,
                    _createModernPageRoute(
                      FullImagePage(
                        imageUrls: imageUrls,
                        initialIndex: index,
                        downloaderService: _downloaderService,
                      ),
                    ),
                  );
                }
              },
              onLongPress: () => _toggleSelection(index),
              theme: theme,
            );
          },
          childCount: imageUrls.length,
        ),
      ),
    );
  }
}

// Separate widget for image grid item
class ImageGridItem extends StatelessWidget {
  final ImageData imageData;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ThemeData theme;

  const ImageGridItem({
    super.key,
    required this.imageData,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: color.surface,
        elevation: isSelected ? 8 : 2,
        shadowColor: isSelected ? color.primary.withOpacity(0.4) : color.shadow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isSelected ? Border.all(color: color.primary, width: 2) : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Hero(
                    tag: imageData.originalUrl,
                    child: CachedNetworkImage(
                      imageUrl: imageData.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: color.surfaceVariant.withOpacity(0.3),
                        highlightColor: color.surface,
                        child: Container(color: color.surfaceVariant),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: color.errorContainer.withOpacity(0.1),
                        child: Icon(Icons.broken_image_rounded, color: color.error),
                      ),
                    ),
                  ),
                ),

                // Selection overlay
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      color: color.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                // Selection indicator
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.check_rounded, color: color.onPrimary, size: 16),
                    ),
                  ),

                // Image number
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Image ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Full image viewer page
class FullImagePage extends StatefulWidget {
  final List<ImageData> imageUrls;
  final int initialIndex;
  final DownloaderService downloaderService;

  const FullImagePage({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.downloaderService,
  });

  @override
  State<FullImagePage> createState() => _FullImagePageState();
}

class _FullImagePageState extends State<FullImagePage> {
  late PageController pageController;
  late int currentIndex;
  bool isDownloading = false;
  final List<TransformationController> transformationControllers = [];

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
    for (int i = 0; i < widget.imageUrls.length; i++) {
      transformationControllers.add(TransformationController());
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    for (var controller in transformationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _downloadImage(String imageUrl) async {
    setState(() {
      isDownloading = true;
    });

    final result = await widget.downloaderService.downloadSingleImage(
      imageUrl: imageUrl,
    );

    if (mounted) {
      setState(() {
        isDownloading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success']
                ? result['message']
                : 'Failed: ${result['error']}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImageData = widget.imageUrls[currentIndex];
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        title: Text(
          'Image ${currentIndex + 1} of ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.copy),
              color: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: currentImageData.originalUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image URL copied to clipboard')),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: isDownloading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.download),
              color: Colors.white,
              onPressed: isDownloading ? null : () => _downloadImage(currentImageData.originalUrl),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final imageData = widget.imageUrls[index];
          return InteractiveViewer(
            transformationController: transformationControllers[index],
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
