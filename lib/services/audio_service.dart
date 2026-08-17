import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

import '../models/media_file.dart';
import '../navigation_service.dart';

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  bool _initialized = false;

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    _player.loopModeStream.listen((_) {
      playbackState.add(_transformEvent(_player.playbackEvent));
    });

    _player.shuffleModeEnabledStream.listen((_) {
      playbackState.add(_transformEvent(_player.playbackEvent));
    });

    _player.sequenceStateStream.listen((sequenceState) {
      //if (sequenceState == null) return;

      final currentItem = sequenceState.currentSource?.tag as MediaItem?;
      if (currentItem != null) {
        mediaItem.add(currentItem);
      }

      final queueItems = sequenceState.effectiveSequence
          .map((source) => source.tag as MediaItem)
          .toList();

      queue.add(queueItems);
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed &&
          playbackState.value.repeatMode == AudioServiceRepeatMode.none) {
        stop();
      }
    });

    AudioService.notificationClicked.listen((clicked) {
      if (clicked) _handleNotificationClick();
    });
  }

  void _handleNotificationClick() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = rootNavigatorKey.currentState;
      if (navigator == null) return;

      final context = navigator.overlay?.context;
      final route = context != null ? ModalRoute.of(context) : null;

      if (route?.settings.name == '/audio-player') return;

      navigator.pushNamed('/audio-player');
    });
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setRepeatMode,
        MediaAction.setShuffleMode,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
      repeatMode: const {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode] ?? AudioServiceRepeatMode.none,
      shuffleMode: _player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }

  // ================= PLAYLIST =================

  Future<void> loadPlaylist(
    List<MediaFile> files, {
    int initialIndex = 0,
  }) async {
    try {
      final mediaItems = files.map(_createMediaItem).toList();
      final audioSources = files.map(_createAudioSource).toList();

      queue.add(mediaItems);

      await _player.setAudioSources(audioSources, initialIndex: initialIndex);
    } catch (e) {
      debugPrint('Error loading playlist: $e');
    }
  }

  MediaItem _createMediaItem(MediaFile file) {
    return MediaItem(
      id: file.id,
      title: file.name,
      artist: file.artist ?? 'Unknown Artist',
      album: file.album ?? 'Unknown Album',
      genre: file.genre,
      duration: file.duration != null
          ? Duration(milliseconds: file.duration!)
          : null,
      artUri: file.thumbnailPath != null ? Uri.file(file.thumbnailPath!) : null,
      extras: {
        'path': file.path,
        'displayPath': file.displayPath,
        'size': file.size,
        'dateModified': file.dateModified.millisecondsSinceEpoch,
        'dateAdded': file.dateAdded?.millisecondsSinceEpoch,
        'mimeType': file.mimeType,
        'isLocked': file.isLocked,
        'parentFolder': file.parentFolder,
      },
    );
  }

  AudioSource _createAudioSource(MediaFile file) {
    final uri = file.path.startsWith('http')
        ? Uri.parse(file.path)
        : Uri.file(file.path);

    return AudioSource.uri(uri, tag: _createMediaItem(file));
  }

  Future<void> addNext(MediaFile file) async {
    try {
      final source = _createAudioSource(file);
      final item = _createMediaItem(file);

      final currentIndex = _player.currentIndex ?? 0;
      final insertIndex = currentIndex + 1;

      final currentSources = List<AudioSource>.from(_player.sequence);

      currentSources.insert(insertIndex, source);

      queue.value.insert(insertIndex, item);
      queue.add(List<MediaItem>.from(queue.value));

      await _player.setAudioSources(
        currentSources,
        initialIndex: currentIndex,
        initialPosition: _player.position,
      );
    } catch (e) {
      debugPrint('Add next error: $e');
    }
  }

  Future<void> addToQueue(MediaFile file) async {
    try {
      final source = _createAudioSource(file);
      final item = _createMediaItem(file);

      final sources = List<AudioSource>.from(_player.sequence)..add(source);

      queue.value.add(item);
      queue.add(List<MediaItem>.from(queue.value));

      await _player.setAudioSources(
        sources,
        initialIndex: _player.currentIndex ?? 0,
        initialPosition: _player.position,
      );
    } catch (e) {
      debugPrint('Add queue error: $e');
    }
  }

  Future<void> removeFromQueue(int index) async {
    try {
      final sources = List<AudioSource>.from(_player.sequence);

      if (index < 0 || index >= sources.length) return;

      final currentIndex = _player.currentIndex ?? 0;

      sources.removeAt(index);
      queue.value.removeAt(index);
      queue.add(List<MediaItem>.from(queue.value));

      final newIndex = index < currentIndex ? currentIndex - 1 : currentIndex;

      await _player.setAudioSources(
        sources,
        initialIndex: newIndex.clamp(0, sources.length - 1),
        initialPosition: _player.position,
      );
    } catch (e) {
      debugPrint('Remove queue error: $e');
    }
  }

  // ================= CONTROLS =================

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      await super.stop();
      queue.add([]);
      mediaItem.add(null);
    } catch (e) {
      debugPrint('Stop error: $e');
    }
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
    playbackState.add(_transformEvent(_player.playbackEvent));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.all ||
        shuffleMode == AudioServiceShuffleMode.group) {
      await _player.shuffle();
      await _player.setShuffleModeEnabled(true);
    } else {
      await _player.setShuffleModeEnabled(false);
    }
    playbackState.add(_transformEvent(_player.playbackEvent));
  }

  // ================= DISPOSE =================

  Future<void> dispose() async {
    await _player.dispose();
  }

  // ================= STREAMS =================

  AudioPlayer get player => _player;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
}
