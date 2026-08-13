import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/media_file.dart';
import '../models/recent_file.dart';
import '../services/database_service.dart';
import '../services/file_scanner_service.dart';
import '../services/permission_service.dart';
import '../services/security_service.dart';
import 'package:uuid/uuid.dart';

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

  Future<void> scanMedia() async {
    state = const AsyncValue.loading();

    try {
      final hasPermission = await PermissionService.instance
          .hasAllPermissions();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      final files = await _scanner.scanAllMedia();
      await _db.clearMediaFiles();
      await _db.insertMediaFiles(files);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> addToRecent(MediaFile file, {Duration? lastPosition}) async {
    if (!_isRecentHistoryEnabled()) return;
    if (file.isLocked ||
        file.path.toLowerCase().endsWith('.slock') ||
        file.id.toLowerCase().endsWith('.slock')) {
      return;
    }

    final isLockedInService =
        await SecurityService.instance.isFileLocked(file.path);
    if (isLockedInService) return;

    final recent = RecentFile(
      id: _uuid.v4(),
      mediaId: file.id,
      lastAccessed: DateTime.now(),
      lastPosition: lastPosition?.inMilliseconds ?? file.lastPosition,
    );

    await _db.insertOrUpdateRecentFile(recent);
  }

  bool _isRecentHistoryEnabled() {
    try {
      final box = Hive.box('settings');
      return box.get('recentHistoryEnabled', defaultValue: true) as bool;
    } catch (e) {
      return true;
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
