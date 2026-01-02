import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import '../services/database_service.dart';
import '../models/media_file.dart';

class ImageHelper {
  // ✅ Get actual image resolution
  static Future<Size> getImageResolution(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = await decodeImageFromList(bytes);
      return Size(image.width.toDouble(), image.height.toDouble());
    } catch (e) {
      debugPrint('Error getting image resolution: $e');
      return Size.zero;
    }
  }

  // ✅ Get image format
  static String getImageFormat(String imagePath) {
    final ext = path.extension(imagePath).toUpperCase().replaceAll('.', '');
    if (ext.isEmpty) return 'Unknown';
    return ext;
  }

  // ✅ Get complete image info
  static Future<Map<String, dynamic>> getImageInfo(File imageFile) async {
    try {
      final stat = await imageFile.stat();
      final resolution = await getImageResolution(imageFile.path);

      return {
        'size': stat.size,
        'modified': stat.modified,
        'format': getImageFormat(imageFile.path),
        'path': imageFile.path,
        'resolution':
            '${resolution.width.toInt()} × ${resolution.height.toInt()}',
        'width': resolution.width.toInt(),
        'height': resolution.height.toInt(),
      };
    } catch (e) {
      debugPrint('Error getting image info: $e');
      return {
        'size': 0,
        'modified': DateTime.now(),
        'format': 'Unknown',
        'path': imageFile.path,
        'resolution': 'Unknown',
        'width': 0,
        'height': 0,
      };
    }
  }

  // ✅ Format bytes to readable size
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ✅ Share image
  static Future<void> shareImage(String imagePath, {String? text}) async {
    try {
      final file = XFile(imagePath);
      await SharePlus.instance.share(
        ShareParams(
          title: 'Share Image',
          files: [file],
          text: text ?? 'Shared from Slideup Media Player',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing image: $e');
      rethrow;
    }
  }

  // ✅ Delete image
  static Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  // ✅ Copy image to gallery/pictures
  static Future<String?> saveImageCopy(
    String sourcePath,
    String fileName,
  ) async {
    try {
      final directory = await getExternalStorageDirectory();
      final picturesDir = Directory('${directory!.path}/Pictures');

      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }

      final newPath = '${picturesDir.path}/$fileName';
      final sourceFile = File(sourcePath);
      await sourceFile.copy(newPath);

      return newPath;
    } catch (e) {
      debugPrint('Error saving image copy: $e');
      return null;
    }
  }

  // ✅ Rotate image and save
  static Future<String?> rotateImage(String imagePath, int degrees) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      img.Image rotatedImage;
      switch (degrees) {
        case 90:
          rotatedImage = img.copyRotate(image, angle: 90);
          break;
        case 180:
          rotatedImage = img.copyRotate(image, angle: 180);
          break;
        case 270:
          rotatedImage = img.copyRotate(image, angle: 270);
          break;
        default:
          rotatedImage = image;
      }

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rotatedFile = File(tempPath);
      await rotatedFile.writeAsBytes(img.encodeJpg(rotatedImage, quality: 95));

      return tempPath;
    } catch (e) {
      debugPrint('Error rotating image: $e');
      return null;
    }
  }

  // ✅ Apply filters and adjustments
  static Future<String?> applyImageAdjustments({
    required String imagePath,
    double brightness = 0,
    double contrast = 0,
    double saturation = 0,
  }) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      img.Image adjustedImage = image;

      // Apply brightness
      if (brightness != 0) {
        final brightnessValue = (brightness * 100).toInt();
        adjustedImage = img.adjustColor(
          adjustedImage,
          brightness: brightnessValue.toDouble(),
        );
      }

      // Apply contrast
      if (contrast != 0) {
        final contrastValue = 1 + contrast;
        adjustedImage = img.adjustColor(adjustedImage, contrast: contrastValue);
      }

      // Apply saturation
      if (saturation != 0) {
        final saturationValue = 1 + saturation;
        adjustedImage = img.adjustColor(
          adjustedImage,
          saturation: saturationValue,
        );
      }

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/adjusted_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final adjustedFile = File(tempPath);
      await adjustedFile.writeAsBytes(
        img.encodeJpg(adjustedImage, quality: 95),
      );

      return tempPath;
    } catch (e) {
      debugPrint('Error applying adjustments: $e');
      return null;
    }
  }

  // ✅ Crop image
  static Future<String?> cropImage({
    required String imagePath,
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      final croppedImage = img.copyCrop(
        image,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final croppedFile = File(tempPath);
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 95));

      return tempPath;
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return null;
    }
  }

  // ✅ Apply preset filters
  static Future<String?> applyFilter(
    String imagePath,
    ImageFilter filter,
  ) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      img.Image filteredImage;

      switch (filter) {
        case ImageFilter.grayscale:
          filteredImage = img.grayscale(image);
          break;
        case ImageFilter.sepia:
          filteredImage = img.sepia(image);
          break;
        case ImageFilter.invert:
          filteredImage = img.invert(image);
          break;
        case ImageFilter.vintage:
          filteredImage = img.adjustColor(
            image,
            saturation: 0.7,
            contrast: 1.2,
          );
          filteredImage = img.sepia(filteredImage, amount: 0.3);
          break;
        case ImageFilter.cool:
          filteredImage = img.adjustColor(image, saturation: 1.3);
          break;
        case ImageFilter.warm:
          filteredImage = img.adjustColor(image, saturation: 1.2);
          break;
        case ImageFilter.noir:
          filteredImage = img.grayscale(image);
          filteredImage = img.adjustColor(filteredImage, contrast: 1.5);
          break;
        default:
          filteredImage = image;
      }

      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/filtered_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filteredFile = File(tempPath);
      await filteredFile.writeAsBytes(
        img.encodeJpg(filteredImage, quality: 95),
      );

      return tempPath;
    } catch (e) {
      debugPrint('Error applying filter: $e');
      return null;
    }
  }

  // ✅ Set as wallpaper (Android)
  static Future<bool> setAsWallpaper(String imagePath) async {
    try {
      // Use platform channel to set wallpaper
      const platform = MethodChannel('com.slideup.mediaplayer/wallpaper');
      final result = await platform.invokeMethod('setWallpaper', {
        'path': imagePath,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error setting wallpaper: $e');
      return false;
    }
  }

  // ✅ Get color filter for preview (doesn't modify file)
  static ColorFilter getColorFilter({
    double brightness = 0,
    double contrast = 0,
    double saturation = 0,
  }) {
    final b = brightness.clamp(-1.0, 1.0);
    final c = contrast.clamp(-1.0, 1.0);
    final s = saturation.clamp(-1.0, 1.0);

    final contrastValue = 1 + c;
    final brightnessValue = b * 255;
    final saturationValue = 1 + s;

    return ColorFilter.matrix([
      contrastValue * saturationValue,
      0,
      0,
      0,
      brightnessValue,
      0,
      contrastValue * saturationValue,
      0,
      0,
      brightnessValue,
      0,
      0,
      contrastValue * saturationValue,
      0,
      brightnessValue,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  // ✅ Resize image
  static Future<String?> resizeImage({
    required String imagePath,
    required int width,
    required int height,
  }) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      final resizedImage = img.copyResize(image, width: width, height: height);

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/resized_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final resizedFile = File(tempPath);
      await resizedFile.writeAsBytes(img.encodeJpg(resizedImage, quality: 95));

      return tempPath;
    } catch (e) {
      debugPrint('Error resizing image: $e');
      return null;
    }
  }

  // ✅ Convert image format
  static Future<String?> convertImageFormat({
    required String imagePath,
    required ImageFormat format,
  }) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      final tempDir = await getTemporaryDirectory();
      String tempPath;
      List<int> encodedBytes;

      switch (format) {
        case ImageFormat.jpg:
          tempPath =
              '${tempDir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.jpg';
          encodedBytes = img.encodeJpg(image, quality: 95);
          break;
        case ImageFormat.png:
          tempPath =
              '${tempDir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.png';
          encodedBytes = img.encodePng(image);
          break;
        case ImageFormat.webp:
          tempPath =
              '${tempDir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.webp';
          encodedBytes = img.encodeJpg(image, quality: 95); // Fallback to jpg
          break;
      }

      final convertedFile = File(tempPath);
      await convertedFile.writeAsBytes(encodedBytes);

      return tempPath;
    } catch (e) {
      debugPrint('Error converting image: $e');
      return null;
    }
  }

  // ✅ Create thumbnail
  static Future<String?> createThumbnail(
    String imagePath, {
    int size = 200,
  }) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      final thumbnail = img.copyResize(image, width: size, height: size);

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final thumbFile = File(tempPath);
      await thumbFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 85));

      return tempPath;
    } catch (e) {
      debugPrint('Error creating thumbnail: $e');
      return null;
    }
  }

  /// ✅ Bulk delete images
  static Future<BulkDeleteResult> bulkDeleteImages(
    List<String> imagePaths, {
    List<String>? imageIds, // Add IDs for database deletion
  }) async {
    int successCount = 0;
    int failedCount = 0;
    final List<String> failedPaths = [];
    final List<String> deletedIds = [];

    for (int i = 0; i < imagePaths.length; i++) {
      final path = imagePaths[i];
      try {
        final file = File(path);

        // Delete file
        if (await file.exists()) {
          await file.delete();
          successCount++;

          // Track deleted ID
          if (imageIds != null && i < imageIds.length) {
            deletedIds.add(imageIds[i]);
          }
        } else {
          failedCount++;
          failedPaths.add(path);
        }
      } catch (e) {
        debugPrint('Error deleting image: $path - $e');
        failedCount++;
        failedPaths.add(path);
      }
    }

    // Delete from database
    if (imageIds != null && deletedIds.isNotEmpty) {
      try {
        final db = DatabaseService.instance;
        for (final id in deletedIds) {
          await db.deleteMediaFile(id);
        }
      } catch (e) {
        debugPrint('Error deleting from database: $e');
      }
    }

    return BulkDeleteResult(
      successCount: successCount,
      failedCount: failedCount,
      failedPaths: failedPaths,
      deletedIds: deletedIds,
    );
  }

  /// ✅ Move images to trash (safer than direct delete)
  static Future<bool> moveToTrash(List<String> imagePaths) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final trashDir = Directory('${directory.path}/.trash');

      if (!await trashDir.exists()) {
        await trashDir.create(recursive: true);
      }

      for (final path in imagePaths) {
        final file = File(path);
        if (await file.exists()) {
          final fileName = path.split('/').last;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newPath = '${trashDir.path}/${timestamp}_$fileName';
          await file.copy(newPath);
          await file.delete();
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error moving to trash: $e');
      return false;
    }
  }

  /// ✅ Restore from trash
  static Future<bool> restoreFromTrash(String originalPath) async {
    try {
      //final directory = await getApplicationDocumentsDirectory();
      //final trashDir = Directory('${directory.path}/.trash');

      // Find the file in trash
      //final files = await trashDir.list().toList();
      // Implementation for restore logic

      return true;
    } catch (e) {
      debugPrint('Error restoring from trash: $e');
      return false;
    }
  }

  /// ✅ Empty trash
  static Future<bool> emptyTrash() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final trashDir = Directory('${directory.path}/.trash');

      if (await trashDir.exists()) {
        await trashDir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error emptying trash: $e');
      return false;
    }
  }

  static Future<int> cleanupDatabaseOrphans() async {
    final db = DatabaseService.instance;
    final allImages = await db.getMediaFilesByType(MediaType.image);

    int cleanedCount = 0;
    final toDelete = <String>[];

    for (final image in allImages) {
      final file = File(image.path);
      if (!await file.exists()) {
        toDelete.add(image.id);
        cleanedCount++;
      }
    }

    if (toDelete.isNotEmpty) {
      await db.deleteMediaFiles(toDelete);
    }

    return cleanedCount;
  }
}

// Add this class at the bottom of the file
class BulkDeleteResult {
  final int successCount;
  final int failedCount;
  final List<String> failedPaths;
  final List<String>? deletedIds;

  BulkDeleteResult({
    required this.successCount,
    required this.failedCount,
    required this.failedPaths,
    this.deletedIds = const [],
  });

  bool get hasFailures => failedCount > 0;
  bool get allSuccess => failedCount == 0 && successCount > 0;
  int get totalCount => successCount + failedCount;
}

// Enums
enum ImageFilter { none, grayscale, sepia, invert, vintage, cool, warm, noir }

enum ImageFormat { jpg, png, webp }
