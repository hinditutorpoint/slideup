import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playlist.dart';
import '../models/media_file.dart';
import '../services/database_service.dart';
import '../services/security_service.dart';
import 'package:uuid/uuid.dart';

/// Encodes a [MediaFile] into a value storable in `Playlist.mediaIds`.
///
/// Local files are stored by their DB id. URL-based items (e.g. m3u music
/// streams) are NOT present in the media DB, so they are persisted as a
/// `json:`-prefixed base64url-encoded [MediaFile.toJson] payload so they
/// can be fully reconstructed when the playlist is opened.
String encodePlaylistMediaId(MediaFile file) {
  if (file.path.startsWith('http')) {
    final json = jsonEncode(file.toJson());
    return 'json:${base64Url.encode(utf8.encode(json))}';
  }
  return file.id;
}

/// Decodes a media id produced by [encodePlaylistMediaId]. Returns null when
/// the payload cannot be decoded.
MediaFile? decodePlaylistMediaId(String mediaId) {
  if (!mediaId.startsWith('json:')) return null;
  try {
    final json = utf8.decode(base64Url.decode(mediaId.substring(5)));
    return MediaFile.fromJson(jsonDecode(json) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

// Playlists Provider
class PlaylistsNotifier extends Notifier<AsyncValue<List<Playlist>>> {
  final _db = DatabaseService.instance;
  final _uuid = const Uuid();

  @override
  AsyncValue<List<Playlist>> build() {
    _loadPlaylists();
    return const AsyncValue.loading();
  }

  Future<void> _loadPlaylists() async {
    state = const AsyncValue.loading();
    try {
      final playlists = await _db.getAllPlaylists();
      state = AsyncValue.data(playlists);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadPlaylists() async {
    await _loadPlaylists();
  }

  Future<void> createPlaylist({
    required String name,
    String? description,
    bool isLocked = false,
    String? password,
  }) async {
    final playlist = Playlist(
      id: _uuid.v4(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isLocked: isLocked,
      passwordHash: isLocked && password != null
          ? SecurityService.instance.hashPassword(password)
          : null,
    );

    await _db.insertPlaylist(playlist);
    await loadPlaylists();
  }

  /// Creates a new playlist (or updates [playlistId] when provided) with the
  /// given media ids. Returns the saved playlist id.
  Future<String> savePlaylistWithMedia({
    required String name,
    String? playlistId,
    required List<String> mediaIds,
    String? description,
  }) async {
    if (playlistId != null) {
      final existing = await _db.getPlaylistById(playlistId);
      if (existing != null) {
        await _db.updatePlaylist(
          existing.copyWith(
            name: name,
            description: description,
            mediaIds: mediaIds,
            updatedAt: DateTime.now(),
          ),
        );
        await loadPlaylists();
        return playlistId;
      }
    }

    final playlist = Playlist(
      id: _uuid.v4(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mediaIds: mediaIds,
    );
    await _db.insertPlaylist(playlist);
    await loadPlaylists();
    return playlist.id;
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    final updated = playlist.copyWith(updatedAt: DateTime.now());
    await _db.updatePlaylist(updated);
    await loadPlaylists();
  }

  Future<void> deletePlaylist(String id) async {
    await _db.deletePlaylist(id);
    await loadPlaylists();
  }

  Future<void> addMediaToPlaylist(String playlistId, String mediaId) async {
    final playlist = await _db.getPlaylistById(playlistId);
    if (playlist == null) return;

    final updatedMediaIds = [...playlist.mediaIds, mediaId];
    final updated = playlist.copyWith(
      mediaIds: updatedMediaIds,
      updatedAt: DateTime.now(),
    );

    await _db.updatePlaylist(updated);
    await loadPlaylists();
  }

  Future<void> removeMediaFromPlaylist(
    String playlistId,
    String mediaId,
  ) async {
    final playlist = await _db.getPlaylistById(playlistId);
    if (playlist == null) return;

    final updatedMediaIds = playlist.mediaIds
        .where((id) => id != mediaId)
        .toList();
    final updated = playlist.copyWith(
      mediaIds: updatedMediaIds,
      updatedAt: DateTime.now(),
    );

    await _db.updatePlaylist(updated);
    await loadPlaylists();
  }
}

final playlistsProvider =
    NotifierProvider<PlaylistsNotifier, AsyncValue<List<Playlist>>>(() {
      return PlaylistsNotifier();
    });

// Playlist Media Files Provider
final playlistMediaFilesProvider =
    FutureProvider.family<List<MediaFile>, String>((ref, playlistId) async {
      // Watch playlists provider to invalidate when playlists change
      ref.watch(playlistsProvider);

      final db = DatabaseService.instance;
      final playlist = await db.getPlaylistById(playlistId);

      if (playlist == null) return [];

      final files = <MediaFile>[];
      for (final mediaId in playlist.mediaIds) {
        // URL-based items are encoded with the `json:` prefix.
        final decoded = decodePlaylistMediaId(mediaId);
        if (decoded != null) {
          files.add(decoded);
          continue;
        }

        final file = await db.getMediaFileById(mediaId);
        // Some flows build MediaFile objects with `id = path` (e.g.
        // MediaFile.fromFile), so fall back to a path lookup.
        if (file != null) {
          files.add(file);
        } else {
          final byPath = await db.getMediaFileByPath(mediaId);
          if (byPath != null) files.add(byPath);
        }
      }

      return files;
    });
