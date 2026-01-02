import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/tts_request.dart';
import '../services/tts_audio_player.dart';
import '../services/tts_service.dart';
import '../services/model_download_service.dart';
import '../services/language_detection_service.dart';
import '../tts_controller.dart';

// ==================== STATE PROVIDERS ====================

/// TTS initialization state
final ttsInitializedProvider = StateProvider<bool>((ref) => false);

/// TTS is currently initializing
final ttsInitializingProvider = StateProvider<bool>((ref) => false);

/// TTS initialization error
final ttsInitErrorProvider = StateProvider<String?>((ref) => null);

/// TTS status stream
final ttsStatusProvider = StreamProvider<TtsStatus>((ref) {
  return TtsAudioPlayer.instance.statusStream;
});

/// Current model name
final currentTtsModelProvider = StateProvider<String?>((ref) {
  return TtsController.instance.currentModelName;
});

/// Current playback speed
final ttsSpeedProvider = StateProvider<double>((ref) {
  return TtsController.instance.currentSpeed;
});

/// Is currently speaking
final ttsSpeakingProvider = StreamProvider<bool>((ref) {
  return TtsAudioPlayer.instance.statusStream.map((status) {
    return status.state == TtsPlaybackState.playing ||
        status.state == TtsPlaybackState.generating ||
        status.state == TtsPlaybackState.loading;
  });
});

// ==================== CACHE PROVIDERS ====================

/// Cache statistics
final ttsCacheStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return TtsController.instance.getCacheStats();
});

/// All cached audio entries
final ttsCachedEntriesProvider = FutureProvider<List<CachedAudioEntry>>((
  ref,
) async {
  return TtsController.instance.getGeneratedAudioList();
});

/// Cached audio entries for a specific book
final ttsBookCachedEntriesProvider =
    FutureProvider.family<List<CachedAudioEntry>, String>((ref, bookId) async {
      return TtsController.instance.getGeneratedAudioForBook(bookId);
    });

/// Cache summary by book
final ttsCacheSummaryProvider = FutureProvider<Map<String, CacheBookSummary>>((
  ref,
) async {
  return TtsController.instance.getCacheSummaryByBook();
});

/// Total cache size formatted
final ttsCacheSizeProvider = FutureProvider<String>((ref) async {
  return TtsController.instance.getGeneratedAudioFormattedSize();
});

/// Check if a specific page is cached
final ttsPageCachedProvider =
    FutureProvider.family<bool, ({String bookId, int pageNumber})>((
      ref,
      params,
    ) async {
      return TtsController.instance.isPageCached(
        bookId: params.bookId,
        pageNumber: params.pageNumber,
      );
    });

// ==================== TTS CONTROLLER PROVIDER ====================

/// TTS Controller Provider
final ttsControllerProvider = Provider<TtsControllerNotifier>((ref) {
  return TtsControllerNotifier(ref);
});

class TtsControllerNotifier {
  final Ref _ref;
  final TtsController _controller = TtsController.instance;

  TtsControllerNotifier(this._ref);

  // ==================== GETTERS ====================

  bool get isInitialized => _controller.isInitialized;
  bool get isSherpaInitialized => _controller.isSherpaInitialized;
  String? get currentModelName => _controller.currentModelName;
  String? get currentModelId => _controller.currentModelId;
  String? get currentModelPath => _controller.currentModelPath;
  double get currentSpeed => _controller.currentSpeed;
  TtsStatus get currentStatus => _controller.currentStatus;

  // ==================== INITIALIZATION ====================

  /// Initialize TTS with model download service
  Future<void> init(ModelDownloadService modelService) async {
    await _controller.init(modelService);
  }

