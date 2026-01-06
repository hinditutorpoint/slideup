import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
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

  // ============================================================
  // VIDEO THUMBNAIL METHODS (Using FFmpeg)
  // ============================================================

  /// Generate video thumbnail using FFmpeg
  Future<String?> generateVideoThumbnail(
    String videoPath, {
    int width = 256,
    int height = 256,
    int quality = 75,
    double timePosition = 1.0, // seconds
  }) async {
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

      debugPrint('🎬 Generating video thumbnail with FFmpeg for: $videoPath');

      // FFmpeg command to extract thumbnail
      final ffmpegQuality = ((100 - quality) * 31 / 100).round().clamp(2, 31);

      final command =
          '-ss $timePosition '
          '-i "$videoPath" '
          '-vframes 1 '
          '-vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2:white" '
          '-q:v $ffmpegQuality '
          '-y "$thumbnailPath"';

      debugPrint('📹 FFmpeg command: ffmpeg $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        if (await File(thumbnailPath).exists()) {
          _thumbnailCache[videoPath] = thumbnailPath;
          debugPrint('✅ Video thumbnail generated: $thumbnailPath');
          return thumbnailPath;
        }
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint('❌ FFmpeg failed with code: $returnCode');
        debugPrint('📋 FFmpeg logs: $logs');

        // Try alternative approach - thumbnail from first frame
        return await _generateThumbnailFallback(
          videoPath,
          thumbnailPath,
          width,
          height,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error generating video thumbnail: $e');
      debugPrint('📚 Stack trace: $stackTrace');
    }
    return null;
  }

  /// Fallback method if first approach fails
  Future<String?> _generateThumbnailFallback(
    String videoPath,
    String thumbnailPath,
    int width,
    int height,
  ) async {
    try {
      debugPrint('🔄 Trying fallback thumbnail generation...');

      // Try without seeking (from beginning)
      final command =
          '-i "$videoPath" '
          '-vframes 1 '
          '-vf "scale=$width:$height:force_original_aspect_ratio=decrease" '
          '-y "$thumbnailPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode) &&
          await File(thumbnailPath).exists()) {
        _thumbnailCache[videoPath] = thumbnailPath;
        debugPrint('✅ Video thumbnail generated (fallback): $thumbnailPath');
        return thumbnailPath;
      }
    } catch (e) {
      debugPrint('❌ Fallback also failed: $e');
    }
    return null;
  }

  /// Generate video thumbnail at specific time
  Future<String?> generateVideoThumbnailAtTime(
    String videoPath, {
    required Duration time,
    int width = 256,
    int height = 256,
    int quality = 75,
  }) async {
    await initialize();

    try {
      final timeStr = _formatDuration(time);
      final thumbnailPath = _generateThumbnailPath(
        '${videoPath}_$timeStr',
        'jpg',
      );

      // Check if thumbnail already exists
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }

      debugPrint('🎬 Generating thumbnail at $timeStr for: $videoPath');

      final ffmpegQuality = ((100 - quality) * 31 / 100).round().clamp(2, 31);

      final command =
          '-ss $timeStr '
          '-i "$videoPath" '
          '-vframes 1 '
          '-vf "scale=$width:$height:force_original_aspect_ratio=decrease" '
          '-q:v $ffmpegQuality '
          '-y "$thumbnailPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode) &&
          await File(thumbnailPath).exists()) {
        debugPrint('✅ Thumbnail at $timeStr generated: $thumbnailPath');
        return thumbnailPath;
      }
    } catch (e) {
      debugPrint('❌ Error generating thumbnail at time: $e');
    }
    return null;
  }

  /// Generate multiple thumbnails from video (for preview)
  Future<List<String>> generateVideoThumbnailStrip(
    String videoPath, {
    int count = 10,
    int width = 128,
    int height = 72,
  }) async {
    await initialize();

    final thumbnails = <String>[];

    try {
      // Get video duration first
      final duration = await getVideoDuration(videoPath);
      if (duration == null || duration.inSeconds <= 0) {
        debugPrint('❌ Could not get video duration');
        return thumbnails;
      }

      final interval = duration.inMilliseconds / (count + 1);

      debugPrint(
        '📹 Generating $count thumbnails for video (duration: ${duration.inSeconds}s)',
      );

      for (int i = 1; i <= count; i++) {
        final time = Duration(milliseconds: (interval * i).round());
        final thumbnail = await generateVideoThumbnailAtTime(
          videoPath,
          time: time,
          width: width,
          height: height,
        );
        if (thumbnail != null) {
          thumbnails.add(thumbnail);
        }
      }

      debugPrint('✅ Generated ${thumbnails.length}/$count thumbnails');
    } catch (e) {
      debugPrint('❌ Error generating thumbnail strip: $e');
    }

    return thumbnails;
  }

  /// Get video duration using FFmpeg
  Future<Duration?> getVideoDuration(String videoPath) async {
    try {
      final command = '-i "$videoPath" -hide_banner';

      final session = await FFmpegKit.execute(command);
      final logs = await session.getAllLogsAsString();

      // Parse duration from logs
      final durationRegex = RegExp(
        r'Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2})',
      );
      final match = durationRegex.firstMatch(logs ?? '');

      if (match != null) {
        final hours = int.parse(match.group(1)!);
        final minutes = int.parse(match.group(2)!);
        final seconds = int.parse(match.group(3)!);
        final centiseconds = int.parse(match.group(4)!);

        return Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          milliseconds: centiseconds * 10,
        );
      }
    } catch (e) {
      debugPrint('❌ Error getting video duration: $e');
    }
    return null;
  }

  /// Get video info using FFmpeg
  Future<Map<String, dynamic>?> getVideoInfo(String videoPath) async {
    try {
      final command = '-i "$videoPath" -hide_banner';

      final session = await FFmpegKit.execute(command);
      final logs = await session.getAllLogsAsString() ?? '';

      final info = <String, dynamic>{};

      // Parse duration
      final durationMatch = RegExp(
        r'Duration: (\d{2}:\d{2}:\d{2}\.\d{2})',
      ).firstMatch(logs);
      if (durationMatch != null) {
        info['duration'] = durationMatch.group(1);
      }

      // Parse video stream info
      final videoMatch = RegExp(
        r'Stream #\d+:\d+.*Video: (\w+).*, (\d+)x(\d+)',
      ).firstMatch(logs);
      if (videoMatch != null) {
        info['codec'] = videoMatch.group(1);
        info['width'] = int.tryParse(videoMatch.group(2) ?? '');
        info['height'] = int.tryParse(videoMatch.group(3) ?? '');
      }

      // Parse fps
      final fpsMatch = RegExp(r'(\d+(?:\.\d+)?)\s*fps').firstMatch(logs);
      if (fpsMatch != null) {
        info['fps'] = double.tryParse(fpsMatch.group(1) ?? '');
      }

      // Parse bitrate
      final bitrateMatch = RegExp(r'bitrate:\s*(\d+)\s*kb/s').firstMatch(logs);
      if (bitrateMatch != null) {
        info['bitrate'] = int.tryParse(bitrateMatch.group(1) ?? '');
      }

      // Parse audio info
      final audioMatch = RegExp(
        r'Stream #\d+:\d+.*Audio: (\w+)',
      ).firstMatch(logs);
      if (audioMatch != null) {
        info['audioCodec'] = audioMatch.group(1);
      }

      return info;
    } catch (e) {
      debugPrint('❌ Error getting video info: $e');
      return null;
    }
  }

  /// Generate animated GIF from video
  Future<String?> generateVideoGif(
    String videoPath, {
    Duration startTime = Duration.zero,
    Duration duration = const Duration(seconds: 3),
    int width = 320,
    int fps = 10,
  }) async {
    await initialize();

    try {
      final gifPath = _generateThumbnailPath(
        '${videoPath}_gif_${startTime.inSeconds}',
        'gif',
      );

      if (await File(gifPath).exists()) {
        return gifPath;
      }

      debugPrint('🎞️ Generating GIF from video...');

      final startStr = _formatDuration(startTime);
      final durationStr = duration.inSeconds.toString();

      // Generate palette first for better quality
      final palettePath = path.join(_thumbnailDir.path, 'palette.png');

      final paletteCommand =
          '-ss $startStr '
          '-t $durationStr '
          '-i "$videoPath" '
          '-vf "fps=$fps,scale=$width:-1:flags=lanczos,palettegen" '
          '-y "$palettePath"';

      var session = await FFmpegKit.execute(paletteCommand);
      var returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        debugPrint('❌ Failed to generate palette');
        return null;
      }

      // Generate GIF using palette
      final gifCommand =
          '-ss $startStr '
          '-t $durationStr '
          '-i "$videoPath" '
          '-i "$palettePath" '
          '-lavfi "fps=$fps,scale=$width:-1:flags=lanczos[x];[x][1:v]paletteuse" '
          '-y "$gifPath"';

      session = await FFmpegKit.execute(gifCommand);
      returnCode = await session.getReturnCode();

      // Clean up palette
      try {
        await File(palettePath).delete();
      } catch (_) {}

      if (ReturnCode.isSuccess(returnCode) && await File(gifPath).exists()) {
        debugPrint('✅ GIF generated: $gifPath');
        return gifPath;
      }
    } catch (e) {
      debugPrint('❌ Error generating GIF: $e');
    }
    return null;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = (duration.inMilliseconds.remainder(1000) / 10).round();
    return '$hours:$minutes:$seconds.${twoDigits(milliseconds)}';
  }

  // ============================================================
  // PDF THUMBNAIL METHODS
  // ============================================================

  /// Generate PDF thumbnail using Syncfusion
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
        Size(width, height),
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

  // ============================================================
  // IMAGE THUMBNAIL METHODS
  // ============================================================

  /// Generate image thumbnail using FFmpeg (resize)
  Future<String?> generateImageThumbnail(
    String imagePath, {
    int width = 256,
    int height = 256,
  }) async {
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

      debugPrint('🖼️ Generating image thumbnail for: $imagePath');

      // Use FFmpeg to resize image
      final command =
          '-i "$imagePath" '
          '-vf "scale=$width:$height:force_original_aspect_ratio=decrease" '
          '-q:v 2 '
          '-y "$thumbnailPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode) &&
          await File(thumbnailPath).exists()) {
        _thumbnailCache[imagePath] = thumbnailPath;
        debugPrint('✅ Image thumbnail generated: $thumbnailPath');
        return thumbnailPath;
      }

      // Fallback to original if FFmpeg fails
      _thumbnailCache[imagePath] = imagePath;
      return imagePath;
    } catch (e) {
      debugPrint('❌ Error generating image thumbnail: $e');
      return imagePath;
    }
  }

  // ============================================================
  // GENERAL METHODS
  // ============================================================

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
