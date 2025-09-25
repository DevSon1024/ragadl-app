import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ThumbnailUtils {
  static Future<File> getThumbnail(File imageFile) async {
    final tempDir = await getTemporaryDirectory();
    final thumbnailPath = '${tempDir.path}/thumbnails';
    final thumbnailDir = Directory(thumbnailPath);

    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }

    final imageName = imageFile.path.split('/').last;
    final thumbFile = File('${thumbnailDir.path}/$imageName');

    if (await thumbFile.exists()) {
      return thumbFile;
    } else {
      return await compute(_createThumbnail, {
        'imagePath': imageFile.path,
        'thumbPath': thumbFile.path,
      });
    }
  }

  static Future<File> _createThumbnail(Map<String, String> paths) async {
    final imagePath = paths['imagePath']!;
    final thumbPath = paths['thumbPath']!;

    final imageBytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image != null) {
      final thumbnail = img.copyResize(image, width: 200);
      final thumbFile = File(thumbPath);
      await thumbFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 85));
      return thumbFile;
    }

    throw Exception('Could not decode image');
  }
}