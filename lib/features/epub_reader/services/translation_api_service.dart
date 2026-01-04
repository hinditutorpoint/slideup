import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api.dart';
import '../../speaker_player/services/language_detection_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CANCELLATION TOKEN
// ═══════════════════════════════════════════════════════════════════════════

class TranslationCancelToken {
  bool _isCancelled = false;
  final List<VoidCallback> _listeners = [];
  Completer<void>? _cancelCompleter;

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancelCompleter?.complete();
    for (final listener in _listeners) {
      listener();
    }
    _listeners.clear();
    debugPrint('🛑 Translation cancelled');
  }

  void addListener(VoidCallback listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw TranslationCancelledException();
    }
  }

  Future<void> get whenCancelled {
    _cancelCompleter ??= Completer<void>();
    if (_isCancelled) {
      return Future.value();
    }
    return _cancelCompleter!.future;
  }

  void reset() {
    _isCancelled = false;
    _cancelCompleter = null;
    _listeners.clear();
  }
}

class TranslationCancelledException implements Exception {
  final String message;
  TranslationCancelledException([this.message = 'Translation was cancelled']);

  @override
  String toString() => message;
}

// ═══════════════════════════════════════════════════════════════════════════
// TRANSLATION RESULT
// ═══════════════════════════════════════════════════════════════════════════

class TranslationResult {
  /// The translated text/body (null if cancelled or error)
  final String? translatedText;

  /// The translated title (null if no title provided)
  final String? translatedTitle;

  /// Original text/body before translation
  final String? originalText;

  /// Original title before translation
  final String? originalTitle;

  /// Detected source language code (e.g., 'en', 'hi')
  final String? sourceLanguage;

  /// Source language name (e.g., 'English', 'Hindi')
  final String? sourceLanguageName;

  /// Detection confidence (0.0 to 1.0)
  final double? sourceLanguageConfidence;

  /// Target language code (e.g., 'en', 'hi')
  final String? targetLanguage;

  /// Target language name (e.g., 'English', 'Hindi')
  final String? targetLanguageName;

  /// Whether translation was cancelled
  final bool isCancelled;

  /// Error message if translation failed
  final String? error;

  /// Number of chunks completed
  final int chunksCompleted;

  /// Total number of chunks
  final int totalChunks;

  /// Time taken for translation
  final Duration? duration;

  const TranslationResult._({
    this.translatedText,
    this.translatedTitle,
    this.originalText,
    this.originalTitle,
    this.sourceLanguage,
    this.sourceLanguageName,
    this.sourceLanguageConfidence,
    this.targetLanguage,
    this.targetLanguageName,
    this.isCancelled = false,
    this.error,
    this.chunksCompleted = 0,
    this.totalChunks = 0,
    this.duration,
  });

  /// Create a successful result
  factory TranslationResult.success({
    required String translatedText,
    String? translatedTitle,
    required String originalText,
    String? originalTitle,
    required String sourceLanguage,
    required String sourceLanguageName,
    required double sourceLanguageConfidence,
    required String targetLanguage,
    required String targetLanguageName,
    int chunksCompleted = 1,
    int totalChunks = 1,
    Duration? duration,
  }) => TranslationResult._(
    translatedText: translatedText,
    translatedTitle: translatedTitle,
    originalText: originalText,
    originalTitle: originalTitle,
    sourceLanguage: sourceLanguage,
    sourceLanguageName: sourceLanguageName,
    sourceLanguageConfidence: sourceLanguageConfidence,
    targetLanguage: targetLanguage,
    targetLanguageName: targetLanguageName,
    chunksCompleted: chunksCompleted,
    totalChunks: totalChunks,
    duration: duration,
  );

