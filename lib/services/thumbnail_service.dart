import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ThumbnailService {
  static final ThumbnailService instance = ThumbnailService._();
  ThumbnailService._();

  late Directory _thumbnailDir;
  bool _isInitialized = false;

  // Cache for thumbnails to avoid regenerating
  final Map<String, String> _thumbnailCache = {};

  Future<void> initialize() async {
    if (_isInitialized) return;

    final tempDir = await getExternalStorageDirectory();
    _thumbnailDir = Directory(path.join(tempDir!.path, 'thumbnails'));

    if (!await _thumbnailDir.exists()) {
      await _thumbnailDir.create(recursive: true);
    }

    _isInitialized = true;
    debugPrint('📸 Thumbnail service initialized: ${_thumbnailDir.path}');
  }

  String _generateThumbnailPath(String filePath, String extension) {
    final hash = md5.convert(utf8.encode(filePath)).toString();
    return path.join(_thumbnailDir.path, '$hash.$extension');
  }

  /// Generate video thumbnail
  Future<String?> generateVideoThumbnail(String videoPath) async {
    await initialize();

    try {
      final thumbnailPath = _generateThumbnailPath(videoPath, 'jpg');

      // Check cache first
      if (_thumbnailCache.containsKey(videoPath)) {
        final cachedPath = _thumbnailCache[videoPath]!;
        if (await File(cachedPath).exists()) {
          return cachedPath;
        }
      }

      // Check if thumbnail already exists
      if (await File(thumbnailPath).exists()) {
        _thumbnailCache[videoPath] = thumbnailPath;
        return thumbnailPath;
      }

      debugPrint('🎬 Generating video thumbnail for: $videoPath');

      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 256,
        maxHeight: 256,
        quality: 75,
      );

      if (thumbnail != null) {
        _thumbnailCache[videoPath] = thumbnail;
        debugPrint('✅ Video thumbnail generated: $thumbnail');
        return thumbnail;
      }
    } catch (e) {
      debugPrint('❌ Error generating video thumbnail: $e');
    }
    return null;
  }

  /// Generate PDF thumbnail using Syncfusion v28.2.7
  Future<String?> generatePdfThumbnail(String pdfPath) async {
    await initialize();

    try {
      final thumbnailPath = _generateThumbnailPath(pdfPath, 'png');

      // Check cache first
      if (_thumbnailCache.containsKey(pdfPath)) {
        final cachedPath = _thumbnailCache[pdfPath]!;
        if (await File(cachedPath).exists()) {
          return cachedPath;
        }
      }

      // Check if thumbnail already exists
      if (await File(thumbnailPath).exists()) {
        _thumbnailCache[pdfPath] = thumbnailPath;
        return thumbnailPath;
      }

      debugPrint('📄 Generating PDF thumbnail for: $pdfPath');

      // Load PDF document
      final File pdfFile = File(pdfPath);
      final List<int> bytes = await pdfFile.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      if (document.pages.count == 0) {
        document.dispose();
        return null;
      }

      // Get first page
      final PdfPage page = document.pages[0];

      // Render page using canvas-based approach
      final imageBytes = await _renderPdfPageToImage(
        page,
        1,
        const Size(256, 256),
      );

      if (imageBytes.isNotEmpty) {
        // Save the image
        await File(thumbnailPath).writeAsBytes(imageBytes);

        // Cache the path
        _thumbnailCache[pdfPath] = thumbnailPath;

        debugPrint('✅ PDF thumbnail generated: $thumbnailPath');

        // Dispose the document
        document.dispose();

        return thumbnailPath;
      }

      // Dispose the document
      document.dispose();
      return null;
    } catch (e) {
      debugPrint('❌ Error generating PDF thumbnail: $e');
      return null;
    }
  }

  /// Render PDF page to image bytes using canvas-based approach
  Future<List<int>> _renderPdfPageToImage(
    PdfPage page,
    int pageNumber,
    Size targetSize,
  ) async {
    final width = targetSize.width.toInt();
    final height = targetSize.height.toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );

    // Draw PDF page info (placeholder - full rendering would need platform channels)
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Page $pageNumber',
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: (height * 0.15).toDouble(),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        (height - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List() ?? [];
  }

  /// Generate PDF thumbnail with custom options
  Future<String?> generatePdfThumbnailWithOptions({
    required String pdfPath,
    int pageIndex = 0,
    double width = 256,
    double height = 256,
    String format = 'png',
  }) async {
    await initialize();

    try {
      final thumbnailPath = _generateThumbnailPath(
        '${pdfPath}_p${pageIndex}_${width}x$height',
        format,
      );

      // Check if thumbnail already exists
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }

      debugPrint(
        '📄 Generating custom PDF thumbnail for page $pageIndex: $pdfPath',
      );

      // Load PDF document
      final File pdfFile = File(pdfPath);
      final List<int> bytes = await pdfFile.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // Check if page index is valid
      if (pageIndex >= document.pages.count || pageIndex < 0) {
        debugPrint(
          '❌ Invalid page index: $pageIndex (total pages: ${document.pages.count})',
        );
        document.dispose();
        return null;
      }

      // Get specified page
      final PdfPage page = document.pages[pageIndex];

      // Render page using canvas-based approach
      final imageBytes = await _renderPdfPageToImage(
        page,
        pageIndex + 1,
        Size(width, height),
      );

      // Save thumbnail
      if (imageBytes.isNotEmpty) {
        await File(thumbnailPath).writeAsBytes(imageBytes);

        debugPrint('✅ Custom PDF thumbnail generated: $thumbnailPath');

        // Dispose the document
        document.dispose();

        return thumbnailPath;
      }

      // Dispose the document
      document.dispose();
      return null;
    } catch (e) {
      debugPrint('❌ Error generating custom PDF thumbnail: $e');
      return null;
    }
  }

  /// Get PDF document info
  Future<Map<String, dynamic>?> getPdfInfo(String pdfPath) async {
    try {
      final File pdfFile = File(pdfPath);
      final List<int> bytes = await pdfFile.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      final info = <String, dynamic>{
        'pageCount': document.pages.count,
        'title': document.documentInformation.title,
        'author': document.documentInformation.author,
        'subject': document.documentInformation.subject,
        'keywords': document.documentInformation.keywords,
        'creator': document.documentInformation.creator,
        'producer': document.documentInformation.producer,
        'creationDate': document.documentInformation.creationDate,
        'modificationDate': document.documentInformation.modificationDate,
      };

      // Get page size from first page
      if (document.pages.count > 0) {
        final firstPage = document.pages[0];
        info['pageWidth'] = firstPage.size.width;
        info['pageHeight'] = firstPage.size.height;
      }

      document.dispose();
      return info;
    } catch (e) {
      debugPrint('❌ Error getting PDF info: $e');
      return null;
    }
  }

  /// Generate multiple PDF page thumbnails
  Future<List<String>> generatePdfPageThumbnails({
    required String pdfPath,
    int maxPages = 5,
    double thumbnailWidth = 128,
    double thumbnailHeight = 128,
  }) async {
    await initialize();

    final thumbnails = <String>[];
    PdfDocument? document;

    try {
      final File pdfFile = File(pdfPath);
      final List<int> bytes = await pdfFile.readAsBytes();
      document = PdfDocument(inputBytes: bytes);

      final pageCount = document.pages.count;
      final pagesToGenerate = pageCount < maxPages ? pageCount : maxPages;

      debugPrint('📚 Generating $pagesToGenerate PDF page thumbnails');

      for (int i = 0; i < pagesToGenerate; i++) {
        try {
          final thumbnailPath = _generateThumbnailPath(
            '${pdfPath}_page_$i',
            'png',
          );

          // Check if thumbnail already exists
          if (await File(thumbnailPath).exists()) {
            thumbnails.add(thumbnailPath);
            continue;
          }

          // Get page
          final PdfPage page = document.pages[i];

          // Render to image
          final imageBytes = await _renderPdfPageToImage(
            page,
            i + 1,
            Size(thumbnailWidth, thumbnailHeight),
          );

          // Save thumbnail
          if (imageBytes.isNotEmpty) {
            await File(thumbnailPath).writeAsBytes(imageBytes);
            thumbnails.add(thumbnailPath);
          }
        } catch (e) {
          debugPrint('❌ Error generating thumbnail for page $i: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error generating PDF page thumbnails: $e');
    } finally {
      document?.dispose();
    }

    return thumbnails;
  }

  /// Generate image thumbnail (resize if needed)
  Future<String?> generateImageThumbnail(String imagePath) async {
    await initialize();

    try {
      final thumbnailPath = _generateThumbnailPath(imagePath, 'jpg');

      // Check cache first
      if (_thumbnailCache.containsKey(imagePath)) {
        final cachedPath = _thumbnailCache[imagePath]!;
        if (await File(cachedPath).exists()) {
          return cachedPath;
        }
      }

      // Check if thumbnail already exists
      if (await File(thumbnailPath).exists()) {
        _thumbnailCache[imagePath] = thumbnailPath;
        return thumbnailPath;
      }

      // For now, return original path
      // In production, you might want to create actual resized thumbnails
      _thumbnailCache[imagePath] = imagePath;
      return imagePath;
    } catch (e) {
      debugPrint('❌ Error processing image thumbnail: $e');
      return null;
    }
  }

  /// Get thumbnail for any supported file type
  Future<String?> getThumbnail(String filePath) async {
    final extension = path.extension(filePath).toLowerCase();

    // Video extensions
    if ([
      '.mp4',
      '.mkv',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.m4v',
      '.3gp',
      '.ts',
    ].contains(extension)) {
      return await generateVideoThumbnail(filePath);
    }

    // PDF extension
    if (extension == '.pdf') {
      return await generatePdfThumbnail(filePath);
    }

    // Image extensions
    if ([
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
    ].contains(extension)) {
      return await generateImageThumbnail(filePath);
    }

    return null;
  }

  /// Check if PDF is password protected
  Future<bool> isPdfPasswordProtected(String pdfPath) async {
    try {
      final File pdfFile = File(pdfPath);
      final List<int> bytes = await pdfFile.readAsBytes();

      try {
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        document.dispose();
        return false; // If we can open it without password, it's not protected
      } catch (e) {
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('password') ||
            errorMessage.contains('encrypted')) {
          return true;
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ Error checking PDF password protection: $e');
      return false;
    }
  }

  /// Generate PDF thumbnail with password
  Future<String?> generatePdfThumbnailWithPassword({
    required String pdfPath,
    required String password,
    int pageIndex = 0,
    double width = 256,
    double height = 256,
  }) async {
    await initialize();

    try {
      final thumbnailPath = _generateThumbnailPath(
        '${pdfPath}_protected_p$pageIndex',
        'png',
      );

      // Check if thumbnail already exists
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }

      debugPrint('📄 Generating protected PDF thumbnail: $pdfPath');

      // Load PDF document with password
      final File pdfFile = File(pdfPath);
      final List<int> bytes = await pdfFile.readAsBytes();
      final PdfDocument document = PdfDocument(
        inputBytes: bytes,
        password: password,
      );

      // Check if page index is valid
      if (pageIndex >= document.pages.count || pageIndex < 0) {
        debugPrint(
          '❌ Invalid page index: $pageIndex (total pages: ${document.pages.count})',
        );
        document.dispose();
        return null;
      }

      // Get specified page
      final PdfPage page = document.pages[pageIndex];

      // Render page using canvas-based approach
      final imageBytes = await _renderPdfPageToImage(
        page,
        pageIndex + 1,
        Size(256, 256),
      );

      // Save thumbnail
      if (imageBytes.isNotEmpty) {
        await File(thumbnailPath).writeAsBytes(imageBytes);

        debugPrint('✅ Protected PDF thumbnail generated: $thumbnailPath');

        // Dispose resources
        document.dispose();

        return thumbnailPath;
      }

      // Dispose the document
      document.dispose();
    } catch (e) {
      debugPrint('❌ Error generating protected PDF thumbnail: $e');
    }
    return null;
  }

  /// Clear specific file from cache
  void clearFromCache(String filePath) {
    _thumbnailCache.remove(filePath);
  }

  /// Clear all cached thumbnails
  Future<void> clearCache() async {
    await initialize();

    try {
      if (await _thumbnailDir.exists()) {
        await _thumbnailDir.delete(recursive: true);
        await _thumbnailDir.create();
      }
      _thumbnailCache.clear();
      debugPrint('🧹 Thumbnail cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing thumbnail cache: $e');
    }
  }

  /// Get cache size
  Future<int> getCacheSize() async {
    await initialize();

    int totalSize = 0;
    try {
      if (await _thumbnailDir.exists()) {
        await for (final entity in _thumbnailDir.list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error calculating cache size: $e');
    }
    return totalSize;
  }

  /// Get cache info
  Future<Map<String, dynamic>> getCacheInfo() async {
    await initialize();

    int fileCount = 0;
    int totalSize = 0;

    try {
      if (await _thumbnailDir.exists()) {
        await for (final entity in _thumbnailDir.list(recursive: true)) {
          if (entity is File) {
            fileCount++;
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting cache info: $e');
    }

    return {
      'fileCount': fileCount,
      'totalSize': totalSize,
      'cachePath': _thumbnailDir.path,
      'memoryCache': _thumbnailCache.length,
    };
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
