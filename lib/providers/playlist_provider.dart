import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playlist.dart';
import '../models/media_file.dart';
import '../services/database_service.dart';
import '../services/security_service.dart';
import 'package:uuid/uuid.dart';

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
        final file = await db.getMediaFileById(mediaId);
        if (file != null) {
          files.add(file);
        }
      }

      return files;
    });