  /// Create a cancelled result
  factory TranslationResult.cancelled({
    String? originalText,
    String? originalTitle,
    String? sourceLanguage,
    String? sourceLanguageName,
    double? sourceLanguageConfidence,
    String? targetLanguage,
    String? targetLanguageName,
    int chunksCompleted = 0,
    int totalChunks = 0,
  }) => TranslationResult._(
    isCancelled: true,
    originalText: originalText,
    originalTitle: originalTitle,
    sourceLanguage: sourceLanguage,
    sourceLanguageName: sourceLanguageName,
    sourceLanguageConfidence: sourceLanguageConfidence,
    targetLanguage: targetLanguage,
    targetLanguageName: targetLanguageName,
    chunksCompleted: chunksCompleted,
    totalChunks: totalChunks,
  );

  /// Create an error result
  factory TranslationResult.error({
    required String error,
    String? originalText,
    String? originalTitle,
    String? sourceLanguage,
    String? sourceLanguageName,
    double? sourceLanguageConfidence,
    String? targetLanguage,
    String? targetLanguageName,
  }) => TranslationResult._(
    error: error,
    originalText: originalText,
    originalTitle: originalTitle,
    sourceLanguage: sourceLanguage,
    sourceLanguageName: sourceLanguageName,
    sourceLanguageConfidence: sourceLanguageConfidence,
    targetLanguage: targetLanguage,
    targetLanguageName: targetLanguageName,
  );

  /// Whether translation completed successfully
  bool get isSuccess => translatedText != null && !isCancelled && error == null;

  /// Whether a title was translated
  bool get hasTitle => translatedTitle != null && translatedTitle!.isNotEmpty;

  /// Whether source and target languages are the same
  bool get isSameLanguage => sourceLanguage == targetLanguage;

  /// Whether detection confidence is high (> 0.7)
  bool get isHighConfidence => (sourceLanguageConfidence ?? 0) > 0.7;

  /// Whether detection confidence is low (< 0.3)
  bool get isLowConfidence => (sourceLanguageConfidence ?? 0) < 0.3;

  /// Progress as a value between 0.0 and 1.0
  double get progress => totalChunks > 0 ? chunksCompleted / totalChunks : 0.0;

  /// Formatted confidence string (e.g., "85%")
  String get confidencePercent =>
      '${((sourceLanguageConfidence ?? 0) * 100).toStringAsFixed(0)}%';

  /// Language pair string (e.g., "English → Hindi")
  String get languagePair =>
      '${sourceLanguageName ?? sourceLanguage} → ${targetLanguageName ?? targetLanguage}';

  @override
  String toString() {
    if (isSuccess) {
      return 'TranslationResult.success('
          'hasTitle: $hasTitle, '
          'from: $sourceLanguage ($confidencePercent), '
          'to: $targetLanguage, '
          'chunks: $chunksCompleted/$totalChunks, '
          'duration: ${duration?.inMilliseconds}ms)';
    }
    if (isCancelled) {
      return 'TranslationResult.cancelled(at: $chunksCompleted/$totalChunks)';
    }
    return 'TranslationResult.error($error)';
  }

