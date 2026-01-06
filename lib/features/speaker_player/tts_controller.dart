import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'models/tts_request.dart';
import 'models/download_model.dart';
import 'services/tts_service.dart';
import 'services/tts_audio_player.dart';
import 'services/model_download_service.dart';
import 'repositories/tts_cache_repository.dart';
import 'widgets/tts_overlay_manager.dart';
import 'services/tts_queue_manager.dart';
import 'services/language_detection_service.dart';
import 'services/audiobook_audio_handler.dart';

/// Cached audio entry info
class CachedAudioEntry {
  final String id;
  final String textHash;
  final String textPreview;
  final String filePath;
  final String modelId;
  final Duration duration;
  final double speed;
  final int speakerId;
  final String? bookId;
  final int? pageNumber;
  final DateTime createdAt;
  final int fileSizeBytes;

  CachedAudioEntry({
    required this.id,
    required this.textHash,
    required this.textPreview,
    required this.filePath,
    required this.modelId,
    required this.duration,
    required this.speed,
    required this.speakerId,
    this.bookId,
    this.pageNumber,
    required this.createdAt,
    required this.fileSizeBytes,
  });

  /// Format duration as mm:ss
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format file size
  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Check if file exists
  Future<bool> get exists async => File(filePath).exists();
}

/// Filter options for cached audio
class CachedAudioFilter {
  final String? bookId;
  final String? modelId;
  final double? speed;
  final int? speakerId;
  final DateTime? createdAfter;
  final DateTime? createdBefore;
  final int? limit;
  final int? offset;
  final CachedAudioSortBy sortBy;
  final bool ascending;

  const CachedAudioFilter({
    this.bookId,
    this.modelId,
    this.speed,
    this.speakerId,
    this.createdAfter,
    this.createdBefore,
    this.limit,
    this.offset,
    this.sortBy = CachedAudioSortBy.createdAt,
    this.ascending = false,
  });

  CachedAudioFilter copyWith({
    String? bookId,
    String? modelId,
    double? speed,
    int? speakerId,
    DateTime? createdAfter,
    DateTime? createdBefore,
    int? limit,
    int? offset,
    CachedAudioSortBy? sortBy,
    bool? ascending,
  }) {
    return CachedAudioFilter(
      bookId: bookId ?? this.bookId,
      modelId: modelId ?? this.modelId,
      speed: speed ?? this.speed,
      speakerId: speakerId ?? this.speakerId,
      createdAfter: createdAfter ?? this.createdAfter,
      createdBefore: createdBefore ?? this.createdBefore,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }
}

enum CachedAudioSortBy { createdAt, duration, fileSize, pageNumber }

/// Main TTS Controller with Caching
class TtsController {
  static TtsController? _instance;
  static TtsController get instance => _instance ??= TtsController._();

  TtsController._();

  final TtsService _ttsService = TtsService.instance;
  final TtsAudioPlayer _audioPlayer = TtsAudioPlayer.instance;
  final TtsCacheRepository _cacheRepository = TtsCacheRepository();

  ModelDownloadService? _modelService;
  bool _isOverlayShown = false;
  String? _currentModelId;
  String? _currentModelName;
  String? _currentModelPath;
  DownloadedModel? _currentModel;
  double _currentSpeed = 1.0;

  /// Stream of TTS status
  Stream<TtsStatus> get statusStream => _audioPlayer.statusStream;

  /// Current status
  TtsStatus get currentStatus => _audioPlayer.currentStatus;

  /// Is initialized (both TtsService and Sherpa)
  bool get isInitialized => _ttsService.isInitialized;

  /// Is Sherpa initialized
  bool get isSherpaInitialized => _ttsService.isSherpaInitialized;

  /// Current model info
  String? get currentModelId => _currentModelId;
  String? get currentModelName => _currentModelName;
  String? get currentModelPath => _currentModelPath;

  /// Get current active model info
  DownloadedModel? get currentModel => _currentModel;

  /// Get active model for current type
  Future<DownloadedModel?> getActiveModel() async {
    if (_modelService == null) return null;
    return await _modelService!.getActiveModelForType(SherpaModelType.tts);
  }

  AudiobookAudioHandler? _audioHandler;

  /// Clear current model
  void clearCurrentModel() {
    _currentModelId = null;
    _currentModelName = null;
    _currentModelPath = null;
    _currentModel = null;
  }

  /// Register audio handler for background playback
  void registerAudioHandler(AudiobookAudioHandler handler) {
    _audioHandler = handler;
    debugPrint('[TtsController] Audio handler registered');

    // ✅ Listen to actual player state and sync to handler
    _audioPlayer.statusStream.listen((status) {
      _syncStateToHandler(status);
    });
  }

  /// Sync actual player state to audio handler (for notification)
  void _syncStateToHandler(TtsStatus? status) {
    if (_audioHandler == null) return;

    try {
      if (status == null) return;
      switch (status.state) {
        case TtsPlaybackState.playing:
          _audioHandler!.setPlaying();
          break;
        case TtsPlaybackState.paused:
          _audioHandler!.setPaused();
          break;
        case TtsPlaybackState.loading:
        case TtsPlaybackState.generating:
          _audioHandler!.setLoading();
          break;
        case TtsPlaybackState.completed:
          _audioHandler!.setCompleted();
          break;
        case TtsPlaybackState.idle:
        case TtsPlaybackState.stopped:
        case TtsPlaybackState.initial:
        case TtsPlaybackState.error:
          _audioHandler!.setIdle();
          break;
      }

      // Update position
      if (status.position != null && status.duration != null) {
        _audioHandler!.updatePosition(
          status.position,
          duration: status.duration,
        );
      }
    } catch (e) {
      debugPrint('[TtsController] Sync to handler error: $e');
    }
  }

  /// Unregister audio handler
  void unregisterAudioHandler() {
    _audioHandler = null;
    debugPrint('[TtsController] Audio handler unregistered');
  }

  /// Current playback speed
  double get currentSpeed => _currentSpeed;

  // ==================== QUEUE MANAGER ====================

  final TtsQueueManager _queueManager = TtsQueueManager();
  bool _queueInitialized = false;

  /// Queue streams
  Stream<TtsTask> get taskStream => _queueManager.taskStream;
  Stream<QueueStatus> get queueStream => _queueManager.queueStream;
  Stream<TtsQueueNotification> get notificationStream =>
      _queueManager.notificationStream;

  /// Queue getters
  int get queueLength => _queueManager.queueLength;
  int get readyCount => _queueManager.readyCount;
  bool get isQueueProcessing => _queueManager.isProcessing;
  List<TtsTask> get readyTasks => _queueManager.readyTasks;
  List<TtsTask> get pendingTasks => _queueManager.pendingTasks;
  TtsTask? get currentQueueTask => _queueManager.currentTask;

  // Add this field in the class
  final LanguageDetectionService _langDetector =
      LanguageDetectionService.instance;

  // Language to model ID mapping
  final Map<String, List<String>> _languageModelMap = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // LANGUAGE DETECTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Detect language from text
  DetectedLanguage? detectLanguage(String text) {
    return _langDetector.detect(text);
  }

  /// Detect language code with fallback
  String detectLanguageCode(String text, {String fallback = 'en'}) {
    return _langDetector.detectCode(text, fallback: fallback);
  }

  /// Register a model for a specific language
  void registerLanguageModel(String language, String modelId) {
    final normalizedLang = _normalizeLanguage(language);
    _languageModelMap.putIfAbsent(normalizedLang, () => []).add(modelId);
    debugPrint(
      '[TtsController] Registered model $modelId for: $normalizedLang',
    );
  }

  /// Clear all language-model mappings
  void clearLanguageModels() {
    _languageModelMap.clear();
  }

