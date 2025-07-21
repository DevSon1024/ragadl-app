import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../widgets/grid_utils.dart';
import '../ragalahari_downloader.dart';

class ImageGrid extends StatelessWidget {
  final List<ImageData> imageUrls;
  final bool isLoading;
  final Set<int> selectedImages;
  final bool isSelectionMode;
  final Function(int) onToggleSelection;
  final Function(int) onImageTap;

  const ImageGrid({
    super.key,
    required this.imageUrls,
    required this.isLoading,
    required this.selectedImages,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const SliverToBoxAdapter(
      child: Center(
        key: ValueKey('loader'),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      ),
    )
        : ImageGridContent(
      imageUrls: imageUrls,
      selectedImages: selectedImages,
      isSelectionMode: isSelectionMode,
      onToggleSelection: onToggleSelection,
      onImageTap: onImageTap,
    );
  }
}

class ImageGridContent extends StatelessWidget {
  final List<ImageData> imageUrls;
  final Set<int> selectedImages;
  final bool isSelectionMode;
  final Function(int) onToggleSelection;
  final Function(int) onImageTap;

  const ImageGridContent({
    super.key,
    required this.imageUrls,
    required this.selectedImages,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(8.0),
      sliver: imageUrls.isEmpty
          ? const SliverToBoxAdapter(child: Center(child: Text('No images to display')))
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
              onTap: () => onImageTap(index),
              onLongPress: () => onToggleSelection(index),
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
    );
  }
}