  /// Create a copy with updated values
  TranslationResult copyWith({
    String? translatedText,
    String? translatedTitle,
    String? originalText,
    String? originalTitle,
    String? sourceLanguage,
    String? sourceLanguageName,
    double? sourceLanguageConfidence,
    String? targetLanguage,
    String? targetLanguageName,
    bool? isCancelled,
    String? error,
    int? chunksCompleted,
    int? totalChunks,
    Duration? duration,
  }) {
    return TranslationResult._(
      translatedText: translatedText ?? this.translatedText,
      translatedTitle: translatedTitle ?? this.translatedTitle,
      originalText: originalText ?? this.originalText,
      originalTitle: originalTitle ?? this.originalTitle,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      sourceLanguageName: sourceLanguageName ?? this.sourceLanguageName,
      sourceLanguageConfidence:
          sourceLanguageConfidence ?? this.sourceLanguageConfidence,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      targetLanguageName: targetLanguageName ?? this.targetLanguageName,
      isCancelled: isCancelled ?? this.isCancelled,
      error: error ?? this.error,
      chunksCompleted: chunksCompleted ?? this.chunksCompleted,
      totalChunks: totalChunks ?? this.totalChunks,
      duration: duration ?? this.duration,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() => {
    'translatedText': translatedText,
    'translatedTitle': translatedTitle,
    'originalText': originalText,
    'originalTitle': originalTitle,
    'sourceLanguage': sourceLanguage,
    'sourceLanguageName': sourceLanguageName,
    'sourceLanguageConfidence': sourceLanguageConfidence,
    'targetLanguage': targetLanguage,
    'targetLanguageName': targetLanguageName,
    'isCancelled': isCancelled,
    'error': error,
    'chunksCompleted': chunksCompleted,
    'totalChunks': totalChunks,
    'durationMs': duration?.inMilliseconds,
  };

  /// Create from JSON map
  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult._(
      translatedText: json['translatedText'] as String?,
      translatedTitle: json['translatedTitle'] as String?,
      originalText: json['originalText'] as String?,
      originalTitle: json['originalTitle'] as String?,
      sourceLanguage: json['sourceLanguage'] as String?,
      sourceLanguageName: json['sourceLanguageName'] as String?,
      sourceLanguageConfidence: json['sourceLanguageConfidence'] as double?,
      targetLanguage: json['targetLanguage'] as String?,
      targetLanguageName: json['targetLanguageName'] as String?,
      isCancelled: json['isCancelled'] as bool? ?? false,
      error: json['error'] as String?,
      chunksCompleted: json['chunksCompleted'] as int? ?? 0,
      totalChunks: json['totalChunks'] as int? ?? 0,
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRANSLATION REQUEST
// ═══════════════════════════════════════════════════════════════════════════

/// Input for translation with optional title
class TranslationRequest {
  final String text;
  final String? title;
  final String targetLanguage;

  const TranslationRequest({
    required this.text,
    this.title,
    required this.targetLanguage,
  });

  bool get hasTitle => title != null && title!.trim().isNotEmpty;
}

// ═══════════════════════════════════════════════════════════════════════════
// TRANSLATION SERVICE
// ═══════════════════════════════════════════════════════════════════════════

class TranslationApiService {
  static final TranslationApiService _instance = TranslationApiService._();
  static TranslationApiService get instance => _instance;
  TranslationApiService._();

  // Configuration
  static const int _maxChunkSize = 450;
  static const Duration _rateLimitDelay = Duration(milliseconds: 300);
  static const Duration _requestTimeout = Duration(seconds: 30);

  // Services
  final _detector = LanguageDetectionService.instance;

  // Track active translations
  final Map<String, TranslationCancelToken> _activeTranslations = {};

  // ═══════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════

  Future<String> detectedLanguage(String text) async {
    final detection = _detector.detect(text);
    return detection?.code ?? 'en';
  }

  /// Translate text with optional title
  ///
  /// [text] - Main text/body to translate
  /// [targetLang] - Target language code
  /// [title] - Optional title to translate
  /// [cancelToken] - Optional cancellation token
  /// [onProgress] - Optional progress callback (0.0 to 1.0)
  /// [taskId] - Optional task ID for tracking
  Future<TranslationResult> translate(
    String text,
    String targetLang, {
    String? title,
    TranslationCancelToken? cancelToken,
    void Function(double progress)? onProgress,
    String? taskId,
  }) async {
    final stopwatch = Stopwatch()..start();
    final token = cancelToken ?? TranslationCancelToken();
    final id = taskId ?? DateTime.now().microsecondsSinceEpoch.toString();

    // Track this translation
    _activeTranslations[id] = token;

    // Detect source language (use title + text for better detection)
    final combinedText = [if (title != null) title, text].join(' ');
    final detection = _detector.detect(combinedText);
    final sourceLang = detection?.code ?? 'en';
    final sourceLangName = detection?.name ?? _detector.getLanguageName('en');
    final sourceConfidence = detection?.confidence ?? 0.3;
    final targetLangName = _detector.getLanguageName(targetLang);

    debugPrint(
      '🔍 Detected: $sourceLang ($sourceLangName) - '
      '${(sourceConfidence * 100).toStringAsFixed(1)}% confidence',
    );

    try {
      // Check cancellation before starting
      token.throwIfCancelled();

      // Same language - no translation needed
      if (sourceLang == targetLang) {
        stopwatch.stop();
        onProgress?.call(1.0);
        debugPrint('⏭️ Skipping: source and target are same ($sourceLang)');
        return TranslationResult.success(
          translatedText: text,
          translatedTitle: title,
          originalText: text,
          originalTitle: title,
          sourceLanguage: sourceLang,
          sourceLanguageName: sourceLangName,
          sourceLanguageConfidence: sourceConfidence,
          targetLanguage: targetLang,
          targetLanguageName: targetLangName,
          duration: stopwatch.elapsed,
        );
      }

      // Calculate total work (title counts as 1 chunk)
      final hasTitle = title != null && title.trim().isNotEmpty;
      final textChunks = text.length > _maxChunkSize
          ? _chunkText(text)
          : [text];
      final totalChunks = textChunks.length + (hasTitle ? 1 : 0);
      int completedChunks = 0;

      // Progress helper
      void updateProgress() {
        completedChunks++;
        onProgress?.call(completedChunks / totalChunks);
      }

      // Translate title first (if provided)
      String? translatedTitle;
      if (hasTitle) {
        token.throwIfCancelled();
        translatedTitle = await _translateSingleChunk(
          title,
          sourceLang,
          targetLang,
          token,
        );
        updateProgress();
        debugPrint('✅ Title translated');
      }

      // Translate text
      String translatedText;
      if (text.trim().isEmpty) {
        translatedText = text;
      } else if (text.length <= _maxChunkSize) {
        // Small text: direct translation
        token.throwIfCancelled();
        if (hasTitle) {
          await _delayWithCancellation(_rateLimitDelay, token);
        }
        translatedText = await _translateSingleChunk(
          text,
          sourceLang,
          targetLang,
          token,
        );
        updateProgress();
      } else {
        // Large text: chunked translation
        debugPrint('📦 Split into ${textChunks.length} chunks');

        final translatedChunks = await _translateChunksWithCancellation(
          textChunks,
          sourceLang,
          targetLang,
          token,
          (chunkProgress) {
            final titleWeight = hasTitle ? 1 : 0;
            final overallProgress =
                (titleWeight + (chunkProgress * textChunks.length)) /
                totalChunks;
            onProgress?.call(overallProgress);
          },
          skipFirstDelay: !hasTitle, // Skip delay if no title was translated
        );

        translatedText = _mergeChunks(translatedChunks);
      }

      stopwatch.stop();

      return TranslationResult.success(
        translatedText: translatedText,
        translatedTitle: translatedTitle,
        originalText: text,
        originalTitle: title,
        sourceLanguage: sourceLang,
        sourceLanguageName: sourceLangName,
        sourceLanguageConfidence: sourceConfidence,
        targetLanguage: targetLang,
        targetLanguageName: targetLangName,
        chunksCompleted: totalChunks,
        totalChunks: totalChunks,
        duration: stopwatch.elapsed,
      );
    } on TranslationCancelledException {
      stopwatch.stop();
      return TranslationResult.cancelled(
        originalText: text,
        originalTitle: title,
        sourceLanguage: sourceLang,
        sourceLanguageName: sourceLangName,
        sourceLanguageConfidence: sourceConfidence,
        targetLanguage: targetLang,
        targetLanguageName: targetLangName,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ Translation error: $e');
      return TranslationResult.error(
        error: e.toString(),
        originalText: text,
        originalTitle: title,
        sourceLanguage: sourceLang,
        sourceLanguageName: sourceLangName,
        sourceLanguageConfidence: sourceConfidence,
        targetLanguage: targetLang,
        targetLanguageName: targetLangName,
      );
    } finally {
      _activeTranslations.remove(id);
    }
  }

  /// Translate using a request object
  Future<TranslationResult> translateRequest(
    TranslationRequest request, {
    TranslationCancelToken? cancelToken,
    void Function(double progress)? onProgress,
    String? taskId,
  }) {
    return translate(
      request.text,
      request.targetLanguage,
      title: request.title,
      cancelToken: cancelToken,
      onProgress: onProgress,
      taskId: taskId,
    );
  }

  /// Translate only title (convenience method)
  Future<TranslationResult> translateTitle(
    String title,
    String targetLang, {
    TranslationCancelToken? cancelToken,
    String? taskId,
  }) async {
    final result = await translate(
      '', // Empty body
      targetLang,
      title: title,
      cancelToken: cancelToken,
      taskId: taskId,
    );
    return result;
  }

  /// Batch translate multiple items
  Future<List<TranslationResult>> translateBatch(
    List<TranslationRequest> requests, {
    TranslationCancelToken? cancelToken,
    void Function(int completed, int total)? onItemComplete,
  }) async {
    final results = <TranslationResult>[];
    final token = cancelToken ?? TranslationCancelToken();

    for (int i = 0; i < requests.length; i++) {
      token.throwIfCancelled();

      if (i > 0) {
        await _delayWithCancellation(_rateLimitDelay, token);
      }

      final result = await translateRequest(requests[i], cancelToken: token);

      results.add(result);
      onItemComplete?.call(i + 1, requests.length);
    }

    return results;
  }

  /// Detect language of text
  DetectedLanguage? detectLanguage(String text) => _detector.detect(text);

  /// Get language name from code
  String getLanguageName(String code) => _detector.getLanguageName(code);

  /// Cancel a specific translation by task ID
  void cancelTask(String taskId) {
    _activeTranslations[taskId]?.cancel();
  }

  /// Cancel all active translations
  void cancelAll() {
    for (final token in _activeTranslations.values) {
      token.cancel();
    }
    _activeTranslations.clear();
    debugPrint('🛑 All translations cancelled');
  }

  /// Get count of active translations
  int get activeTranslationCount => _activeTranslations.length;

  /// Check if a specific task is active
  bool isTaskActive(String taskId) => _activeTranslations.containsKey(taskId);

  // ═══════════════════════════════════════════════════════════════════════
  // CHUNKING
  // ═══════════════════════════════════════════════════════════════════════

  List<String> _chunkText(String text) {
    final chunks = <String>[];
    final sentences = _splitIntoSentences(text);
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      if (sentence.length > _maxChunkSize) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }
        chunks.addAll(_splitLongSentence(sentence));
        continue;
      }

      if (buffer.length + sentence.length > _maxChunkSize) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }
      }

      buffer.write(sentence);
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }

    return chunks.where((c) => c.trim().isNotEmpty).toList();
  }

