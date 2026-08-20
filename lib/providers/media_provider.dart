import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/media_file.dart';
import '../models/recent_file.dart';
import '../services/database_service.dart';
import '../services/file_scanner_service.dart';
import '../services/permission_service.dart';
import '../services/security_service.dart';
import 'package:uuid/uuid.dart';
import '../models/playback_record.dart';

// Media Provider
final mediaProvider = NotifierProvider<MediaNotifier, AsyncValue<void>>(() {
  return MediaNotifier();
});

class MediaNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  final _db = DatabaseService.instance;
  final _scanner = FileScannerService.instance;
  final _uuid = const Uuid();

  /// Scans storage for media files.
  ///
  /// When [force] is false (default) and the database already contains files,
  /// an incremental scan is performed: files that are unchanged since the last
  /// scan are reused as-is, so FFprobe/FFmpeg native processes are only spawned
  /// for new or modified files. This keeps app startup fast and avoids stalling
  /// the UI thread on every launch.
  Future<void> scanMedia({bool force = false}) async {
    state = const AsyncValue.loading();

    try {
      final hasPermission = await PermissionService.instance
          .hasAllPermissions();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      final existing = await _db.getAllMediaFiles();
      final idByPath = {for (final f in existing) f.path: f.id};

      final files = await _scanner.scanAllMedia(
        existingByPath: force ? null : {for (final f in existing) f.path: f},
      );
      // Preserve stable ids across rescans: playlists, favorites and recent
      // files reference media by id, but the scanner mints a new uuid per
      // scan. Reuse the previous id for any file that matches by path.
      final mapped = files
          .map((f) {
            final existingId = idByPath[f.path];
            if (existingId != null && existingId != f.id) {
              return f.copyWith(id: existingId);
            }
            return f;
          })
          .toList();
      await _db.clearMediaFiles();
      await _db.insertMediaFiles(mapped);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> addToRecent(MediaFile file, {Duration? lastPosition}) async {
    if (file.isLocked ||
        file.path.toLowerCase().endsWith('.slock') ||
        file.id.toLowerCase().endsWith('.slock')) {
      return;
    }

    final isLockedInService =
        await SecurityService.instance.isFileLocked(file.path);
    if (isLockedInService) return;

    // Keep an access/position record for "Ask to Resume Last Position"
    // (gated by that setting, independent of Recent History).
    await recordPlayback(file, position: lastPosition);

    if (!_isRecentHistoryEnabled()) return;

    final recent = RecentFile(
      id: _uuid.v4(),
      mediaId: file.id,
      lastAccessed: DateTime.now(),
      lastPosition: lastPosition?.inMilliseconds ?? file.lastPosition,
    );

    await _db.insertOrUpdateRecentFile(recent);
  }

  /// Persist an always-on playback record keyed by a content fingerprint
  /// (local files) or the URL (network), so the entry survives a rename/move.
  Future<void> recordPlayback(
    MediaFile file, {
    Duration? position,
  }) {
    return recordPlaybackFor(file, position: position);
  }

  /// Static entry so non-widget services (e.g. the audio handler) can write a
  /// playback record without a [WidgetRef]. Gated by the Ask to Resume setting.
  static Future<void> recordPlaybackFor(
    MediaFile file, {
    Duration? position,
  }) async {
    if (!_isAskResumeEnabled()) return;
    try {
      final db = DatabaseService.instance;
      final isNetwork = file.path.startsWith('http://') ||
          file.path.startsWith('https://');
      final fileHash = isNetwork
          ? null
          : await PlaybackRecord.computeFileFingerprint(File(file.path));
      final mediaKey = isNetwork
          ? 'url:${file.path}'
          : 'fp:$fileHash';
      final existing = await db.getPlaybackRecordByKey(mediaKey);
      final record = PlaybackRecord(
        id: existing?.id ?? const Uuid().v4(),
        mediaKey: mediaKey,
        mediaId: file.id,
        path: file.path,
        title: file.name,
        mediaType: file.type.index,
        lastPlayedAt: DateTime.now(),
        lastPosition: position?.inMilliseconds ?? file.lastPosition,
        duration: file.duration,
        playCount: existing?.playCount ?? 1,
        fileHash: fileHash,
        fileSize: file.size,
        dateModified: file.dateModified,
      );
      await db.upsertPlaybackRecord(record);
    } catch (e) {
      debugPrint('⚠️ Failed to record playback: $e');
    }
  }

  bool _isRecentHistoryEnabled() {
    try {
      final box = Hive.box('settings');
      return box.get('recentHistoryEnabled', defaultValue: true) as bool;
    } catch (e) {
      return true;
    }
  }

  static bool _isAskResumeEnabled() {
    try {
      final box = Hive.box('settings');
      return box.get('askResumeLastPosition', defaultValue: false) as bool;
    } catch (e) {
      return false;
    }
  }

  Future<void> removeFromRecent(String mediaId) async {
    final recents = await _db.getRecentFiles();
    final matches = recents.where((r) => r.mediaId == mediaId);
    if (matches.isEmpty) return;
    final recent = matches.first;
    await _db.deleteRecentFile(recent.id);
  }

  Future<void> clearRecent() async {
    await _db.clearRecentFiles();
  }
}

// Videos Provider
final videosProvider = FutureProvider<List<MediaFile>>((ref) async {
  final db = DatabaseService.instance;
  return await db.getMediaFilesByType(MediaType.video);
});

// Audios Provider
final audiosProvider = FutureProvider<List<MediaFile>>((ref) async {
  final db = DatabaseService.instance;
  return await db.getMediaFilesByType(MediaType.audio);
});

// Documents Provider
final documentsProvider = FutureProvider<List<MediaFile>>((ref) async {
  final db = DatabaseService.instance;
  return await db.getMediaFilesByType(MediaType.document);
});

// Recent Files Provider
final recentFilesProvider = FutureProvider<List<MediaFile>>((ref) async {
  final db = DatabaseService.instance;
  final recents = await db.getRecentFiles(limit: 50);

  final files = <MediaFile>[];
  for (var recent in recents) {
    final file = await _resolveRecentMediaFile(db, recent);
    if (file != null) {
      files.add(file);
    }
  }

  return files;
});

/// Resolve a recent entry to a [MediaFile].
///
/// Order of resolution:
/// 1. Look up the scanned media DB by id (internal storage).
/// 2. Look up the scanned media DB by path (SD card if it was scanned).
/// 3. Rebuild directly from the stored path/URL (SD card or network).
Future<MediaFile?> _resolveRecentMediaFile(
  DatabaseService db,
  RecentFile recent,
) async {
  var file = await db.getMediaFileById(recent.mediaId);
  if (file != null) {
    return recent.lastPosition != null && recent.lastPosition! > 0
        ? file.copyWith(lastPosition: recent.lastPosition)
        : file;
  }

  file = await db.getMediaFileByPath(recent.mediaId);
  if (file != null) {
    return recent.lastPosition != null && recent.lastPosition! > 0
        ? file.copyWith(lastPosition: recent.lastPosition)
        : file;
  }

  // Rename/move detection: the stored path no longer resolves. Match the
  // current file by its content fingerprint so the record follows the file.
  final localPath = recent.mediaId;
  if (!localPath.startsWith('http://') && !localPath.startsWith('https://')) {
    try {
      final f = File(localPath);
      if (await f.exists()) {
        final fp = await PlaybackRecord.computeFileFingerprint(f);
        final byHash = await db.getPlaybackRecordByHash(fp);
        if (byHash != null) {
          final fromFile = MediaFile.fromFile(f);
          if (fromFile != null) {
            // Re-key history under the new path so future lookups hit directly.
            await db.upsertPlaybackRecord(byHash.copyWith(path: f.path));
            final pos = byHash.lastPosition;
            return pos != null && pos > 0
                ? fromFile.copyWith(lastPosition: pos)
                : fromFile;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Fingerprint lookup failed: $e');
    }
  }

  final mediaId = recent.mediaId;
  if (mediaId.startsWith('http://') || mediaId.startsWith('https://')) {
    return MediaFile(
      id: mediaId,
      name: _nameFromUrl(mediaId),
      path: mediaId,
      type: MediaType.video,
      size: 0,
      dateModified: recent.lastAccessed,
      lastPosition: recent.lastPosition,
    );
  }

  final fromFile = MediaFile.fromFile(File(mediaId));
  if (fromFile == null) return null;
  return recent.lastPosition != null && recent.lastPosition! > 0
      ? fromFile.copyWith(lastPosition: recent.lastPosition)
      : fromFile;
}

String _nameFromUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) return segments.last;
    return uri.host;
  } catch (e) {
    return url;
  }
}
