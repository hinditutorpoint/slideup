import 'dart:async';
import 'package:flutter/material.dart';
import '../tts_controller.dart';
import '../models/tts_request.dart';
import '../../txt_reader/utils/reader_utils.dart';

enum AudiobookState {
  idle,
  preparing,
  playing,
  paused,
  translating,
  generating,
  loading,
  error,
  completed,
}

class AudiobookStatus {
  final AudiobookState state;
  final int currentPage;
  final int totalPages;
  final String? currentText;
  final String? error;
  final double progress;
  final bool isTranslating;
  final bool isGenerating;
  final String? detectedLanguage;

  const AudiobookStatus({
    this.state = AudiobookState.idle,
    this.currentPage = 0,
    this.totalPages = 0,
    this.currentText,
    this.error,
    this.progress = 0.0,
    this.isTranslating = false,
    this.isGenerating = false,
    this.detectedLanguage,
  });

  AudiobookStatus copyWith({
    AudiobookState? state,
    int? currentPage,
    int? totalPages,
    String? currentText,
    String? error,
    double? progress,
    bool? isTranslating,
    bool? isGenerating,
    String? detectedLanguage,
  }) {
    return AudiobookStatus(
      state: state ?? this.state,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      currentText: currentText ?? this.currentText,
      error: error ?? this.error,
      progress: progress ?? this.progress,
      isTranslating: isTranslating ?? this.isTranslating,
      isGenerating: isGenerating ?? this.isGenerating,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
    );
  }

  bool get isActive =>
      state == AudiobookState.playing ||
      state == AudiobookState.preparing ||
      state == AudiobookState.translating ||
      state == AudiobookState.generating ||
      state == AudiobookState.loading;

  bool get isPaused => state == AudiobookState.paused;

  bool get isProcessing =>
      state == AudiobookState.translating ||
      state == AudiobookState.generating ||
      state == AudiobookState.loading ||
      state == AudiobookState.preparing;

