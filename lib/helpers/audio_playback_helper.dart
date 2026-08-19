import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/media_file.dart';
import '../providers/audio_handler_provider.dart';
import '../providers/download_providers.dart';
import '../providers/mini_player_provider.dart';
import '../providers/media_provider.dart';
import '../features/documents/models/download_task.dart';

class AudioPlaybackHelper {
  /// Play audio with mini player
  static Future<void> playAudio(
    WidgetRef ref,
    MediaFile mediaFile,
    List<MediaFile> playlist, {
    int? startIndex,
  }) async {
    try {
      // Add to recent
      await ref.read(mediaProvider.notifier).addToRecent(mediaFile);

      // Show mini player
      ref.read(miniPlayerProvider.notifier).show(mediaFile, playlist);

      // Get audio handler
      final audioHandler = ref.read(audioHandlerProvider);

      // Filter only audio files
      final audioFiles = playlist
          .where((file) => file.type == MediaType.audio)
          .toList();

      if (audioFiles.isEmpty) return;

      // Replace URL sources with their completed local downloads so the
      // player streams from disk instead of the network.
      final resolved = <MediaFile>[];
      for (final file in audioFiles) {
        resolved.add(await _resolveDownloadedSource(ref, file));
      }

      // Find index
      final index =
          startIndex ??
          audioFiles.indexWhere((file) => file.id == mediaFile.id);

      // Load and play
      await audioHandler.loadPlaylist(
        resolved,
        initialIndex: index >= 0 ? index : 0,
      );

      await audioHandler.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
      ref.read(miniPlayerProvider.notifier).hide();
    }
  }

  /// If [file] points at a URL that already has a completed download, return
  /// a copy pointing at the local file; otherwise return the file unchanged.
  static Future<MediaFile> _resolveDownloadedSource(
    WidgetRef ref,
    MediaFile file,
  ) async {
    if (!file.path.startsWith('http')) return file;
    try {
      final task = await ref
          .read(downloadServiceProvider)
          .getDownloadByIdentifier(file.path);
      if (task != null &&
          task.status == DownloadStatus.completed &&
          task.filePath != null &&
          File(task.filePath!).existsSync()) {
        return file.copyWith(
          path: task.filePath,
          mimeType: _mimeForPath(task.filePath!),
        );
      }
    } catch (e) {
      debugPrint('Error resolving downloaded source: $e');
    }
    return file;
  }

  static String? _mimeForPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'flac':
        return 'audio/flac';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'aac':
        return 'audio/aac';
      default:
        return 'audio/mpeg';
    }
  }

  /// Stop audio and hide mini player
  static Future<void> stopAudio(WidgetRef ref) async {
    try {
      final audioHandler = ref.read(audioHandlerProvider);
      await audioHandler.stop();
      ref.read(miniPlayerProvider.notifier).hide();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  /// Toggle play/pause
  static Future<void> togglePlayPause(WidgetRef ref) async {
    try {
      final audioHandler = ref.read(audioHandlerProvider);
      final playbackState = audioHandler.playbackState.value;

      if (playbackState.playing) {
        await audioHandler.pause();
      } else {
        await audioHandler.play();
      }
    } catch (e) {
      debugPrint('Error toggling playback: $e');
    }
  }
}
