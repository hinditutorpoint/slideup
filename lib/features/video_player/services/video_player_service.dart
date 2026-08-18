import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../../../navigation_service.dart';
import '../models/video_player_state.dart';
import '../models/player_settings.dart';
import 'settings_storage_service.dart';

class VideoPlayerService {
  mk.Player? _player;
  VideoController? _videoController;

  final _stateController = StreamController<VideoPlayerState>.broadcast();
  Stream<VideoPlayerState> get stateStream => _stateController.stream;

  VideoPlayerState _state = const VideoPlayerState();
  VideoPlayerState get state => _state;

  PlayerSettings _settings = const PlayerSettings();
  PlayerSettings get settings => _settings;

  List<mk.Media> _playlist = [];
  List<String> _playlistTitles = [];
  List<String> _playlistUrls = [];
  List<String?> _playlistFileIds = [];
  String? _currentFileId;

  Timer? _hideControlsTimer;
  Timer? _positionSaveTimer;
  Timer? _thumbnailDebounceTimer;
  Timer? _seekExecutionTimer;

  bool _isDisposed = false;
  bool _isDisposing = false;
  bool _isInitialized = false;

  final List<StreamSubscription> _subscriptions = [];

  VideoController get videoController {
    if (_videoController == null || _isDisposed) {
      throw Exception('VideoController not available');
    }
    return _videoController!;
  }

  mk.Player get player {
    if (_player == null || _isDisposed) {
      throw Exception('Player not available');
    }
    return _player!;
  }