  /// Set model service
  void setModelService(ModelDownloadService modelService) {
    _controller.setModelService(modelService);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LANGUAGE DETECTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Detect language from text
  DetectedLanguage? detectLanguage(String text) {
    return _controller.detectLanguage(text);
  }

  /// Detect language code with fallback
  String detectLanguageCode(String text, {String fallback = 'en'}) {
    return _controller.detectLanguageCode(text, fallback: fallback);
  }

  /// Register language-model mapping
  void registerLanguageModel(String language, String modelId) {
    _controller.registerLanguageModel(language, modelId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERATE AUDIO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate audio with auto language detection
  Future<GenerateResult> generateAudioWithLanguage({
    required String text,
    String? language,
    double speed = 1.0,
    int speakerId = 0,
    bool useCache = true,
    String? bookId,
    int? pageNumber,
  }) async {
    final result = await _controller.generateAudio(
      text: text,
      language: language,
      speed: speed,
      speakerId: speakerId,
      useCache: useCache,
      bookId: bookId,
      pageNumber: pageNumber,
    );

    if (result.success) {
      _refreshCacheProviders();
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SPEAK WITH LANGUAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Speak with auto language detection (BLOCKING)
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
    return await _controller.speakWithLanguage(
      text: text,
      context: context,
      language: language,
      speed: speed,
      speakerId: speakerId,
      showUi: showUi,
      useCache: useCache,
      bookId: bookId,
      pageNumber: pageNumber,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: () {
        onCompleted?.call();
        _refreshCacheProviders();
      },
    );
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
    return await _controller.speakPageWithLanguage(
      text: text,
      context: context,
      bookId: bookId,
      pageNumber: pageNumber,
      language: language,
      speed: speed,
      speakerId: speakerId,
      showUi: showUi,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: () {
        onCompleted?.call();
        _refreshCacheProviders();
      },
    );
  }

  /// Speak with auto detection (NON-BLOCKING)
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
    return _controller.speakWithLanguageAsync(
      text: text,
      language: language,
      bookId: bookId,
      pageNumber: pageNumber,
      showUi: showUi,
      speed: speed,
      speakerId: speakerId,
      useCache: useCache,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: () {
        onCompleted?.call();
        _refreshCacheProviders();
      },
    );
  }

  /// Speak page with auto detection (NON-BLOCKING)
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
    return _controller.speakPageWithLanguageAsync(
      text: text,
      bookId: bookId,
      pageNumber: pageNumber,
      language: language,
      showUi: showUi,
      speed: speed,
      speakerId: speakerId,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: () {
        onCompleted?.call();
        _refreshCacheProviders();
      },
    );
  }

  /// Stop all TTS processes
  Future<void> stopAll([BuildContext? context]) async {
    await _controller.stopAll(context);
  }

  /// Get available languages
  Future<List<String>> getAvailableLanguages() async {
    return _controller.getAvailableLanguages();
  }

  /// Check if language is available
  Future<bool> isLanguageAvailable(String language) async {
    return _controller.isLanguageAvailable(language);
  }

  /// Initialize with specific model
  Future<bool> initializeWithModel({
    required String modelPath,
    String? modelName,
  }) async {
    _ref.read(ttsInitializingProvider.notifier).state = true;
    _ref.read(ttsInitErrorProvider.notifier).state = null;

    try {
      final result = await _controller.initializeWithModel(
        modelPath: modelPath,
        modelName: modelName,
      );

      _ref.read(ttsInitializedProvider.notifier).state = result;
      _ref.read(currentTtsModelProvider.notifier).state = modelName;
      _ref.read(ttsInitializingProvider.notifier).state = false;

      if (!result) {
        _ref.read(ttsInitErrorProvider.notifier).state =
            'Failed to initialize model';
      }

      return result;
    } catch (e) {
      _ref.read(ttsInitializingProvider.notifier).state = false;
      _ref.read(ttsInitErrorProvider.notifier).state = e.toString();
      return false;
    }
  }

  /// Initialize with active TTS model
  Future<bool> initializeWithActiveModel() async {
    _ref.read(ttsInitializingProvider.notifier).state = true;
    _ref.read(ttsInitErrorProvider.notifier).state = null;

    try {
      final result = await _controller.initializeWithActiveModel();

      _ref.read(ttsInitializedProvider.notifier).state = result;
      _ref.read(currentTtsModelProvider.notifier).state =
          _controller.currentModelName;
      _ref.read(ttsInitializingProvider.notifier).state = false;

      if (!result) {
        _ref.read(ttsInitErrorProvider.notifier).state =
            'No active TTS model available';
      }

      return result;
    } catch (e) {
      _ref.read(ttsInitializingProvider.notifier).state = false;
      _ref.read(ttsInitErrorProvider.notifier).state = e.toString();
      return false;
    }
  }

  // ==================== SPEAK METHODS ====================

  /// Speak text (uses default model if modelPath not provided)
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
    return await _controller.speak(
      text: text,
      context: context,
      modelPath: modelPath,
      modelId: modelId,
      modelName: modelName,
      showUi: showUi,
      speed: speed,
      speakerId: speakerId,
      bookId: bookId,
      pageNumber: pageNumber,
      useCache: useCache,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onAudioGenerated: onAudioGenerated,
      onError: onError,
      onCompleted: () {
        onCompleted?.call();
        _refreshCacheProviders();
      },
    );
  }

  /// Speak page content with caching
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
    return await _controller.speakPage(
      text: text,
      context: context,
      bookId: bookId,
      pageNumber: pageNumber,
      showUi: showUi,
      speed: speed,
      speakerId: speakerId,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: () {
        onCompleted?.call();
        _refreshCacheProviders();
      },
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
    return await _controller.speakSelection(
      text: text,
      context: context,
      showUi: showUi,
      speed: speed,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: () {
        onCompleted?.call();
        _refreshCacheProviders();
      },
    );
  }

  // ==================== GENERATE METHODS ====================

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
    final result = await _controller.generateOnly(
      text: text,
      modelPath: modelPath,
      modelId: modelId,
      speed: speed,
      speakerId: speakerId,
      useCache: useCache,
      bookId: bookId,
      pageNumber: pageNumber,
    );

    if (result != null) {
      _refreshCacheProviders();
    }

    return result;
  }

