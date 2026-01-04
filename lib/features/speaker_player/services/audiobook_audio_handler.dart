import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class AudiobookAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  // Callbacks to controller
  final Future<void> Function()? onPlay;
  final Future<void> Function()? onPause;
  final Future<void> Function()? onStop;
  final Future<void> Function()? onSkipToNext;
  final Future<void> Function()? onSkipToPrevious;
  final Future<void> Function(Duration position)? onSeek;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  AudiobookAudioHandler({
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onSkipToNext,
    this.onSkipToPrevious,
    this.onSeek,
  }) {
    _init();
  }

  void _init() {
    // Listen to player state changes
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      _updatePlaybackState(state);
    });

    // Listen to position changes
    _positionSubscription = _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    });

    // Listen to duration changes
    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });
  }

  void _updatePlaybackState(PlayerState state) {
    final playing = state.playing;
    final processingState = state.processingState;

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
        processingState: _mapProcessingState(processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: 0,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Update media item (book/chapter info)
  Future<void> updateMediaInfo({
    required String title,
    required String album,
    String? artist,
    Duration? duration,
    Uri? artUri,
  }) async {
    mediaItem.add(
      MediaItem(
        id: 'audiobook_${DateTime.now().millisecondsSinceEpoch}',
        album: album,
        title: title,
        artist: artist,
        duration: duration,
        artUri: artUri,
      ),
    );
  }

  /// Set audio source
  Future<void> setAudioSource(String filePath) async {
    try {
      await _player.setFilePath(filePath);
    } catch (e) {
      debugPrint('[AudioHandler] Set audio source error: $e');
    }
  }

  /// Play
  @override
  Future<void> play() async {
    try {
      await onPlay?.call();
      await _player.play();
    } catch (e) {
      debugPrint('[AudioHandler] Play error: $e');
    }
  }

  /// Pause
  @override
  Future<void> pause() async {
    try {
      await onPause?.call();
      await _player.pause();
    } catch (e) {
      debugPrint('[AudioHandler] Pause error: $e');
    }
  }

  /// Stop
  @override
  Future<void> stop() async {
    try {
      await onStop?.call();
      await _player.stop();
      await super.stop();
    } catch (e) {
      debugPrint('[AudioHandler] Stop error: $e');
    }
  }

  /// Skip to next
  @override
  Future<void> skipToNext() async {
    try {
      await onSkipToNext?.call();
    } catch (e) {
      debugPrint('[AudioHandler] Skip next error: $e');
    }
  }

  /// Skip to previous
  @override
  Future<void> skipToPrevious() async {
    try {
      await onSkipToPrevious?.call();
    } catch (e) {
      debugPrint('[AudioHandler] Skip previous error: $e');
    }
  }

  /// Seek
  @override
  Future<void> seek(Duration position) async {
    try {
      await onSeek?.call(position);
      await _player.seek(position);
    } catch (e) {
      debugPrint('[AudioHandler] Seek error: $e');
    }
  }

  /// Set speed
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
    } catch (e) {
      debugPrint('[AudioHandler] Set speed error: $e');
    }
  }

  /// Dispose
  Future<void> dispose() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _player.dispose();
  }
}
