import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../models/epub_book.dart';
import '../../speaker_player/tts_controller.dart';
import '../../speaker_player/models/tts_request.dart';
import '../../speaker_player/services/language_detection_service.dart';
import '../../speaker_player/services/model_download_service.dart';
import '../../speaker_player/services/background_chapter_generator.dart';
import '../../speaker_player/services/audiobook_audio_handler.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AUDIOBOOK STATUS
// ═══════════════════════════════════════════════════════════════════════════

enum AudiobookState {
  idle,
  initializing,
  preparing,
  playing,
  paused,
  generating,
  loading,
  error,
  completed,
}

class ChapterStatus {
  final int index;
  final ChapterGenerationState state;
  final double progress;
  final String? error;
  final Duration? duration;
  final String? audioPath;

  const ChapterStatus({
    required this.index,
    this.state = ChapterGenerationState.idle,
    this.progress = 0.0,
    this.error,
    this.duration,
    this.audioPath,
  });

  ChapterStatus copyWith({
    ChapterGenerationState? state,
    double? progress,
    String? error,
    Duration? duration,
    String? audioPath,
  }) {
    return ChapterStatus(
      index: index,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      error: error,
      duration: duration ?? this.duration,
      audioPath: audioPath ?? this.audioPath,
    );
  }
}

enum ChapterGenerationState {
  idle,
  queued,
  generating,
  ready,
  playing,
  completed,
  error,
}

class ChapterGenerationInfo {
  final int chapterIndex;
  final String chapterTitle;
  final ChapterGenerationState state;
  final double progress;

  const ChapterGenerationInfo({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.state,
    this.progress = 0.0,
  });
}

class AudiobookStatus {
  final AudiobookState state;
  final int currentChapter;
  final int totalChapters;
  final String? currentChapterTitle;
  final String? currentText;
  final String? error;
  final double playbackProgress;
  final String? detectedLanguage;
  final ChapterStatus? currentChapterStatus;
  final ChapterStatus? nextChapterStatus;
  final List<int> queuedChapters;
  final List<int> readyChapters;
  final double playbackSpeed;
  final bool skipSilence;
  final Duration? sleepTimerRemaining;
  final bool isSleepTimerActive;
  final bool isTtsInitialized;
  final bool isTtsInitializing;
  final String? ttsModelName;
  final double generationProgress;
  final String? generationMessage;
  final List<ChapterGenerationInfo> generationQueue;
  final int readyChapterCount;

  const AudiobookStatus({
    this.state = AudiobookState.idle,
    this.currentChapter = 0,
    this.totalChapters = 0,
    this.currentChapterTitle,
    this.currentText,
    this.error,
    this.playbackProgress = 0.0,
    this.detectedLanguage,
    this.currentChapterStatus,
    this.nextChapterStatus,
    this.queuedChapters = const [],
    this.readyChapters = const [],
    this.playbackSpeed = 1.0,
    this.skipSilence = false,
    this.sleepTimerRemaining,
    this.isSleepTimerActive = false,
    this.isTtsInitialized = false,
    this.isTtsInitializing = false,
    this.ttsModelName,
    this.generationProgress = 0.0,
    this.generationMessage,
    this.generationQueue = const [],
    this.readyChapterCount = 0,
  });

  AudiobookStatus copyWith({
    AudiobookState? state,
    int? currentChapter,
    int? totalChapters,
    String? currentChapterTitle,
    String? currentText,
    String? error,
    double? playbackProgress,
    String? detectedLanguage,
    ChapterStatus? currentChapterStatus,
    ChapterStatus? nextChapterStatus,
    List<int>? queuedChapters,
    List<int>? readyChapters,
    double? playbackSpeed,
    bool? skipSilence,
    Duration? sleepTimerRemaining,
    bool? isSleepTimerActive,
    bool? isTtsInitialized,
    bool? isTtsInitializing,
    String? ttsModelName,
    double? generationProgress,
    String? generationMessage,
    List<ChapterGenerationInfo>? generationQueue,
    int? readyChapterCount,
  }) {
    return AudiobookStatus(
      state: state ?? this.state,
      currentChapter: currentChapter ?? this.currentChapter,
      totalChapters: totalChapters ?? this.totalChapters,
      currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
      currentText: currentText,
      error: error,
      playbackProgress: playbackProgress ?? this.playbackProgress,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      currentChapterStatus: currentChapterStatus ?? this.currentChapterStatus,
      nextChapterStatus: nextChapterStatus ?? this.nextChapterStatus,
      queuedChapters: queuedChapters ?? this.queuedChapters,
      readyChapters: readyChapters ?? this.readyChapters,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      skipSilence: skipSilence ?? this.skipSilence,
      sleepTimerRemaining: sleepTimerRemaining,
      isSleepTimerActive: isSleepTimerActive ?? this.isSleepTimerActive,
      isTtsInitialized: isTtsInitialized ?? this.isTtsInitialized,
      isTtsInitializing: isTtsInitializing ?? this.isTtsInitializing,
      ttsModelName: ttsModelName ?? this.ttsModelName,
      generationProgress: generationProgress ?? this.generationProgress,
      generationMessage: generationMessage,
      generationQueue: generationQueue ?? this.generationQueue,
      readyChapterCount: readyChapterCount ?? this.readyChapterCount,
    );
  }

  bool get isActive =>
      state == AudiobookState.playing ||
      state == AudiobookState.generating ||
      state == AudiobookState.loading ||
      state == AudiobookState.preparing;

  bool get isPaused => state == AudiobookState.paused;

  bool get isProcessing =>
      state == AudiobookState.generating ||
      state == AudiobookState.loading ||
      state == AudiobookState.preparing ||
      state == AudiobookState.initializing;

  bool get isCurrentChapterGenerating =>
      currentChapterStatus?.state == ChapterGenerationState.generating;

  bool get isNextChapterGenerating =>
      nextChapterStatus?.state == ChapterGenerationState.generating;

  bool get isNextChapterReady =>
      nextChapterStatus?.state == ChapterGenerationState.ready;