  String _normalizeLanguage(String lang) {
    return lang.toLowerCase().trim().replaceAll('_', '-').split('-').first;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODEL SELECTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Find best model for a language
  /// Returns (id, name, path) or null
  Future<({String id, String name, String path})?> _findModelForLanguage(
    String language,
  ) async {
    if (_modelService == null) return null;

    final normalizedLang = _normalizeLanguage(language);
    debugPrint('[TtsController] Finding model for: $normalizedLang');

    // 1. Check custom mapping first
    final mappedIds = _languageModelMap[normalizedLang];
    if (mappedIds != null) {
      for (final modelId in mappedIds) {
        final model = await _modelService!.getModel(modelId);
        if (model != null && model.isDownloaded) {
          debugPrint('[TtsController] Using mapped model: ${model.name}');
          return (id: model.id, name: model.name, path: model.localPath);
        }
      }
    }

    // 2. Search TTS models for language match
    final ttsModels = await _modelService!.getModelsByType(SherpaModelType.tts);
    final downloadedModels = ttsModels.where((m) => m.isDownloaded).toList();

    // Exact match
    for (final model in downloadedModels) {
      if (_normalizeLanguage(model.language) == normalizedLang) {
        debugPrint('[TtsController] Found exact match: ${model.name}');
        return (id: model.id, name: model.name, path: model.localPath);
      }
    }

    // Prefix match
    for (final model in downloadedModels) {
      final modelLang = _normalizeLanguage(model.language);
      if (modelLang.startsWith(normalizedLang) ||
          normalizedLang.startsWith(modelLang)) {
        debugPrint('[TtsController] Found prefix match: ${model.name}');
        return (id: model.id, name: model.name, path: model.localPath);
      }
    }

    // Name contains language
    for (final model in downloadedModels) {
      final nameLower = model.name.toLowerCase();
      if (nameLower.contains(normalizedLang)) {
        debugPrint('[TtsController] Found name match: ${model.name}');
        return (id: model.id, name: model.name, path: model.localPath);
      }
    }

    return null;
  }

  /// Select model with fallback chain
  /// Order: Language match -> Current model -> Active model -> Any TTS model
  Future<({String id, String name, String path})?> _selectModel(
    String? language,
  ) async {
    // 1. Try language-specific model
    if (language != null && language.isNotEmpty) {
      final langModel = await _findModelForLanguage(language);
      if (langModel != null) return langModel;
    }

    // 2. Use current model if set
    if (_currentModelId != null &&
        _currentModelName != null &&
        _currentModelPath != null) {
      return (
        id: _currentModelId!,
        name: _currentModelName!,
        path: _currentModelPath!,
      );
    }

    // 3. Try active TTS model
    if (_modelService != null) {
      final activeModel = await _modelService!.getActiveModelForType(
        SherpaModelType.tts,
      );
      if (activeModel != null && activeModel.isDownloaded) {
        return (
          id: activeModel.id,
          name: activeModel.name,
          path: activeModel.localPath,
        );
      }

      // 4. Any available TTS model
      final ttsModels = await _modelService!.getModelsByType(
        SherpaModelType.tts,
      );
      final downloaded = ttsModels.where((m) => m.isDownloaded).toList();
      if (downloaded.isNotEmpty) {
        final model = downloaded.first;
        return (id: model.id, name: model.name, path: model.localPath);
      }
    }

    return null;
  }

  /// Play cached audio entry in background (no BuildContext required)
  /// Uses AudioHandler's player for proper background support
  Future<bool> playCachedEntryBackground({
    required dynamic entry,
    bool showUi = false,
    Function(double)? onProgress,
    Function(TtsPlaybackState)? onStateChanged,
    VoidCallback? onCompleted,
    Function(String)? onError,
  }) async {
    try {
      // Extract file path
      String? filePath;
      String? textPreview;
      double speed = 1.0;
      int speakerId = 0;
      Duration? duration;

      if (entry is CachedAudioEntry) {
        filePath = entry.filePath;
        textPreview = entry.textPreview;
        speed = entry.speed;
        speakerId = entry.speakerId;
        duration = entry.duration;
      } else {
        try {
          filePath = entry.filePath as String?;
          textPreview = entry.textPreview as String? ?? '';
          speed = (entry.speed as num?)?.toDouble() ?? 1.0;
          speakerId = entry.speakerId as int? ?? 0;
          duration = entry.duration as Duration?;
        } catch (e) {
          onError?.call('Invalid entry format');
          return false;
        }
      }

      if (filePath == null || filePath.isEmpty) {
        onError?.call('No audio file path');
        return false;
      }

      // Check file exists
      final file = File(filePath);
      if (!await file.exists()) {
        onError?.call('Audio file not found');
        return false;
      }

      debugPrint('[TtsController] Playing (background safe): $filePath');

      // ✅ Update notification info
      if (_audioHandler != null) {
        await _audioHandler!.updateMediaInfo(
          title: textPreview ?? 'Playing',
          album: 'Audiobook',
          duration: duration,
        );
        _audioHandler!.setLoading();
      }

      // Notify state
      onStateChanged?.call(TtsPlaybackState.loading);

      // Create request
      final request = TtsRequest(
        text: textPreview ?? '',
        modelPath: _currentModelPath,
        speed: speed,
        speakerId: speakerId,
        showUi: false,
        onStateChanged: (state) {
          onStateChanged?.call(state);
          // ✅ Sync to notification
          _syncPlaybackStateToHandler(state);
        },
        onProgress: (progress) {
          onProgress?.call(progress);
          // ✅ Update notification position
          if (_audioHandler != null && duration != null) {
            final position = Duration(
              milliseconds: (duration.inMilliseconds * progress).round(),
            );
            _audioHandler!.updatePosition(position, duration: duration);
          }
        },
        onError: (error) {
          onError?.call(error);
          _audioHandler?.setIdle();
        },
        onCompleted: () {
          onCompleted?.call();
          _audioHandler?.setCompleted();
        },
      );

      // ✅ Play using TtsAudioPlayer (the actual player)
      final success = await _audioPlayer.playFromFile(
        filePath,
        request: request,
      );

      if (success) {
        _audioHandler?.setPlaying();
      } else {
        _audioHandler?.setIdle();
      }

      return success;
    } catch (e, stack) {
      debugPrint('[TtsController] playCachedEntryBackground error: $e\n$stack');
      onError?.call(e.toString());
      _audioHandler?.setIdle();
      return false;
    }
  }

  void _syncPlaybackStateToHandler(TtsPlaybackState state) {
    if (_audioHandler == null) return;

    switch (state) {
      case TtsPlaybackState.playing:
        _audioHandler!.setPlaying();
        break;
      case TtsPlaybackState.paused:
        _audioHandler!.setPaused();
        break;
      case TtsPlaybackState.loading:
      case TtsPlaybackState.generating:
        _audioHandler!.setLoading();
        break;
      case TtsPlaybackState.completed:
        _audioHandler!.setCompleted();
        break;
      default:
        _audioHandler!.setIdle();
    }
  }

  /// Initialize queue manager (call in init())
  void _initQueueManager() {
    if (_queueInitialized) return;

    _queueManager.onGenerateAudio = _generateAudioForTask;
    _queueManager.onPlayAudio = _playAudioForTask;
    _queueManager.onTaskReady = (task) {
      debugPrint('[TtsController] Task ready: ${task.id}');
    };
    _queueManager.onTaskFailed = (task) {
      debugPrint('[TtsController] Task failed: ${task.id} - ${task.error}');
    };

    _queueInitialized = true;
    debugPrint('[TtsController] Queue manager initialized');
  }

  /// Helper: Generate structured path for audio file
  Future<String> _getStructuredAudioPath(
    String bookId,
    int chapterIndex,
  ) async {
    // Prefer external storage, fallback to app documents
    final baseDir = await getExternalStorageDirectory();
    final appDir = baseDir ?? await getApplicationDocumentsDirectory();
    final sanitizedBookId = bookId.replaceAll(RegExp(r'[^\w\d_-]'), '_');
    final bookDir = Directory(
      path.join(appDir.path, 'audiobooks', sanitizedBookId),
    );

    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }

    // Naming: ch_{index}.wav (e.g., ch_1.wav)
    return path.join(bookDir.path, 'ch_$chapterIndex.wav');
  }