  /// Pre-generate audio for pages
  Future<void> preGeneratePages({
    required List<String> pageTexts,
    required String bookId,
    int startPage = 0,
    double speed = 1.0,
    Function(int page, int total)? onProgress,
  }) async {
    await _controller.preGeneratePages(
      pageTexts: pageTexts,
      bookId: bookId,
      startPage: startPage,
      speed: speed,
      onProgress: onProgress,
    );

    _refreshCacheProviders();
  }

  // ==================== CACHE METHODS ====================

  /// Get all generated audio entries
  Future<List<CachedAudioEntry>> getGeneratedAudioList({
    CachedAudioFilter? filter,
  }) async {
    return _controller.getGeneratedAudioList(filter: filter);
  }

  /// Get generated audio for a specific book
  Future<List<CachedAudioEntry>> getGeneratedAudioForBook(String bookId) async {
    return _controller.getGeneratedAudioForBook(bookId);
  }

  /// Get generated audio count
  Future<int> getGeneratedAudioCount({String? bookId, String? modelId}) async {
    return _controller.getGeneratedAudioCount(bookId: bookId, modelId: modelId);
  }

  /// Get total size of generated audio
  Future<int> getGeneratedAudioTotalSize({String? bookId}) async {
    return _controller.getGeneratedAudioTotalSize(bookId: bookId);
  }

  /// Get formatted total size
  Future<String> getGeneratedAudioFormattedSize({String? bookId}) async {
    return _controller.getGeneratedAudioFormattedSize(bookId: bookId);
  }

  /// Check if page audio is cached
  Future<bool> isPageCached({
    required String bookId,
    required int pageNumber,
    double speed = 1.0,
  }) async {
    return _controller.isPageCached(
      bookId: bookId,
      pageNumber: pageNumber,
      speed: speed,
    );
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
    return _controller.playCachedEntry(
      entry: entry,
      context: context,
      showUi: showUi,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: onCompleted,
    );
  }