  String get userFacingMessage {
    if (isTtsInitializing) return 'Preparing text-to-speech engine...';

    switch (state) {
      case AudiobookState.idle:
        return 'Ready to start';
      case AudiobookState.initializing:
        return 'Initializing audiobook...';
      case AudiobookState.preparing:
        return 'Preparing chapter...';
      case AudiobookState.generating:
        if (generationMessage != null) return generationMessage!;
        if (generationProgress > 0) {
          return 'Generating audio: ${(generationProgress * 100).toInt()}%';
        }
        return 'Generating audio...';
      case AudiobookState.loading:
        return 'Loading audio...';
      case AudiobookState.playing:
        return 'Playing chapter ${currentChapter + 1}';
      case AudiobookState.paused:
        return 'Paused';
      case AudiobookState.error:
        return error ?? 'An error occurred';
      case AudiobookState.completed:
        return 'Audiobook completed';
    }
  }

  String get stateLabel {
    if (isTtsInitializing) return 'Initializing TTS...';

    switch (state) {
      case AudiobookState.idle:
        return 'Ready';
      case AudiobookState.initializing:
        return 'Initializing...';
      case AudiobookState.preparing:
        return 'Preparing...';
      case AudiobookState.playing:
        return 'Playing';
      case AudiobookState.paused:
        return 'Paused';
      case AudiobookState.generating:
        return 'Generating audio...';
      case AudiobookState.loading:
        return 'Loading...';
      case AudiobookState.error:
        return 'Error';
      case AudiobookState.completed:
        return 'Completed';
    }
  }