  /// Simple generate audio with cache - Returns path to audio file
  Future<String?> generateAudioSimple({
    required String text,
    required String bookId,
    required int pageNumber,
    double speed = 1.0,
    void Function(double progress)? onProgress,
  }) async {
    try {
      debugPrint(
        '[TtsController] generateAudioSimple: book=$bookId, page=$pageNumber',
      );

      // 1. Ensure initialized
      if (_currentModelPath == null || _currentModelId == null) {
        debugPrint('[TtsController] No model, initializing...');
        final initialized = await initializeWithActiveModel();
        if (!initialized) {
          debugPrint('[TtsController] ✗ Initialization failed');
          return null;
        }
      }

      // 2. Check cache FIRST
      final cached = await _cacheRepository.getCachedAudio(
        text: text,
        modelId: _currentModelId!,
        speed: speed,
        speakerId: 0,
      );

      if (cached != null) {
        debugPrint('[TtsController] ✓ Cache hit: ${cached.filePath}');
        return cached.filePath;
      }

      // 3. NOT cached - Generate new
      debugPrint('[TtsController] Generating NEW audio...');
      debugPrint('[TtsController] Text length: ${text.length} chars');
      debugPrint(
        '[TtsController] Text preview: ${text.substring(0, text.length > 200 ? 200 : text.length)}...',
      );

      // ✅ Use structured path
      final outputPath = await _getStructuredAudioPath(bookId, pageNumber);
      debugPrint('[TtsController] Target path: $outputPath');
      debugPrint('[TtsController] Model path: $_currentModelPath');
      debugPrint('[TtsController] Speed: $speed, Speaker: 0');

      final result = await _ttsService.generateAudio(
        text: text,
        modelPath: _currentModelPath!,
        speed: speed,
        speakerId: 0,
        outputPath: outputPath,
        onProgress: onProgress,
      );

      if (result == null) {
        debugPrint('[TtsController] ✗ TtsService returned null');
        return null;
      }

      debugPrint(
        '[TtsController] ✓ Generated ${result.audioData.length} bytes',
      );

      // ✅ FIX: Check if file path exists
      if (result.filePath == null || result.filePath!.isEmpty) {
        debugPrint('[TtsController] ✗ No file path in result');
        return null;
      }

      // ✅ FIX: Verify file was actually created
      final generatedFile = File(result.filePath!);
      if (!await generatedFile.exists()) {
        debugPrint(
          '[TtsController] ✗ Generated file not found: ${result.filePath}',
        );
        return null;
      }

      debugPrint('[TtsController] ✓ File exists: ${result.filePath}');

      // 4. Save to cache
      try {
        await _cacheRepository.saveToCache(
          text: text,
          modelId: _currentModelId!,
          audioData: result.audioData,
          duration: result.duration,
          speed: speed,
          speakerId: 0,
          bookId: bookId,
          pageNumber: pageNumber,
        );

        debugPrint('[TtsController] ✓ Saved to cache');
      } catch (e) {
        debugPrint(
          '[TtsController] ⚠ Cache save failed: $e (but file exists, continuing)',
        );
        // Don't fail if cache save fails - we still have the audio file
      }

      return result.filePath;
    } catch (e, stack) {
      debugPrint('[TtsController] ✗ Error: $e\n$stack');
      return null;
    }
  }

  /// Generate audio for a queued task
  Future<String?> _generateAudioForTask(TtsTask task) async {
    try {
      // Ensure we have a model
      if (_currentModelPath == null || _currentModelId == null) {
        final initialized = await initializeWithActiveModel();
        if (!initialized) {
          throw Exception('No TTS model available');
        }
      }

      // Ensure Sherpa is ready
      if (!_ttsService.isSherpaInitialized) {
        await _waitForSherpaInitialization();
      }

      // ✅ Check cache first
      if (task.useCache && _currentModelId != null) {
        final cached = await _cacheRepository.getCachedAudio(
          text: task.text,
          modelId: _currentModelId!,
          speed: task.speed,
          speakerId: task.speakerId,
        );

        if (cached != null) {
          debugPrint('[TtsController] Using cached audio for task: ${task.id}');
          task.duration = cached.duration;
          return cached.filePath;
        }
      }

      // ✅ Generate new audio with PROPER chunking
      debugPrint('[TtsController] Generating audio for task: ${task.id}');

      // ✅ Use structured path (if bookId and pageNumber available)
      String? outputPath;
      if (task.bookId != null && task.pageNumber != null) {
        outputPath = await _getStructuredAudioPath(
          task.bookId!,
          task.pageNumber!,
        );
      }

      final result = await _ttsService.generateAudioWithChunks(
        text: task.text,
        modelPath: _currentModelPath!,
        speed: task.speed,
        speakerId: task.speakerId,
        outputPath: outputPath,
        onProgress: (progress) {
          task.progress = progress;
          task.onProgress?.call(progress);
        },
      );

      if (result == null) {
        throw Exception('Audio generation returned null');
      }

      // ✅ Cache the result
      if (task.useCache && _currentModelId != null) {
        await _cacheRepository.saveToCache(
          text: task.text,
          modelId: _currentModelId!,
          audioData: result.audioData,
          duration: result.duration,
          speed: task.speed,
          speakerId: task.speakerId,
          bookId: task.bookId,
          pageNumber: task.pageNumber,
        );
      }

      task.duration = result.duration;
      task.audioData = result.audioData;

      return result.filePath;
    } catch (e) {
      debugPrint('[TtsController] Generate for task error: $e');
      rethrow;
    }
  }

  /// Play audio for a queued task
  Future<void> _playAudioForTask(TtsTask task, String audioPath) async {
    final request = TtsRequest(
      text: task.text,
      modelPath: _currentModelPath,
      speed: task.speed,
      speakerId: task.speakerId,
      showUi: task.showUi,
      onStateChanged: task.onStateChanged,
      onProgress: task.onProgress,
      onError: task.onError,
      onCompleted: task.onCompleted,
    );

    final success = await _audioPlayer.playFromFile(
      audioPath,
      request: request,
    );
    if (!success) {
      throw Exception('Failed to play audio');
    }
  }

  // ==================== NON-BLOCKING SPEAK METHODS ====================

  /// Speak text (NON-BLOCKING) - Returns task ID immediately
  ///
  /// Audio is generated in background. User is notified when ready.
  /// Use [taskStream] or [notificationStream] to track progress.
  String speakAsync({
    required String text,
    BuildContext? context,
    String? bookId,
    int? pageNumber,
    bool showUi = true,
    double speed = 1.0,
    int speakerId = 0,
    bool useCache = true,
    Function(TtsPlaybackState)? onStateChanged,
    Function(double)? onProgress,
    Function(String)? onError,
    VoidCallback? onCompleted,
  }) {
    // Quick validation
    if (text.trim().isEmpty) {
      onError?.call('No text to speak');
      return '';
    }

    // Initialize queue if needed
    _initQueueManager();

    // Notify loading state immediately
    onStateChanged?.call(TtsPlaybackState.loading);

    // Check if model is ready, if not, try to initialize in background
    if (_currentModelPath == null) {
      _initializeModelInBackground();
    }

    // Add to queue (returns immediately)
    final taskId = _queueManager.speak(
      text: text,
      bookId: bookId,
      pageNumber: pageNumber,
      speed: speed,
      speakerId: speakerId,
      showUi: showUi,
      useCache: useCache,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: onCompleted,
    );

    debugPrint(
      '[TtsController] Speak queued: $taskId (queue: ${_queueManager.queueLength})',
    );
    return taskId;
  }