  /// Delete a cached audio entry
  Future<bool> deleteCachedEntry(CachedAudioEntry entry) async {
    final result = await _controller.deleteCachedEntry(entry);
    if (result) {
      _refreshCacheProviders();
    }
    return result;
  }

  /// Delete multiple cached audio entries
  Future<int> deleteCachedEntries(List<CachedAudioEntry> entries) async {
    final result = await _controller.deleteCachedEntries(entries);
    if (result > 0) {
      _refreshCacheProviders();
    }
    return result;
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    return _controller.getCacheStats();
  }

  /// Get cache summary by book
  Future<Map<String, CacheBookSummary>> getCacheSummaryByBook() async {
    return _controller.getCacheSummaryByBook();
  }

  /// Get unique book IDs with cached audio
  Future<List<String>> getBooksWithCachedAudio() async {
    return _controller.getBooksWithCachedAudio();
  }

  /// Clear cache for a specific book
  Future<void> clearCacheForBook(String bookId) async {
    await _controller.clearCacheForBook(bookId);
    _refreshCacheProviders();
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    await _controller.clearAllCache();
    _refreshCacheProviders();
  }

  /// Export cached audio entry
  Future<String?> exportCachedEntry({
    required CachedAudioEntry entry,
    required String destinationPath,
  }) async {
    return _controller.exportCachedEntry(
      entry: entry,
      destinationPath: destinationPath,
    );
  }

  // ==================== MODEL METHODS ====================

  /// Switch model
  Future<bool> switchModel({
    required String modelPath,
    required String modelId,
    String? modelName,
  }) async {
    final result = await _controller.switchModel(
      modelPath: modelPath,
      modelId: modelId,
      modelName: modelName,
    );

    _ref.read(currentTtsModelProvider.notifier).state = modelName;
    return result;
  }

  // ==================== PLAYBACK CONTROLS ====================

  /// Show floating player
  void showPlayer(BuildContext context, {String? text, String? modelName}) {
    _controller.showPlayer(context, text: text, modelName: modelName);
  }

  /// Hide floating player
  void hidePlayer(BuildContext context) {
    _controller.hidePlayer(context);
  }

  /// Play
  Future<void> play() => _controller.play();

  /// Pause
  Future<void> pause() => _controller.pause();

  /// Toggle play/pause
  Future<void> togglePlayPause() => _controller.togglePlayPause();

  /// Stop
  Future<void> stop(BuildContext context) => _controller.stop(context);

  /// Seek to position
  Future<void> seek(Duration position) => _controller.seek(position);

  /// Seek to percentage
  Future<void> seekToPercentage(double percentage) =>
      _controller.seekToPercentage(percentage);

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _controller.setSpeed(speed);
    _ref.read(ttsSpeedProvider.notifier).state = speed;
  }

  // ==================== PRIVATE METHODS ====================

  /// Refresh cache-related providers
  void _refreshCacheProviders() {
    _ref.invalidate(ttsCacheStatsProvider);
    _ref.invalidate(ttsCachedEntriesProvider);
    _ref.invalidate(ttsCacheSummaryProvider);
    _ref.invalidate(ttsCacheSizeProvider);
  }

  /// Dispose
  Future<void> dispose() async {
    await _controller.dispose();
  }
}

// ==================== HELPER EXTENSIONS ====================

extension TtsProviderExtensions on WidgetRef {
  /// Get TTS controller notifier
  TtsControllerNotifier get tts => read(ttsControllerProvider);

  /// Check if TTS is initialized
  bool get isTtsInitialized => read(ttsInitializedProvider);

  /// Check if TTS is initializing
  bool get isTtsInitializing => read(ttsInitializingProvider);

  /// Get current TTS model name
  String? get ttsModelName => read(currentTtsModelProvider);

  /// Get current TTS speed
  double get ttsSpeed => read(ttsSpeedProvider);
}