  String get detailedStatus {
    final parts = <String>[];

    if (isCurrentChapterGenerating) {
      parts.add('Generating Ch.${currentChapter + 1}');
    }
    if (isNextChapterGenerating) {
      parts.add('Pre-loading Ch.${currentChapter + 2}');
    }
    if (isNextChapterReady) {
      parts.add('Ch.${currentChapter + 2} ready');
    }
    if (generationQueue.isNotEmpty) {
      parts.add('${generationQueue.length} in queue');
    }
    if (readyChapterCount > 0) {
      parts.add('$readyChapterCount ready');
    }

    return parts.isEmpty ? stateLabel : parts.join(' • ');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AUDIOBOOK SETTINGS
// ═══════════════════════════════════════════════════════════════════════════

class AudiobookSettings {
  final double playbackSpeed;
  final bool skipSilence;
  final int preloadChaptersCount;
  final Duration delayBetweenChapters;
  final bool autoAdvance;
  final bool continueInBackground;
  final Duration? sleepTimer;

  const AudiobookSettings({
    this.playbackSpeed = 1.0,
    this.skipSilence = false,
    this.preloadChaptersCount = 2,
    this.delayBetweenChapters = const Duration(milliseconds: 800),
    this.autoAdvance = true,
    this.continueInBackground = true,
    this.sleepTimer,
  });

  AudiobookSettings copyWith({
    double? playbackSpeed,
    bool? skipSilence,
    int? preloadChaptersCount,
    Duration? delayBetweenChapters,
    bool? autoAdvance,
    bool? continueInBackground,
    Duration? sleepTimer,
  }) {
    return AudiobookSettings(
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      skipSilence: skipSilence ?? this.skipSilence,
      preloadChaptersCount: preloadChaptersCount ?? this.preloadChaptersCount,
      delayBetweenChapters: delayBetweenChapters ?? this.delayBetweenChapters,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      continueInBackground: continueInBackground ?? this.continueInBackground,
      sleepTimer: sleepTimer,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EPUB AUDIOBOOK CONTROLLER
// ═══════════════════════════════════════════════════════════════════════════

class EpubAudiobookController {
  final EpubBook book;
  final String bookId;
  final Future<String?> Function(int chapterIndex) getChapterText;
  final Future<String?> Function(int chapterIndex)? getTranslatedChapterText;
  final bool Function()? isTranslationMode;
  final void Function(int chapterIndex)? onChapterChanged;
  final void Function(String message)? onMessage;
  final void Function(AudiobookStatus status)? onStatusChanged;
  final ModelDownloadService? modelService;

  final _statusController = StreamController<AudiobookStatus>.broadcast();
  Stream<AudiobookStatus> get statusStream => _statusController.stream;

  AudiobookStatus _status = const AudiobookStatus();
  AudiobookStatus get status => _status;

  AudiobookSettings _settings;
  AudiobookSettings get settings => _settings;

  bool _isDisposed = false;
  bool _stopRequested = false;
  bool _pauseRequested = false;
  bool _skipToNextRequested = false;
  int _currentChapterIndex = 0;

  Completer<bool>? _playbackCompleter;
  //bool _isPlaybackActive = false;

  final Map<int, ChapterStatus> _chapterStatuses = {};
  final Set<int> _readyChapters = {};
  final List<int> _generationQueue = [];

  Timer? _statusDebounceTimer;
  AudiobookStatus? _pendingStatus;
  static const _statusDebounceMs = 50;

  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;
  Timer? _sleepTimerUpdateTimer;

  final LanguageDetectionService _langDetector =
      LanguageDetectionService.instance;
  WeakReference<BuildContext>? _contextRef;

  // Background generation
  final BackgroundChapterGenerator _bgGenerator =
      BackgroundChapterGenerator.instance;
  StreamSubscription<GenerationJob>? _bgJobSubscription;

  // ✅ One-by-one generation tracking
  int _nextChapterToQueue = 0;
  bool _backgroundGenerationActive = false;

  AudiobookAudioHandler? _audioHandler;
  bool _isAudioServiceInitialized = false;

  EpubAudiobookController({
    required this.book,
    required this.bookId,
    required this.getChapterText,
    this.getTranslatedChapterText,
    this.isTranslationMode,
    this.onChapterChanged,
    this.onMessage,
    this.onStatusChanged,
    this.modelService,
    AudiobookSettings? settings,
  }) : _settings = settings ?? const AudiobookSettings();

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  void _updateStatus(AudiobookStatus newStatus, {bool immediate = false}) {
    if (_isDisposed) return;

    _pendingStatus = newStatus;

    if (immediate) {
      _flushStatus();
      return;
    }

    _statusDebounceTimer?.cancel();
    _statusDebounceTimer = Timer(
      const Duration(milliseconds: _statusDebounceMs),
      _flushStatus,
    );
  }

  void _flushStatus() {
    if (_isDisposed || _pendingStatus == null) return;

    try {
      _status = _pendingStatus!;
      _pendingStatus = null;

      if (!_statusController.isClosed) {
        _statusController.add(_status);
      }
      onStatusChanged?.call(_status);
    } catch (e) {
      debugPrint('[EpubAudiobook] Status update error: $e');
    }
  }

  void _updateChapterStatus(int chapterIndex, ChapterStatus chapterStatus) {
    _chapterStatuses[chapterIndex] = chapterStatus;

    if (chapterStatus.state == ChapterGenerationState.ready ||
        chapterStatus.state == ChapterGenerationState.completed) {
      _readyChapters.add(chapterIndex);
    }

    _updateStatus(
      _status.copyWith(
        currentChapterStatus: chapterIndex == _currentChapterIndex
            ? chapterStatus
            : _status.currentChapterStatus,
        nextChapterStatus: chapterIndex == _currentChapterIndex + 1
            ? chapterStatus
            : _status.nextChapterStatus,
        readyChapters: _readyChapters.toList(),
        queuedChapters: _generationQueue.toList(),
        readyChapterCount: _readyChapters.length,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> initializeTts() async {
    if (_isDisposed) return;

    debugPrint('[EpubAudiobook] initializeTts() called');

    _updateStatus(
      _status.copyWith(
        isTtsInitializing: true,
        state: AudiobookState.initializing,
      ),
      immediate: true,
    );

    try {
      await Future.delayed(Duration.zero);

      if (!TtsController.instance.isInitialized) {
        if (modelService != null) {
          await TtsController.instance.init(modelService!);
        } else {
          final service = ModelDownloadService();
          await service.init();
          await TtsController.instance.init(service);
        }
      }

      if (TtsController.instance.isInitialized &&
          TtsController.instance.isSherpaInitialized &&
          TtsController.instance.currentModelPath != null) {
        _updateStatus(
          _status.copyWith(
            isTtsInitialized: true,
            isTtsInitializing: false,
            ttsModelName: TtsController.instance.currentModelName,
            state: AudiobookState.idle,
          ),
          immediate: true,
        );
        return;
      }

      final success = await TtsController.instance.initializeWithActiveModel();

      if (_isDisposed) return;

      _updateStatus(
        _status.copyWith(
          isTtsInitialized: success,
          isTtsInitializing: false,
          ttsModelName: TtsController.instance.currentModelName,
          state: success ? AudiobookState.idle : AudiobookState.error,
          error: success ? null : 'Failed to initialize TTS',
        ),
        immediate: true,
      );

      if (!success) {
        _safeMessage('TTS initialization failed. Please check your model.');
      }
    } catch (e, st) {
      debugPrint('[EpubAudiobook] TTS init error: $e\n$st');
      _updateStatus(
        _status.copyWith(
          isTtsInitialized: false,
          isTtsInitializing: false,
          state: AudiobookState.error,
          error: 'TTS initialization failed: $e',
        ),
        immediate: true,
      );
    }
  }

  Future<bool> _ensureTtsInitialized({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_status.isTtsInitialized) return true;

    if (TtsController.instance.isInitialized &&
        TtsController.instance.isSherpaInitialized &&
        TtsController.instance.currentModelPath != null) {
      _updateStatus(
        _status.copyWith(
          isTtsInitialized: true,
          isTtsInitializing: false,
          ttsModelName: TtsController.instance.currentModelName,
        ),
        immediate: true,
      );
      return true;
    }

    if (!_status.isTtsInitializing) {
      await initializeTts();
    }

    final endTime = DateTime.now().add(timeout);
    while (!_status.isTtsInitialized && DateTime.now().isBefore(endTime)) {
      if (_isDisposed || _stopRequested) return false;
      await Future.delayed(const Duration(milliseconds: 100));

      if (TtsController.instance.isInitialized &&
          TtsController.instance.isSherpaInitialized &&
          TtsController.instance.currentModelPath != null) {
        _updateStatus(
          _status.copyWith(
            isTtsInitialized: true,
            isTtsInitializing: false,
            ttsModelName: TtsController.instance.currentModelName,
          ),
          immediate: true,
        );
        return true;
      }
    }

    return _status.isTtsInitialized;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // START/STOP
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> start({
    int fromChapter = 0,
    required BuildContext context,
  }) async {
    if (_isDisposed) return;

    try {
      _stopRequested = false;
      _pauseRequested = false;
      _skipToNextRequested = false;
      _currentChapterIndex = fromChapter.clamp(0, book.chapterCount - 1);
      _contextRef = WeakReference(context);

      _updateStatus(
        AudiobookStatus(
          state: AudiobookState.initializing,
          currentChapter: _currentChapterIndex,
          totalChapters: book.chapterCount,
          currentChapterTitle: _getChapterTitle(_currentChapterIndex),
          isTtsInitializing: true,
          playbackSpeed: _settings.playbackSpeed,
          skipSilence: _settings.skipSilence,
        ),
        immediate: true,
      );

      final ttsReady = await _ensureTtsInitialized();

      if (!ttsReady) {
        _updateStatus(
          _status.copyWith(
            state: AudiobookState.error,
            error: 'TTS not available',
          ),
          immediate: true,
        );
        _safeMessage('TTS not available. Please download a TTS model.');
        return;
      }

      // ✅ INITIALIZE AUDIO SERVICE
      await _initializeAudioService();

      // Start background generation
      _startBackgroundGeneration();

      // Start playback loop
      if (!context.mounted) return;
      unawaited(_readLoop(context));
    } catch (e, stack) {
      debugPrint('[EpubAudiobook] Start error: $e\n$stack');
      _updateStatus(
        _status.copyWith(state: AudiobookState.error, error: e.toString()),
        immediate: true,
      );
      _safeMessage('Failed to start audiobook');
    }
  }

  /// ✅ Initialize Audio Service for background playback
  Future<void> _initializeAudioService() async {
    if (_isAudioServiceInitialized) return;

    try {
      debugPrint('[EpubAudiobook] Initializing audio service...');

      _audioHandler = await AudioService.init(
        builder: () => AudiobookAudioHandler(
          // ✅ These callbacks control the ACTUAL player via TtsController
          onPlay: () async {
            debugPrint('[AudioService] → Play');
            resume(); // This calls TtsController.play()
          },
          onPause: () async {
            debugPrint('[AudioService] → Pause');
            pause(); // This calls TtsController.pause()
          },
          onStop: () async {
            debugPrint('[AudioService] → Stop');
            await stop();
          },
          onSkipToNext: () async {
            debugPrint('[AudioService] → Next');
            await _handleSkipToNext();
          },
          onSkipToPrevious: () async {
            debugPrint('[AudioService] → Previous');
            await _handleSkipToPrevious();
          },
          onSeek: (position) async {
            debugPrint('[AudioService] → Seek: $position');
            await TtsController.instance.seek(position);
          },
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.slideup.mediaplayer',
          androidNotificationChannelName: 'Audiobook Player',
          androidShowNotificationBadge: true,
          androidNotificationIcon: 'drawable/ic_notification',
          androidStopForegroundOnPause: false,
        ),
      );

      _isAudioServiceInitialized = true;

      // ✅ Register handler with TtsController so it syncs state
      TtsController.instance.registerAudioHandler(_audioHandler!);

      await _updateMediaInfo();
      debugPrint('[EpubAudiobook] ✅ Audio service initialized');
    } catch (e, stack) {
      debugPrint('[EpubAudiobook] Audio service error: $e\n$stack');
      _isAudioServiceInitialized = false;
    }
  }

  Future<void> _handleSkipToNext() async {
    try {
      debugPrint('[AudioService] Skip to next');
      _skipToNextRequested = true;
      _pauseRequested = false;
      _completePlaybackSafe(false);

      TtsController.instance.forceStop();

      if (_currentChapterIndex < book.chapterCount - 1) {
        _currentChapterIndex++;
        _safeChapterChanged(_currentChapterIndex);

        _updateStatus(
          _status.copyWith(
            currentChapter: _currentChapterIndex,
            currentChapterTitle: _getChapterTitle(_currentChapterIndex),
            playbackProgress: 0.0,
            state: AudiobookState.preparing,
          ),
          immediate: true,
        );

        await _updateMediaInfo();
      }
    } catch (e) {
      debugPrint('[AudioService] Skip next error: $e');
    }
  }

  Future<void> _handleSkipToPrevious() async {
    try {
      debugPrint('[AudioService] Skip to previous');
      _skipToNextRequested = true;
      _pauseRequested = false;
      _completePlaybackSafe(false);

      TtsController.instance.forceStop();

      if (_currentChapterIndex > 0) {
        _currentChapterIndex--;
        _safeChapterChanged(_currentChapterIndex);

        _updateStatus(
          _status.copyWith(
            currentChapter: _currentChapterIndex,
            currentChapterTitle: _getChapterTitle(_currentChapterIndex),
            playbackProgress: 0.0,
            state: AudiobookState.preparing,
          ),
          immediate: true,
        );

        await _updateMediaInfo();
      }
    } catch (e) {
      debugPrint('[AudioService] Skip previous error: $e');
    }
  }

  /// ✅ Update notification media info
  Future<void> _updateMediaInfo() async {
    if (_audioHandler == null) return;

    final title =
        _getChapterTitle(_currentChapterIndex) ??
        'Chapter ${_currentChapterIndex + 1}';

    await _audioHandler!.updateMediaInfo(
      title: title,
      album: book.title,
      artist: book.author,
    );
  }

  Future<void> stop([BuildContext? context]) async {
    try {
      _stopRequested = true;
      _pauseRequested = false;
      //_isPlaybackActive = false;

      _completePlaybackSafe(false);
      _cancelSleepTimer();

      TtsController.instance.forceStop(); // ✅ Stops actual player

      if (_audioHandler != null) {
        _audioHandler!.setIdle();
        await _audioHandler!.stop(); // ✅ Removes notification
      }

      _stopBackgroundGeneration();

      _updateStatus(
        _status.copyWith(state: AudiobookState.idle, playbackProgress: 0.0),
        immediate: true,
      );
    } catch (e) {
      debugPrint('[EpubAudiobook] Next error: $e');
    }
  }

  void forceStop() {
    try {
      _stopRequested = true;
      _pauseRequested = false;
      //_isPlaybackActive = false;
      _completePlaybackSafe(false);
      _cancelSleepTimer();
      TtsController.instance.forceStop();

      // ✅ Stop background generation
      _stopBackgroundGeneration();

      _status = const AudiobookStatus();
    } catch (e) {
      debugPrint('[EpubAudiobook] Force stop error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKGROUND GENERATION (ONE-BY-ONE)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startBackgroundGeneration() async {
    if (_backgroundGenerationActive) {
      debugPrint('[EpubAudiobook] Background generation already active');
      return;
    }

    try {
      _backgroundGenerationActive = true;
      debugPrint(
        '[EpubAudiobook] 🔄 Starting ONE-BY-ONE background generation...',
      );

      // Listen to background generation updates
      _bgJobSubscription?.cancel();
      _bgJobSubscription = _bgGenerator.jobStatusStream.listen((job) {
        if (job.bookId == bookId && !_isDisposed) {
          _updateChapterStatus(
            job.chapterIndex,
            ChapterStatus(
              index: job.chapterIndex,
              state: _mapJobStatusToChapterState(job.status),
              progress: job.progress,
              error: job.error,
              audioPath: job.audioPath,
            ),
          );

          // ✅ When a job completes, queue the next chapter
          if (job.status == JobStatus.completed ||
              job.status == JobStatus.skipped ||
              job.status == JobStatus.failed) {
            debugPrint(
              '[EpubAudiobook] Chapter ${job.chapterIndex} finished, queuing next...',
            );
            _queueNextChapter();
          }
        }
      });

      // ✅ Start with the chapter after current
      _nextChapterToQueue = _currentChapterIndex + 1;

      // ✅ Queue the first chapter
      _queueNextChapter();
    } catch (e) {
      debugPrint('[EpubAudiobook] Background generation error: $e');
      _backgroundGenerationActive = false;
    }
  }

  /// ✅ Queue a single chapter for generation
  Future<void> _queueNextChapter() async {
    if (_isDisposed || !_backgroundGenerationActive) return;

    try {
      // Check if we've reached the end
      if (_nextChapterToQueue >= book.chapterCount) {
        debugPrint('[EpubAudiobook] ✓ All chapters queued for generation');
        return;
      }

      final chapterIndex = _nextChapterToQueue;

      // Check if already cached
      final isCached = await TtsController.instance.isPageCached(
        bookId: bookId,
        pageNumber: chapterIndex,
      );

      if (isCached) {
        debugPrint(
          '[EpubAudiobook] Chapter $chapterIndex already cached, skipping',
        );
        _nextChapterToQueue++;

        // Mark as ready in status
        _updateChapterStatus(
          chapterIndex,
          ChapterStatus(
            index: chapterIndex,
            state: ChapterGenerationState.ready,
            progress: 1.0,
          ),
        );

        // Immediately queue next
        _queueNextChapter();
        return;
      }

      // Check if already in queue or generating
      final existingJob = _bgGenerator.allJobs
          .where((j) => j.bookId == bookId && j.chapterIndex == chapterIndex)
          .firstOrNull;

      if (existingJob != null &&
          (existingJob.status == JobStatus.queued ||
              existingJob.status == JobStatus.generating)) {
        debugPrint(
          '[EpubAudiobook] Chapter $chapterIndex already queued/generating',
        );
        _nextChapterToQueue++;
        return;
      }

      // Get chapter text
      final text = await _getChapterTextSafe(chapterIndex);
      if (text == null || text.isEmpty) {
        debugPrint(
          '[EpubAudiobook] Chapter $chapterIndex has no text, skipping',
        );
        _nextChapterToQueue++;
        _queueNextChapter();
        return;
      }

      final title =
          _getChapterTitle(chapterIndex) ?? 'Chapter ${chapterIndex + 1}';

      // ✅ Prepend title to text
      final fullText = "$title.\n\n$text";

      // ✅ Queue single chapter
      debugPrint('[EpubAudiobook] 📝 Queuing Chapter $chapterIndex: $title');

      _bgGenerator.addJob(
        bookId: bookId,
        chapterIndex: chapterIndex,
        chapterTitle: title,
        text: fullText,
        isSilent: false, // Show notification for each chapter
      );

      _nextChapterToQueue++;
    } catch (e) {
      debugPrint(
        '[EpubAudiobook] Error queuing chapter $_nextChapterToQueue: $e',
      );
      _nextChapterToQueue++;
      _queueNextChapter(); // Try next chapter
    }
  }

  /// ✅ Stop background generation
  void _stopBackgroundGeneration() {
    _backgroundGenerationActive = false;
    _bgJobSubscription?.cancel();
    _bgJobSubscription = null;
    debugPrint('[EpubAudiobook] Background generation stopped');
  }

  ChapterGenerationState _mapJobStatusToChapterState(JobStatus status) {
    switch (status) {
      case JobStatus.queued:
        return ChapterGenerationState.queued;
      case JobStatus.generating:
        return ChapterGenerationState.generating;
      case JobStatus.completed:
      case JobStatus.skipped:
        return ChapterGenerationState.ready;
      case JobStatus.failed:
        return ChapterGenerationState.error;
      case JobStatus.cancelled:
        return ChapterGenerationState.idle;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN READING LOOP
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _readLoop(BuildContext? context) async {
    debugPrint('[EpubAudiobook] Read loop started');

    int consecutiveFailures = 0;
    const maxConsecutiveFailures = 3;

    while (!_stopRequested && !_isDisposed) {
      try {
        if (_currentChapterIndex >= book.chapterCount) {
          _updateStatus(
            _status.copyWith(
              state: AudiobookState.completed,
              currentChapter: book.chapterCount - 1,
            ),
            immediate: true,
          );
          _safeMessage('Audiobook completed!');
          break;
        }

        final chapterToPlay = _currentChapterIndex;
        debugPrint('[EpubAudiobook] Processing chapter $chapterToPlay');

        // Handle pause
        while (_pauseRequested && !_stopRequested && !_isDisposed) {
          await Future.delayed(const Duration(milliseconds: 100));
          _updateStatus(_status.copyWith(state: AudiobookState.paused));
          if (_stopRequested || _isDisposed) break;
        }

        if (_stopRequested || _isDisposed) break;

        _updateStatus(
          _status.copyWith(
            state: AudiobookState.preparing,
            currentChapter: chapterToPlay,
            currentChapterTitle: _getChapterTitle(chapterToPlay),
          ),
          immediate: true,
        );

        // Get text
        String? text;
        String? lang;

        if (isTranslationMode?.call() == true &&
            getTranslatedChapterText != null) {
          text = await getTranslatedChapterText!(chapterToPlay);
          lang = 'en';
        } else {
          text = await getChapterText(chapterToPlay);
          lang = _langDetector.detectCode(text ?? '');
        }

        if (text == null || text.isEmpty) {
          debugPrint('[EpubAudiobook] Chapter $chapterToPlay text is empty');
          _currentChapterIndex++;
          continue;
        }

        // ✅ Prepend Title
        final title = _getChapterTitle(chapterToPlay);
        if (title != null && title.trim().isNotEmpty) {
          text = "$title.\n\n$text";
        }
        bool success = false;
        // ✅ Get context or use cached reference
        if (!context!.mounted) {
          success = await _generateAndPlayChapter(
            text: text,
            language: lang,
            context: _contextRef?.target,
            chapterIndex: chapterToPlay,
          );
        } else {
          success = await _generateAndPlayChapter(
            text: text,
            language: lang,
            context: context,
            chapterIndex: chapterToPlay,
          );
        }

        if (_stopRequested || _isDisposed) break;

        if (success) {
          consecutiveFailures = 0;
          _skipToNextRequested = false;

          await _updateMediaInfo();

          if (_settings.autoAdvance) {
            _currentChapterIndex++;
            _safeChapterChanged(_currentChapterIndex);
            if (_settings.delayBetweenChapters > Duration.zero) {
              await Future.delayed(_settings.delayBetweenChapters);
            }
          } else {
            _updateStatus(
              _status.copyWith(state: AudiobookState.paused),
              immediate: true,
            );
            _pauseRequested = true;
          }
        } else {
          if (_skipToNextRequested) {
            debugPrint(
              '[EpubAudiobook] Manual skip detected, ignoring failure.',
            );
            _skipToNextRequested = false;
            consecutiveFailures = 0;
            continue;
          }

          consecutiveFailures++;
          debugPrint(
            '[EpubAudiobook] Playback failed for Ch.$chapterToPlay (Failures: $consecutiveFailures)',
          );

          if (consecutiveFailures >= maxConsecutiveFailures) {
            _updateStatus(
              _status.copyWith(
                state: AudiobookState.error,
                error: 'Playback failed multiple times. Stopping.',
              ),
              immediate: true,
            );
            _safeMessage('Playback stopped due to errors.');
            break;
          }

          _updateStatus(
            _status.copyWith(
              state: AudiobookState.paused,
              error: 'Chapter playback failed',
            ),
            immediate: true,
          );
          _pauseRequested = true;
        }
      } catch (e, stack) {
        debugPrint('[EpubAudiobook] Read loop error: $e\n$stack');
        _updateStatus(
          _status.copyWith(state: AudiobookState.error, error: e.toString()),
          immediate: true,
        );
        break;
      }
    }

    debugPrint('[EpubAudiobook] Read loop ended');
    _stopRequested = false;
    //_isPlaybackActive = false;
  }

  Future<bool> _generateAndPlayChapter({
    required String text,
    required String? language,
    required BuildContext? context,
    required int chapterIndex,
  }) async {
    if (_isDisposed || _stopRequested || text.isEmpty) return false;

    _playbackCompleter = Completer<bool>();
    //_isPlaybackActive = true;

    try {
      debugPrint('[EpubAudiobook] ===== CHAPTER $chapterIndex: START =====');

      // 1. Check if cached
      final isCached = await TtsController.instance.isPageCached(
        bookId: bookId,
        pageNumber: chapterIndex,
      );

      if (isCached) {
        debugPrint('[EpubAudiobook] Chapter $chapterIndex: Using cache');
        _updateStatus(
          _status.copyWith(
            state: AudiobookState.loading,
            currentChapter: chapterIndex,
            generationProgress: 1.0,
            generationMessage: 'Loading cached audio...',
          ),
          immediate: true,
        );
      } else {
        // 2. CHECK BACKGROUND GENERATOR
        final bgJob = _bgGenerator.allJobs
            .where((j) => j.bookId == bookId && j.chapterIndex == chapterIndex)
            .firstOrNull;

        if (bgJob != null &&
            (bgJob.status == JobStatus.queued ||
                bgJob.status == JobStatus.generating)) {
          debugPrint(
            '[EpubAudiobook] Chapter $chapterIndex is in background queue. Waiting...',
          );

          _updateStatus(
            _status.copyWith(
              state: AudiobookState.generating,
              currentChapter: chapterIndex,
              generationProgress: bgJob.progress,
              generationMessage: 'Waiting for background generation...',
            ),
            immediate: true,
          );

          // ✅ Wait for completion with timeout
          final startTime = DateTime.now();
          while (bgJob.status != JobStatus.completed &&
              bgJob.status != JobStatus.skipped &&
              bgJob.status != JobStatus.failed &&
              bgJob.status != JobStatus.cancelled) {
            if (_stopRequested || _isDisposed) {
              _completePlaybackSafe(false);
              return false;
            }

            // Update progress
            _updateStatus(
              _status.copyWith(
                generationProgress: bgJob.progress,
                generationMessage:
                    'Generating: ${(bgJob.progress * 100).toInt()}%',
              ),
            );

            await Future.delayed(const Duration(milliseconds: 200));

            // Timeout after 10 minutes
            if (DateTime.now().difference(startTime) >
                const Duration(minutes: 10)) {
              debugPrint(
                '[EpubAudiobook] Background generation timeout for Ch $chapterIndex',
              );
              _completePlaybackSafe(false);
              return false;
            }
          }

          if (bgJob.status == JobStatus.failed ||
              bgJob.status == JobStatus.cancelled) {
            debugPrint(
              '[EpubAudiobook] Background generation failed for Ch $chapterIndex',
            );
            _completePlaybackSafe(false);
            return false;
          }

          debugPrint(
            '[EpubAudiobook] Background generation completed for Ch $chapterIndex',
          );
        } else {
          // 3. Generate Foreground (if not in bg queue)
          debugPrint(
            '[EpubAudiobook] Chapter $chapterIndex: Generating (Foreground)...',
          );

          _updateStatus(
            _status.copyWith(
              state: AudiobookState.generating,
              currentChapter: chapterIndex,
              generationProgress: 0.0,
              generationMessage: 'Generating audio...',
            ),
            immediate: true,
          );

          final audioPath = await TtsController.instance.generateAudioSimple(
            text: text,
            bookId: bookId,
            pageNumber: chapterIndex,
            speed: _settings.playbackSpeed,
            onProgress: (progress) {
              if (!_isDisposed && !_stopRequested) {
                _updateStatus(
                  _status.copyWith(
                    state: AudiobookState.generating,
                    currentChapter: chapterIndex,
                    generationProgress: progress,
                    generationMessage:
                        'Generating: ${(progress * 100).toInt()}%',
                  ),
                );
              }
            },
          );

          if (audioPath == null) {
            debugPrint(
              '[EpubAudiobook] Chapter $chapterIndex: Generation FAILED',
            );
            _updateStatus(
              _status.copyWith(
                state: AudiobookState.error,
                error: 'Generation failed',
              ),
              immediate: true,
            );
            _completePlaybackSafe(false);
            return false;
          }

          debugPrint(
            '[EpubAudiobook] Chapter $chapterIndex: Generation SUCCESS',
          );
        }
      }

      if (_stopRequested || _isDisposed) {
        _completePlaybackSafe(false);
        return false;
      }

      // Get cached entry for playback
      final entries = await TtsController.instance.getGeneratedAudioForBook(
        bookId,
      );
      final entry = entries
          .where((e) => e.pageNumber == chapterIndex)
          .firstOrNull;

      if (entry == null) {
        debugPrint('[EpubAudiobook] Chapter $chapterIndex: Entry not found');
        _completePlaybackSafe(false);
        return false;
      }

      debugPrint('[EpubAudiobook] Chapter $chapterIndex: Starting playback');

      _updateStatus(
        _status.copyWith(
          state: AudiobookState.playing,
          currentChapter: chapterIndex,
          playbackProgress: 0.0,
          generationProgress: 0.0,
          generationMessage: null,
        ),
        immediate: true,
      );

      final playContext = context ?? _contextRef?.target;

      if (playContext == null || !playContext.mounted) {
        debugPrint(
          '[EpubAudiobook] No valid context, attempting background playback',
        );
        // Try to play without UI context (background mode)
        await _playAudioEntryBackground(entry);
      } else {
        await _playAudioEntry(entry, playContext);
      }

      debugPrint(
        '[EpubAudiobook] Chapter $chapterIndex: Waiting for playback completion...',
      );

      final success = await _playbackCompleter!.future.timeout(
        Duration(minutes: 30),
        onTimeout: () {
          debugPrint('[EpubAudiobook] Chapter $chapterIndex: TIMEOUT');
          return false;
        },
      );

      debugPrint(
        '[EpubAudiobook] ===== CHAPTER $chapterIndex: END (success=$success) =====',
      );
      return success;
    } catch (e, stack) {
      debugPrint('[EpubAudiobook] Chapter $chapterIndex: ERROR - $e\n$stack');
      _completePlaybackSafe(false);
      return false;
    } finally {
      //_isPlaybackActive = false;
    }
  }

  // ✅ New method for background playback
  Future<void> _playAudioEntryBackground(dynamic entry) async {
    try {
      if (entry.filePath == null) {
        _completePlaybackSafe(false);
        return;
      }

      // ✅ Always use background-safe method
      final success = await TtsController.instance.playCachedEntryBackground(
        entry: entry,
        showUi: false,
        onProgress: (progress) {
          if (!_isDisposed && !_stopRequested) {
            _updateStatus(_status.copyWith(playbackProgress: progress));
          }
        },
        onStateChanged: (state) {
          if (_isDisposed || _stopRequested) return;

          switch (state) {
            case TtsPlaybackState.playing:
              _updateStatus(_status.copyWith(state: AudiobookState.playing));
              break;
            case TtsPlaybackState.paused:
              if (_pauseRequested) {
                _updateStatus(_status.copyWith(state: AudiobookState.paused));
              }
              break;
            case TtsPlaybackState.loading:
            case TtsPlaybackState.generating:
              _updateStatus(_status.copyWith(state: AudiobookState.generating));
              break;
            default:
              break;
          }
        },
        onCompleted: () {
          _completePlaybackSafe(true);
        },
        onError: (err) {
          debugPrint('[EpubAudiobook] Playback error: $err');
          _completePlaybackSafe(false);
        },
      );

      if (!success) {
        _completePlaybackSafe(false);
      }
    } catch (e) {
      debugPrint('[EpubAudiobook] _playAudioEntry error: $e');
      _completePlaybackSafe(false);
    }
  }

  Future<void> _playAudioEntry(dynamic entry, BuildContext context) async {
    try {
      if (entry.filePath != null) {
        await TtsController.instance.playCachedEntry(
          entry: entry,
          context: context,
          showUi: false,
          onProgress: (progress) {
            if (!_isDisposed && !_stopRequested) {
              _updateStatus(_status.copyWith(playbackProgress: progress));
            }
          },
          onStateChanged: (state) {
            if (_isDisposed || _stopRequested) return;

            try {
              switch (state) {
                case TtsPlaybackState.playing:
                  _updateStatus(
                    _status.copyWith(state: AudiobookState.playing),
                  );
                  break;
                case TtsPlaybackState.generating:
                case TtsPlaybackState.loading:
                  _updateStatus(
                    _status.copyWith(state: AudiobookState.generating),
                  );
                  break;
                case TtsPlaybackState.paused:
                  if (_pauseRequested) {
                    _updateStatus(
                      _status.copyWith(state: AudiobookState.paused),
                    );
                  }
                  break;
                case TtsPlaybackState.completed:
                  break;
                case TtsPlaybackState.error:
                case TtsPlaybackState.idle:
                case TtsPlaybackState.stopped:
                case TtsPlaybackState.initial:
                  break;
              }
            } catch (e) {
              debugPrint('[EpubAudiobook] State change error: $e');
            }
          },
          onCompleted: () {
            _completePlaybackSafe(true);
          },
          onError: (err) {
            debugPrint('[EpubAudiobook] Playback error: $err');
            _completePlaybackSafe(false);
          },
        );
      } else {
        _completePlaybackSafe(false);
      }
    } catch (e) {
      debugPrint('[EpubAudiobook] Play error: $e');
      _completePlaybackSafe(false);
    }
  }

  void _completePlaybackSafe(bool success) {
    if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
      _playbackCompleter!.complete(success);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC CONTROLS
  // ═══════════════════════════════════════════════════════════════════════════

  void pause() {
    _pauseRequested = true;
    _updateStatus(
      _status.copyWith(state: AudiobookState.paused),
      immediate: true,
    );
    TtsController.instance.pause();

    // ✅ UPDATE NOTIFICATION
    _audioHandler?.pause();
  }

  void resume() {
    _pauseRequested = false;
    _updateStatus(
      _status.copyWith(state: AudiobookState.playing),
      immediate: true,
    );
    TtsController.instance.play();

    // ✅ UPDATE NOTIFICATION
    _audioHandler?.play();
  }

  void togglePlayPause() {
    if (_status.state == AudiobookState.playing) {
      pause();
    } else if (_status.state == AudiobookState.paused) {
      resume();
    } else {
      debugPrint(
        '[EpubAudiobook] togglePlayPause ignored in state: ${_status.state}',
      );
    }
  }

  Future<void> nextChapter(BuildContext context) async {
    try {
      if (_currentChapterIndex < book.chapterCount - 1) {
        _skipToNextRequested = true;
        _pauseRequested = false;
        _completePlaybackSafe(false);

        if (context.mounted) {
          await TtsController.instance.stop(context);
        }

        _currentChapterIndex++;
        _safeChapterChanged(_currentChapterIndex);

        _updateStatus(
          _status.copyWith(
            currentChapter: _currentChapterIndex,
            currentChapterTitle: _getChapterTitle(_currentChapterIndex),
            playbackProgress: 0.0,
            state: AudiobookState.preparing,
          ),
          immediate: true,
        );
      }
    } catch (e) {
      debugPrint('[EpubAudiobook] Next error: $e');
    }
  }

  Future<void> previousChapter(BuildContext? context) async {
    try {
      if (_currentChapterIndex > 0) {
        _skipToNextRequested = true;
        _pauseRequested = false;
        _completePlaybackSafe(false);

        if (context != null && context.mounted) {
          await TtsController.instance.stop(context);
        } else {
          TtsController.instance.forceStop();
        }

        _currentChapterIndex--;
        _safeChapterChanged(_currentChapterIndex);

        _updateStatus(
          _status.copyWith(
            currentChapter: _currentChapterIndex,
            currentChapterTitle: _getChapterTitle(_currentChapterIndex),
            playbackProgress: 0.0,
            state: AudiobookState.preparing,
          ),
          immediate: true,
        );

        await _updateMediaInfo();
      }
    } catch (e) {
      debugPrint('[EpubAudiobook] Previous error: $e');
    }
  }

  Future<void> jumpToChapter(int chapterIndex, BuildContext? context) async {
    try {
      if (chapterIndex >= 0 && chapterIndex < book.chapterCount) {
        _skipToNextRequested = true;
        _pauseRequested = false;
        _completePlaybackSafe(false);

        if (context != null && context.mounted) {
          await TtsController.instance.stop(context);
        } else {
          TtsController.instance.forceStop();
        }

        _currentChapterIndex = chapterIndex;
        _safeChapterChanged(_currentChapterIndex);

        _updateStatus(
          _status.copyWith(
            currentChapter: _currentChapterIndex,
            currentChapterTitle: _getChapterTitle(_currentChapterIndex),
            playbackProgress: 0.0,
            state: AudiobookState.preparing,
          ),
          immediate: true,
        );

        await _updateMediaInfo();
      }
    } catch (e) {
      debugPrint('[EpubAudiobook] Jump error: $e');
    }
  }

  void setPlaybackSpeed(double speed) {
    _settings = _settings.copyWith(playbackSpeed: speed.clamp(0.5, 3.0));
    _updateStatus(
      _status.copyWith(playbackSpeed: _settings.playbackSpeed),
      immediate: true,
    );
    try {
      TtsController.instance.setSpeed(_settings.playbackSpeed);
    } catch (e) {
      debugPrint('[EpubAudiobook] Set speed error: $e');
    }
  }

  void skipToNext() {
    if (_status.isActive && !_isDisposed) {
      _skipToNextRequested = true;
      _pauseRequested = false;
      try {
        TtsController.instance.forceStop();
      } catch (e) {
        debugPrint('[EpubAudiobook] skipToNext stop error: $e');
      }
      _completePlaybackSafe(true);
    }
  }

  void skipToPrevious() {
    if (_status.isActive && !_isDisposed) {
      _pauseRequested = false;
      if (_currentChapterIndex > 0) {
        _currentChapterIndex = (_currentChapterIndex - 2).clamp(
          0,
          book.chapterCount,
        );
        try {
          TtsController.instance.forceStop();
        } catch (e) {
          debugPrint('[EpubAudiobook] skipToPrevious stop error: $e');
        }
        _completePlaybackSafe(true);
      } else {
        try {
          TtsController.instance.forceStop();
        } catch (e) {
          debugPrint('[EpubAudiobook] skipToPrevious restart error: $e');
        }
        _currentChapterIndex--;
        _completePlaybackSafe(true);
      }
    }
  }

  void pausePlayback() {
    _pauseRequested = true;
    _updateStatus(
      _status.copyWith(state: AudiobookState.paused),
      immediate: true,
    );
    try {
      TtsController.instance.pause();
    } catch (e) {
      debugPrint('[EpubAudiobook] pausePlayback error: $e');
    }
  }

  void resumePlayback() {
    _pauseRequested = false;
    _updateStatus(
      _status.copyWith(state: AudiobookState.playing),
      immediate: true,
    );
    try {
      TtsController.instance.play();
    } catch (e) {
      debugPrint('[EpubAudiobook] resumePlayback error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String? _getChapterTitle(int index) {
    if (index >= 0 && index < book.chapters.length) {
      return book.chapters[index].title;
    }
    return 'Chapter ${index + 1}';
  }

  Future<String?> _getChapterTextSafe(int index) async {
    try {
      if (isTranslationMode?.call() == true &&
          getTranslatedChapterText != null) {
        return await getTranslatedChapterText!(index);
      }
      return await getChapterText(index);
    } catch (e) {
      debugPrint('Error getting chapter text: $e');
      return null;
    }
  }

  void _safeMessage(String message) {
    if (!_isDisposed) {
      onMessage?.call(message);
    }
  }

  void _safeChapterChanged(int chapter) {
    try {
      onChapterChanged?.call(chapter);
    } catch (e) {
      debugPrint('[EpubAudiobook] Chapter changed error: $e');
    }
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimerUpdateTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerUpdateTimer = null;
    _sleepTimerEnd = null;
    _updateStatus(
      _status.copyWith(isSleepTimerActive: false, sleepTimerRemaining: null),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS UPDATES
  // ═══════════════════════════════════════════════════════════════════════════

  void updateSettings(AudiobookSettings newSettings) {
    _settings = newSettings;
    debugPrint('[EpubAudiobook] Settings updated: $_settings');

    if (_status.isActive) {
      _startBackgroundGeneration();
    }
  }

  void setSleepTimer(Duration? duration) {
    _cancelSleepTimer();

    if (duration != null) {
      _sleepTimerEnd = DateTime.now().add(duration);
      _updateStatus(
        _status.copyWith(
          isSleepTimerActive: true,
          sleepTimerRemaining: duration,
        ),
      );

      _sleepTimer = Timer(duration, () {
        final ctx = _contextRef?.target;
        if (ctx != null && ctx.mounted) {
          stop(ctx);
        } else {
          forceStop();
        }
        _safeMessage('Sleep timer ended');
      });

      _sleepTimerUpdateTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) {
        if (_sleepTimerEnd != null) {
          final remaining = _sleepTimerEnd!.difference(DateTime.now());
          if (remaining.isNegative) {
            timer.cancel();
          } else {
            _updateStatus(_status.copyWith(sleepTimerRemaining: remaining));
          }
        }
      });
    }
  }

  void cancelSleepTimer() {
    _cancelSleepTimer();
    _safeMessage('Sleep timer cancelled');
  }

  void dispose() {
    debugPrint('[EpubAudiobook] Dispose');
    _isDisposed = true;
    _stopRequested = true;
    _statusDebounceTimer?.cancel();

    _stopBackgroundGeneration();

    _statusController.close();
    _cancelSleepTimer();

    // ✅ DISPOSE AUDIO HANDLER
    TtsController.instance.unregisterAudioHandler();
    _audioHandler?.dispose();
    _audioHandler = null;
    _isAudioServiceInitialized = false;

    try {
      TtsController.instance.forceStop();
    } catch (e) {
      debugPrint('[EpubAudiobook] Dispose stop error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// UTILS
// ═══════════════════════════════════════════════════════════════════════════

void unawaited(Future<void> future) {
  future.catchError((e) {
    debugPrint('[EpubAudiobook] Unawaited error: $e');
  });
}