  /// Speak page (NON-BLOCKING) - Returns task ID immediately
  String speakPageAsync({
    required String text,
    required String bookId,
    required int pageNumber,
    BuildContext? context,
    bool showUi = true,
    double speed = 1.0,
    int speakerId = 0,
    Function(TtsPlaybackState)? onStateChanged,
    Function(double)? onProgress,
    Function(String)? onError,
    VoidCallback? onCompleted,
  }) {
    return speakAsync(
      text: text,
      bookId: bookId,
      pageNumber: pageNumber,
      showUi: showUi,
      speed: speed,
      speakerId: speakerId,
      useCache: true,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: onCompleted,
    );
  }

  /// Speak selected text (NON-BLOCKING) - Returns task ID immediately
  String speakSelectionAsync({
    required String text,
    BuildContext? context,
    bool showUi = true,
    double speed = 1.0,
    Function(TtsPlaybackState)? onStateChanged,
    Function(double)? onProgress,
    Function(String)? onError,
    VoidCallback? onCompleted,
  }) {
    return speakAsync(
      text: text,
      showUi: showUi,
      speed: speed,
      useCache: true,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: onCompleted,
    );
  }

  /// Initialize model in background (non-blocking)
  void _initializeModelInBackground() {
    Future.microtask(() async {
      try {
        debugPrint('[TtsController] Background model initialization...');
        await initializeWithActiveModel();
      } catch (e) {
        debugPrint('[TtsController] Background init error: $e');
      }
    });
  }

  // ==================== QUEUE CONTROL METHODS ====================

  /// Get task by ID
  TtsTask? getTask(String taskId) => _queueManager.getTask(taskId);

  /// Cancel a specific task
  void cancelTask(String taskId) {
    try {
      _queueManager.cancelTask(taskId);
    } catch (e) {
      debugPrint('[TtsController] Cancel task error: $e');
    }
  }

  /// Cancel all queued tasks
  void cancelAllTasks() {
    try {
      _queueManager.cancelAll();
    } catch (e) {
      debugPrint('[TtsController] Cancel all tasks error: $e');
    }
  }

  /// Pause queue processing
  void pauseQueue() {
    try {
      _queueManager.pauseQueue();
    } catch (e) {
      debugPrint('[TtsController] Pause queue error: $e');
    }
  }

  /// Resume queue processing
  void resumeQueue() {
    try {
      _queueManager.resumeQueue();
    } catch (e) {
      debugPrint('[TtsController] Resume queue error: $e');
    }
  }

  /// Play a ready task
  Future<void> playReadyTask(String taskId) async {
    try {
      await _queueManager.playReadyTask(taskId);
    } catch (e) {
      debugPrint('[TtsController] Play ready task error: $e');
    }
  }

  /// Clear finished tasks from memory
  void clearFinishedTasks() {
    try {
      _queueManager.clearFinishedTasks();
    } catch (e) {
      debugPrint('[TtsController] Clear finished tasks error: $e');
    }
  }

  // ==================== GENERATED AUDIO LIST METHODS ====================

  /// Get all generated/cached audio entries
  ///
  /// Returns a list of all cached audio entries with optional filtering
  Future<List<CachedAudioEntry>> getGeneratedAudioList({
    CachedAudioFilter? filter,
  }) async {
    try {
      final entries = await _cacheRepository.getAllCachedEntries(
        bookId: filter?.bookId,
        modelId: filter?.modelId,
        speed: filter?.speed,
        speakerId: filter?.speakerId,
      );

      List<CachedAudioEntry> result = [];

      for (final entry in entries) {
        // Get file size
        int fileSize = 0;
        try {
          final file = File(entry.filePath);
          if (await file.exists()) {
            fileSize = await file.length();
          }
        } catch (_) {}

        result.add(
          CachedAudioEntry(
            id: entry.id,
            textHash: entry.textHash,
            textPreview: entry.textPreview,
            filePath: entry.filePath,
            modelId: entry.modelId,
            duration: entry.duration,
            speed: entry.speed,
            speakerId: entry.speakerId,
            bookId: entry.bookId,
            pageNumber: entry.pageNumber,
            createdAt: entry.createdAt,
            fileSizeBytes: fileSize,
          ),
        );
      }

      // Apply date filters
      if (filter?.createdAfter != null) {
        result = result
            .where((e) => e.createdAt.isAfter(filter!.createdAfter!))
            .toList();
      }
      if (filter?.createdBefore != null) {
        result = result
            .where((e) => e.createdAt.isBefore(filter!.createdBefore!))
            .toList();
      }

      // Apply sorting
      switch (filter?.sortBy ?? CachedAudioSortBy.createdAt) {
        case CachedAudioSortBy.createdAt:
          result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case CachedAudioSortBy.duration:
          result.sort((a, b) => a.duration.compareTo(b.duration));
          break;
        case CachedAudioSortBy.fileSize:
          result.sort((a, b) => a.fileSizeBytes.compareTo(b.fileSizeBytes));
          break;
        case CachedAudioSortBy.pageNumber:
          result.sort(
            (a, b) => (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0),
          );
          break;
      }

      // Reverse if descending
      if (filter?.ascending == false) {
        result = result.reversed.toList();
      }

      // Apply pagination
      if (filter?.offset != null && filter!.offset! > 0) {
        result = result.skip(filter.offset!).toList();
      }
      if (filter?.limit != null && filter!.limit! > 0) {
        result = result.take(filter.limit!).toList();
      }

      return result;
    } catch (e, stack) {
      debugPrint('[TtsController] Error getting audio list: $e\n$stack');
      return [];
    }
  }

  /// Get generated audio entries for a specific book
  Future<List<CachedAudioEntry>> getGeneratedAudioForBook(String bookId) async {
    return getGeneratedAudioList(
      filter: CachedAudioFilter(
        bookId: bookId,
        sortBy: CachedAudioSortBy.pageNumber,
        ascending: true,
      ),
    );
  }

  /// Get generated audio count
  Future<int> getGeneratedAudioCount({String? bookId, String? modelId}) async {
    final list = await getGeneratedAudioList(
      filter: CachedAudioFilter(bookId: bookId, modelId: modelId),
    );
    return list.length;
  }

  /// Get total size of generated audio
  Future<int> getGeneratedAudioTotalSize({String? bookId}) async {
    final list = await getGeneratedAudioList(
      filter: CachedAudioFilter(bookId: bookId),
    );
    return list.fold<int>(0, (sum, entry) => sum + entry.fileSizeBytes);
  }

