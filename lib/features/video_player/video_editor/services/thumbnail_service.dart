import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final Map<String, Uint8List> _memoryCache = {};
  Directory? _cacheDir;
  bool _isDisposed = false;
  bool _isInitialized = false;

  // Video info cache
  final Map<String, Map<String, dynamic>> _videoInfoCache = {};

  // Mutex for sequential execution
  final _executionLock = _AsyncLock();

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _cacheDir = await _getCacheDirectory();
      await FFmpegKitConfig.setLogLevel(48); // AV_LOG_WARNING
      _isInitialized = true;
      debugPrint('✅ ThumbnailService initialized');
    } catch (e) {
      debugPrint('❌ ThumbnailService init error: $e');
    }
  }

  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null) {
      try {
        if (await _cacheDir!.exists()) return _cacheDir!;
      } catch (_) {}
    }

    try {
      final tempDir = await getExternalStorageDirectory();
      _cacheDir = Directory(p.join(tempDir!.path, 'video_thumbnails'));

      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }

      return _cacheDir!;
    } catch (e) {
      debugPrint('❌ Get cache directory error: $e');
      return await getTemporaryDirectory();
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GET VIDEO INFO (Cached)
  // ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getVideoInfo(String videoPath) async {
    // Check cache first
    if (_videoInfoCache.containsKey(videoPath)) {
      return _videoInfoCache[videoPath];
    }

    try {
      if (!await _validateVideoFile(videoPath)) return null;

      final session = await FFprobeKit.getMediaInformation(videoPath);
      final info = session.getMediaInformation();

      if (info == null) return null;

      final streams = info.getStreams();
      int? width;
      int? height;
      double? fps;
      String? codec;
      int? rotation;

      for (final stream in streams) {
        // ✅ FIX: Convert Map<Object?, Object?> to Map<String, dynamic>
        final rawProperties = stream.getAllProperties();
        if (rawProperties == null) continue;

        final properties = _convertToStringDynamicMap(rawProperties);
        if (properties == null) continue;

        if (properties['codec_type'] == 'video') {
          width = _parseInt(properties['width']);
          height = _parseInt(properties['height']);
          codec = properties['codec_name']?.toString();

          // Check rotation in side_data_list
          rotation = _extractRotation(properties);

          // Parse FPS
          fps = _parseFps(properties['r_frame_rate']?.toString());

          break;
        }
      }

      // Handle rotation (swap dimensions if rotated 90 or 270)
      if (rotation == 90 || rotation == 270) {
        final temp = width;
        width = height;
        height = temp;
      }

      // Parse duration
      final durationStr = info.getDuration();
      Duration? duration;
      if (durationStr != null) {
        final seconds = double.tryParse(durationStr);
        if (seconds != null && seconds > 0) {
          duration = Duration(milliseconds: (seconds * 1000).toInt());
        }
      }

      final result = <String, dynamic>{
        'duration': duration,
        'width': width ?? 1920,
        'height': height ?? 1080,
        'fps': fps ?? 30.0,
        'codec': codec,
        'rotation': rotation ?? 0,
        'size': info.getSize(),
        'bitrate': info.getBitrate(),
        'format': info.getFormat(),
      };

      // Cache the result
      _videoInfoCache[videoPath] = result;

      return result;
    } catch (e, stack) {
      debugPrint('❌ Get video info error: $e');
      debugPrint('Stack: $stack');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPER METHODS FOR TYPE CONVERSION
  // ═══════════════════════════════════════════════════════

  /// Safely convert Map<Object?, Object?> to Map<String, dynamic>
  Map<String, dynamic>? _convertToStringDynamicMap(
    Map<Object?, Object?>? source,
  ) {
    if (source == null) return null;

    try {
      return source.map((key, value) {
        final stringKey = key?.toString() ?? '';

        // Recursively convert nested maps
        if (value is Map<Object?, Object?>) {
          return MapEntry(stringKey, _convertToStringDynamicMap(value));
        } else if (value is List) {
          return MapEntry(stringKey, _convertList(value));
        }

        return MapEntry(stringKey, value);
      });
    } catch (e) {
      debugPrint('⚠️ Map conversion error: $e');
      return null;
    }
  }

  /// Convert list items recursively
  List<dynamic> _convertList(List<dynamic> source) {
    return source.map((item) {
      if (item is Map<Object?, Object?>) {
        return _convertToStringDynamicMap(item);
      } else if (item is List) {
        return _convertList(item);
      }
      return item;
    }).toList();
  }

  /// Safely parse int from various types
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Parse FPS from fraction string like "30000/1001"
  double? _parseFps(String? fpsStr) {
    if (fpsStr == null || fpsStr.isEmpty) return null;

    if (fpsStr.contains('/')) {
      final parts = fpsStr.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den > 0) {
          return num / den;
        }
      }
    }

    return double.tryParse(fpsStr);
  }

  /// Extract rotation from properties (handles different FFprobe versions)
  int? _extractRotation(Map<String, dynamic> properties) {
    // Method 1: Check tags
    final tags = properties['tags'];
    if (tags is Map) {
      final tagsMap = _convertToStringDynamicMap(
        // ignore: unnecessary_type_check
        tags is Map<Object?, Object?> ? tags : null,
      );
      if (tagsMap != null && tagsMap['rotate'] != null) {
        return _parseInt(tagsMap['rotate']);
      }
    }

    // Method 2: Check side_data_list (newer FFprobe versions)
    final sideDataList = properties['side_data_list'];
    if (sideDataList is List) {
      for (final sideData in sideDataList) {
        if (sideData is Map) {
          final sideDataMap = _convertToStringDynamicMap(
            sideData is Map<Object?, Object?> ? sideData : null,
          );
          if (sideDataMap != null && sideDataMap['rotation'] != null) {
            return _parseInt(sideDataMap['rotation']);
          }
        }
      }
    }

    // Method 3: Check display matrix
    final displayMatrix = properties['display_matrix'];
    if (displayMatrix != null) {
      // Parse rotation from display matrix string if present
      final rotationMatch = RegExp(
        r'rotation of (-?\d+)',
      ).firstMatch(displayMatrix.toString());
      if (rotationMatch != null) {
        return _parseInt(rotationMatch.group(1));
      }
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GENERATE SINGLE THUMBNAIL - FIXED DIMENSIONS
  // ═══════════════════════════════════════════════════════

  Future<Uint8List?> getThumbnailAtPosition({
    required String videoPath,
    required Duration position,
    int width = 320,
    int height = 180,
    int quality = 80,
  }) async {
    if (_isDisposed) return null;

    if (!_isInitialized) {
      await initialize();
    }

    // Validate input
    if (!await _validateVideoFile(videoPath)) {
      debugPrint('❌ Invalid video file: $videoPath');
      return null;
    }

    // Check memory cache first
    final cacheKey = _generateCacheKey(videoPath, position, width, height);
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // Use lock to prevent concurrent FFmpeg executions
    return _executionLock.synchronized(() async {
      try {
        // Get video info to determine proper output dimensions
        final videoInfo = await getVideoInfo(videoPath);
        final videoWidth = videoInfo?['width'] as int? ?? 1920;
        final videoHeight = videoInfo?['height'] as int? ?? 1080;

        // Calculate proper output dimensions that won't cause padding issues
        final outputDimensions = _calculateSafeDimensions(
          videoWidth: videoWidth,
          videoHeight: videoHeight,
          targetWidth: width,
          targetHeight: height,
        );

        final cacheDir = await _getCacheDirectory();
        final outputFileName =
            'thumb_${DateTime.now().millisecondsSinceEpoch}_${cacheKey.hashCode.abs()}.jpg';
        final outputPath = p.join(cacheDir.path, outputFileName);

        // Clean up old file if exists
        await _safeDeleteFile(outputPath);

        final timeStr = _formatDurationForFFmpeg(position);

        // Build command with safe dimensions
        final command = _buildSafeThumbnailCommand(
          videoPath: videoPath,
          outputPath: outputPath,
          timeStr: timeStr,
          outputWidth: outputDimensions['width']!,
          outputHeight: outputDimensions['height']!,
          quality: quality,
        );

        debugPrint('🎬 Thumbnail command: $command');

        // Execute with timeout
        final result = await _executeFFmpegWithTimeout(
          command,
          const Duration(seconds: 30),
        );

        if (result == true) {
          final file = File(outputPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();

            // Cache in memory
            _addToMemoryCache(cacheKey, bytes);

            // Clean up temp file
            await _safeDeleteFile(outputPath);

            return bytes;
          }
        }

        debugPrint('⚠️ Thumbnail generation failed, trying fallback...');
        return await _generateThumbnailFallback(
          videoPath: videoPath,
          position: position,
          outputPath: outputPath,
        );
      } catch (e, stack) {
        debugPrint('❌ Get thumbnail error: $e');
        debugPrint('Stack: $stack');
        return null;
      }
    });
  }

  Map<String, int> _calculateSafeDimensions({
    required int videoWidth,
    required int videoHeight,
    required int targetWidth,
    required int targetHeight,
  }) {
    // Ensure dimensions are even (required by many codecs)
    int safeWidth = targetWidth;
    int safeHeight = targetHeight;

    // Calculate aspect ratio
    final videoAspect = videoWidth / videoHeight;
    final targetAspect = targetWidth / targetHeight;

    if (videoAspect > targetAspect) {
      // Video is wider - fit to width
      safeWidth = targetWidth;
      safeHeight = (targetWidth / videoAspect).round();
    } else {
      // Video is taller - fit to height
      safeHeight = targetHeight;
      safeWidth = (targetHeight * videoAspect).round();
    }

    // Ensure even dimensions
    safeWidth = (safeWidth ~/ 2) * 2;
    safeHeight = (safeHeight ~/ 2) * 2;

    // Ensure minimum size
    safeWidth = safeWidth.clamp(2, targetWidth);
    safeHeight = safeHeight.clamp(2, targetHeight);

    return {'width': safeWidth, 'height': safeHeight};
  }

  String _buildSafeThumbnailCommand({
    required String videoPath,
    required String outputPath,
    required String timeStr,
    required int outputWidth,
    required int outputHeight,
    required int quality,
  }) {
    final escapedInput = _escapePathForShell(videoPath);
    final escapedOutput = _escapePathForShell(outputPath);

    // Simple scale without padding to avoid dimension issues
    return '-y '
        '-ss $timeStr '
        '-i $escapedInput '
        '-vframes 1 '
        '-vf "scale=$outputWidth:$outputHeight:force_original_aspect_ratio=decrease" '
        '-q:v ${((100 - quality) / 100 * 31).clamp(1, 31).toInt()} '
        '-f image2 '
        '$escapedOutput';
  }

  Future<Uint8List?> _generateThumbnailFallback({
    required String videoPath,
    required Duration position,
    required String outputPath,
  }) async {
    try {
      // Ultra-simple fallback command
      final timeStr = _formatDurationForFFmpeg(position);
      final escapedInput = _escapePathForShell(videoPath);
      final escapedOutput = _escapePathForShell(outputPath);

      final command =
          '-y '
          '-ss $timeStr '
          '-i $escapedInput '
          '-vframes 1 '
          '-q:v 5 '
          '$escapedOutput';

      final result = await _executeFFmpegWithTimeout(
        command,
        const Duration(seconds: 20),
      );

      if (result == true) {
        final file = File(outputPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await _safeDeleteFile(outputPath);
          return bytes;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Fallback thumbnail error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GENERATE TIMELINE THUMBNAILS
  // ═══════════════════════════════════════════════════════

  Future<List<Uint8List>> generateTimelineThumbnails({
    required String videoPath,
    required Duration videoDuration,
    int count = 10,
    int width = 120,
    int height = 68,
    Function(double)? onProgress,
  }) async {
    if (_isDisposed) return [];

    if (!_isInitialized) {
      await initialize();
    }

    final thumbnails = <Uint8List>[];

    try {
      if (videoDuration.inMilliseconds <= 0) {
        debugPrint('⚠️ Invalid video duration');
        return thumbnails;
      }

      if (!await _validateVideoFile(videoPath)) {
        debugPrint('❌ Invalid video file');
        return thumbnails;
      }

      final interval = videoDuration.inMilliseconds / count;

      // Generate thumbnails sequentially
      for (int i = 0; i < count; i++) {
        if (_isDisposed) break;

        // Add small offset to avoid exactly 0
        final positionMs = (interval * i).toInt();
        final position = Duration(
          milliseconds: positionMs < 100 ? 100 : positionMs,
        );

        final thumb = await getThumbnailAtPosition(
          videoPath: videoPath,
          position: position,
          width: width,
          height: height,
          quality: 60,
        );

        if (thumb != null) {
          thumbnails.add(thumb);
        }

        onProgress?.call((i + 1) / count);

        // Small delay between operations
        await Future.delayed(const Duration(milliseconds: 30));
      }

      debugPrint('✅ Generated ${thumbnails.length}/$count thumbnails');
      return thumbnails;
    } catch (e) {
      debugPrint('❌ Generate timeline thumbnails error: $e');
      return thumbnails;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ FFMPEG EXECUTION
  // ═══════════════════════════════════════════════════════

  Future<bool?> _executeFFmpegWithTimeout(
    String command,
    Duration timeout,
  ) async {
    try {
      final completer = Completer<bool>();
      int? sessionId;

      final session = await FFmpegKit.executeAsync(
        command,
        (session) async {
          try {
            final returnCode = await session.getReturnCode();
            sessionId = session.getSessionId();

            if (!completer.isCompleted) {
              completer.complete(ReturnCode.isSuccess(returnCode));
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
        },
        (log) {
          // Only log errors
          if (log.getLevel() <= 16) {
            debugPrint('FFmpeg Error: ${log.getMessage()}');
          }
        },
        null, // Statistics callback
      );

      sessionId = session.getSessionId();

      final result = await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('⚠️ FFmpeg timeout, cancelling...');
          if (sessionId != null) {
            FFmpegKit.cancel(sessionId!);
          }
          return false;
        },
      );

      return result;
    } catch (e) {
      debugPrint('❌ Execute FFmpeg error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPER METHODS
  // ═══════════════════════════════════════════════════════

  Future<bool> _validateVideoFile(String path) async {
    try {
      if (path.isEmpty) return false;

      final file = File(path);
      if (!await file.exists()) return false;

      final stat = await file.stat();
      return stat.size > 0;
    } catch (e) {
      return false;
    }
  }

  String _generateCacheKey(
    String path,
    Duration position,
    int width,
    int height,
  ) {
    final pathHash = path.hashCode.abs();
    final posMs = position.inMilliseconds;
    return '${pathHash}_${posMs}_${width}x$height';
  }

  void _addToMemoryCache(String key, Uint8List bytes) {
    const maxCacheItems = 200;

    if (_memoryCache.length >= maxCacheItems) {
      final keysToRemove = _memoryCache.keys.take(50).toList();
      for (final k in keysToRemove) {
        _memoryCache.remove(k);
      }
    }

    _memoryCache[key] = bytes;
  }

  String _formatDurationForFFmpeg(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$milliseconds';
  }

  String _escapePathForShell(String path) {
    if (Platform.isWindows) {
      return '"${path.replaceAll('"', '\\"')}"';
    } else {
      return '"${path.replaceAll('"', '\\"').replaceAll("'", "\\'")}"';
    }
  }

  Future<void> _safeDeleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CACHE & DISPOSE
  // ═══════════════════════════════════════════════════════

  void clearMemoryCache() {
    _memoryCache.clear();
    _videoInfoCache.clear();
  }

  void dispose() {
    _isDisposed = true;
    clearMemoryCache();
    debugPrint('✅ ThumbnailService disposed');
  }
}

// ═══════════════════════════════════════════════════════
// ✅ ASYNC LOCK
// ═══════════════════════════════════════════════════════

class _AsyncLock {
  Future<void>? _lastOperation;

  Future<T> synchronized<T>(Future<T> Function() operation) async {
    while (_lastOperation != null) {
      try {
        await _lastOperation;
      } catch (_) {}
    }

    final completer = Completer<void>();
    _lastOperation = completer.future;

    try {
      final result = await operation();
      return result;
    } finally {
      completer.complete();
      _lastOperation = null;
    }
  }
}
