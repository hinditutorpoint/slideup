import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

/// Audio handler that forwards commands to the actual player
/// Does NOT have its own AudioPlayer - just manages notification/controls
class AudiobookAudioHandler extends BaseAudioHandler with SeekHandler {
  // Callbacks to controller (the actual player)
  final Future<void> Function()? onPlay;
  final Future<void> Function()? onPause;
  final Future<void> Function()? onStop;
  final Future<void> Function()? onSkipToNext;
  final Future<void> Function()? onSkipToPrevious;
  final Future<void> Function(Duration position)? onSeek;

  AudiobookAudioHandler({
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onSkipToNext,
    this.onSkipToPrevious,
    this.onSeek,
  }) {
    // Initialize with idle state
    _setState(AudioProcessingState.idle, playing: false);
    debugPrint('[AudioHandler] Initialized (no internal player)');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE MANAGEMENT - Called by TtsController/EpubAudiobookController
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update the playback state (call this from your actual player)
  void updatePlaybackState({
    required bool playing,
    required AudioProcessingState processingState,
    Duration position = Duration.zero,
    Duration bufferedPosition = Duration.zero,
    double speed = 1.0,
  }) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: playing,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
        speed: speed,
      ),
    );
  }

  /// Shorthand to set state
  void _setState(AudioProcessingState state, {required bool playing}) {
    updatePlaybackState(playing: playing, processingState: state);
  }

  /// Set playing state
  void setPlaying() => _setState(AudioProcessingState.ready, playing: true);

  /// Set paused state
  void setPaused() => _setState(AudioProcessingState.ready, playing: false);

  /// Set loading state
  void setLoading() => _setState(AudioProcessingState.loading, playing: false);

  /// Set completed state
  void setCompleted() =>
      _setState(AudioProcessingState.completed, playing: false);

  /// Set idle state
  void setIdle() => _setState(AudioProcessingState.idle, playing: false);

  /// Update position (call periodically from your player)
  void updatePosition(
    Duration position, {
    Duration? bufferedPosition,
    Duration? duration,
  }) {
    playbackState.add(
      playbackState.value.copyWith(
        updatePosition: position,
        bufferedPosition: bufferedPosition ?? position,
      ),
    );

    // Update duration in media item if provided
    if (duration != null && mediaItem.value != null) {
      mediaItem.add(mediaItem.value!.copyWith(duration: duration));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEDIA INFO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update media item (book/chapter info for notification)
  Future<void> updateMediaInfo({
    required String title,
    String? album,
    String? artist,
    Duration? duration,
    Uri? artUri,
  }) async {
    mediaItem.add(
      MediaItem(
        id: 'audiobook_${DateTime.now().millisecondsSinceEpoch}',
        album: album ?? 'Audiobook',
        title: title,
        artist: artist,
        duration: duration,
        artUri: artUri,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION BUTTON HANDLERS - Forward to actual player
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> play() async {
    debugPrint('[AudioHandler] Play button pressed');
    await onPlay?.call();
  }

  @override
  Future<void> pause() async {
    debugPrint('[AudioHandler] Pause button pressed');
    await onPause?.call();
  }

  @override
  Future<void> stop() async {
    debugPrint('[AudioHandler] Stop button pressed');
    await onStop?.call();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('[AudioHandler] Skip next pressed');
    await onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('[AudioHandler] Skip previous pressed');
    await onSkipToPrevious?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    debugPrint('[AudioHandler] Seek to: $position');
    await onSeek?.call(position);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> dispose() async {
    // Nothing to dispose - no internal player
    debugPrint('[AudioHandler] Disposed');
  }
}
