import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ThumbnailService {
  final Map<String, List<Uint8List>> _thumbnailCache = {};
  final Map<String, Uint8List> _singleThumbnailCache = {};

  static const int _maxCacheSize = 50;

  // ═══════════════════════════════════════════════════════
  // ✅ SINGLE THUMBNAIL AT POSITION
  // ═══════════════════════════════════════════════════════

  Future<Uint8List?> getThumbnailAtPosition({
    required String videoPath,
    required Duration position,
    int width = 160,
    int height = 90,
  }) async {
    final cacheKey = '${videoPath}_${position.inSeconds}_${width}x$height';

    // Check cache
    if (_singleThumbnailCache.containsKey(cacheKey)) {
      return _singleThumbnailCache[cacheKey];
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
        tempDir.path,
        'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final timeString = _formatDurationForFFmpeg(position);

      final command =
          '-ss $timeString -i "$videoPath" -vframes 1 -s ${width}x$height -q:v 2 "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();

          // Cache management
          if (_singleThumbnailCache.length >= _maxCacheSize) {
            _singleThumbnailCache.remove(_singleThumbnailCache.keys.first);
          }
          _singleThumbnailCache[cacheKey] = bytes;

          // Cleanup temp file
          await file.delete();

          return bytes;
        }
      }
    } catch (e) {
      debugPrint('❌ Thumbnail generation failed: $e');
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GENERATE TIMELINE THUMBNAILS
  // ═══════════════════════════════════════════════════════

  Future<List<Uint8List>> generateTimelineThumbnails({
    required String videoPath,
    required Duration videoDuration,
    int count = 10,
    int width = 160,
    int height = 90,
    Function(double progress)? onProgress,
  }) async {
    final cacheKey = '${videoPath}_timeline_$count';

    // Check cache
    if (_thumbnailCache.containsKey(cacheKey)) {
      return _thumbnailCache[cacheKey]!;
    }

    final thumbnails = <Uint8List>[];
    final interval = videoDuration.inMilliseconds / count;

    try {
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < count; i++) {
        final position = Duration(milliseconds: (interval * i).toInt());
        final outputPath = path.join(
          tempDir.path,
          'timeline_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );

        final timeString = _formatDurationForFFmpeg(position);
        final command =
            '-ss $timeString -i "$videoPath" -vframes 1 -s ${width}x$height -q:v 3 "$outputPath"';

        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          final file = File(outputPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            thumbnails.add(bytes);
            await file.delete();
          }
        }

        onProgress?.call((i + 1) / count);
      }

      // Cache
      if (thumbnails.isNotEmpty) {
        if (_thumbnailCache.length >= 10) {
          _thumbnailCache.remove(_thumbnailCache.keys.first);
        }
        _thumbnailCache[cacheKey] = thumbnails;
      }
    } catch (e) {
      debugPrint('❌ Timeline thumbnail generation failed: $e');
    }

    return thumbnails;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXTRACT FRAMES
  // ═══════════════════════════════════════════════════════

  Future<List<Uint8List>> extractFrames({
    required String videoPath,
    required Duration startTime,
    required Duration endTime,
    int fps = 1,
    int width = 320,
    int height = 180,
    Function(double progress)? onProgress,
  }) async {
    final frames = <Uint8List>[];

    try {
      final tempDir = await getTemporaryDirectory();
      final outputDir = Directory(
        path.join(
          tempDir.path,
          'frames_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      await outputDir.create();

      final duration = endTime - startTime;
      final startString = _formatDurationForFFmpeg(startTime);
      final durationString = _formatDurationForFFmpeg(duration);

      final command =
          '-ss $startString -i "$videoPath" -t $durationString -vf "fps=$fps,scale=$width:$height" "${outputDir.path}/frame_%04d.jpg"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final files = await outputDir.list().toList();
        files.sort((a, b) => a.path.compareTo(b.path));

        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          if (file is File) {
            final bytes = await file.readAsBytes();
            frames.add(bytes);
          }
          onProgress?.call((i + 1) / files.length);
        }
      }

      // Cleanup
      await outputDir.delete(recursive: true);
    } catch (e) {
      debugPrint('❌ Frame extraction failed: $e');
    }

    return frames;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  String _formatDurationForFFmpeg(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(
      3,
      '0',
    );
    return '$hours:$minutes:$seconds.$milliseconds';
  }

  void clearCache() {
    _thumbnailCache.clear();
    _singleThumbnailCache.clear();
  }

  void dispose() {
    clearCache();
  }
}
