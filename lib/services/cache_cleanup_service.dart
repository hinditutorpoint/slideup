import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Removes orphaned temp files left behind by interrupted operations
/// (failed model downloads, image edits, TTS playback, video thumbnails).
/// Runs automatically at app startup to prevent the app cache from
/// ballooning (e.g. multi-hundred-MB partial model downloads).
class CacheCleanupService {
  CacheCleanupService._();

  static final CacheCleanupService instance = CacheCleanupService._();

  static const Duration _maxAge = Duration(hours: 1);

  static final List<RegExp> _ttsPatterns = [
    RegExp(r'^tts_playback_.+\.wav$'),
    RegExp(r'^tts_.+\.wav$'),
  ];

  static final List<RegExp> _imageEditPatterns = [
    RegExp(r'^(rotated|adjusted|cropped)_.+\.jpg$'),
  ];

  static final List<RegExp> _thumbnailPatterns = [
    RegExp(r'^thumb_.+\.jpg$'),
  ];

  /// Cleans orphaned temp files in the app cache directory.
  ///
  /// Partial model downloads are only removed when older than [_maxAge] so a
  /// freshly interrupted download can still be resumed (the app persists
  /// downloadedBytes in the DB for Range-based resume). Other temp files (TTS
  /// wavs, image edits, video thumbnails) are also removed when older than
  /// [_maxAge].
  Future<void> cleanupOrphanedTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return;

      await _cleanModelDownloadTemp(tempDir);
      await _cleanOldFiles(tempDir, _ttsPatterns);
      await _cleanOldFiles(tempDir, _imageEditPatterns);
      await _cleanOldFiles(tempDir, _thumbnailPatterns);
    } catch (e) {
      debugPrint('❌ Cache cleanup error: $e');
    }
  }

  Future<void> _cleanModelDownloadTemp(Directory tempDir) async {
    final modelDir = Directory('${tempDir.path}/model_downloads');
    if (!await modelDir.exists()) return;
    try {
      await for (final entity in modelDir.list(recursive: true)) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          if (DateTime.now().difference(stat.modified) > _maxAge) {
            await entity.delete();
            debugPrint(
              '🧹 Cache cleanup: removed stale partial ${entity.path}',
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ Cache cleanup: failed to scan model_downloads: $e');
    }
  }

  Future<void> _cleanOldFiles(Directory dir, List<RegExp> patterns) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!patterns.any((p) => p.hasMatch(name))) continue;

        try {
          final stat = await entity.stat();
          if (DateTime.now().difference(stat.modified) > _maxAge) {
            await entity.delete();
            debugPrint('🧹 Cache cleanup: removed stale $name');
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ Cache cleanup: error listing $dir: $e');
    }
  }
}