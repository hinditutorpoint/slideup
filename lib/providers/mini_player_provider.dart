import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../models/media_file.dart';
import 'audio_handler_provider.dart';
import '../services/audio_service.dart';

class MiniPlayerState {
  final bool isVisible;
  final bool isExpanded;
  final MediaFile? currentMedia;
  final List<MediaFile> playlist;
  final Offset position;
  final bool isAppInForeground;

  MiniPlayerState({
    this.isVisible = false,
    this.isExpanded = false,
    this.currentMedia,
    this.playlist = const [],
    this.position = const Offset(20, 100),
    this.isAppInForeground = true,
  });

  MiniPlayerState copyWith({
    bool? isVisible,
    bool? isExpanded,
    MediaFile? currentMedia,
    List<MediaFile>? playlist,
    Offset? position,
    bool? isAppInForeground,
  }) {
    return MiniPlayerState(
      isVisible: isVisible ?? this.isVisible,
      isExpanded: isExpanded ?? this.isExpanded,
      currentMedia: currentMedia ?? this.currentMedia,
      playlist: playlist ?? this.playlist,
      position: position ?? this.position,
      isAppInForeground: isAppInForeground ?? this.isAppInForeground,
    );
  }
}

class MiniPlayerNotifier extends Notifier<MiniPlayerState> {
  @override
  MiniPlayerState build() {
    debugPrint('🎵 MiniPlayerNotifier.build() called');
    final audioHandler = ref.read(audioHandlerProvider);
    _listenToPlaybackState(audioHandler);
    _listenToMediaItem(audioHandler);
    return MiniPlayerState();
  }

  void _listenToPlaybackState(AudioPlayerHandler audioHandler) {
    debugPrint('🎵 MiniPlayerNotifier._listenToPlaybackState() called');

    audioHandler.playbackState.listen((playbackState) {
      debugPrint(
        '🎵 Playback state: ${playbackState.processingState}, playing: ${playbackState.playing}',
      );

      // Only hide when truly stopped AND app is in foreground
      // Don't hide if audio is just paused or app is in background
      if (playbackState.processingState == AudioProcessingState.idle) {
        // Check if there's no media item (truly stopped)
        final hasMedia = audioHandler.mediaItem.value != null;

        if (!hasMedia && state.isVisible && state.isAppInForeground) {
          debugPrint('🎵 No media and idle, hiding mini player');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (audioHandler.mediaItem.value == null) {
              hide();
            }
          });
        }
      } else if (playbackState.processingState ==
          AudioProcessingState.completed) {
        // Only hide on completion if repeat mode is off
        final repeatMode = playbackState.repeatMode;
        if (repeatMode == AudioServiceRepeatMode.none &&
            state.isAppInForeground) {
          debugPrint('🎵 Playback completed, hiding mini player');
          Future.delayed(const Duration(milliseconds: 500), () {
            hide();
          });
        }
      }
    });
  }

  void _listenToMediaItem(AudioPlayerHandler audioHandler) {
    audioHandler.mediaItem.listen((mediaItem) {
      debugPrint('🎵 Media item changed: ${mediaItem?.title}');

      if (mediaItem != null && state.isVisible) {
        // Update current media from mediaItem if needed
        // This keeps the mini player in sync when tracks change
        final currentMedia = state.currentMedia;
        if (currentMedia?.id != mediaItem.id) {
          // Find the matching MediaFile in playlist
          final matchingFile = state.playlist.firstWhere(
            (f) => f.id == mediaItem.id,
            orElse: () => state.currentMedia!,
          );
          state = state.copyWith(currentMedia: matchingFile);
        }
      }
    });
  }

  /// Call this when app lifecycle changes
  void setAppForegroundState(bool isInForeground) {
    debugPrint('🎵 App foreground state: $isInForeground');
    state = state.copyWith(isAppInForeground: isInForeground);

    // When app comes back to foreground, check if we should show mini player
    if (isInForeground) {
      final audioHandler = ref.read(audioHandlerProvider);
      final hasMedia = audioHandler.mediaItem.value != null;
      final isPlaying = audioHandler.playbackState.value.playing;

      debugPrint(
        '🎵 Returning to foreground - hasMedia: $hasMedia, isPlaying: $isPlaying',
      );

      // If there's media playing/paused, ensure mini player is visible
      if (hasMedia && !state.isExpanded) {
        // Mini player should be visible if there's active media
        if (!state.isVisible && state.currentMedia != null) {
          state = state.copyWith(isVisible: true);
        }
      }
    }
  }

  void show(MediaFile media, List<MediaFile> playlist) {
    debugPrint('🎵 MiniPlayerNotifier.show() called for: ${media.name}');
    state = state.copyWith(
      isVisible: true,
      currentMedia: media,
      playlist: playlist,
      isExpanded: false,
    );
    debugPrint(
      '🎵 Mini player state updated - isVisible: ${state.isVisible}, currentMedia: ${state.currentMedia?.name}',
    );
  }

  void hide() {
    debugPrint('🎵 MiniPlayerNotifier.hide() called');
    state = state.copyWith(isVisible: false, isExpanded: false);
    debugPrint('🎵 Mini player hidden - isVisible: ${state.isVisible}');
  }

  void expand() {
    debugPrint('🎵 MiniPlayerNotifier.expand() called');
    state = state.copyWith(isExpanded: true);
  }

  void collapse() {
    debugPrint('🎵 MiniPlayerNotifier.collapse() called');
    final audioHandler = ref.read(audioHandlerProvider);
    final hasMedia = audioHandler.mediaItem.value != null;

    if (hasMedia) {
      state = state.copyWith(isExpanded: false, isVisible: true);
    } else {
      hide();
    }
  }

  void updatePosition(Offset position) {
    state = state.copyWith(position: position);
  }

  /// Force show mini player (useful when returning from background)
  void ensureVisible() {
    final audioHandler = ref.read(audioHandlerProvider);
    final hasMedia = audioHandler.mediaItem.value != null;

    if (hasMedia && state.currentMedia != null && !state.isExpanded) {
      debugPrint('🎵 Ensuring mini player is visible');
      state = state.copyWith(isVisible: true);
    }
  }
}

final miniPlayerProvider =
    NotifierProvider<MiniPlayerNotifier, MiniPlayerState>(() {
      return MiniPlayerNotifier();
    });