  bool get isInitialized => _isInitialized;
  bool get isDisposed => _isDisposed;

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ VideoPlayerService already initialized');
      return;
    }

    if (_isDisposed) {
      debugPrint('❌ Cannot initialize disposed VideoPlayerService');
      return;
    }

    debugPrint('🎬 Initializing VideoPlayerService...');

    try {
      // Load settings
      try {
        _settings = await SettingsStorageService.loadPlayerSettings();
      } catch (e) {
        debugPrint('⚠️ Failed to load settings, using defaults: $e');
        _settings = const PlayerSettings();
      }

      // Enable wakelock
      try {
        await WakelockPlus.enable();
      } catch (e) {
        debugPrint('⚠️ Failed to enable wakelock: $e');
      }

      // Configure volume controller
      try {
        VolumeController.instance.showSystemUI = false;
      } catch (e) {
        debugPrint('⚠️ Failed to configure volume controller: $e');
      }

      // Create player
      _player = mk.Player(
        configuration: mk.PlayerConfiguration(
          title: 'Video Player',
          bufferSize: 32 * 1024 * 1024,
          ready: () => debugPrint('✅ Player ready'),
        ),
      );

      // Create video controller
      _videoController = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      // Setup listeners
      _setupListeners();

      // Get initial brightness
      try {
        final brightness = await ScreenBrightness().application;
        _updateState(_state.copyWith(brightness: brightness));
      } catch (e) {
        debugPrint('⚠️ Could not get brightness: $e');
      }

      _isInitialized = true;
      _updateState(_state.copyWith(isInitialized: true, isLoading: false));
      debugPrint('✅ VideoPlayerService initialized');
    } catch (e, stackTrace) {
      debugPrint('❌ VideoPlayerService initialization failed: $e');
      debugPrint('Stack: $stackTrace');
      _updateState(
        _state.copyWith(
          hasError: true,
          errorMessage: e.toString(),
          isLoading: false,
        ),
      );
      rethrow;
    }
  }

  void _setupListeners() {
    if (_player == null || _isDisposed) return;

    try {
      _subscriptions.add(
        _player!.stream.playing.listen((playing) {
          if (!_isDisposed) {
            _updateState(_state.copyWith(isPlaying: playing));
            if (playing) _scheduleHideControls();
          }
        }, onError: (e) => debugPrint('⚠️ Playing stream error: $e')),
      );

      _subscriptions.add(
        _player!.stream.position.listen((position) {
          if (!_isDisposed) {
            _updateState(_state.copyWith(position: position));
            _scheduleSavePosition();
          }
        }, onError: (e) => debugPrint('⚠️ Position stream error: $e')),
      );

      _subscriptions.add(
        _player!.stream.duration.listen((duration) {
          if (!_isDisposed) {
            _updateState(_state.copyWith(duration: duration));
          }
        }, onError: (e) => debugPrint('⚠️ Duration stream error: $e')),
      );

      _subscriptions.add(
        _player!.stream.buffering.listen((buffering) {
          if (!_isDisposed) {
            _updateState(_state.copyWith(isBuffering: buffering));
          }
        }, onError: (e) => debugPrint('⚠️ Buffering stream error: $e')),
      );

      _subscriptions.add(
        _player!.stream.buffer.listen((buffer) {
          if (!_isDisposed) {
            _updateState(_state.copyWith(bufferedPosition: buffer));
          }
        }, onError: (e) => debugPrint('⚠️ Buffer stream error: $e')),
      );

      _subscriptions.add(
        _player!.stream.volume.listen((volume) {
          if (!_isDisposed) {
            _updateState(_state.copyWith(volume: volume / 100));
          }
        }, onError: (e) => debugPrint('⚠️ Volume stream error: $e')),
      );

      _subscriptions.add(
        _player!.stream.rate.listen((rate) {
          if (!_isDisposed) {
            _updateState(_state.copyWith(speed: rate, is2xSpeed: rate >= 2.0));
          }
        }, onError: (e) => debugPrint('⚠️ Rate stream error: $e')),
      );

      _subscriptions.add(
        _player!.stream.tracks.listen((tracks) {
          if (!_isDisposed) {
            final realAudio = tracks.audio
                .where((t) => t.id != 'auto' && t.id != 'no')
                .length;
            final realVideo = tracks.video
                .where((t) => t.id != 'auto' && t.id != 'no')
                .length;
            final realSubtitle = tracks.subtitle
                .where((t) => t.id != 'auto' && t.id != 'no')
                .length;
            debugPrint(
              '📊 Tracks updated - Audio: ${tracks.audio.length} (real: $realAudio), '
              'Video: ${tracks.video.length} (real: $realVideo), '
              'Subtitle: ${tracks.subtitle.length} (real: $realSubtitle)',
            );
            _updateState(
              _state.copyWith(
                audioTracks: tracks.audio,
                subtitleTracks: tracks.subtitle,
                videoTracks: tracks.video,
              ),
            );
          }
        }, onError: (e) => debugPrint('⚠️ Tracks stream error: $e')),
      );

      _subscriptions.add(
        _player!.stream.track.listen((track) {
          if (!_isDisposed) {
            debugPrint(
              '🎯 Current track - Audio: ${track.audio.id}, '
              'Video: ${track.video.id}, Subtitle: ${track.subtitle.id}',
            );
            _updateState(
              _state.copyWith(
                currentAudioTrack: track.audio,
                currentSubtitleTrack: track.subtitle.id != 'no'
                    ? track.subtitle
                    : null,
                currentVideoTrack: track.video,
              ),
            );
          }
        }, onError: (e) => debugPrint('⚠️ Track stream error: $e')),
      );

      _subscriptions.add(
        _player!.stream.playlist.listen((playlist) {
          if (!_isDisposed) {
            final newIndex = playlist.index;
            final newTitle = _getTitleForIndex(newIndex);
            final newUrl = _getUrlForIndex(newIndex);
            final newFileId = _getFileIdForIndex(newIndex);

            // ✅ Debug logging
            debugPrint('═══════════════════════════════════════════');
            debugPrint('📺 PLAYLIST INDEX CHANGED');
            debugPrint('   Old Index: ${_state.currentIndex}');
            debugPrint('   New Index: $newIndex');
            debugPrint('   Old Title: ${_state.currentTitle}');
            debugPrint('   New Title: $newTitle');
            debugPrint('═══════════════════════════════════════════');

            // Update current file ID for position saving
            _currentFileId = newFileId;

            _updateState(
              _state.copyWith(
                currentIndex: newIndex,
                playlistLength: playlist.medias.length,
                currentTitle: newTitle, // ✅ ADD
                currentUrl: newUrl, // ✅ ADD
                currentFileId: newFileId, // ✅ ADD
              ),
            );
          }
        }, onError: (e) => debugPrint('⚠️ Playlist stream error: $e')),
      );

      _subscriptions.add(
        _player!.stream.completed.listen((completed) {
          if (completed && !_isDisposed) {
            debugPrint('✅ Playback completed');
            _onPlaybackCompleted();
          }
        }, onError: (e) => debugPrint('⚠️ Completed stream error: $e')),
      );

      _subscriptions.add(
        _player!.stream.error.listen((error) {
          if (!_isDisposed) {
            debugPrint('❌ Player error: $error');
            _updateState(_state.copyWith(hasError: true, errorMessage: error));
          }
        }, onError: (e) => debugPrint('⚠️ Error stream error: $e')),
      );
    } catch (e) {
      debugPrint('❌ Failed to setup listeners: $e');
    }
  }

  void _updateState(VideoPlayerState newState) {
    if (_isDisposed) return;

    try {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(_state);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update state: $e');
    }
  }

  void updateState(VideoPlayerState newState) {
    _updateState(newState);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ THUMBNAIL GENERATION (FFmpeg)
  // ═══════════════════════════════════════════════════════

  Future<Uint8List?> generateThumbnailAtPosition(Duration position) async {
    if (_isDisposed) return null;

    try {
      final currentUrl = _getUrlForIndex(_state.currentIndex);
      if (currentUrl.isEmpty) {
        debugPrint('⚠️ No current URL for thumbnail');
        return null;
      }

      if (position < Duration.zero || position > _state.duration) {
        debugPrint('⚠️ Invalid thumbnail position: $position');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/thumb_$timestamp.jpg';

      final timeInSeconds = position.inSeconds;
      final command =
          '-ss $timeInSeconds -i "$currentUrl" -vframes 1 -vf scale=320:-1 -q:v 2 "$outputPath" -y';

      debugPrint('🎬 Generating thumbnail at ${position.inSeconds}s');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();

          Future.delayed(const Duration(seconds: 2), () async {
            try {
              if (await file.exists()) {
                await file.delete();
              }
            } catch (e) {
              debugPrint('⚠️ Thumbnail cleanup error: $e');
            }
          });

          debugPrint('✅ Thumbnail generated successfully');
          return bytes;
        }
      } else {
        final output = await session.getOutput();
        debugPrint('❌ FFmpeg failed: $returnCode');
        if (output != null && output.isNotEmpty) {
          debugPrint('FFmpeg output: $output');
        }
      }

      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Thumbnail generation error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  void _debouncedThumbnailGeneration(Duration position) {
    _thumbnailDebounceTimer?.cancel();
    _thumbnailDebounceTimer = Timer(
      const Duration(milliseconds: 200),
      () async {
        if (_isDisposed || !_state.isSeekingHorizontally) return;

        final thumbnail = await generateThumbnailAtPosition(position);

        if (!_isDisposed && _state.isSeekingHorizontally) {
          _updateState(_state.copyWith(seekPreviewThumbnail: thumbnail));
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ YOUTUBE-STYLE INCREMENTAL SEEKING
  // ═══════════════════════════════════════════════════════

  void startHorizontalSeek() {
    if (_isDisposed) return;

    debugPrint('🎬 Starting horizontal seek');

    _updateState(
      _state.copyWith(
        isSeekingHorizontally: true,
        accumulatedSeekSeconds: 0,
        showSeekPreview: true,
        seekPreviewThumbnail: null,
        seekPreviewPosition: _state.position,
      ),
    );
  }

  void updateHorizontalSeek(double delta) {
    if (_isDisposed || !_state.isSeekingHorizontally) return;

    try {
      final seekIncrement = (delta / 10).round();

      if (seekIncrement == 0) return;

      final newAccumulated = _state.accumulatedSeekSeconds + seekIncrement;

      final currentPos = _state.position;
      final targetPos = currentPos + Duration(seconds: newAccumulated);
      final clampedPos = Duration(
        milliseconds: targetPos.inMilliseconds.clamp(
          0,
          _state.duration.inMilliseconds,
        ),
      );

      _updateState(
        _state.copyWith(
          accumulatedSeekSeconds: newAccumulated,
          seekPreviewPosition: clampedPos,
          seekDirection: newAccumulated > 0
              ? SeekDirection.forward
              : SeekDirection.backward,
          seekSeconds: newAccumulated.abs(),
        ),
      );

      debugPrint(
        '🎬 Seek accumulated: ${newAccumulated > 0 ? '+' : ''}${newAccumulated}s → ${clampedPos.inSeconds}s',
      );

      _debouncedThumbnailGeneration(clampedPos);
    } catch (e) {
      debugPrint('⚠️ Update horizontal seek error: $e');
    }
  }

  Future<void> endHorizontalSeek() async {
    if (_isDisposed || !_state.isSeekingHorizontally) return;

    try {
      final seekAmount = _state.accumulatedSeekSeconds;

      debugPrint(
        '🎬 Ending horizontal seek: ${seekAmount > 0 ? '+' : ''}${seekAmount}s',
      );

      if (seekAmount != 0) {
        final targetPosition = _state.seekPreviewPosition;

        _updateState(
          _state.copyWith(
            showSeekIndicator: true,
            seekDirection: seekAmount > 0
                ? SeekDirection.forward
                : SeekDirection.backward,
            seekSeconds: seekAmount.abs(),
          ),
        );

        await seek(targetPosition!);

        debugPrint(
          '✅ Seeked ${seekAmount > 0 ? '+' : ''}${seekAmount}s to ${targetPosition.inSeconds}s',
        );
      }

      _updateState(
        _state.copyWith(
          isSeekingHorizontally: false,
          accumulatedSeekSeconds: 0,
        ),
      );

      _hideSeekIndicatorsAfterDelay();
    } catch (e) {
      debugPrint('❌ End horizontal seek error: $e');

      _updateState(
        _state.copyWith(
          isSeekingHorizontally: false,
          accumulatedSeekSeconds: 0,
          showSeekPreview: false,
        ),
      );
    }
  }

  void hideSeekPreview() {
    if (_isDisposed) return;

    _thumbnailDebounceTimer?.cancel();
    _seekExecutionTimer?.cancel();

    _updateState(
      _state.copyWith(
        showSeekPreview: false,
        seekPreviewThumbnail: null,
        isSeekingHorizontally: false,
        accumulatedSeekSeconds: 0,
      ),
    );
  }

  void _hideSeekIndicatorsAfterDelay() {
    _seekExecutionTimer?.cancel();
    _seekExecutionTimer = Timer(const Duration(milliseconds: 1000), () {
      if (_isDisposed) return;

      _updateState(
        _state.copyWith(
          showSeekIndicator: false,
          showSeekPreview: false,
          seekPreviewThumbnail: null,
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MEDIA CONTROL
  // ═══════════════════════════════════════════════════════

  Future<void> openMedia({
    required String url,
    String? fileId,
    List<String>? playlist,
    int startIndex = 0,
    List<String>? titles, // ✅ ADD
    List<String?>? fileIds, // ✅ ADD
  }) async {
    if (_isDisposed || _player == null) {
      debugPrint('⚠️ Cannot open media: service disposed or player null');
      return;
    }

    _updateState(
      _state.copyWith(isLoading: true, isCompleted: false, clearError: true),
    );
    _currentFileId = fileId;

    // ✅ Store titles and file IDs for later lookup
    _playlistTitles = titles ?? [];
    _playlistUrls = playlist ?? [url];
    _playlistFileIds = fileIds ?? [fileId];

    try {
      if (playlist != null && playlist.isNotEmpty) {
        _playlist = playlist.map((u) => mk.Media(u)).toList();
        await _player!.open(
          mk.Playlist(_playlist, index: startIndex),
          play: _settings.autoPlay,
        );
      } else {
        _playlist = [mk.Media(url)];
        await _player!.open(mk.Media(url), play: _settings.autoPlay);
      }

      // Restore position if enabled
      if (_settings.rememberPosition && fileId != null) {
        try {
          var savedPosition =
              await SettingsStorageService.getPlaybackPosition(fileId);
          // Network URLs played via the launcher may have been saved under the
          // url.hashCode key (PlayerMedia.fromUrl) while recent-history items
          // pass the raw URL as fileId. Try both.
          if (savedPosition == null &&
              (fileId.startsWith('http://') || fileId.startsWith('https://'))) {
            savedPosition = await SettingsStorageService.getPlaybackPosition(
              fileId.hashCode.toString(),
            );
          }
          if (savedPosition != null && savedPosition.inSeconds > 5) {
            debugPrint(
              '🎬 Saved position found: ${savedPosition.inSeconds}s '
              '(duration=${_state.duration.inSeconds}s)',
            );
            if (await _confirmResumeFromLastPosition()) {
              await _resumeFromPosition(savedPosition);
            } else {
              await SettingsStorageService.clearPlaybackPosition(fileId);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to restore position: $e');
        }
      }

      // Add to recent files
      try {
        await SettingsStorageService.addRecentFile(url);
      } catch (e) {
        debugPrint('⚠️ Failed to add recent file: $e');
      }

      // ✅ Set initial title
      final initialTitle = _getTitleForIndex(startIndex);
      final initialUrl = _getUrlForIndex(startIndex);
      final initialFileId = _getFileIdForIndex(startIndex);

      debugPrint('📺 Initial media - Index: $startIndex, Title: $initialTitle');

      _updateState(
        _state.copyWith(
          isLoading: false,
          playlistLength: _playlist.length,
          currentIndex: startIndex,
          currentTitle: initialTitle, // ✅ ADD
          currentUrl: initialUrl, // ✅ ADD
          currentFileId: initialFileId, // ✅ ADD
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to open media: $e');
      debugPrint('Stack: $stackTrace');
      _updateState(
        _state.copyWith(
          isLoading: false,
          hasError: true,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  // ✅ ADD: Helper methods for getting media info by index
  String _getTitleForIndex(int index) {
    if (index >= 0 && index < _playlistTitles.length) {
      final title = _playlistTitles[index];
      return title.isNotEmpty ? title : 'Video ${index + 1}';
    }
    return 'Video ${index + 1}';
  }

  String _getUrlForIndex(int index) {
    if (index >= 0 && index < _playlistUrls.length) {
      return _playlistUrls[index];
    }
    return '';
  }

  String? _getFileIdForIndex(int index) {
    if (index >= 0 && index < _playlistFileIds.length) {
      return _playlistFileIds[index];
    }
    return null;
  }

  /// Restore a saved playback position. Seeks directly on the player so the
  /// position is not clamped to zero while the duration is still unknown.
  Future<void> _resumeFromPosition(Duration position) async {
    if (_isDisposed || _player == null) return;
    try {
      _updateState(_state.copyWith(isCompleted: false));
      // Network streams (and some slow local files) are still loading right
      // after open(), so a seek issued before the demuxer reports a duration
      // gets dropped by the engine. Wait until the stream is ready first.
      await _waitUntilStreamReady();
      await _player!.seek(position);
      _updateState(_state.copyWith(position: position));
      debugPrint('✅ Resumed at ${position.inSeconds}s');
    } catch (e) {
      debugPrint('⚠️ Failed to resume position: $e');
    }
  }

  /// Waits until the player reports a real (non-zero) duration so that seeks
  /// issued during resume are not dropped. Times out to avoid hanging.
  Future<void> _waitUntilStreamReady() async {
    if (_player == null || _isDisposed) return;
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline) && !_isDisposed) {
      try {
        final duration = _player!.state.duration;
        if (duration > Duration.zero) return;
      } catch (e) {
        // state may throw while platform is initializing; keep waiting
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }
    debugPrint('⚠️ Timed out waiting for stream to be ready');
  }

  /// When "Ask to Resume Last Position" is enabled, prompt the user before
  /// restoring a saved playback position. Otherwise resume automatically.
  Future<bool> _confirmResumeFromLastPosition() async {
    try {
      final ask = Hive.box('settings').get(
            'askResumeLastPosition',
            defaultValue: false,
          ) as bool;
      if (!ask) return true;

      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) return true;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Resume Playback'),
          content: const Text('Play from last saved position?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Start Over'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Resume'),
            ),
          ],
        ),
      );
      return result ?? true;
    } catch (e) {
      debugPrint('⚠️ Failed to ask resume position: $e');
      return true;
    }
  }

  Future<void> playOrPause() async {
    if (_isDisposed || _player == null) return;

    try {
      await _player!.playOrPause();
    } catch (e) {
      debugPrint('❌ playOrPause error: $e');
    }
  }

  Future<void> play() async {
    if (_isDisposed || _player == null) return;

    try {
      if (_state.isCompleted) {
        _updateState(_state.copyWith(isCompleted: false));
      }
      await _player!.play();
    } catch (e) {
      debugPrint('❌ play error: $e');
    }
  }

  Future<void> pause() async {
    if (_isDisposed || _player == null) return;

    try {
      await _player!.pause();
      _hideControlsTimer?.cancel();
    } catch (e) {
      debugPrint('❌ pause error: $e');
    }
  }

  Future<void> stop() async {
    debugPrint('🛑 stop() method called');

    if (_isDisposed || _player == null) {
      debugPrint(
        '⚠️ Cannot stop: disposed=$_isDisposed, player=${_player == null}',
      );
      return;
    }

    debugPrint('🛑 Stopping player...');

    try {
      // ✅ SAVE POSITION BEFORE STOPPING
      if (_settings.rememberPosition && _currentFileId != null) {
        try {
          await SettingsStorageService.savePlaybackPosition(
            _currentFileId!,
            _state.position,
          );
          debugPrint('✅ Position saved: ${_state.position.inSeconds}s');
        } catch (e) {
          debugPrint('⚠️ Failed to save position: $e');
        }
      }

      await _player!.stop();
      await _player!.pause();

      _updateState(
        _state.copyWith(isPlaying: false, isLoading: false, isBuffering: false),
      );

      debugPrint('✅ Player stopped successfully');
    } catch (e) {
      debugPrint('❌ Stop error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    if (_isDisposed || _player == null) return;

    try {
      _updateState(_state.copyWith(isCompleted: false));
      final clamped = Duration(
        milliseconds: position.inMilliseconds.clamp(
          0,
          _state.duration.inMilliseconds,
        ),
      );
      await _player!.seek(clamped);
    } catch (e) {
      debugPrint('❌ seek error: $e');
    }
  }

  Future<void> seekRelative(int seconds) async {
    if (_isDisposed) return;

    try {
      final newPosition = _state.position + Duration(seconds: seconds);
      await seek(newPosition);

      // ✅ Only show indicator for double-tap seeks
      if (!_state.isSeekingHorizontally) {
        _updateState(
          _state.copyWith(
            seekDirection: seconds > 0
                ? SeekDirection.forward
                : SeekDirection.backward,
            seekSeconds: seconds.abs(),
            showSeekIndicator: true,
          ),
        );

        Future.delayed(const Duration(milliseconds: 800), () {
          if (!_isDisposed && !_state.isSeekingHorizontally) {
            _updateState(
              _state.copyWith(
                showSeekIndicator: false,
                seekDirection: SeekDirection.none,
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('❌ seekRelative error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYLIST NAVIGATION
  // ═══════════════════════════════════════════════════════

  Future<void> playNext() async {
    if (_isDisposed || _player == null) return;

    try {
      if (_state.canPlayNext) {
        await _player!.next();
      }
    } catch (e) {
      debugPrint('❌ playNext error: $e');
    }
  }

  Future<void> playPrevious() async {
    if (_isDisposed || _player == null) return;

    try {
      if (_state.canPlayPrevious) {
        await _player!.previous();
      }
    } catch (e) {
      debugPrint('❌ playPrevious error: $e');
    }
  }

  Future<void> jumpToIndex(int index) async {
    if (_isDisposed || _player == null) return;

    try {
      if (index >= 0 && index < _playlist.length) {
        await _player!.jump(index);
      }
    } catch (e) {
      debugPrint('❌ jumpToIndex error: $e');
    }
  }

  void _onPlaybackCompleted() {
    try {
      _updateState(_state.copyWith(isCompleted: true, isPlaying: false));
      if (_settings.loopPlaylist && _state.canPlayNext) {
        playNext();
      } else if (_settings.loopPlaylist && !_state.canPlayNext) {
        jumpToIndex(0);
      }
    } catch (e) {
      debugPrint('❌ _onPlaybackCompleted error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VOLUME & BRIGHTNESS
  // ═══════════════════════════════════════════════════════

  Future<void> setVolume(double volume) async {
    if (_isDisposed || _player == null) return;

    try {
      final clamped = volume.clamp(0.0, 1.0);
      await _player!.setVolume(clamped * 100);
      _updateState(_state.copyWith(volume: clamped));
    } catch (e) {
      debugPrint('❌ setVolume error: $e');
    }
  }

  Future<void> adjustVolume(double delta) async {
    if (_isDisposed) return;

    try {
      final newVolume = (_state.volume + delta).clamp(0.0, 1.0);
      await setVolume(newVolume);

      _updateState(_state.copyWith(showVolumeIndicator: true));

      Future.delayed(const Duration(seconds: 1), () {
        if (!_isDisposed) {
          _updateState(_state.copyWith(showVolumeIndicator: false));
        }
      });
    } catch (e) {
      debugPrint('❌ adjustVolume error: $e');
    }
  }

  Future<void> toggleMute() async {
    if (_isDisposed || _player == null) return;

    try {
      if (_state.isMuted) {
        await setVolume(_state.volume > 0 ? _state.volume : 1.0);
        _updateState(_state.copyWith(isMuted: false));
      } else {
        await _player!.setVolume(0);
        _updateState(_state.copyWith(isMuted: true));
      }
    } catch (e) {
      debugPrint('❌ toggleMute error: $e');
    }
  }

  Future<void> setBrightness(double brightness) async {
    if (_isDisposed) return;

    try {
      final clamped = brightness.clamp(0.0, 1.0);
      await ScreenBrightness().setApplicationScreenBrightness(clamped);
      _updateState(_state.copyWith(brightness: clamped));
    } catch (e) {
      debugPrint('⚠️ Could not set brightness: $e');
    }
  }

  Future<void> adjustBrightness(double delta) async {
    if (_isDisposed) return;

    try {
      final newBrightness = (_state.brightness + delta).clamp(0.0, 1.0);
      await setBrightness(newBrightness);

      _updateState(_state.copyWith(showBrightnessIndicator: true));

      Future.delayed(const Duration(seconds: 1), () {
        if (!_isDisposed) {
          _updateState(_state.copyWith(showBrightnessIndicator: false));
        }
      });
    } catch (e) {
      debugPrint('❌ adjustBrightness error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SPEED CONTROL
  // ═══════════════════════════════════════════════════════

  Future<void> setSpeed(double speed) async {
    if (_isDisposed || _player == null) return;

    try {
      await _player!.setRate(speed);
      _updateState(_state.copyWith(speed: speed, is2xSpeed: speed >= 2.0));
    } catch (e) {
      debugPrint('❌ setSpeed error: $e');
    }
  }

  Future<void> enable2xSpeed() async {
    try {
      await setSpeed(2.0);
      _updateState(_state.copyWith(showSpeedIndicator: true));
    } catch (e) {
      debugPrint('❌ enable2xSpeed error: $e');
    }
  }

  Future<void> disable2xSpeed() async {
    try {
      await setSpeed(1.0);
      _updateState(_state.copyWith(showSpeedIndicator: false));
    } catch (e) {
      debugPrint('❌ disable2xSpeed error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VIDEO FIT & FLIP
  // ═══════════════════════════════════════════════════════

  void setVideoFit(VideoFit fit) {
    if (_isDisposed) return;

    try {
      _updateState(_state.copyWith(videoFit: fit));
      debugPrint('✅ Video fit set to: $fit');
    } catch (e) {
      debugPrint('❌ setVideoFit error: $e');
    }
  }

  void cycleVideoFit() {
    if (_isDisposed) return;

    try {
      final current = _state.videoFit;
      VideoFit next;

      switch (current) {
        case VideoFit.contain:
          next = VideoFit.cover;
          break;
        case VideoFit.cover:
          next = VideoFit.fill;
          break;
        case VideoFit.fill:
          next = VideoFit.fitWidth;
          break;
        case VideoFit.fitWidth:
          next = VideoFit.fitHeight;
          break;
        case VideoFit.fitHeight:
          next = VideoFit.contain;
          break;
      }

      setVideoFit(next);
    } catch (e) {
      debugPrint('❌ cycleVideoFit error: $e');
    }
  }

  void toggleFlipHorizontal() {
    if (_isDisposed) return;

    try {
      _updateState(
        _state.copyWith(isFlippedHorizontally: !_state.isFlippedHorizontally),
      );
    } catch (e) {
      debugPrint('❌ toggleFlipHorizontal error: $e');
    }
  }

  void toggleFlipVertical() {
    if (_isDisposed) return;

    try {
      _updateState(
        _state.copyWith(isFlippedVertically: !_state.isFlippedVertically),
      );
    } catch (e) {
      debugPrint('❌ toggleFlipVertical error: $e');
    }
  }

  void resetFlip() {
    if (_isDisposed) return;

    try {
      _updateState(
        _state.copyWith(
          isFlippedHorizontally: false,
          isFlippedVertically: false,
        ),
      );
    } catch (e) {
      debugPrint('❌ resetFlip error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TRACK SELECTION - WITH FULL ERROR HANDLING
  // ═══════════════════════════════════════════════════════

  Future<void> setAudioTrack(mk.AudioTrack track) async {
    if (_isDisposed || _player == null) {
      throw Exception('Player not available');
    }

    debugPrint('═══════════════════════════════════════════');
    debugPrint('🎵 Setting audio track:');
    debugPrint('   ID: ${track.id}');
    debugPrint('   Title: ${track.title}');
    debugPrint('   Language: ${track.language}');
    debugPrint('═══════════════════════════════════════════');

    try {
      await _player!.setAudioTrack(track);
      _updateState(_state.copyWith(currentAudioTrack: track));
      debugPrint('✅ Audio track set successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to set audio track: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  Future<void> setVideoTrack(mk.VideoTrack track) async {
    if (_isDisposed || _player == null) {
      throw Exception('Player not available');
    }

    debugPrint('═══════════════════════════════════════════');
    debugPrint('🎬 Setting video track:');
    debugPrint('   ID: ${track.id}');
    debugPrint('   W: ${track.w}');
    debugPrint('   H: ${track.h}');
    debugPrint('═══════════════════════════════════════════');

    try {
      await _player!.setVideoTrack(track);
      _updateState(_state.copyWith(currentVideoTrack: track));
      debugPrint('✅ Video track set successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to set video track: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  Future<void> setSubtitleTrack(mk.SubtitleTrack track) async {
    if (_isDisposed || _player == null) {
      throw Exception('Player not available');
    }

    debugPrint('═══════════════════════════════════════════');
    debugPrint('📝 Setting subtitle track:');
    debugPrint('   ID: ${track.id}');
    debugPrint('   Title: ${track.title}');
    debugPrint('   Language: ${track.language}');
    debugPrint('═══════════════════════════════════════════');

    try {
      await _player!.setSubtitleTrack(track);
      _updateState(_state.copyWith(currentSubtitleTrack: track));
      debugPrint('✅ Subtitle track set successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to set subtitle track: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  Future<void> disableSubtitles() async {
    if (_isDisposed || _player == null) {
      throw Exception('Player not available');
    }

    debugPrint('📝 Disabling subtitles...');

    try {
      await _player!.setSubtitleTrack(mk.SubtitleTrack.no());
      _updateState(_state.copyWith(clearCurrentSubtitleTrack: true));
      debugPrint('✅ Subtitles disabled');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to disable subtitles: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  Future<void> loadExternalSubtitle(String path) async {
    if (_isDisposed || _player == null) {
      throw Exception('Player not available');
    }

    debugPrint('📝 Loading external subtitle: $path');

    try {
      await _player!.setSubtitleTrack(mk.SubtitleTrack.uri(path));
      debugPrint('✅ External subtitle loaded');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to load external subtitle: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CONTROLS & UI
  // ═══════════════════════════════════════════════════════

  void showControls() {
    if (_isDisposed) return;

    try {
      _hideControlsTimer?.cancel();
      _updateState(_state.copyWith(showControls: true));
      _scheduleHideControls();
    } catch (e) {
      debugPrint('❌ showControls error: $e');
    }
  }

  void hideControls() {
    if (_isDisposed) return;

    try {
      _hideControlsTimer?.cancel();
      _updateState(_state.copyWith(showControls: false));
    } catch (e) {
      debugPrint('❌ hideControls error: $e');
    }
  }

  void toggleControls() {
    if (_isDisposed) return;

    try {
      if (_state.showControls) {
        hideControls();
      } else {
        showControls();
      }
    } catch (e) {
      debugPrint('❌ toggleControls error: $e');
    }
  }

  void _scheduleHideControls() {
    try {
      _hideControlsTimer?.cancel();
      if (_state.isPlaying && !_state.isLocked && !_isDisposed) {
        _hideControlsTimer = Timer(const Duration(seconds: 4), () {
          if (!_isDisposed && _state.isPlaying) {
            hideControls();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ _scheduleHideControls error: $e');
    }
  }

  void lockControls() {
    if (_isDisposed) return;

    try {
      _updateState(_state.copyWith(isLocked: true, showControls: false));
    } catch (e) {
      debugPrint('❌ lockControls error: $e');
    }
  }

  void unlockControls() {
    if (_isDisposed) return;

    try {
      _updateState(_state.copyWith(isLocked: false));
      showControls();
    } catch (e) {
      debugPrint('❌ unlockControls error: $e');
    }
  }

  void setControlsMode(ControlsMode mode) {
    if (_isDisposed) return;

    try {
      _updateState(_state.copyWith(controlsMode: mode));
    } catch (e) {
      debugPrint('❌ setControlsMode error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYER MODE
  // ═══════════════════════════════════════════════════════

  Future<void> enterFullscreen() async {
    if (_isDisposed) return;

    try {
      _updateState(_state.copyWith(mode: PlayerMode.fullscreen));
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      // Force a SINGLE landscape orientation. Requesting both landscape
      // orientations maps to Android's sensor-landscape mode, which does not
      // rotate on devices with auto-rotate disabled (common on OEM skins like
      // ColorOS). A single orientation forces SCREEN_ORIENTATION_LANDSCAPE.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
    } catch (e) {
      debugPrint('❌ enterFullscreen error: $e');
    }
  }

  Future<void> exitFullscreen() async {
    if (_isDisposed) return;

    try {
      _updateState(_state.copyWith(mode: PlayerMode.normal));
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      debugPrint('❌ exitFullscreen error: $e');
    }
  }

  Future<void> toggleFullscreen() async {
    try {
      if (_state.mode == PlayerMode.fullscreen) {
        await exitFullscreen();
      } else {
        await enterFullscreen();
      }
    } catch (e) {
      debugPrint('❌ toggleFullscreen error: $e');
    }
  }

  void enterPiPMode() {
    if (_isDisposed) return;

    try {
      _updateState(_state.copyWith(mode: PlayerMode.pip));
    } catch (e) {
      debugPrint('❌ enterPiPMode error: $e');
    }
  }

  void exitPiPMode() {
    if (_isDisposed) return;

    try {
      _updateState(_state.copyWith(mode: PlayerMode.normal));
    } catch (e) {
      debugPrint('❌ exitPiPMode error: $e');
    }
  }

  void enterBackgroundMode() {
    if (_isDisposed) return;

    try {
      _updateState(_state.copyWith(mode: PlayerMode.background));
    } catch (e) {
      debugPrint('❌ enterBackgroundMode error: $e');
    }
  }

  void exitBackgroundMode() {
    if (_isDisposed) return;

    try {
      _updateState(_state.copyWith(mode: PlayerMode.normal));
    } catch (e) {
      debugPrint('❌ exitBackgroundMode error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SCREENSHOT
  // ═══════════════════════════════════════════════════════

  Future<Uint8List?> takeScreenshot() async {
    if (_isDisposed || _player == null) return null;

    try {
      return await _player!.screenshot(format: 'image/png');
    } catch (e) {
      debugPrint('❌ Screenshot failed: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ POSITION SAVE
  // ═══════════════════════════════════════════════════════

  void _scheduleSavePosition() {
    if (!_settings.rememberPosition || _currentFileId == null || _isDisposed) {
      return;
    }

    try {
      _positionSaveTimer?.cancel();
      _positionSaveTimer = Timer(const Duration(seconds: 5), () {
        if (!_isDisposed && _currentFileId != null) {
          try {
            SettingsStorageService.savePlaybackPosition(
              _currentFileId!,
              _state.position,
            );
          } catch (e) {
            debugPrint('⚠️ Failed to save position: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('❌ _scheduleSavePosition error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SETTINGS
  // ═══════════════════════════════════════════════════════

  Future<void> updateSettings(PlayerSettings newSettings) async {
    if (_isDisposed) return;

    try {
      _settings = newSettings;
      await SettingsStorageService.savePlayerSettings(newSettings);
    } catch (e) {
      debugPrint('❌ updateSettings error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DISPOSE
  // ═══════════════════════════════════════════════════════

  Future<void> dispose() async {
    debugPrint('🧹 VideoPlayerService dispose() method called');
    debugPrint('🧹 Service state at dispose() entry:');
    debugPrint('   - isInitialized: $_isInitialized');
    debugPrint('   - isDisposed: $_isDisposed');

    // Prevent multiple dispose calls
    if (_isDisposed || _isDisposing) {
      debugPrint('⚠️ VideoPlayerService already disposed/disposing');
      return;
    }

    _isDisposing = true;
    debugPrint('🧹 VideoPlayerService dispose started...');
    debugPrint('🧹 Service state before disposal:');
    debugPrint('   - isInitialized: $_isInitialized');
    debugPrint('   - isPlaying: ${_player?.state.playing ?? false}');
    debugPrint('   - playlist length: ${_playlist.length}');
    debugPrint('   - isDisposed: $_isDisposed');

    // Step 1: Mark as disposed to prevent new operations
    _isDisposed = true;
    debugPrint('🧹 Marked as disposed');

    try {
      // Step 2: Cancel timers first
      debugPrint('🧹 Step 2: Cancelling timers...');
      _cancelTimers();

      // Step 3: Cancel all subscriptions
      debugPrint('🧹 Step 3: Cancelling subscriptions...');
      await _cancelSubscriptions();

      // Step 4: Save position before dispose
      debugPrint('🧹 Step 4: Saving position...');
      await _saveCurrentPosition();

      // Step 5: Stop playback (can be any thread)
      debugPrint('🧹 Step 5: Stopping playback...');
      await _stopPlayback();

      // Step 6: Close state controller
      debugPrint('🧹 Step 6: Closing state controller...');
      _closeStateController();

      // Step 7: ✅ CRITICAL - Dispose player on main thread
      debugPrint('🧹 Step 7: Disposing player on main thread...');
      await _disposePlayerOnMainThread();

      // Step 8: Cleanup system resources
      debugPrint('🧹 Step 8: Cleaning up system resources...');
      await _cleanupSystemResources();

      _isInitialized = false;
      _isDisposing = false;
      debugPrint('✅ VideoPlayerService disposed completely');
      debugPrint('🧹 Service state after disposal:');
      debugPrint('   - isInitialized: $_isInitialized');
      debugPrint('   - isDisposed: $_isDisposed');
    } catch (e) {
      debugPrint('❌ Error during disposal: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      // Ensure cleanup even if errors occur
      _isInitialized = false;
      _isDisposing = false;
      _isDisposed = true;
    }
  }

  void _cancelTimers() {
    try {
      _hideControlsTimer?.cancel();
      _hideControlsTimer = null;
      _positionSaveTimer?.cancel();
      _positionSaveTimer = null;
      _thumbnailDebounceTimer?.cancel();
      _thumbnailDebounceTimer = null;
      _seekExecutionTimer?.cancel();
      _seekExecutionTimer = null;
    } catch (e) {
      debugPrint('⚠️ Error cancelling timers: $e');
    }
  }

  Future<void> _cancelSubscriptions() async {
    try {
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();
      debugPrint('✅ Subscriptions cancelled');
    } catch (e) {
      debugPrint('⚠️ Error cancelling subscriptions: $e');
    }
  }

  Future<void> _saveCurrentPosition() async {
    if (_settings.rememberPosition && _currentFileId != null) {
      try {
        await SettingsStorageService.savePlaybackPosition(
          _currentFileId!,
          _state.position,
        );
        debugPrint('✅ Position saved');
      } catch (e) {
        debugPrint('⚠️ Could not save position: $e');
      }
    }
  }

  Future<void> _stopPlayback() async {
    try {
      if (_player != null) {
        debugPrint('🧹 Stopping playback...');
        await _player!.stop();
        debugPrint('✅ Playback stopped');
      } else {
        debugPrint('⚠️ Player is null, skipping stop');
      }
    } catch (e) {
      debugPrint('⚠️ Error stopping player: $e');
      debugPrint('⚠️ Stack trace: ${StackTrace.current}');
    }
  }

  void _closeStateController() {
    try {
      if (!_stateController.isClosed) {
        _stateController.close();
        debugPrint('✅ State controller closed');
      }
    } catch (e) {
      debugPrint('⚠️ Error closing state controller: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CRITICAL: Dispose on Main Thread
  // ═══════════════════════════════════════════════════════

  Future<void> _disposePlayerOnMainThread() async {
    final player = _player!;
    try {
      debugPrint('🧹 Disposing player on main thread...');

      // Wait for buffers to clear (stop already called in _stopPlayback)
      await Future.delayed(const Duration(milliseconds: 200));

      // ✅ Use Future.sync to ensure main isolate
      await Future.sync(() async {
        try {
          await player.dispose();
          debugPrint('✅ Player disposed');
        } catch (e) {
          debugPrint('⚠️ Player dispose error: $e');
          debugPrint('⚠️ Stack trace: ${StackTrace.current}');
        }
      });
    } catch (e) {
      debugPrint('❌ Error in _disposePlayerOnMainThread: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _cleanupSystemResources() async {
    debugPrint('🧹 Cleaning up system resources...');

    // Disable wakelock
    try {
      await WakelockPlus.disable();
      debugPrint('✅ Wakelock disabled');
    } catch (e) {
      debugPrint('⚠️ Error disabling wakelock: $e');
    }

    // Reset system UI
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      debugPrint('✅ System UI reset');
    } catch (e) {
      debugPrint('⚠️ Error resetting system UI: $e');
    }

    // Reset brightness
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
      debugPrint('✅ Brightness reset');
    } catch (e) {
      debugPrint('⚠️ Error resetting brightness: $e');
    }

    debugPrint('✅ System resources cleanup completed');
  }
}
