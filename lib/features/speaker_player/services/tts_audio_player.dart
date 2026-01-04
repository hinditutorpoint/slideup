import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/tts_request.dart';

class TtsAudioPlayer {
  static TtsAudioPlayer? _instance;
  static TtsAudioPlayer get instance => _instance ??= TtsAudioPlayer._();

  TtsAudioPlayer._() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();

  final _statusController = StreamController<TtsStatus>.broadcast();
  Stream<TtsStatus> get statusStream => _statusController.stream;

  TtsStatus _currentStatus = const TtsStatus();
  TtsStatus get currentStatus => _currentStatus;

  String? _currentTempFile;
  TtsRequest? _currentRequest;

  bool _isDisposed = false;

  // ✅ FIX: Track if completion was already called for current playback
  bool _completionCalled = false;
  String? _currentPlaybackId;

  // ✅ FIX: Stream subscriptions for proper cleanup
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  void _init() {
    if (_isDisposed) return;

    // Listen to player state
    _playerStateSubscription = _player.playerStateStream.listen(
      _handlePlayerState,
      onError: (error) {
        debugPrint('[TtsAudioPlayer] Player state stream error: $error');
        _handleError(error.toString());
      },
    );

    // Listen to position
    _positionSubscription = _player.positionStream.listen(
      _handlePositionUpdate,
      onError: (error) {
        debugPrint('[TtsAudioPlayer] Position stream error: $error');
      },
    );

    // Listen to duration
    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null) {
        _updateStatus(duration: duration);
      }
    });

    _initAudioSession();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    await session.setActive(true);
  }

  void _handlePlayerState(PlayerState state) {
    if (_isDisposed) return;

    debugPrint(
      '[TtsAudioPlayer] Player state: ${state.processingState}, playing: ${state.playing}',
    );

    TtsPlaybackState newState;

    if (state.processingState == ProcessingState.completed) {
      newState = TtsPlaybackState.completed;

      // ✅ FIX: Only call onCompleted once per playback
      _triggerCompletionOnce();
    } else if (state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering) {
      newState = TtsPlaybackState.loading;
    } else if (state.playing) {
      newState = TtsPlaybackState.playing;
    } else if (state.processingState == ProcessingState.idle) {
      // ✅ FIX: Distinguish between initial idle and post-completion idle
      if (_completionCalled) {
        // Already handled completion, stay at completed or go to idle
        newState = TtsPlaybackState.idle;
      } else if (_currentRequest != null) {
        // We have a request but not playing - paused
        newState = TtsPlaybackState.paused;
      } else {
        newState = TtsPlaybackState.idle;
      }
    } else {
      newState = TtsPlaybackState.paused;
    }

    _updateStatus(state: newState);

    // ✅ FIX: Safely call onStateChanged
    _safeCallStateChanged(newState);
  }

  void _handlePositionUpdate(Duration position) {
    if (_isDisposed) return;

    final duration = _player.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    _updateStatus(position: position, duration: duration, progress: progress);

    // ✅ FIX: Safely call onProgress
    _safeCallProgress(progress);
  }

  void _handleError(String error) {
    _updateStatus(state: TtsPlaybackState.error, error: error);
    _currentRequest?.onError?.call(error);
  }

  // ✅ FIX: Ensure completion is called only once per playback session
  void _triggerCompletionOnce() {
    if (_completionCalled) {
      debugPrint('[TtsAudioPlayer] Completion already called, skipping');
      return;
    }

    _completionCalled = true;
    debugPrint('[TtsAudioPlayer] Triggering onCompleted callback');

    // Store reference before potentially clearing
    final request = _currentRequest;

    // Call completion callback
    try {
      request?.onCompleted?.call();
    } catch (e) {
      debugPrint('[TtsAudioPlayer] onCompleted callback error: $e');
    }
  }

  // ✅ FIX: Safe callback methods with null checks
  void _safeCallStateChanged(TtsPlaybackState state) {
    try {
      _currentRequest?.onStateChanged?.call(state);
    } catch (e) {
      debugPrint('[TtsAudioPlayer] onStateChanged callback error: $e');
    }
  }

  void _safeCallProgress(double progress) {
    try {
      _currentRequest?.onProgress?.call(progress);
    } catch (e) {
      debugPrint('[TtsAudioPlayer] onProgress callback error: $e');
    }
  }

  void _updateStatus({
    String? requestId,
    TtsPlaybackState? state,
    double? progress,
    Duration? position,
    Duration? duration,
    String? error,
    String? text,
    String? audioFilePath,
  }) {
    if (_isDisposed) return;

    _currentStatus = _currentStatus.copyWith(
      requestId: requestId,
      state: state,
      progress: progress,
      position: position,
      duration: duration,
      error: error,
      text: text,
      audioFilePath: audioFilePath,
    );

    if (!_statusController.isClosed) {
      _statusController.add(_currentStatus);
    }
  }

  // ✅ FIX: Reset state for new playback
  void _prepareForNewPlayback(TtsRequest? request, String filePath) {
    _completionCalled = false;
    _currentPlaybackId = '${DateTime.now().millisecondsSinceEpoch}';
    _currentRequest = request;

    debugPrint('[TtsAudioPlayer] New playback: $_currentPlaybackId');
  }

  /// Play audio from bytes
  Future<bool> playFromBytes(Uint8List audioData, {TtsRequest? request}) async {
    if (_isDisposed) return false;

    try {
      // Save to temp file first
      final baseDir = await getExternalStorageDirectory();
      final tempDir = baseDir ?? await getTemporaryDirectory();
      final tempFile =
          '${tempDir.path}/tts_playback_${DateTime.now().millisecondsSinceEpoch}.wav';

      await File(tempFile).writeAsBytes(audioData);
      _currentTempFile = tempFile;

      // Notify audio generated
      request?.onAudioGenerated?.call(tempFile, audioData);

      // Play from file
      return await playFromFile(tempFile, request: request);
    } catch (e) {
      debugPrint('[TtsAudioPlayer] Play from bytes error: $e');
      _updateStatus(state: TtsPlaybackState.error, error: e.toString());
      request?.onError?.call(e.toString());
      return false;
    }
  }

  /// Play audio from file
  Future<bool> playFromFile(String filePath, {TtsRequest? request}) async {
    if (_isDisposed) return false;

    try {
      debugPrint('[TtsAudioPlayer] Playing file: $filePath');

      // ✅ FIX: Prepare for new playback (reset completion flag)
      _prepareForNewPlayback(request, filePath);

      _updateStatus(
        requestId: request?.id,
        state: TtsPlaybackState.loading,
        text: request?.text,
        audioFilePath: filePath,
        progress: 0,
        position: Duration.zero,
        error: null,
      );

      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $filePath');
      }

      // ✅ FIX: Stop any current playback first
      await _player.stop();

      // Set file and play
      await _player.setFilePath(filePath);

      // Set speed if specified
      if (request?.speed != null && request!.speed != 1.0) {
        await _player.setSpeed(request.speed);
      }

      await _player.play();

      debugPrint('[TtsAudioPlayer] Playback started successfully');
      return true;
    } catch (e) {
      debugPrint('[TtsAudioPlayer] Play file error: $e');
      _updateStatus(state: TtsPlaybackState.error, error: e.toString());
      request?.onError?.call(e.toString());
      return false;
    }
  }

  /// Play (resume)
  Future<void> play() async {
    if (_isDisposed) return;

    try {
      await _player.play();
    } catch (e) {
      debugPrint('[TtsAudioPlayer] Play error: $e');
    }
  }

  /// Pause
  Future<void> pause() async {
    if (_isDisposed) return;

    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[TtsAudioPlayer] Pause error: $e');
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    try {
      if (_player.playing == true) {
        await pause();
      } else {
        await play();
      }
    } catch (e) {
      debugPrint('[TtsAudioPlayer] Toggle play/pause error: $e');
    }
  }

  /// Force stop without async operations (for dispose/emergency)
  void forceStop() {
    try {
      debugPrint('[TtsAudioPlayer] Force stop called');

      // Mark completion as called to prevent callbacks
      _completionCalled = true;

      _player.stop();

      _currentStatus = const TtsStatus(state: TtsPlaybackState.idle);
      _currentRequest = null;
      _currentPlaybackId = null;

      if (!_statusController.isClosed) {
        _statusController.add(_currentStatus);
      }
    } catch (e) {
      debugPrint('[TtsAudioPlayer] Force stop error: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    if (_isDisposed) return;

    try {
      debugPrint('[TtsAudioPlayer] Stop called');

      // Mark as completed to prevent spurious callbacks
      _completionCalled = true;

      await _player.stop();

      _currentRequest = null;

      _updateStatus(
        state: TtsPlaybackState.idle,
        progress: 0,
        position: Duration.zero,
      );

      await _cleanupTempFile();
    } catch (e) {
      debugPrint('[TtsAudioPlayer] Stop error: $e');
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;

    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('[TtsAudioPlayer] Seek error: $e');
    }
  }

  /// Seek to percentage (0.0 - 1.0)
  Future<void> seekToPercentage(double percentage) async {
    final duration = _player.duration;
    if (duration != null) {
      final position = Duration(
        milliseconds: (duration.inMilliseconds * percentage.clamp(0.0, 1.0))
            .round(),
      );
      await seek(position);
    }
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    if (_isDisposed) return;

    try {
      await _player.setSpeed(speed.clamp(0.5, 3.0));
    } catch (e) {
      debugPrint('[TtsAudioPlayer] Set speed error: $e');
    }
  }

  /// Clean up temp file
  Future<void> _cleanupTempFile() async {
    if (_currentTempFile != null) {
      try {
        final file = File(_currentTempFile!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      _currentTempFile = null;
    }
  }

  /// Is currently playing
  bool get isPlaying => _player.playing;

  /// Current position
  Duration get position => _player.position;

  /// Total duration
  Duration? get duration => _player.duration;

  /// Dispose player and cleanup
  Future<void> dispose() async {
    if (_isDisposed) return;

    try {
      debugPrint('[TtsAudioPlayer] Disposing...');
      _isDisposed = true;

      // Cancel subscriptions
      await _playerStateSubscription?.cancel();
      await _positionSubscription?.cancel();
      await _durationSubscription?.cancel();

      await stop();
      await _player.dispose();

      if (!_statusController.isClosed) {
        await _statusController.close();
      }

      _instance = null;
      debugPrint('[TtsAudioPlayer] Disposed');
    } catch (e) {
      debugPrint('[TtsAudioPlayer] Dispose error: $e');
    }
  }
}
