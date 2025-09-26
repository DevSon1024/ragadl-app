import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

// A top-level function to be used with compute() for isolate processing.
// This prevents UI jank by running heavy image processing in the background.
Future<File> _generateThumbnailIsolate(Map<String, String> args) async {
  final String imagePath = args['imagePath']!;
  final String thumbPath = args['thumbPath']!;
  final int width = int.parse(args['width']!);

  final File originalFile = File(imagePath);
  final Uint8List imageBytes = await originalFile.readAsBytes();

  // Decode the image
  final originalImage = img.decodeImage(imageBytes);

  if (originalImage == null) {
    throw Exception('Could not decode image');
  }

  // Resize the image to a thumbnail size.
  // Using a fixed width and maintaining aspect ratio.
  final thumbnail = img.copyResize(
    originalImage,
    width: width, // Resize to a smaller width for the thumbnail
  );

  // Encode the thumbnail as a JPEG with a specified quality.
  // 85 is a good balance between quality and file size.
  final thumbnailBytes = img.encodeJpg(thumbnail, quality: 85);

  // Save the thumbnail to the cache directory.
  final thumbnailFile = File(thumbPath);
  await thumbnailFile.writeAsBytes(thumbnailBytes);

  return thumbnailFile;
}

class ThumbnailUtils {
  /// Generates a compressed thumbnail for the given [originalImage].
  ///
  /// It first checks if a thumbnail is already cached. If so, it returns the cached file.
  /// Otherwise, it generates a new thumbnail in a background isolate to avoid UI freezes,
  /// caches it, and then returns the file.
  static Future<File> getThumbnail(File originalImage) async {
    try {
      // Get the application's support directory to store thumbnails.
      final Directory supportDir = await getApplicationSupportDirectory();
      final String thumbDirPath = '${supportDir.path}/thumbnails';
      final Directory thumbDir = Directory(thumbDirPath);

      // Create the thumbnails directory if it doesn't exist.
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }

      // Generate a unique name for the thumbnail based on the original image's
      // path and modification date to ensure freshness.
      final String imageName = originalImage.path.split('/').last;
      final int lastModified = originalImage.lastModifiedSync().millisecondsSinceEpoch;
      final String thumbFileName = '${imageName}_$lastModified.jpg';
      final String thumbPath = '${thumbDir.path}/$thumbFileName';
      final File thumbFile = File(thumbPath);

      // If the thumbnail already exists in the cache, return it directly.
      if (await thumbFile.exists()) {
        return thumbFile;
      }

      // If the thumbnail doesn't exist, generate it in a separate isolate.
      // We pass all necessary data as a map to the isolate function.
      return await compute(_generateThumbnailIsolate, {
        'imagePath': originalImage.path,
        'thumbPath': thumbPath,
        'width': '200', // Desired width for thumbnails
      });
    } catch (e) {
      // If thumbnail generation fails, rethrow the exception to be handled by the FutureBuilder.
      debugPrint('Error generating thumbnail: $e');
      rethrow;
    }
  }
}