  List<String> _splitIntoSentences(String text) {
    final pattern = RegExp(r'[^.!?।॥\n]+[.!?।॥]*\s*|\n+', multiLine: true);
    return pattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  List<String> _splitLongSentence(String sentence) {
    final chunks = <String>[];
    final words = sentence.split(RegExp(r'\s+'));
    final buffer = StringBuffer();

    for (final word in words) {
      if (buffer.length + word.length + 1 > _maxChunkSize) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }
      }

      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(word);
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }

    return chunks;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CHUNK TRANSLATION
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<String>> _translateChunksWithCancellation(
    List<String> chunks,
    String sourceLang,
    String targetLang,
    TranslationCancelToken cancelToken,
    void Function(double)? onProgress, {
    bool skipFirstDelay = true,
  }) async {
    final results = <String>[];

    for (int i = 0; i < chunks.length; i++) {
      cancelToken.throwIfCancelled();

      // Add delay between chunks (skip first if specified)
      if (i > 0 || !skipFirstDelay) {
        await _delayWithCancellation(_rateLimitDelay, cancelToken);
      }

      cancelToken.throwIfCancelled();

      final translated = await _translateSingleChunk(
        chunks[i],
        sourceLang,
        targetLang,
        cancelToken,
      );
      results.add(translated);

      onProgress?.call((i + 1) / chunks.length);
      debugPrint('✅ Chunk ${i + 1}/${chunks.length}');
    }

    return results;
  }