  String get stateLabel {
    switch (state) {
      case AudiobookState.idle:
        return 'Ready';
      case AudiobookState.preparing:
        return 'Preparing...';
      case AudiobookState.playing:
        return 'Playing';
      case AudiobookState.paused:
        return 'Paused';
      case AudiobookState.translating:
        return 'Translating...';
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
}

class AudiobookController {
  final List<String> Function() getPages;
  final Map<int, String> Function() getTranslatedPages;
  final bool Function() isTranslationViewActive;
  final String bookId;
  final AudiobookSettings settings;
  final String targetLanguage;

  // Callbacks
  final Future<String?> Function(int pageIndex)? onTranslatePage;
  final void Function(int pageIndex)? onPageChanged;
  final void Function(String message)? onMessage;
  final void Function(AudiobookStatus status)? onStatusChanged;
  final String Function(String text)? detectLanguage;

  // State
  final _statusController = StreamController<AudiobookStatus>.broadcast();
  Stream<AudiobookStatus> get statusStream => _statusController.stream;

  AudiobookStatus _status = const AudiobookStatus();
  AudiobookStatus get status => _status;

  bool _isDisposed = false;
  bool _stopRequested = false;
  bool _pauseRequested = false;
  bool _forceStopRequested = false;
  int _currentPageIndex = 0;
  Completer<bool>? _speakCompleter;

  AudiobookController({
    required this.getPages,
    required this.getTranslatedPages,
    required this.isTranslationViewActive,
    required this.bookId,
    required this.settings,
    this.targetLanguage = 'en',
    this.onTranslatePage,
    this.onPageChanged,
    this.onMessage,
    this.onStatusChanged,
    this.detectLanguage,
  });

  void _updateStatus(AudiobookStatus newStatus) {
    if (_isDisposed) return;
    try {
      _status = newStatus;
      if (!_statusController.isClosed) {
        _statusController.add(newStatus);
      }
      onStatusChanged?.call(newStatus);
    } catch (e) {
      debugPrint('[AudiobookController] Status update error: $e');
    }
  }

  /// Start audiobook from specific page
  Future<void> start({int fromPage = 0, required BuildContext context}) async {
    if (_isDisposed) return;

    try {
      final pages = getPages();
      if (pages.isEmpty) {
        _updateStatus(
          _status.copyWith(
            state: AudiobookState.error,
            error: 'No pages to read',
          ),
        );
        _safeMessage('No pages available');
        return;
      }

      _stopRequested = false;
      _pauseRequested = false;
      _currentPageIndex = fromPage.clamp(0, pages.length - 1);

      _updateStatus(
        _status.copyWith(
          state: AudiobookState.preparing,
          currentPage: _currentPageIndex,
          totalPages: pages.length,
          error: null,
        ),
      );

      // Start the reading loop
      await _readLoop(context);
    } catch (e, stack) {
      debugPrint('[AudiobookController] Start error: $e\n$stack');
      _updateStatus(
        _status.copyWith(state: AudiobookState.error, error: e.toString()),
      );
      _safeMessage('Failed to start audiobook');
    }
  }

  /// Main reading loop with full error handling
  Future<void> _readLoop(BuildContext context) async {
    while (!_stopRequested && !_isDisposed) {
      try {
        final pages = getPages();

        // Check bounds
        if (_currentPageIndex >= pages.length) {
          _updateStatus(
            _status.copyWith(
              state: AudiobookState.completed,
              currentPage: pages.length - 1,
            ),
          );
          _safeMessage('Audiobook completed!');
          break;
        }

        // Handle pause
        await _handlePause();
        if (_stopRequested || _isDisposed) break;

        // Get text for current page (respects translation view)
        final textToSpeak = await _getPageTextSafe(_currentPageIndex);

        if (textToSpeak == null || textToSpeak.isEmpty) {
          debugPrint('[AudiobookController] Empty page, skipping');
          _currentPageIndex++;
          continue;
        }

        // Detect language for UI display
        final detectedLang = detectLanguage?.call(textToSpeak) ?? 'en';

        // Update status with current text
        _updateStatus(
          _status.copyWith(
            state: AudiobookState.generating,
            currentPage: _currentPageIndex,
            totalPages: pages.length,
            currentText: _truncateText(textToSpeak, 100),
            detectedLanguage: detectedLang,
            isGenerating: true,
          ),
        );

        // Notify page change (this will scroll the reader)
        _safePageChanged(_currentPageIndex);
        if (!context.mounted) return;
        // Speak the page
        final success = await _speakPageSafe(textToSpeak, context);

        if (_stopRequested || _isDisposed) break;

        if (!success) {
          debugPrint(
            '[AudiobookController] Speak failed, continuing to next page',
          );
          // Don't stop, try next page
        }

        // Preload next pages in background (fire and forget)
        _preloadNextPagesSafe(_currentPageIndex + 1);

        // Delay between pages
        if (settings.delayBetweenPages > 0 && !_stopRequested && !_isDisposed) {
          await Future.delayed(
            Duration(milliseconds: (settings.delayBetweenPages * 1000).toInt()),
          );
        }

        // Move to next page
        _currentPageIndex++;
      } catch (e, stack) {
        debugPrint('[AudiobookController] Read loop error: $e\n$stack');

        // Try to continue with next page instead of stopping
        _currentPageIndex++;

        if (_currentPageIndex >= getPages().length) {
          _updateStatus(
            _status.copyWith(state: AudiobookState.completed, error: null),
          );
          break;
        }

        // Brief delay before retry
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Final state
    if (!_isDisposed && !_stopRequested) {
      _updateStatus(
        _status.copyWith(
          state: AudiobookState.completed,
          isGenerating: false,
          isTranslating: false,
        ),
      );
    }
  }

  /// Handle pause state
  Future<void> _handlePause() async {
    while (_pauseRequested && !_stopRequested && !_isDisposed) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Get text for a page (translated if translation view is active)
  Future<String?> _getPageTextSafe(int pageIndex) async {
    try {
      final pages = getPages();
      if (pageIndex < 0 || pageIndex >= pages.length) return null;

      // IMPORTANT: Check if translation view is active
      final useTranslation = isTranslationViewActive();
      final translatedPages = getTranslatedPages();

      if (useTranslation) {
        // First check if already translated
        if (translatedPages.containsKey(pageIndex) &&
            translatedPages[pageIndex]!.isNotEmpty) {
          return translatedPages[pageIndex];
        }

        // If auto-translate is enabled, translate now
        if (settings.autoTranslateBeforeSpeak && onTranslatePage != null) {
          _updateStatus(
            _status.copyWith(
              state: AudiobookState.translating,
              isTranslating: true,
            ),
          );

          try {
            final translated = await onTranslatePage!(pageIndex);

            _updateStatus(_status.copyWith(isTranslating: false));

            if (translated != null && translated.isNotEmpty) {
              return translated;
            }
          } catch (e) {
            debugPrint('[AudiobookController] Translation error: $e');
            _safeMessage('Translation failed, using original');
            _updateStatus(_status.copyWith(isTranslating: false));
          }
        }

        // Check again after translation attempt
        final updatedTranslations = getTranslatedPages();
        if (updatedTranslations.containsKey(pageIndex) &&
            updatedTranslations[pageIndex]!.isNotEmpty) {
          return updatedTranslations[pageIndex];
        }
      }

      // Return original text
      return pages[pageIndex];
    } catch (e, stack) {
      debugPrint('[AudiobookController] Get page text error: $e\n$stack');
      return null;
    }
  }

  /// Speak a page with full error handling
  Future<bool> _speakPageSafe(String text, BuildContext context) async {
    if (_isDisposed || _stopRequested || text.isEmpty) return false;

    _speakCompleter = Completer<bool>();

    try {
      _updateStatus(
        _status.copyWith(
          state: AudiobookState.playing,
          isGenerating: false,
          progress: 0.0,
        ),
      );

      // Check if context is still valid
      if (!context.mounted) {
        debugPrint('[AudiobookController] Context not mounted');
        return false;
      }

      await TtsController.instance.speak(
        text: text,
        context: context,
        showUi: false,
        bookId: bookId,
        pageNumber: _currentPageIndex,
        useCache: true,
        onStateChanged: (state) {
          if (_isDisposed) return;

          try {
            if (state == TtsPlaybackState.playing) {
              _updateStatus(
                _status.copyWith(
                  state: AudiobookState.playing,
                  isGenerating: false,
                ),
              );
            } else if (state == TtsPlaybackState.loading ||
                state == TtsPlaybackState.generating) {
              _updateStatus(
                _status.copyWith(
                  state: AudiobookState.generating,
                  isGenerating: true,
                ),
              );
            }
          } catch (e) {
            debugPrint('[AudiobookController] State change error: $e');
          }
        },
        onProgress: (progress) {
          if (_isDisposed) return;
          try {
            _updateStatus(_status.copyWith(progress: progress.clamp(0.0, 1.0)));
          } catch (e) {
            debugPrint('[AudiobookController] Progress error: $e');
          }
        },
        onError: (error) {
          debugPrint('[AudiobookController] TTS error: $error');
          _completeSpeakSafe(false);
        },
        onCompleted: () {
          _completeSpeakSafe(true);
        },
      );

      // Wait for completion with timeout
      final result = await _speakCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          debugPrint('[AudiobookController] Speak timeout');
          return false;
        },
      );

      return result;
    } catch (e, stack) {
      debugPrint('[AudiobookController] Speak error: $e\n$stack');
      _completeSpeakSafe(false);
      return false;
    }
  }

  void _completeSpeakSafe(bool success) {
    try {
      if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
        _speakCompleter!.complete(success);
      }
    } catch (e) {
      debugPrint('[AudiobookController] Complete speak error: $e');
    }
  }

  /// Preload next pages safely
  void _preloadNextPagesSafe(int fromPage) {
    if (!settings.continueInBackground) return;

    Future.microtask(() async {
      try {
        final pages = getPages();

        for (int i = 0; i < settings.preloadPagesCount; i++) {
          if (_isDisposed || _stopRequested) break;

          final pageIndex = fromPage + i;
          if (pageIndex >= pages.length) break;

          final text = await _getPageTextSafe(pageIndex);
          if (text != null && text.isNotEmpty) {
            await TtsController.instance.generateOnly(
              text: text,
              bookId: bookId,
              pageNumber: pageIndex,
              useCache: true,
            );
          }
        }
      } catch (e) {
        debugPrint('[AudiobookController] Preload error: $e');
      }
    });
  }

  void _safeMessage(String message) {
    try {
      onMessage?.call(message);
    } catch (e) {
      debugPrint('[AudiobookController] Message callback error: $e');
    }
  }

  void _safePageChanged(int page) {
    try {
      onPageChanged?.call(page);
    } catch (e) {
      debugPrint('[AudiobookController] Page changed callback error: $e');
    }
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Pause playback
  void pause() {
    try {
      if (_status.state == AudiobookState.playing) {
        _pauseRequested = true;
        _updateStatus(_status.copyWith(state: AudiobookState.paused));
        TtsController.instance.pause();
      }
    } catch (e) {
      debugPrint('[AudiobookController] Pause error: $e');
    }
  }

  /// Resume playback
  void resume() {
    try {
      if (_status.state == AudiobookState.paused) {
        _pauseRequested = false;
        _updateStatus(_status.copyWith(state: AudiobookState.playing));
        TtsController.instance.play();
      }
    } catch (e) {
      debugPrint('[AudiobookController] Resume error: $e');
    }
  }

  /// Toggle play/pause
  void togglePlayPause() {
    if (_status.state == AudiobookState.playing) {
      pause();
    } else if (_status.state == AudiobookState.paused) {
      resume();
    }
  }

  /// Force stop without context (for dispose)
  void forceStop() {
    try {
      _forceStopRequested = true;
      _stopRequested = true;
      _pauseRequested = false;

      // Complete any pending speak operation
      _completeSpeakSafe(false);

      // Force stop TTS
      TtsController.instance.forceStop();

      // Update status without callbacks (might be disposed)
      _status = const AudiobookStatus(state: AudiobookState.idle);
    } catch (e) {
      debugPrint('[AudiobookController] Force stop error: $e');
    }
  }

  /// Stop playback
  Future<void> stop(BuildContext context) async {
    try {
      _stopRequested = true;
      _pauseRequested = false;
      _completeSpeakSafe(false);

      // Only use context if mounted
      if (context.mounted && !_forceStopRequested) {
        await TtsController.instance.stop(context);
      } else {
        TtsController.instance.forceStop();
      }

      _updateStatus(
        _status.copyWith(
          state: AudiobookState.idle,
          isGenerating: false,
          isTranslating: false,
          progress: 0.0,
        ),
      );
    } catch (e) {
      debugPrint('[AudiobookController] Stop error: $e');
    }
  }

  /// Skip to next page
  Future<void> nextPage(BuildContext context) async {
    try {
      final pages = getPages();
      if (_currentPageIndex < pages.length - 1) {
        _completeSpeakSafe(false);

        if (context.mounted) {
          await TtsController.instance.stop(context);
        }

        _currentPageIndex++;
        _safePageChanged(_currentPageIndex);

        _updateStatus(
          _status.copyWith(currentPage: _currentPageIndex, progress: 0.0),
        );
      }
    } catch (e) {
      debugPrint('[AudiobookController] Next page error: $e');
    }
  }

  /// Skip to previous page
  Future<void> previousPage(BuildContext context) async {
    try {
      if (_currentPageIndex > 0) {
        _completeSpeakSafe(false);

        if (context.mounted) {
          await TtsController.instance.stop(context);
        }

        _currentPageIndex--;
        _safePageChanged(_currentPageIndex);

        _updateStatus(
          _status.copyWith(currentPage: _currentPageIndex, progress: 0.0),
        );
      }
    } catch (e) {
      debugPrint('[AudiobookController] Previous page error: $e');
    }
  }

  /// Jump to specific page
  Future<void> jumpToPage(int pageIndex, BuildContext context) async {
    try {
      final pages = getPages();
      if (pageIndex >= 0 && pageIndex < pages.length) {
        _completeSpeakSafe(false);

        if (context.mounted) {
          await TtsController.instance.stop(context);
        }

        _currentPageIndex = pageIndex;
        _safePageChanged(_currentPageIndex);

        _updateStatus(
          _status.copyWith(currentPage: _currentPageIndex, progress: 0.0),
        );
      }
    } catch (e) {
      debugPrint('[AudiobookController] Jump to page error: $e');
    }
  }

  /// Dispose controller
  void dispose() {
    try {
      _isDisposed = true;
      _stopRequested = true;
      _forceStopRequested = true;
      _completeSpeakSafe(false);

      if (!_statusController.isClosed) {
        _statusController.close();
      }
    } catch (e) {
      debugPrint('[AudiobookController] Dispose error: $e');
    }
  }
}
