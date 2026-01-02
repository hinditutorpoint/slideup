import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/media_file.dart';
import '../providers/audio_handler_provider.dart';
import '../providers/mini_player_provider.dart';
import '../providers/media_provider.dart';

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

      // Find index
      final index =
          startIndex ??
          audioFiles.indexWhere((file) => file.id == mediaFile.id);

      // Load and play
      await audioHandler.loadPlaylist(
        audioFiles,
        initialIndex: index >= 0 ? index : 0,
      );

      await audioHandler.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
      ref.read(miniPlayerProvider.notifier).hide();
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