  /// Get formatted total size of generated audio
  Future<String> getGeneratedAudioFormattedSize({String? bookId}) async {
    final bytes = await getGeneratedAudioTotalSize(bookId: bookId);
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Play a cached audio entry
  Future<bool> playCachedEntry({
    required CachedAudioEntry entry,
    required BuildContext context,
    bool showUi = true,
    Function(TtsPlaybackState state)? onStateChanged,
    Function(double progress)? onProgress,
    Function(String error)? onError,
    Function()? onCompleted,
  }) async {
    try {
      if (!await entry.exists) {
        onError?.call('Audio file not found');
        return false;
      }

      if (showUi && context.mounted) {
        showPlayer(
          context,
          text: entry.textPreview,
          modelName: _currentModelName,
        );
      }

      final request = TtsRequest(
        text: entry.textPreview,
        modelPath: _currentModelPath,
        speed: entry.speed,
        speakerId: entry.speakerId,
        showUi: showUi,
        onStateChanged: onStateChanged,
        onProgress: onProgress,
        onError: onError,
        onCompleted: () {
          onCompleted?.call();
          _handleCompletion(context, showUi);
        },
      );

      return await _audioPlayer.playFromFile(entry.filePath, request: request);
    } catch (e, stack) {
      debugPrint('[TtsController] Error playing cached entry: $e\n$stack');
      onError?.call(e.toString());
      return false;
    }
  }

  /// Delete a specific cached audio entry
  Future<bool> deleteCachedEntry(CachedAudioEntry entry) async {
    try {
      await _cacheRepository.deleteCacheEntry(entry.id);
      return true;
    } catch (e, stack) {
      debugPrint('[TtsController] Error deleting cached entry: $e\n$stack');
      return false;
    }
  }

  /// Delete multiple cached audio entries
  Future<int> deleteCachedEntries(List<CachedAudioEntry> entries) async {
    int deleted = 0;
    for (final entry in entries) {
      if (await deleteCachedEntry(entry)) {
        deleted++;
      }
    }
    return deleted;
  }

  /// Export cached audio to a specific location
  Future<String?> exportCachedEntry({
    required CachedAudioEntry entry,
    required String destinationPath,
  }) async {
    try {
      final sourceFile = File(entry.filePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final destFile = await sourceFile.copy(destinationPath);
      return destFile.path;
    } catch (e, stack) {
      debugPrint('[TtsController] Error exporting cached entry: $e\n$stack');
      return null;
    }
  }

  /// Get unique book IDs with cached audio
  Future<List<String>> getBooksWithCachedAudio() async {
    final allEntries = await getGeneratedAudioList();
    final bookIds = <String>{};

    for (final entry in allEntries) {
      if (entry.bookId != null) {
        bookIds.add(entry.bookId!);
      }
    }

    return bookIds.toList();
  }

  /// Get cache summary by book
  Future<Map<String, CacheBookSummary>> getCacheSummaryByBook() async {
    final allEntries = await getGeneratedAudioList();
    final summaries = <String, CacheBookSummary>{};

    for (final entry in allEntries) {
      final bookId = entry.bookId ?? 'unknown';

      if (!summaries.containsKey(bookId)) {
        summaries[bookId] = CacheBookSummary(
          bookId: bookId,
          entryCount: 0,
          totalDuration: Duration.zero,
          totalSizeBytes: 0,
          pages: [],
        );
      }

      final current = summaries[bookId]!;
      summaries[bookId] = CacheBookSummary(
        bookId: bookId,
        entryCount: current.entryCount + 1,
        totalDuration: current.totalDuration + entry.duration,
        totalSizeBytes: current.totalSizeBytes + entry.fileSizeBytes,
        pages: [
          ...current.pages,
          if (entry.pageNumber != null) entry.pageNumber!,
        ],
      );
    }

    return summaries;
  }

  // ==================== EXISTING METHODS ====================

  /// Initialize controller
  Future<void> init(ModelDownloadService modelService) async {
    try {
      _modelService = modelService;
      await _cacheRepository.init();
      _initQueueManager();
      debugPrint('[TtsController] Initialized');
    } catch (e) {
      debugPrint('[TtsController] Initialization failed: $e');
    }
  }

  /// Initialize with active TTS model
  Future<bool> initializeWithActiveModel() async {
    debugPrint('[TtsController] initializeWithActiveModel called');
    debugPrint(
      '[TtsController] _modelService is null: ${_modelService == null}',
    );

    if (_modelService == null) {
      debugPrint('[TtsController] ModelDownloadService not set');
      return false;
    }

    try {
      // First, ensure Sherpa bindings are initialized
      debugPrint(
        '[TtsController] isSherpaInitialized: ${_ttsService.isSherpaInitialized}',
      );

      if (!_ttsService.isSherpaInitialized) {
        try {
          debugPrint('[TtsController] Initializing Sherpa bindings...');
          await _waitForSherpaInitialization();
          debugPrint('[TtsController] Sherpa initialized successfully');
        } catch (e) {
          debugPrint('[TtsController] Sherpa initialization failed: $e');
          return false;
        }
      }

      debugPrint('[TtsController] Getting active TTS model...');
      final activeModel = await _modelService!.getActiveModelForType(
        SherpaModelType.tts,
      );

      debugPrint('[TtsController] activeModel: ${activeModel?.name}');
      debugPrint(
        '[TtsController] activeModel.isDownloaded: ${activeModel?.isDownloaded}',
      );
      debugPrint(
        '[TtsController] activeModel.localPath: ${activeModel?.localPath}',
      );

      if (activeModel == null || !activeModel.isDownloaded) {
        debugPrint('[TtsController] No active TTS model');
        return false;
      }

      // Check if model path exists
      final modelDir = Directory(activeModel.localPath);
      final exists = await modelDir.exists();
      debugPrint('[TtsController] Model directory exists: $exists');

      if (!exists) {
        debugPrint(
          '[TtsController] Model directory not found: ${activeModel.localPath}',
        );
        return false;
      }

      _currentModelId = activeModel.id;
      _currentModelName = activeModel.name;
      _currentModelPath = activeModel.localPath;
      _currentModel = activeModel;

      debugPrint(
        '[TtsController] Setting default model: ${activeModel.localPath}',
      );
      final result = await _ttsService.setDefaultModel(
        modelPath: activeModel.localPath,
        modelName: activeModel.name,
      );

      debugPrint('[TtsController] setDefaultModel result: $result');
      return result;
    } catch (e, st) {
      debugPrint('[TtsController] Error initializing: $e');
      debugPrint('[TtsController] Stack: $st');
      return false;
    }
  }

  /// Wait for Sherpa initialization to complete
  Future<void> _waitForSherpaInitialization() async {
    if (_ttsService.isSherpaInitialized) {
      return;
    }

    final completer = Completer<void>();
    late StreamSubscription<TtsPlaybackState> subscription;

    subscription = _ttsService.stateStream.listen((status) {
      if (status == TtsPlaybackState.idle && _ttsService.isSherpaInitialized) {
        subscription.cancel();
        completer.complete();
      } else if (status == TtsPlaybackState.error) {
        subscription.cancel();
        completer.completeError('Sherpa initialization failed');
      }
    });

    final timeout = Future.delayed(const Duration(seconds: 30), () {
      subscription.cancel();
      completer.completeError('Sherpa initialization timed out');
    });

    await Future.any([completer.future, timeout]);
  }

  /// Speak text with caching support
  Future<bool> speak({
    required String text,
    required BuildContext context,
    String? modelPath,
    String? modelId,
    String? modelName,
    bool showUi = true,
    double speed = 1.0,
    int speakerId = 0,
    String? bookId,
    int? pageNumber,
    bool useCache = true,
    Function(TtsPlaybackState state)? onStateChanged,
    Function(double progress)? onProgress,
    Function(String? filePath, Uint8List? audioData)? onAudioGenerated,
    Function(String error)? onError,
    Function()? onCompleted,
  }) async {
    String? effectiveModelPath = modelPath ?? _currentModelPath;
    String? effectiveModelId = modelId ?? _currentModelId;
    String? effectiveModelName = modelName ?? _currentModelName;

    if (effectiveModelPath == null) {
      final initialized = await initializeWithActiveModel();
      if (!context.mounted) return false;
      if (!initialized) {
        final error = 'No TTS model available. Please download a TTS model.';
        onError?.call(error);
        _showNoModelError(context);
        return false;
      }
      effectiveModelPath = _currentModelPath;
      effectiveModelId = _currentModelId;
      effectiveModelName = _currentModelName;
    }

    if (!_ttsService.isSherpaInitialized) {
      try {
        debugPrint('[TtsController] Waiting for Sherpa initialization...');
        await _waitForSherpaInitialization();
      } catch (e) {
        final error = 'TTS service initialization failed. Please try again.';
        debugPrint('[TtsController] Sherpa initialization error: $e');
        onError?.call(error);
        if (context.mounted) {
          _showInitializationError(context, error);
        }
        return false;
      }
    }

    if (showUi && context.mounted) {
      showPlayer(context, text: text, modelName: effectiveModelName);
    }

    // Check cache first
    if (useCache && effectiveModelId != null) {
      final cached = await _cacheRepository.getCachedAudio(
        text: text,
        modelId: effectiveModelId,
        speed: speed,
        speakerId: speakerId,
      );

      if (cached != null) {
        debugPrint('[TtsController] Playing from cache: ${cached.textHash}');

        final request = TtsRequest(
          text: text,
          modelPath: effectiveModelPath,
          speed: speed,
          speakerId: speakerId,
          showUi: showUi,
          onStateChanged: onStateChanged,
          onProgress: onProgress,
          onAudioGenerated: onAudioGenerated,
          onError: onError,
          onCompleted: () {
            onCompleted?.call();
            _handleCompletion(context, showUi);
          },
        );

        return await _audioPlayer.playFromFile(
          cached.filePath,
          request: request,
        );
      }
    }

    // Generate new audio
    debugPrint('[TtsController] Generating new audio');

    try {
      final result = await _ttsService.generateAudio(
        text: text,
        modelPath: effectiveModelPath,
        speed: speed,
        speakerId: speakerId,
        onProgress: (progress) {
          debugPrint(
            '[TtsController] Generation progress: ${(progress * 100).toInt()}%',
          );
          // You can emit this to UI if needed
        },
      );

      if (result == null) {
        onError?.call('Failed to generate audio');
        return false;
      }

      // Cache the audio
      if (useCache && effectiveModelId != null) {
        await _cacheRepository.saveToCache(
          text: text,
          modelId: effectiveModelId,
          audioData: result.audioData,
          duration: result.duration,
          speed: speed,
          speakerId: speakerId,
          bookId: bookId,
          pageNumber: pageNumber,
        );
      }

      onAudioGenerated?.call(result.filePath, result.audioData);

      final request = TtsRequest(
        text: text,
        modelPath: effectiveModelPath,
        speed: speed,
        speakerId: speakerId,
        showUi: showUi,
        onStateChanged: onStateChanged,
        onProgress: onProgress,
        onError: onError,
        onCompleted: () {
          onCompleted?.call();
          _handleCompletion(context, showUi);
        },
      );

      return await _audioPlayer.playFromBytes(
        result.audioData,
        request: request,
      );
    } catch (e) {
      debugPrint('[TtsController] Error: $e');
      onError?.call(e.toString());
      return false;
    }
  }

  /// Speak page content (with page-specific caching)
  Future<bool> speakPage({
    required String text,
    required BuildContext context,
    required String bookId,
    required int pageNumber,
    bool showUi = true,
    double speed = 1.0,
    int speakerId = 0,
    Function(TtsPlaybackState state)? onStateChanged,
    Function(double progress)? onProgress,
    Function(String error)? onError,
    Function()? onCompleted,
  }) async {
    return speak(
      text: text,
      context: context,
      showUi: showUi,
      speed: speed,
      speakerId: speakerId,
      bookId: bookId,
      pageNumber: pageNumber,
      useCache: true,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: onCompleted,
    );
  }

  /// Speak selected text
  Future<bool> speakSelection({
    required String text,
    required BuildContext context,
    bool showUi = true,
    double speed = 1.0,
    Function(TtsPlaybackState state)? onStateChanged,
    Function(double progress)? onProgress,
    Function(String error)? onError,
    Function()? onCompleted,
  }) async {
    return speak(
      text: text,
      context: context,
      showUi: showUi,
      speed: speed,
      useCache: true,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: onCompleted,
    );
  }

  /// Generate audio only (with caching)
  Future<TtsGenerationResult?> generateOnly({
    required String text,
    String? modelPath,
    String? modelId,
    double speed = 1.0,
    int speakerId = 0,
    bool useCache = true,
    String? bookId,
    int? pageNumber,
  }) async {
    final effectiveModelPath = modelPath ?? _currentModelPath;
    final effectiveModelId = modelId ?? _currentModelId;

    if (effectiveModelPath == null) {
      await initializeWithActiveModel();
    }

    if (!_ttsService.isSherpaInitialized) {
      try {
        debugPrint(
          '[TtsController] Waiting for Sherpa initialization for generateOnly...',
        );
        await _waitForSherpaInitialization();
      } catch (e) {
        debugPrint(
          '[TtsController] Sherpa initialization error for generateOnly: $e',
        );
        return null;
      }
    }

    // Check cache
    if (useCache && effectiveModelId != null) {
      final cached = await _cacheRepository.getCachedAudio(
        text: text,
        modelId: effectiveModelId,
        speed: speed,
        speakerId: speakerId,
      );

      if (cached != null) {
        final file = File(cached.filePath);
        final audioData = await file.readAsBytes();
        return TtsGenerationResult(
          audioData: audioData,
          filePath: cached.filePath,
          sampleRate: 22050,
          duration: cached.duration,
        );
      }
    }

    final result = await _ttsService.generateAudio(
      text: text,
      modelPath: effectiveModelPath,
      speed: speed,
      speakerId: speakerId,
    );

    if (result != null && useCache && effectiveModelId != null) {
      await _cacheRepository.saveToCache(
        text: text,
        modelId: effectiveModelId,
        audioData: result.audioData,
        duration: result.duration,
        speed: speed,
        speakerId: speakerId,
        bookId: bookId,
        pageNumber: pageNumber,
      );
    }

    return result;
  }

  /// Initialize with default model path
  Future<bool> initializeWithModel({
    required String modelPath,
    String? modelName,
  }) async {
    _currentModelName = modelName;

    if (!_ttsService.isSherpaInitialized) {
      debugPrint(
        '[TtsController] Sherpa not initialized, attempting to initialize...',
      );
    }

    return await _ttsService.setDefaultModel(
      modelPath: modelPath,
      modelName: modelName,
    );
  }

  /// Set model download service (for getting active models)
  void setModelService(ModelDownloadService service) {
    _modelService = service;
  }

  /// Pre-generate audio for pages (background caching)
  Future<void> preGeneratePages({
    required List<String> pageTexts,
    required String bookId,
    int startPage = 0,
    double speed = 1.0,
    Function(int page, int total)? onProgress,
  }) async {
    if (_currentModelId == null || _currentModelPath == null) {
      await initializeWithActiveModel();
    }

    final modelId = _currentModelId;
    final modelPath = _currentModelPath;

    if (modelId == null || modelPath == null) {
      debugPrint('[TtsController] Cannot pre-generate: no model');
      return;
    }

    if (!_ttsService.isSherpaInitialized) {
      try {
        debugPrint(
          '[TtsController] Waiting for Sherpa initialization for preGeneratePages...',
        );
        await _waitForSherpaInitialization();
      } catch (e) {
        debugPrint(
          '[TtsController] Sherpa initialization error for preGeneratePages: $e',
        );
        return;
      }
    }

    for (int i = 0; i < pageTexts.length; i++) {
      final pageNumber = startPage + i;

      final cached = await _cacheRepository.getCachedAudioForPage(
        bookId: bookId,
        pageNumber: pageNumber,
        modelId: modelId,
        speed: speed,
      );

      if (cached == null) {
        final result = await _ttsService.generateAudio(
          text: pageTexts[i],
          modelPath: modelPath,
          speed: speed,
        );

        if (result != null) {
          await _cacheRepository.saveToCache(
            text: pageTexts[i],
            modelId: modelId,
            audioData: result.audioData,
            duration: result.duration,
            speed: speed,
            bookId: bookId,
            pageNumber: pageNumber,
          );
        }
      }

      onProgress?.call(i + 1, pageTexts.length);
    }
  }

  /// Check if page audio is cached
  Future<bool> isPageCached({
    required String bookId,
    required int pageNumber,
    double speed = 1.0,
  }) async {
    if (_currentModelId == null) return false;

    if (!_ttsService.isSherpaInitialized) {
      try {
        debugPrint(
          '[TtsController] Waiting for Sherpa initialization for isPageCached...',
        );
        await _waitForSherpaInitialization();
      } catch (e) {
        debugPrint(
          '[TtsController] Sherpa initialization error for isPageCached: $e',
        );
        return false;
      }
    }

    final cached = await _cacheRepository.getCachedAudioForPage(
      bookId: bookId,
      pageNumber: pageNumber,
      modelId: _currentModelId!,
      speed: speed,
    );

    return cached != null;
  }

  /// Get cache stats
  Future<Map<String, dynamic>> getCacheStats() async {
    final entries = await getGeneratedAudioList();
    final totalSize = await getGeneratedAudioTotalSize();
    final formattedSize = await getGeneratedAudioFormattedSize();

    return {
      'entries': entries.length,
      'totalSizeBytes': totalSize,
      'formattedSize': formattedSize,
      'oldestEntry': entries.isNotEmpty ? entries.last.createdAt : null,
      'newestEntry': entries.isNotEmpty ? entries.first.createdAt : null,
    };
  }

  /// Clear cache for book
  Future<void> clearCacheForBook(String bookId) async {
    await _cacheRepository.deleteCacheForBook(bookId);
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    await _cacheRepository.clearAllCache();
  }

  void _handleCompletion(BuildContext context, bool showUi) {
    if (showUi) {
      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) {
          hidePlayer(context);
        }
      });
    }
  }