  Future<void> _delayWithCancellation(
    Duration duration,
    TranslationCancelToken cancelToken,
  ) async {
    await Future.any([Future.delayed(duration), cancelToken.whenCancelled]);
    cancelToken.throwIfCancelled();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SINGLE CHUNK TRANSLATION
  // ═══════════════════════════════════════════════════════════════════════

  Future<String> _translateSingleChunk(
    String text,
    String sourceLang,
    String targetLang,
    TranslationCancelToken cancelToken,
  ) async {
    if (text.trim().isEmpty) return text;

    cancelToken.throwIfCancelled();

    if (sourceLang == targetLang) return text;

    try {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {
        'q': text,
        'langpair': '$sourceLang|$targetLang',
      });

      final response = await _httpGetWithCancellation(uri, cancelToken);

      cancelToken.throwIfCancelled();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['responseData']?['responseStatus'] != 200) {
          return _translateTextFallback(
            text,
            sourceLang,
            targetLang,
            cancelToken,
          );
        }

        final translatedText =
            data['responseData']?['translatedText'] as String?;

        if (translatedText != null &&
            translatedText.isNotEmpty &&
            !_isTranslationError(translatedText)) {
          return translatedText;
        }
      }

      return _translateTextFallback(text, sourceLang, targetLang, cancelToken);
    } catch (e) {
      if (e is TranslationCancelledException) rethrow;
      debugPrint('⚠️ Primary API error: $e');
      return _translateTextFallback(text, sourceLang, targetLang, cancelToken);
    }
  }

  Future<http.Response> _httpGetWithCancellation(
    Uri uri,
    TranslationCancelToken cancelToken,
  ) async {
    final client = http.Client();
    cancelToken.addListener(client.close);

    try {
      final response = await client.get(uri).timeout(_requestTimeout);
      return response;
    } finally {
      cancelToken.removeListener(client.close);
    }
  }

  Future<http.Response> _httpPostWithCancellation(
    Uri uri,
    Map<String, String> headers,
    String body,
    TranslationCancelToken cancelToken,
  ) async {
    final client = http.Client();
    cancelToken.addListener(client.close);

    try {
      final response = await client
          .post(uri, headers: headers, body: body)
          .timeout(_requestTimeout);
      return response;
    } finally {
      cancelToken.removeListener(client.close);
    }
  }

  bool _isTranslationError(String text) {
    final lowerText = text.toLowerCase();
    return lowerText.contains('mymemory warning') ||
        lowerText.contains('limit reached') ||
        lowerText.contains('query length limit');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FALLBACK TRANSLATION
  // ═══════════════════════════════════════════════════════════════════════

  Future<String> _translateTextFallback(
    String text,
    String sourceLang,
    String targetLang,
    TranslationCancelToken cancelToken,
  ) async {
    cancelToken.throwIfCancelled();

    final Uri url = Uri.parse('${Api.baseUrl}/translation');

    final payload = jsonEncode({
      'text': text,
      'source': sourceLang,
      'target': targetLang,
    });

    try {
      final response = await _httpPostWithCancellation(
        url,
        {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${Api.apiKey}',
        },
        payload,
        cancelToken,
      );

      cancelToken.throwIfCancelled();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final translated = data['translated'] as String?;

        if (data['success'] == true &&
            translated != null &&
            translated.isNotEmpty) {
          return translated;
        }
      }

      return text;
    } catch (e) {
      if (e is TranslationCancelledException) rethrow;
      debugPrint('❌ Fallback error: $e');
      return text;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MERGE
  // ═══════════════════════════════════════════════════════════════════════

  String _mergeChunks(List<String> chunks) {
    return chunks
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r' +'), ' ')
        .replaceAll(RegExp(r' ([.,!?])'), r'\1')
        .trim();
  }
}