  void _showNoModelError(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No TTS model available'),
        action: SnackBarAction(
          label: 'Download',
          onPressed: () {
            Navigator.pushNamed(context, '/models');
          },
        ),
      ),
    );
  }

  void _showInitializationError(BuildContext context, String error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('TTS initialization failed: $error'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            initializeWithActiveModel();
          },
        ),
      ),
    );
  }

  /// Show floating player
  void showPlayer(BuildContext context, {String? text, String? modelName}) {
    if (!_isOverlayShown) {
      TtsOverlayManager.show(
        context,
        text: text,
        modelName: modelName ?? _currentModelName,
      );
      _isOverlayShown = true;
    } else {
      TtsOverlayManager.updateText(text);
    }
  }

  /// Hide floating player
  void hidePlayer(BuildContext context) {
    if (_isOverlayShown) {
      TtsOverlayManager.hide();
      _isOverlayShown = false;
    }
  }

  /// Force stop everything without context (for dispose)
  void forceStop() {
    try {
      // Stop audio player
      _audioPlayer.forceStop();
      // ✅ Notify audio service
      if (_audioHandler != null) {
        _audioHandler!.stop();
      }
      // Hide overlay if shown
      if (_isOverlayShown) {
        TtsOverlayManager.forceHide();
        _isOverlayShown = false;
      }
    } catch (e) {
      debugPrint('[TtsController] Force stop error: $e');
    }
  }

  Future<void> play() async {
    try {
      await _audioPlayer.play();
      if (_audioHandler != null) {
        await _audioHandler!.play();
      }
    } catch (e) {
      debugPrint('[TtsController] Play error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();

      // ✅ Notify audio service
      if (_audioHandler != null) {
        await _audioHandler!.pause();
      }
    } catch (e) {
      debugPrint('[TtsController] Pause error: $e');
    }
  }

  Future<void> togglePlayPause() => _audioPlayer.togglePlayPause();

  Future<void> stop(BuildContext context) async {
    try {
      await _audioPlayer.stop();

      // ✅ Notify audio service
      if (_audioHandler != null) {
        await _audioHandler!.stop();
      }

      if (context.mounted) {
        hidePlayer(context);
      }
    } catch (e) {
      debugPrint('[TtsController] Stop error: $e');
    }
  }

  Future<void> seek(Duration position) => _audioPlayer.seek(position);
  Future<void> seekToPercentage(double percentage) =>
      _audioPlayer.seekToPercentage(percentage);

  Future<void> setSpeed(double speed) async {
    _currentSpeed = speed;
    await _audioPlayer.setSpeed(speed);
  }

  /// Reset disposed state (for reuse)
  void reset() {}

  /// Switch model
  Future<bool> switchModel({
    required String modelPath,
    required String modelId,
    String? modelName,
  }) async {
    _currentModelId = modelId;
    _currentModelName = modelName;
    _currentModelPath = modelPath;
    _currentModel = null; // Will be set when model is loaded

    return await _ttsService.setDefaultModel(
      modelPath: modelPath,
      modelName: modelName,
    );
  }

  /// Generate audio with auto language detection and model selection
  ///
  /// [text] - Text to convert to speech
  /// [language] - Optional language hint (auto-detects if null)
  /// [speed] - Playback speed
  /// [speakerId] - Speaker ID for multi-speaker models
  /// [useCache] - Whether to use cache
  /// [bookId] - Optional book ID for cache
  /// [pageNumber] - Optional page number for cache
  ///
  /// Returns cached path if exists, otherwise generates new audio.
  Future<GenerateResult> generateAudio({
    required String text,
    String? language,
    double speed = 1.0,
    int speakerId = 0,
    bool useCache = true,
    String? bookId,
    int? pageNumber,
    void Function(double progress)? onProgress,
  }) async {
    if (text.trim().isEmpty) {
      return GenerateResult.failure('Text cannot be empty');
    }

    debugPrint(
      '[TtsController] generateAudio: "${text.substring(0, text.length.clamp(0, 50))}..."',
    );

    try {
      // Detect language if not provided
      String? detectedLang = language;
      if (detectedLang == null || detectedLang.isEmpty) {
        final detected = _langDetector.detect(text);
        detectedLang = detected?.code;
        if (detected != null) {
          debugPrint(
            '[TtsController] Detected: ${detected.name} (${(detected.confidence * 100).toStringAsFixed(0)}%)',
          );
        }
      }

      // Select model
      final selectedModel = await _selectModel(detectedLang);
      if (selectedModel == null) {
        return GenerateResult.failure(
          'No TTS model available${detectedLang != null ? ' for $detectedLang' : ''}',
        );
      }

      // Update current model if different
      if (_currentModelId != selectedModel.id) {
        _currentModelId = selectedModel.id;
        _currentModelName = selectedModel.name;
        _currentModelPath = selectedModel.path;

        await _ttsService.setDefaultModel(modelPath: selectedModel.path);
      }

      // Ensure Sherpa initialized
      if (!_ttsService.isSherpaInitialized) {
        await _waitForSherpaInitialization();
      }

      // Check cache
      if (useCache) {
        final cached = await _cacheRepository.getCachedAudio(
          text: text,
          modelId: selectedModel.id,
          speed: speed,
          speakerId: speakerId,
        );

        if (cached != null) {
          debugPrint('[TtsController] Cache hit');

          Uint8List? audioData;
          try {
            final file = File(cached.filePath);
            if (await file.exists()) {
              audioData = await file.readAsBytes();
            }
          } catch (_) {}

          return GenerateResult.success(
            audioPath: cached.filePath,
            audioData: audioData,
            duration: Duration(milliseconds: cached.durationMs),
            fromCache: true,
            modelUsed: selectedModel.name,
            languageDetected: detectedLang,
          );
        }
      }

      // Generate new audio
      debugPrint('[TtsController] Generating with: ${selectedModel.name}');

      final result = await _ttsService.generateAudioWithChunks(
        text: text,
        modelPath: selectedModel.path,
        speed: speed,
        speakerId: speakerId,
        onProgress: onProgress,
      );

      if (result == null || result.filePath == null) {
        return GenerateResult.failure('Audio generation failed');
      }

      // Save to cache
      if (useCache) {
        await _cacheRepository.saveToCache(
          text: text,
          modelId: selectedModel.id,
          audioData: result.audioData,
          duration: result.duration,
          speed: speed,
          speakerId: speakerId,
          bookId: bookId,
          pageNumber: pageNumber,
        );
      }

      return GenerateResult.success(
        audioPath: result.filePath!,
        audioData: result.audioData,
        duration: result.duration,
        fromCache: false,
        modelUsed: selectedModel.name,
        languageDetected: detectedLang,
      );
    } catch (e, st) {
      debugPrint('[TtsController] generateAudio error: $e\n$st');
      return GenerateResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SPEAK WITH LANGUAGE (BLOCKING)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Speak with auto language detection (BLOCKING)
  /// Waits for completion before returning
  Future<bool> speakWithLanguage({
    required String text,
    required BuildContext context,
    String? language,
    double speed = 1.0,
    int speakerId = 0,
    bool showUi = true,
    bool useCache = true,
    String? bookId,
    int? pageNumber,
    Function(TtsPlaybackState state)? onStateChanged,
    Function(double progress)? onProgress,
    Function(String error)? onError,
    VoidCallback? onCompleted,
  }) async {
    if (text.trim().isEmpty) {
      onError?.call('No text to speak');
      return false;
    }

    // Generate audio with language selection
    final result = await generateAudio(
      text: text,
      language: language,
      speed: speed,
      speakerId: speakerId,
      useCache: useCache,
      bookId: bookId,
      pageNumber: pageNumber,
    );

    if (!result.success || result.audioPath == null) {
      final error = result.error ?? 'Failed to generate audio';
      onError?.call(error);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return false;
    }

    // Show UI
    if (showUi && context.mounted) {
      showPlayer(context, text: text, modelName: result.modelUsed);
    }

    // Play audio
    final request = TtsRequest(
      text: text,
      modelPath: _currentModelPath,
      speed: speed,
      speakerId: speakerId,
      showUi: showUi,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: () {
        onCompleted?.call();
        _handleCompletion(context, showUi);
      },
    );

    return await _audioPlayer.playFromFile(result.audioPath!, request: request);
  }

  /// Speak page with auto language detection (BLOCKING)
  Future<bool> speakPageWithLanguage({
    required String text,
    required BuildContext context,
    required String bookId,
    required int pageNumber,
    String? language,
    double speed = 1.0,
    int speakerId = 0,
    bool showUi = true,
    Function(TtsPlaybackState state)? onStateChanged,
    Function(double progress)? onProgress,
    Function(String error)? onError,
    VoidCallback? onCompleted,
  }) async {
    return speakWithLanguage(
      text: text,
      context: context,
      language: language,
      speed: speed,
      speakerId: speakerId,
      showUi: showUi,
      useCache: true,
      bookId: bookId,
      pageNumber: pageNumber,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: onCompleted,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SPEAK WITH LANGUAGE ASYNC (NON-BLOCKING)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Speak with auto language detection (NON-BLOCKING)
  /// Returns task ID immediately
  String speakWithLanguageAsync({
    required String text,
    String? language,
    BuildContext? context,
    String? bookId,
    int? pageNumber,
    bool showUi = true,
    double speed = 1.0,
    int speakerId = 0,
    bool useCache = true,
    Function(TtsPlaybackState)? onStateChanged,
    Function(double)? onProgress,
    Function(String)? onError,
    VoidCallback? onCompleted,
  }) {
    if (text.trim().isEmpty) {
      onError?.call('No text to speak');
      return '';
    }

    _initQueueManager();
    onStateChanged?.call(TtsPlaybackState.loading);

    // Detect language and select model in background
    _selectModelForLanguageAsync(language ?? _langDetector.detectCode(text));

    return _queueManager.speak(
      text: text,
      bookId: bookId,
      pageNumber: pageNumber,
      speed: speed,
      speakerId: speakerId,
      showUi: showUi,
      useCache: useCache,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: onCompleted,
    );
  }

  /// Speak page with auto language detection (NON-BLOCKING)
  String speakPageWithLanguageAsync({
    required String text,
    required String bookId,
    required int pageNumber,
    String? language,
    BuildContext? context,
    bool showUi = true,
    double speed = 1.0,
    int speakerId = 0,
    Function(TtsPlaybackState)? onStateChanged,
    Function(double)? onProgress,
    Function(String)? onError,
    VoidCallback? onCompleted,
  }) {
    return speakWithLanguageAsync(
      text: text,
      language: language,
      bookId: bookId,
      pageNumber: pageNumber,
      showUi: showUi,
      speed: speed,
      speakerId: speakerId,
      useCache: true,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: onCompleted,
    );
  }

  void _selectModelForLanguageAsync(String? language) {
    Future.microtask(() async {
      try {
        final model = await _selectModel(language);
        if (model != null && _currentModelId != model.id) {
          _currentModelId = model.id;
          _currentModelName = model.name;
          _currentModelPath = model.path;
          await _ttsService.setDefaultModel(
            modelPath: model.path,
            modelName: model.name,
          );
        }
      } catch (e) {
        debugPrint('[TtsController] Async model selection error: $e');
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STOP ALL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stop all TTS processes
  Future<void> stopAll([BuildContext? context]) async {
    debugPrint('[TtsController] Stopping all...');

    try {
      cancelAllTasks();
      await _audioPlayer.stop();

      if (context != null && context.mounted) {
        hidePlayer(context);
      } else {
        TtsOverlayManager.forceHide();
        _isOverlayShown = false;
      }
    } catch (e) {
      debugPrint('[TtsController] stopAll error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get available languages with TTS models
  Future<List<String>> getAvailableLanguages() async {
    if (_modelService == null) return [];

    try {
      final ttsModels = await _modelService!.getModelsByType(
        SherpaModelType.tts,
      );
      final downloaded = ttsModels.where((m) => m.isDownloaded).toList();

      final languages = <String>{};
      for (final model in downloaded) {
        languages.add(_normalizeLanguage(model.language));
      }
      languages.addAll(_languageModelMap.keys);

      return languages.toList()..sort();
    } catch (e) {
      return [];
    }
  }

  /// Check if language has available model
  Future<bool> isLanguageAvailable(String language) async {
    final model = await _findModelForLanguage(language);
    return model != null;
  }

  Future<void> dispose() async {
    try {
      // ✅ Unregister audio handler first
      unregisterAudioHandler();

      _queueManager.dispose();
      await _audioPlayer.dispose();
      _ttsService.dispose();
      await _cacheRepository.close();
      _instance = null;
    } catch (e) {
      debugPrint('[TtsController] Dispose error: $e');
    }
  }
}

/// Summary of cached audio for a book
class CacheBookSummary {
  final String bookId;
  final int entryCount;
  final Duration totalDuration;
  final int totalSizeBytes;
  final List<int> pages;

  CacheBookSummary({
    required this.bookId,
    required this.entryCount,
    required this.totalDuration,
    required this.totalSizeBytes,
    required this.pages,
  });

  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    final seconds = totalDuration.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  int get pagesCached => pages.length;
}

// ═══════════════════════════════════════════════════════════════════════════
// GENERATE AUDIO WITH LANGUAGE
// ═══════════════════════════════════════════════════════════════════════════

/// Result of audio generation with language support
class GenerateResult {
  final bool success;
  final String? audioPath;
  final Uint8List? audioData;
  final Duration? duration;
  final bool fromCache;
  final String? modelUsed;
  final String? languageDetected;
  final String? error;

  const GenerateResult._({
    required this.success,
    this.audioPath,
    this.audioData,
    this.duration,
    this.fromCache = false,
    this.modelUsed,
    this.languageDetected,
    this.error,
  });

  factory GenerateResult.success({
    required String audioPath,
    Uint8List? audioData,
    Duration? duration,
    bool fromCache = false,
    String? modelUsed,
    String? languageDetected,
  }) {
    return GenerateResult._(
      success: true,
      audioPath: audioPath,
      audioData: audioData,
      duration: duration,
      fromCache: fromCache,
      modelUsed: modelUsed,
      languageDetected: languageDetected,
    );
  }

  factory GenerateResult.failure(String error) {
    return GenerateResult._(success: false, error: error);
  }
}
