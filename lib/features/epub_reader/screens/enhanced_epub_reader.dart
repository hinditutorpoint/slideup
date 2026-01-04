import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart' hide TextSelectionToolbar;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/safe_async.dart';
import '../models/epub_book.dart';
import '../models/epub_chapter.dart';
import '../models/reading_progress.dart';
import '../providers/epub_provider.dart';
import '../services/epub_reader_service.dart';
import '../widgets/epub_content_view.dart';
import '../widgets/chapter_list_widget.dart';
import '../widgets/reading_settings_widget.dart';

import '../services/translation_api_service.dart';
import '../controllers/epub_audiobook_controller.dart';
import '../widgets/draggable_audiobook_controls.dart';
import '../../speaker_player/tts_controller.dart';
import '../../speaker_player/services/language_detection_service.dart';
import '../../speaker_player/providers/model_download_provider.dart';

enum PreloadStrategy {
  disabled, // No preloading
  nextOnly, // Only next chapter
  adjacent, // Previous + next
  aggressive, // Previous + next + 2 ahead
}

class EnhancedEpubReader extends ConsumerStatefulWidget {
  final String? bookId;
  final String? filePath;
  final EpubBook? book;

  const EnhancedEpubReader({super.key, this.bookId, this.filePath, this.book})
    : assert(
        bookId != null || filePath != null || book != null,
        'Either bookId, filePath, or book must be provided',
      );

  @override
  ConsumerState<EnhancedEpubReader> createState() => _EnhancedEpubReaderState();
}

class _EnhancedEpubReaderState extends ConsumerState<EnhancedEpubReader>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Controllers
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _uiAnimationController;
  late Animation<double> _uiAnimation;
  PageController? _pageController;

  // State
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _showUI = false;
  bool _isSelectingText = false;
  String? _selectedText;
  int _selectionStart = 0;
  int _selectionEnd = 0;
  Offset _selectionPosition = Offset.zero;

  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;

  // Chapter navigation state
  int _currentPageIndex = 0;
  bool _isPageControllerReady = false;
  bool _isSyncingPage = false;

  // Timers
  Timer? _uiHideTimer;
  Timer? _autoSaveTimer;

  // Selection overlay
  OverlayEntry? _selectionOverlay;

  ReaderSettings get settings => ref.watch(readerSettingsProvider);

  // Add to state variables in _EnhancedEpubReaderState
  bool _isAudiobookMode = false;
  EpubAudiobookController? _audiobookController;
  AudiobookStatus _audiobookStatus = const AudiobookStatus();
  bool _showSettings = false;

  // Add StreamSubscription
  StreamSubscription<AudiobookStatus>? _audiobookStatusSubscription;

  // Translation state
  final PreloadStrategy _preloadStrategy = PreloadStrategy.adjacent;
  TranslationCancelToken? _cancelToken;
  bool _isTranslating = false;
  bool _isPreloading = false;
  String? _translatedText;
  // ignore: unused_field
  String? _translatedTitle;
  double _translationProgress = 0;
  int? _translatingChapterIndex;
  final Map<String, TranslationResult> _translationCache = {};
  final Set<int> _preloadingChapters = {};
  final Set<int> _preloadedChapters = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize animation controller
    _uiAnimationController = AnimationController(
      duration: AppConstants.animationDuration,
      vsync: this,
    );
    _uiAnimation = CurvedAnimation(
      parent: _uiAnimationController,
      curve: Curves.easeInOut,
    );
    _uiAnimationController.value = 0.0;

    _enableScreenOn();
    // Load book
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeReader();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTranslation();
    _setImmersiveMode(false);
    _uiAnimationController.dispose();
    _pageController?.dispose();
    _uiHideTimer?.cancel();
    _autoSaveTimer?.cancel();
    _removeSelectionOverlay();

    // Dispose audiobook controller
    _audiobookStatusSubscription?.cancel();
    _audiobookController?.dispose();

    _saveProgressSafely();
    _disableScreenOn();

    super.dispose();
  }

  Future<void> _enableScreenOn() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Failed to enable wakelock: $e');
    }
  }

  Future<void> _disableScreenOn() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Failed to disable wakelock: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUDIOBOOK METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  void _toggleAudiobookMode() {
    if (_isAudiobookMode) {
      _stopAudiobook();
    } else {
      _startAudiobook();
    }
  }

  Future<void> _startAudiobook() async {
    try {
      final state = ref.read(readerServiceProvider).currentState;
      if (!state.hasBook) {
        _showError('No book loaded');
        return;
      }

      final book = state.book!;

      setState(() {
        _isAudiobookMode = true;
        _audiobookStatus = const AudiobookStatus(
          state: AudiobookState.initializing,
          isTtsInitializing: true,
        );
      });

      _audiobookController = EpubAudiobookController(
        book: book,
        bookId: book.id,
        modelService: ref.read(modelDownloadServiceProvider),
        getChapterText: (chapterIndex) async {
          try {
            // Use getChapter instead of goToChapter to avoid changing reader state
            final result = await ref
                .read(readerServiceProvider)
                .getChapter(chapterIndex);

            if (result.isSuccess) {
              // Use textContent (plain text) instead of htmlContent to avoid TTS crash
              // Sherpa TTS library cannot handle HTML tags and will crash with SIGSEGV
              return result.requireData.textContent;
            }
            return null;
          } catch (e) {
            debugPrint('[Audiobook] Failed to get chapter text: $e');
            return null;
          }
        },
        // Add translation support if needed
        getTranslatedChapterText: (chapterIndex) async {
          final cacheKey = "$chapterIndex-${settings.targetLanguage}";
          if (_translationCache.containsKey(cacheKey)) {
            return _translationCache[cacheKey]!.translatedText;
          }
          // Silent translation for background generation/audio
          return await _translateChapterSilently(chapterIndex);
        },
        isTranslationMode: () => settings.translationEnabled,
        onChapterChanged: (chapterIndex) {
          if (mounted &&
              _pageController != null &&
              _pageController!.hasClients) {
            try {
              _pageController!.animateToPage(
                chapterIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } catch (e) {
              debugPrint('[Audiobook] Page animation error: $e');
            }
          }
        },
        onMessage: (message) {
          if (mounted) {
            _showMessage(message);
          }
        },
        onStatusChanged: (status) {
          if (mounted) {
            setState(() {
              _audiobookStatus = status;
            });

            if (status.state == AudiobookState.completed) {
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted &&
                    _audiobookStatus.state == AudiobookState.completed) {
                  _stopAudiobook();
                }
              });
            }
          }
        },
        settings: const AudiobookSettings(
          preloadChaptersCount: 2,
          autoAdvance: true,
          continueInBackground: true,
        ),
      );

      _audiobookStatusSubscription = _audiobookController!.statusStream.listen((
        status,
      ) {
        if (mounted) {
          setState(() => _audiobookStatus = status);
        }
      }, onError: (e) => debugPrint('[Audiobook] Status stream error: $e'));

      // Initialize TTS first (non-blocking UI update)
      await _audiobookController!.initializeTts();
      if (context.mounted && _audiobookController != null) {
        await _audiobookController!.start(
          fromChapter: state.currentChapterIndex,
          context: context,
        );
      }
    } catch (e, stack) {
      debugPrint('[Audiobook] Start error: $e\n$stack');
      _showError('Failed to start audiobook');
      _stopAudiobook();
    }
  }

  Future<void> _stopAudiobook() async {
    try {
      _audiobookStatusSubscription?.cancel();
      _audiobookStatusSubscription = null;

      if (_audiobookController != null) {
        // Only use context if mounted
        if (context.mounted) {
          await _audiobookController!.stop(context);
        } else {
          _audiobookController!.forceStop();
        }

        _audiobookController!.dispose();
        _audiobookController = null;
      }

      if (mounted) {
        setState(() {
          _isAudiobookMode = false;
          _audiobookStatus = const AudiobookStatus();
        });
      }
    } catch (e) {
      debugPrint('[Audiobook] Stop error: $e');
      // Ensure state is reset even on error
      if (mounted) {
        setState(() {
          _isAudiobookMode = false;
          _audiobookStatus = const AudiobookStatus();
        });
      }
    }
  }

  void _audiobookPlayPause() {
    try {
      _audiobookController?.togglePlayPause();
    } catch (e) {
      debugPrint('[Audiobook] PlayPause error: $e');
    }
  }

  Future<void> _audiobookPrevious() async {
    try {
      if (context.mounted) {
        await _audiobookController?.previousChapter(context);
      }
    } catch (e) {
      debugPrint('[Audiobook] Previous error: $e');
    }
  }

  Future<void> _audiobookNext() async {
    try {
      if (context.mounted) {
        await _audiobookController?.nextChapter(context);
      }
    } catch (e) {
      debugPrint('[Audiobook] Next error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    try {
      switch (state) {
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
          _saveProgressSafely();
          break;
        case AppLifecycleState.resumed:
          break;
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          break;
      }
    } catch (e) {
      debugPrint('Lifecycle state change error: $e');
    }
  }

  Future<void> _initializeReader() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      Result<EpubBook>? result;

      if (widget.book != null && widget.book!.filePath != null) {
        result = await ref
            .read(readerNotifierProvider.notifier)
            .openBook(widget.book!.filePath!);
      } else if (widget.filePath != null) {
        result = await ref
            .read(readerNotifierProvider.notifier)
            .openBook(widget.filePath!);
      } else if (widget.bookId != null) {
        final book = ref.read(libraryProvider.notifier).getBook(widget.bookId!);
        if (book != null && book.filePath != null) {
          result = await ref
              .read(readerNotifierProvider.notifier)
              .openBook(book.filePath!);
        } else {
          throw Exception('Book not found or not downloaded');
        }
      }

      if (result != null && result.isFailure) {
        throw result.error!;
      }

      if (mounted) {
        // Get initial chapter index
        final state = ref.read(readerServiceProvider).currentState;
        _currentPageIndex = state.currentChapterIndex;

        // Initialize PageController with correct initial page
        _pageController = PageController(initialPage: _currentPageIndex);
        _isPageControllerReady = true;

        setState(() {
          _isLoading = false;
        });

        _startUIHideTimer();
        _setImmersiveMode(true);

        // Trigger translation if enabled
        if (settings.translationEnabled) {
          _translateCurrentChapter();
        }
      }
    } catch (e, st) {
      debugPrint('Initialize reader error: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _saveProgressSafely() async {
    if (!mounted) return;
    try {
      await ref.read(readerNotifierProvider.notifier).saveProgress();
    } catch (e) {
      debugPrint('Save progress error: $e');
    }
  }

  void _toggleUI() {
    try {
      setState(() {
        _showUI = !_showUI;
      });

      if (_showUI) {
        _uiAnimationController.forward();
        _setImmersiveMode(false);
        _startUIHideTimer();
      } else {
        _uiAnimationController.reverse();
        _setImmersiveMode(true);
        _uiHideTimer?.cancel();
      }
    } catch (e) {
      debugPrint('Toggle UI error: $e');
    }
  }

  void _startUIHideTimer() {
    try {
      _uiHideTimer?.cancel();
      _uiHideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _showUI && !_isSelectingText) {
          _toggleUI();
        }
      });
    } catch (e) {
      debugPrint('❌ Start UI hide timer error: $e');
    }
  }

  void _setImmersiveMode(bool immersive) {
    try {
      if (immersive) {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [],
        );
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values,
        );
      }
    } catch (e) {
      debugPrint('Set immersive mode error: $e');
    }
  }

  Widget _buildPreloadIndicator() {
    if (!settings.translationEnabled) return const SizedBox.shrink();
    if (_preloadingChapters.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 100,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Preloading ${_preloadingChapters.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          Scaffold(
            key: _scaffoldKey,
            body: _buildBody(),
            drawer: _buildDrawer(),
            // endDrawer: _buildEndDrawer(), // Using custom Stack drawer for "close only on button"
          ),
          if (_showSettings) _buildCustomEndDrawer(settings),
          if (_isPreloading) _buildPreloadIndicator(),
        ],
      ),
    );
  }

  Widget _buildCustomEndDrawer(ReaderSettings settings) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        child: Row(
          children: [
            // Barrier (non-dismissible)
            const Expanded(child: SizedBox()),
            // Drawer Content
            Container(
              width: MediaQuery.of(context).size.width * 0.85,
              color: Colors.white,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _showSettings = false),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ReadingSettingsSheet(
                        initialSettings: settings,
                        onSettingsChanged: (newSettings) {
                          // Settings are handled by the sheet's internal update
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    return _buildReaderContent();
  }

  Widget _buildLoadingState() {
    return Container(
      color: _getBackgroundColor(),
      child: SafeArea(
        child: Column(
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(height: 56, color: Colors.white),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 24,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(
                        10,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            width: double.infinity,
                            height: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: _getBackgroundColor(),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to Open Book',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'An unknown error occurred',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _initializeReader,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaderContent() {
    ref.listen(readerSettingsProvider, (previous, next) {
      // Translation toggled ON
      if (next.translationEnabled && previous?.translationEnabled != true) {
        _translateCurrentChapter();

        // Preload after translation
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && settings.translationEnabled) {
            _preloadAdjacentTranslations(_currentPageIndex);
          }
        });
      }
      // Translation toggled OFF
      else if (!next.translationEnabled &&
          previous?.translationEnabled == true) {
        _cancelToken?.cancel();
        _clearPreloadCache();
        setState(() {
          _translatedText = null;
          _translatedTitle = null;
          _isTranslating = false;
          _translationProgress = 0;
        });
      }
      // Language changed
      else if (next.translationEnabled &&
          previous?.targetLanguage != next.targetLanguage) {
        _cancelToken?.cancel();
        _clearPreloadCache();
        _translationCache.clear(); // Clear all cached translations

        setState(() {
          _translatedText = null;
          _translatedTitle = null;
        });

        _translateCurrentChapter();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && settings.translationEnabled) {
            _preloadAdjacentTranslations(_currentPageIndex);
          }
        });
      }
    });

    return ref
        .watch(readerStateProvider)
        .when(
          data: (state) => _buildReaderWithState(state),
          loading: () => _buildLoadingState(),
          error: (e, st) => _buildErrorState(),
        );
  }

  Widget _buildReaderWithState(ReadingState state) {
    if (!state.hasBook || !state.hasChapter) {
      return _buildLoadingState();
    }

    final settings = state.settings;
    final chapter = state.currentChapter!;
    final book = state.book!;
    final chapterTitles = state.hasBook
        ? state.book!.chapters.map((ch) => ch.title).toList()
        : <String>[];

    if (!_isSyncingPage &&
        _isPageControllerReady &&
        _currentPageIndex != state.currentChapterIndex) {
      _isSyncingPage = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncPageControllerWithState(state.currentChapterIndex);
          _isSyncingPage = false;
        }
      });
    }

    return Listener(
      onPointerDown: (event) {
        _pointerDownPosition = event.position;
        _pointerDownTime = DateTime.now();
      },
      onPointerUp: (event) {
        if (_isSelectingText) return;
        if (_pointerDownPosition == null || _pointerDownTime == null) return;

        final distance = (event.position - _pointerDownPosition!).distance;
        final duration = DateTime.now().difference(_pointerDownTime!);

        if (distance < 15 && duration.inMilliseconds < 250) {
          _handleZoneTap(event.position);
        }

        _pointerDownPosition = null;
        _pointerDownTime = null;
      },
      onPointerCancel: (_) {
        _pointerDownPosition = null;
        _pointerDownTime = null;
      },
      child: Stack(
        children: [
          _buildMainContent(state, settings, chapter, book),
          if (!_isSelectingText) _buildTopBar(state, book),
          if (!_isSelectingText) _buildBottomBar(state, settings),
          if (_isSelectingText && _selectedText != null)
            _buildDraggableSelectionToolbar(),

          // Translation spinner indicator (top-right)
          if (_isTranslating) _buildTranslationProgressIndicator(),

          // Draggable Audiobook Controls
          if (_isAudiobookMode)
            DraggableAudiobookControls(
              bookId: book.id,
              status: _audiobookStatus,
              chapterTitles: chapterTitles,
              onPlayPause: _audiobookPlayPause,
              onStop: _stopAudiobook,
              onPrevious: _audiobookPrevious,
              onNext: _audiobookNext,
              onClose: _stopAudiobook,
              onChapterTap: (chapterIndex) async {
                if (_audiobookController != null && context.mounted) {
                  await _audiobookController!.jumpToChapter(
                    chapterIndex,
                    context,
                  );
                }
              },
              onSpeedChange: (speed) {
                _audiobookController?.setPlaybackSpeed(speed);
              },
              onSleepTimer: (duration) {
                _audiobookController?.setSleepTimer(duration);
              },
              onCancelSleepTimer: () {
                _audiobookController?.cancelSleepTimer();
              },
              screenSize: MediaQuery.of(context).size,
              safeArea: MediaQuery.of(context).padding,
              backgroundColor: _getAudiobookBackgroundColor(settings.theme),
              textColor: _getAudiobookTextColor(settings.theme),
            ),
        ],
      ),
    );
  }

  Widget _buildTranslationProgressIndicator() {
    // Determine status text
    String statusText;
    if (_translationProgress > 0) {
      statusText = 'Translating ${(_translationProgress * 100).toInt()}%';
    } else {
      statusText = 'Loading translation...';
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  value: _translationProgress > 0 ? _translationProgress : null,
                  strokeWidth: 2,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _cancelTranslation,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAudiobookBackgroundColor(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.dark:
        return Colors.grey[900]!.withValues(alpha: 0.95);
      case ReadingTheme.sepia:
        return const Color(0xFF3E2723).withValues(alpha: 0.95);
      case ReadingTheme.light:
        return Colors.black.withValues(alpha: 0.9);
    }
  }

  Color _getAudiobookTextColor(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.dark:
      case ReadingTheme.light:
        return Colors.white;
      case ReadingTheme.sepia:
        return const Color(0xFFFFF8E1);
    }
  }

  void _handleZoneTap(Offset position) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Define zones
    final leftZone = screenWidth * 0.25; // Left 25%
    final rightZone = screenWidth * 0.75; // Right 25%
    final topZone = screenHeight * 0.15; // Top 15% (for UI toggle)
    final bottomZone = screenHeight * 0.85; // Bottom 15% (for UI toggle)

    // Top or bottom edge - always toggle UI
    if (position.dy < topZone || position.dy > bottomZone) {
      _toggleUI();
      return;
    }

    // Left zone - Previous chapter or toggle UI
    if (position.dx < leftZone) {
      if (settings.enableTapNavigation) {
        _handlePreviousChapter();
      } else {
        _toggleUI();
      }
      return;
    }

    // Right zone - Next chapter or toggle UI
    if (position.dx > rightZone) {
      if (settings.enableTapNavigation) {
        _handleNextChapter();
      } else {
        _toggleUI();
      }
      return;
    }

    // Center zone - Toggle UI
    _toggleUI();
  }

  void _syncPageControllerWithState(int targetChapterIndex) {
    if (!mounted) return;
    if (_pageController == null || !_pageController!.hasClients) return;

    final currentPage = _pageController!.page?.round() ?? _currentPageIndex;

    if (currentPage != targetChapterIndex) {
      debugPrint('Syncing PageController: $currentPage -> $targetChapterIndex');

      setState(() {
        _currentPageIndex = targetChapterIndex;
      });

      _pageController!.animateToPage(
        targetChapterIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildMainContent(
    ReadingState state,
    ReaderSettings settings,
    EpubChapter chapter,
    EpubBook book,
  ) {
    // Ensure PageController is ready
    if (!_isPageControllerReady || _pageController == null) {
      return _buildLoadingState();
    }

    return Container(
      color: _getBackgroundColorForTheme(settings.theme),
      child: SafeArea(
        top: false,
        bottom: false,
        child: PageView.builder(
          physics: settings.enableSwipeNavigation
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          controller: _pageController,
          itemCount: book.chapterCount,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            // Show content for the page that matches current state
            if (index == state.currentChapterIndex) {
              return EpubContentView(
                key: ValueKey('chapter_${index}_${chapter.id}'),
                chapter: chapter,
                settings: settings,
                highlights: ref.read(currentChapterHighlightsProvider),
                translatedText: settings.translationEnabled
                    ? _translatedText
                    : null,
                isTranslating: _isTranslating,
                initialScrollPosition: state.progress?.chapterProgress ?? 0.0,
                onScrollProgress: _onScrollProgress,
                onTextSelected: _onTextSelected,
                onLinkTapped: _onLinkTapped,
                onImageTapped: _onImageTapped,
              );
            }

            return _buildChapterPlaceholder(index, book);
          },
        ),
      ),
    );
  }

  Widget _buildChapterPlaceholder(int index, EpubBook book) {
    final chapterMeta = index < book.chapters.length
        ? book.chapters[index]
        : null;

    return Container(
      color: _getBackgroundColor(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              chapterMeta?.title ?? 'Chapter ${index + 1}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ReadingState state, EpubBook book) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _uiAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -100 * (1 - _uiAnimation.value)),
            child: Opacity(opacity: _uiAnimation.value, child: child),
          );
        },
        child: _ReaderTopBar(
          book: book,
          currentChapter: _currentPageIndex,
          totalChapters: state.totalChapters,
          onBack: _handleBack,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          onBookmarkTap: _handleAddBookmark,
          onSettingsTap: () {
            setState(() {
              _showSettings = true;
            });
          },
          onSearchTap: _handleSearch,
        ),
      ),
    );
  }

  Widget _buildBottomBar(ReadingState state, ReaderSettings settings) {
    if (!settings.showProgressBar) return const SizedBox.shrink();

    final book = state.book;
    final canGoPrevious = _currentPageIndex > 0;
    final canGoNext = book != null && _currentPageIndex < book.chapterCount - 1;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _uiAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 100 * (1 - _uiAnimation.value)),
            child: Opacity(opacity: _uiAnimation.value, child: child),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Audiobook and Translation toggles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAudiobookToggle(),
                      const SizedBox(width: 12),
                      _buildTranslationToggle(),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Progress slider
                  Row(
                    children: [
                      Text(
                        '${(state.overallProgress * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: state.overallProgress.clamp(0.0, 1.0),
                            onChanged: _handleProgressChange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Navigation buttons
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.skip_previous,
                          color: canGoPrevious ? Colors.white : Colors.white38,
                        ),
                        onPressed: canGoPrevious
                            ? _handlePreviousChapter
                            : null,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _scaffoldKey.currentState?.openDrawer(),
                          child: Column(
                            children: [
                              Text(
                                state.currentChapter?.title ??
                                    'Chapter ${_currentPageIndex + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.list,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Table of Contents',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.skip_next,
                          color: canGoNext ? Colors.white : Colors.white38,
                        ),
                        onPressed: canGoNext ? _handleNextChapter : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudiobookToggle() {
    return GestureDetector(
      onTap: _toggleAudiobookMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _isAudiobookMode
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: _isAudiobookMode
                ? Colors.green
                : Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isAudiobookMode ? Icons.headset : Icons.headset_off,
                key: ValueKey(_isAudiobookMode),
                color: _isAudiobookMode ? Colors.green : Colors.white70,
                size: 22,
              ),
            ),
            const SizedBox(width: 8),

            // Label
            Text(
              _isAudiobookMode ? 'Audiobook Playing' : 'Start Audiobook',
              style: TextStyle(
                color: _isAudiobookMode ? Colors.green : Colors.white,
                fontSize: 13,
                fontWeight: _isAudiobookMode
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),

            // Status indicator when active
            if (_isAudiobookMode) ...[
              const SizedBox(width: 8),
              if (_audiobookStatus.isProcessing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green,
                  ),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getStatusDotColor(),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusDotColor() {
    switch (_audiobookStatus.state) {
      case AudiobookState.initializing:
        return Colors.amber;
      case AudiobookState.playing:
        return Colors.green;
      case AudiobookState.paused:
        return Colors.orange;
      case AudiobookState.generating:
      case AudiobookState.loading:
      case AudiobookState.preparing:
        return Colors.amber;
      case AudiobookState.error:
        return Colors.red;
      case AudiobookState.completed:
        return Colors.teal;
      case AudiobookState.idle:
        return Colors.grey;
    }
  }

  bool _isSameLanguage(String source, String target) {
    if (source == target) return true;

    // Normalize (remove region codes)
    final normalizedSource = source.toLowerCase().split(RegExp(r'[-_]')).first;
    final normalizedTarget = target.toLowerCase().split(RegExp(r'[-_]')).first;

    return normalizedSource == normalizedTarget;
  }

  Widget _buildTranslationToggle() {
    final isEnabled = settings.translationEnabled;

    // Detect source language of current chapter
    String? detectedLang;
    final state = ref.read(readerServiceProvider).currentState;
    if (state.hasChapter) {
      final text = state.currentChapter?.textContent ?? '';
      final detection = LanguageDetectionService.instance.detect(text);
      detectedLang = detection?.code;
    }

    // Check if same language
    final isSameLang =
        detectedLang != null &&
        _isSameLanguage(detectedLang, settings.targetLanguage);

    return GestureDetector(
      onTap: _toggleTranslation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isEnabled
              ? (isSameLang
                    ? Colors.orange.withValues(alpha: 0.3) // Warning color
                    : Colors.blue.withValues(alpha: 0.3))
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isEnabled
                ? (isSameLang ? Colors.orange : Colors.blue)
                : Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEnabled ? Icons.translate : Icons.translate_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),

            if (_isTranslating)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else if (isSameLang && isEnabled)
              // Show warning for same language
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Same',
                    style: TextStyle(
                      color: Colors.orange.shade200,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            else
              Text(
                isEnabled ? 'ON' : 'OFF',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),

            // Show detected language
            if (detectedLang != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  detectedLang.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTranslation() async {
    try {
      final newValue = !settings.translationEnabled;

      // If enabling translation, check if needed
      if (newValue) {
        final state = ref.read(readerServiceProvider).currentState;
        if (state.hasChapter) {
          final originalText = state.currentChapter?.textContent ?? '';
          final detection = LanguageDetectionService.instance.detect(
            originalText,
          );
          final sourceLang = detection?.code ?? 'en';
          final targetLang = settings.targetLanguage;

          // ✅ Warn user if same language
          if (_isSameLanguage(sourceLang, targetLang)) {
            final confirmed = await _showSameLanguageDialog(
              sourceLang,
              targetLang,
            );
            if (!confirmed) return;
          }
        }
      }

      await ref
          .read(readerNotifierProvider.notifier)
          .updateSettings(settings.copyWith(translationEnabled: newValue));

      if (newValue) {
        await _translateCurrentChapter();
      } else {
        _cancelToken?.cancel();
        _cancelToken = null;
        _clearPreloadCache();
        setState(() {
          _translatedText = null;
          _translatedTitle = null;
          _isTranslating = false;
          _translationProgress = 0;
        });
      }
    } catch (e) {
      debugPrint('❌ Toggle translation error: $e');
    }
  }

  String _getLanguageName(String code) {
    return LanguageDetectionService.instance.getLanguageName(code);
  }

  /// Show dialog when source and target language are same
  Future<bool> _showSameLanguageDialog(String source, String target) async {
    final sourceName = _getLanguageName(source);
    final targetName = _getLanguageName(target);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Same Language Detected'),
        content: Text(
          'The content appears to be in $sourceName, '
          'which is the same as your target language ($targetName).\n\n'
          'Translation is not needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Translate Anyway'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _translateCurrentChapter() async {
    if (!settings.translationEnabled) return;

    final state = ref.read(readerServiceProvider).currentState;
    if (!state.hasChapter) return;

    final chapterIndex = state.currentChapterIndex;
    final targetLang = settings.targetLanguage;
    final cacheKey = "$chapterIndex-$targetLang";
    final chapter = state.currentChapter!;

    debugPrint(
      '🔄 translateCurrentChapter: chapter=$chapterIndex, lang=$targetLang',
    );

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 1: Check memory cache
    // ═══════════════════════════════════════════════════════════════════════
    if (_translationCache.containsKey(cacheKey)) {
      debugPrint('✅ Found in memory cache');
      final cached = _translationCache[cacheKey]!;
      if (mounted) {
        setState(() {
          _translatedText = cached.translatedText;
          _translatedTitle = cached.translatedTitle;
          _isTranslating = false;
          _translationProgress = 0;
        });
      }
      return;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 2: Check database for saved translation
    // ═══════════════════════════════════════════════════════════════════════
    try {
      final savedTranslation = ref
          .read(readerNotifierProvider.notifier)
          .getSavedChapterTranslation(
            chapterIndex: chapterIndex,
            targetLanguage: targetLang,
          );

      if (savedTranslation != null) {
        debugPrint('✅ Found in database');

        // Create result and cache it
        final result = TranslationResult.success(
          translatedText: savedTranslation.translatedContent,
          translatedTitle: savedTranslation.chapterId,
          originalText: chapter.textContent ?? '',
          originalTitle: chapter.title,
          sourceLanguage: savedTranslation.sourceLanguage,
          sourceLanguageName: '',
          sourceLanguageConfidence: 1.0,
          targetLanguage: targetLang,
          targetLanguageName: '',
        );
        _translationCache[cacheKey] = result;

        if (mounted && _currentPageIndex == chapterIndex) {
          setState(() {
            _translatedText = result.translatedText;
            _translatedTitle = result.translatedTitle;
            _isTranslating = false;
            _translationProgress = 0;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Database check error: $e');
      // Continue to translate if DB check fails
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP 3: Translate from API
    // ═══════════════════════════════════════════════════════════════════════

    // Cancel any existing translation
    _cancelToken?.cancel();
    _cancelToken = TranslationCancelToken();
    _translatingChapterIndex = chapterIndex;

    if (mounted) {
      setState(() {
        _isTranslating = true;
        _translationProgress = 0;
        _translatedText = null;
        _translatedTitle = null;
      });
    }

    debugPrint('🚀 Starting API translation for chapter $chapterIndex');

    try {
      final originalText = chapter.textContent ?? '';
      if (originalText.isEmpty) {
        debugPrint('⚠️ Chapter has no text content');
        if (mounted) {
          setState(() {
            _isTranslating = false;
            _translationProgress = 0;
          });
        }
        return;
      }

      final result = await TranslationApiService.instance.translate(
        originalText,
        targetLang,
        title: chapter.title,
        cancelToken: _cancelToken,
        onProgress: (progress) {
          // ✅ Check if still on same chapter
          if (mounted && _currentPageIndex == chapterIndex) {
            setState(() {
              _translationProgress = progress;
            });
          }
        },
      );

      // ✅ Verify we're still on the same chapter
      if (!mounted || _currentPageIndex != chapterIndex) {
        debugPrint('⚠️ Page changed during translation, discarding result');
        return;
      }

      if (result.isSuccess) {
        debugPrint('✅ Translation successful');

        // Cache the result
        _translationCache[cacheKey] = result;

        setState(() {
          _translatedText = result.translatedText;
          _translatedTitle = result.translatedTitle;
          _isTranslating = false;
          _translationProgress = 0;
        });

        // Save to database
        await _saveTranslationToDatabase(
          chapterIndex: chapterIndex,
          result: result,
        );

        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && settings.translationEnabled) {
            _preloadAdjacentTranslations(chapterIndex);
          }
        });
      } else if (result.isCancelled) {
        debugPrint('🛑 Translation was cancelled');
        if (mounted && _currentPageIndex == chapterIndex) {
          setState(() {
            _isTranslating = false;
            _translationProgress = 0;
          });
        }
      } else {
        debugPrint('❌ Translation failed: ${result.error}');
        if (mounted && _currentPageIndex == chapterIndex) {
          setState(() {
            _isTranslating = false;
            _translationProgress = 0;
          });
          _showError('Translation failed');
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Translation exception: $e\n$stack');
      if (mounted && _currentPageIndex == chapterIndex) {
        setState(() {
          _isTranslating = false;
          _translationProgress = 0;
        });
      }
    } finally {
      if (_translatingChapterIndex == chapterIndex) {
        _translatingChapterIndex = null;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAVE TRANSLATION TO DATABASE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveTranslationToDatabase({
    required int chapterIndex,
    required TranslationResult result,
  }) async {
    try {
      await ref
          .read(readerNotifierProvider.notifier)
          .saveChapterTranslation(
            translatedTitle: result.translatedTitle ?? '',
            translatedContent: result.translatedText!,
            sourceLanguage: result.sourceLanguage!,
            targetLanguage: result.targetLanguage!,
            provider: TranslationProvider.manual,
          );
      debugPrint('💾 Translation saved to database');
    } catch (e) {
      debugPrint('⚠️ Failed to save translation: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRELOAD ADJACENT CHAPTERS (optional optimization)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _preloadAdjacentTranslations(int currentIndex) async {
    if (!settings.translationEnabled) return;
    if (_preloadStrategy == PreloadStrategy.disabled) return;

    final state = ref.read(readerServiceProvider).currentState;
    if (!state.hasBook) return;

    final totalChapters = state.book!.chapterCount;
    final chaptersToPreload = <int>[];

    switch (_preloadStrategy) {
      case PreloadStrategy.disabled:
        return;

      case PreloadStrategy.nextOnly:
        if (currentIndex + 1 < totalChapters) {
          chaptersToPreload.add(currentIndex + 1);
        }
        break;

      case PreloadStrategy.adjacent:
        if (currentIndex + 1 < totalChapters) {
          chaptersToPreload.add(currentIndex + 1);
        }
        if (currentIndex - 1 >= 0) {
          chaptersToPreload.add(currentIndex - 1);
        }
        break;

      case PreloadStrategy.aggressive:
        // Previous
        if (currentIndex - 1 >= 0) {
          chaptersToPreload.add(currentIndex - 1);
        }
        // Next
        if (currentIndex + 1 < totalChapters) {
          chaptersToPreload.add(currentIndex + 1);
        }
        // 2 ahead
        if (currentIndex + 2 < totalChapters) {
          chaptersToPreload.add(currentIndex + 2);
        }
        // 2 behind
        if (currentIndex - 2 >= 0) {
          chaptersToPreload.add(currentIndex - 2);
        }
        break;
    }

    debugPrint(
      '📚 Preload strategy: $_preloadStrategy - chapters: $chaptersToPreload',
    );

    for (final chapterIndex in chaptersToPreload) {
      if (!_preloadedChapters.contains(chapterIndex) &&
          !_preloadingChapters.contains(chapterIndex)) {
        _preloadChapterTranslation(chapterIndex, settings.targetLanguage);
      }
    }
  }

  /// Preload a single chapter translation (background operation)
  Future<void> _preloadChapterTranslation(
    int chapterIndex,
    String targetLang,
  ) async {
    final cacheKey = "$chapterIndex-$targetLang";

    // Already in memory cache
    if (_translationCache.containsKey(cacheKey)) {
      _preloadedChapters.add(chapterIndex);
      return;
    }

    // Mark as preloading
    _preloadingChapters.add(chapterIndex);

    try {
      debugPrint('🔄 Preloading chapter $chapterIndex translation...');

      // Check database first
      final savedTranslation = ref
          .read(readerNotifierProvider.notifier)
          .getSavedChapterTranslation(
            chapterIndex: chapterIndex,
            targetLanguage: targetLang,
          );

      if (savedTranslation != null &&
          savedTranslation.translatedContent.isNotEmpty == true) {
        debugPrint('✅ Preload: Found chapter $chapterIndex in database');

        // Get chapter for metadata
        final chapterResult = await ref
            .read(readerServiceProvider)
            .getChapter(chapterIndex);

        if (chapterResult.isSuccess) {
          final chapter = chapterResult.requireData;

          // Cache it
          final result = TranslationResult.success(
            translatedText: savedTranslation.translatedContent,
            translatedTitle: savedTranslation.translatedTitle,
            originalText: chapter.textContent ?? '',
            originalTitle: chapter.title,
            sourceLanguage: savedTranslation.sourceLanguage,
            sourceLanguageName: '',
            sourceLanguageConfidence: 1.0,
            targetLanguage: targetLang,
            targetLanguageName: '',
          );

          _translationCache[cacheKey] = result;
          _preloadedChapters.add(chapterIndex);
          debugPrint('💾 Chapter $chapterIndex cached from database');
        }
        return;
      }

      // Not in database - translate from API
      final chapterResult = await ref
          .read(readerServiceProvider)
          .getChapter(chapterIndex);

      if (chapterResult.isFailure) {
        debugPrint('⚠️ Failed to get chapter $chapterIndex for preload');
        return;
      }

      final chapter = chapterResult.requireData;
      final text = chapter.textContent ?? '';

      if (text.isEmpty) {
        debugPrint('⚠️ Chapter $chapterIndex has no content');
        return;
      }

      // Check if same language
      final detection = LanguageDetectionService.instance.detect(text);
      final sourceLang = detection?.code ?? 'en';

      if (_isSameLanguage(sourceLang, targetLang)) {
        debugPrint(
          '⏭️ Skipping preload: chapter $chapterIndex already in $targetLang',
        );
        return;
      }

      debugPrint('🚀 Translating chapter $chapterIndex in background...');
      setState(() {
        _isPreloading = true;
      });

      // Translate silently (no progress callback, no UI updates)
      final translation = await TranslationApiService.instance.translate(
        text,
        targetLang,
        title: chapter.title,
        // No onProgress callback for background translation
      );

      if (translation.isSuccess) {
        // Cache it
        _translationCache[cacheKey] = translation;
        _preloadedChapters.add(chapterIndex);

        // Save to database
        await ref
            .read(readerNotifierProvider.notifier)
            .saveChapterTranslation(
              translatedTitle: translation.translatedTitle ?? chapter.title,
              translatedContent: translation.translatedText!,
              sourceLanguage: translation.sourceLanguage!,
              targetLanguage: translation.targetLanguage!,
              provider: TranslationProvider.manual,
            );
        setState(() {
          _isPreloading = false;
        });

        debugPrint('✅ Preload complete: chapter $chapterIndex');
      } else {
        debugPrint(
          '❌ Preload failed: chapter $chapterIndex - ${translation.error}',
        );
      }
    } catch (e) {
      debugPrint('❌ Preload error chapter $chapterIndex: $e');
    } finally {
      _preloadingChapters.remove(chapterIndex);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CANCEL TRANSLATION
  // ═══════════════════════════════════════════════════════════════════════════

  void _cancelTranslation() {
    try {
      debugPrint('🛑 User cancelled translation');
      _cancelToken?.cancel();
      _cancelToken = null;
      _translatingChapterIndex = null;
      _clearPreloadCache();
      if (mounted) {
        setState(() {
          _isTranslating = false;
          _translationProgress = 0;
          _isPreloading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Cancel translation error: $e');
    }
  }

  void _clearPreloadCache() {
    try {
      _preloadedChapters.clear();
      _preloadingChapters.clear();
    } catch (e) {
      debugPrint('❌ Clear preload cache error: $e');
    }
  }

  Future<String?> _translateChapterSilently(int chapterIndex) async {
    final targetLang = settings.targetLanguage;
    final cacheKey = "$chapterIndex-$targetLang";

    // Check memory cache
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!.translatedText;
    }

    // Check database
    try {
      final saved = ref
          .read(readerNotifierProvider.notifier)
          .getSavedChapterTranslation(
            chapterIndex: chapterIndex,
            targetLanguage: targetLang,
          );

      if (saved != null && saved.translatedContent.isNotEmpty == true) {
        return saved.translatedContent;
      }
    } catch (e) {
      debugPrint('[SilentTranslation] DB error: $e');
    }

    // Translate from API
    try {
      final result = await ref
          .read(readerServiceProvider)
          .getChapter(chapterIndex);
      if (result.isFailure) return null;

      final chapter = result.requireData;
      final text = chapter.textContent ?? '';
      if (text.isEmpty) return null;
      setState(() {
        _isPreloading = true;
      });

      final translation = await TranslationApiService.instance.translate(
        text,
        targetLang,
        title: chapter.title,
      );

      if (translation.isSuccess) {
        setState(() {
          _isPreloading = false;
        });
        // Cache it
        _translationCache[cacheKey] = translation;

        // Save to database
        await _saveTranslationToDatabase(
          chapterIndex: chapterIndex,
          result: translation,
        );

        return translation.translatedText;
      }

      return null;
    } catch (e) {
      debugPrint('[SilentTranslation] Error: $e');
      return null;
    }
  }

  void _onPageChanged(int index) {
    if (_isSyncingPage || !mounted) return;

    if (_isTranslating && _translatingChapterIndex != index) {
      debugPrint(
        '🛑 Cancelling translation for chapter $_translatingChapterIndex',
      );
      _cancelToken?.cancel();
      _cancelToken = null;
    }

    setState(() {
      _currentPageIndex = index;
      _translatedText = null;
      _translatedTitle = null;
      _isTranslating = false;
      _translationProgress = 0;
    });

    // Update state in service
    ref.read(readerServiceProvider).goToChapter(index);

    // Start translation for new chapter if enabled
    if (settings.translationEnabled) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _currentPageIndex == index) {
          _translateCurrentChapter();

          // ✅ PRELOAD ADJACENT CHAPTERS (after small delay)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && settings.translationEnabled) {
              _preloadAdjacentTranslations(index);
            }
          });
        }
      });
    }

    _startUIHideTimer();
  }

  Widget _buildDraggableSelectionToolbar() {
    return Positioned(
      left: _selectionPosition.dx,
      top: _selectionPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final screenSize = MediaQuery.of(context).size;
            _selectionPosition = Offset(
              (_selectionPosition.dx + details.delta.dx).clamp(
                0.0,
                screenSize.width - 250,
              ),
              (_selectionPosition.dy + details.delta.dy).clamp(
                50.0,
                screenSize.height - 150,
              ),
            );
          });
        },
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with drag handle and close button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.drag_handle,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _selectedText!.length > 20
                              ? '${_selectedText!.substring(0, 20)}...'
                              : _selectedText!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _clearSelection,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Toolbar actions
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToolbarButton(
                        icon: Icons.format_color_fill,
                        label: 'Highlight',
                        onTap: _handleHighlight,
                      ),
                      const SizedBox(width: 4),
                      _ToolbarButton(
                        icon: Icons.copy,
                        label: 'Copy',
                        onTap: _handleCopy,
                      ),
                      const SizedBox(width: 4),
                      _ToolbarButton(
                        icon: Icons.translate,
                        label: 'Translate',
                        onTap: _handleTranslate,
                      ),
                      const SizedBox(width: 4),
                      _ToolbarButton(
                        icon: Icons.record_voice_over,
                        label: 'Listen',
                        onTap: _handleListen,
                      ),
                      const SizedBox(width: 4),
                      _ToolbarButton(
                        icon: Icons.note_add,
                        label: 'Note',
                        onTap: _handleAddNote,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final state = ref.read(readerServiceProvider).currentState;

    if (!state.hasBook) return const SizedBox.shrink();

    return ChapterDrawer(
      book: state.book!,
      onClose: () => Navigator.pop(context),
    );
  }

  Future<bool> _onWillPop() async {
    try {
      await _saveProgressSafely();
      await ref.read(readerNotifierProvider.notifier).closeBook();
      _setImmersiveMode(false);
      return true;
    } catch (e) {
      debugPrint('On will pop error: $e');
      return true;
    }
  }

  void _handleBack() {
    Navigator.of(context).maybePop();
  }

  void _onScrollProgress(double progress) {
    if (!mounted) return;
    try {
      ref.read(readerNotifierProvider.notifier).updatePosition(progress);
    } catch (e) {
      debugPrint('Scroll progress error: $e');
    }
  }

  void _onTextSelected(String text, int start, int end, {Offset? position}) {
    try {
      final screenSize = MediaQuery.of(context).size;

      Offset toolbarPosition;
      if (position != null) {
        toolbarPosition = Offset(
          (position.dx - 125).clamp(0.0, screenSize.width - 250),
          (position.dy - 120).clamp(50.0, screenSize.height - 150),
        );
      } else {
        toolbarPosition = Offset(
          (screenSize.width - 250) / 2,
          screenSize.height / 3,
        );
      }

      setState(() {
        _selectedText = text;
        _selectionStart = start;
        _selectionEnd = end;
        _isSelectingText = true;
        _selectionPosition = toolbarPosition;

        if (_showUI) {
          _showUI = false;
          _uiAnimationController.reverse();
        }
      });
    } catch (e) {
      debugPrint('Text selected error: $e');
    }
  }

  void _onLinkTapped(ChapterLink link) async {
    try {
      if (link.isExternal) {
        _showMessage('External link: ${link.href}');
      } else if (link.targetChapterId != null) {
        await ref
            .read(readerNotifierProvider.notifier)
            .goToChapterByHref(link.targetChapterId!);
      }
    } catch (e) {
      debugPrint('Link tapped error: $e');
      _showError('Failed to navigate');
    }
  }

  void _onImageTapped(ChapterImage image) {
    try {
      showDialog(
        context: context,
        builder: (context) => _ImageViewerDialog(image: image),
      );
    } catch (e) {
      debugPrint('Image tapped error: $e');
    }
  }

  void _handlePreviousChapter() async {
    try {
      if (_pageController == null || !_pageController!.hasClients) return;

      final newPage = _currentPageIndex - 1;
      if (newPage < 0) return;

      debugPrint('Navigating to previous chapter: $newPage');

      // Animate the page controller - onPageChanged will update state
      await _pageController!.animateToPage(
        newPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      debugPrint('Previous chapter error: $e');
      _showError('Failed to go to previous chapter');
    }
  }

  void _handleNextChapter() async {
    try {
      if (_pageController == null || !_pageController!.hasClients) return;

      final state = ref.read(readerServiceProvider).currentState;
      final book = state.book;
      if (book == null) return;

      final newPage = _currentPageIndex + 1;
      if (newPage >= book.chapterCount) return;

      debugPrint('Navigating to next chapter: $newPage');

      // Animate the page controller - onPageChanged will update state
      await _pageController!.animateToPage(
        newPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      debugPrint('Next chapter error: $e');
      _showError('Failed to go to next chapter');
    }
  }

  void _handleProgressChange(double progress) async {
    try {
      final state = ref.read(readerServiceProvider).currentState;
      if (!state.hasBook) return;

      final targetChapter = (progress * state.totalChapters).floor();
      final clampedTarget = targetChapter.clamp(0, state.totalChapters - 1);

      if (clampedTarget != _currentPageIndex && _pageController != null) {
        await _pageController!.animateToPage(
          clampedTarget,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      debugPrint('Progress change error: $e');
    }
  }

  void _handleAddBookmark() async {
    try {
      final result = await ref
          .read(readerNotifierProvider.notifier)
          .addBookmark();

      if (result.isSuccess) {
        _showMessage('Bookmark added');
      } else {
        _showError('Failed to add bookmark');
      }
    } catch (e) {
      debugPrint('Add bookmark error: $e');
      _showError('Failed to add bookmark');
    }
  }

  void _handleSearch() {
    try {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _SearchSheet(),
      );
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  void _handleHighlight() async {
    try {
      if (_selectedText == null) return;

      final result = await ref
          .read(readerNotifierProvider.notifier)
          .addHighlight(
            selectedText: _selectedText!,
            startOffset: _selectionStart,
            endOffset: _selectionEnd,
          );

      _clearSelection();

      if (result.isSuccess) {
        _showMessage('Highlight added');
      } else {
        _showError('Failed to add highlight');
      }
    } catch (e) {
      debugPrint('Highlight error: $e');
      _showError('Failed to add highlight');
    }
  }

  void _handleCopy() {
    try {
      if (_selectedText == null) return;

      Clipboard.setData(ClipboardData(text: _selectedText!));
      _clearSelection();
      _showMessage('Copied to clipboard');
    } catch (e) {
      debugPrint('Copy error: $e');
    }
  }

  void _handleTranslate() async {
    try {
      if (_selectedText == null) return;

      final text = _selectedText!;
      _clearSelection();

      final cachedResult = await ref
          .read(readerNotifierProvider.notifier)
          .getCachedTranslation(originalText: text, targetLanguage: 'en');

      if (cachedResult.isSuccess && cachedResult.data != null) {
        _showTranslation(cachedResult.data!);
      } else {
        _showTranslationDialog(text);
      }
    } catch (e) {
      debugPrint('Translate error: $e');
      _showError('Failed to translate');
    }
  }

  void _handleListen() async {
    try {
      if (_selectedText == null) return;

      final text = _selectedText!;
      _clearSelection();

      // Detect language
      final detectedLang = LanguageDetectionService.instance.detectCode(text);

      // Use TTS with language-based model selection
      if (context.mounted) {
        await TtsController.instance.speakWithLanguage(
          text: text,
          context: context,
          language: detectedLang,
          showUi: true,
          useCache: true,
          onError: (error) {
            _showError('TTS Error: $error');
          },
        );
      }
    } catch (e) {
      debugPrint('Listen error: $e');
      _showError('Failed to play audio');
    }
  }

  void _handleAddNote() {
    try {
      if (_selectedText == null) return;

      final text = _selectedText!;
      _clearSelection();

      showDialog(
        context: context,
        builder: (context) => _AddNoteDialog(
          quotedText: text,
          onSave: (content) async {
            await ref
                .read(readerNotifierProvider.notifier)
                .addNote(content: content, quotedText: text);
          },
        ),
      );
    } catch (e) {
      debugPrint('Add note error: $e');
    }
  }

  void _clearSelection() {
    try {
      setState(() {
        _selectedText = null;
        _isSelectingText = false;
        _selectionPosition = Offset.zero;
      });
      _removeSelectionOverlay();
    } catch (e) {
      debugPrint('Clear selection error: $e');
    }
  }

  void _removeSelectionOverlay() {
    _selectionOverlay?.remove();
    _selectionOverlay = null;
  }

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  Color _getBackgroundColor() {
    try {
      final settings = ref.read(readerSettingsProvider);
      return _getBackgroundColorForTheme(settings.theme);
    } catch (e) {
      return AppConstants.lightBackground;
    }
  }

  Color _getBackgroundColorForTheme(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.dark:
        return AppConstants.darkBackground;
      case ReadingTheme.sepia:
        return AppConstants.sepiaBackground;
      case ReadingTheme.light:
        return AppConstants.lightBackground;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTranslation(TextTranslation translation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _TranslationSheet(translation: translation),
    );
  }

  void _showTranslationDialog(String text) {
    showDialog(
      context: context,
      builder: (context) => _TranslateDialog(
        originalText: text,
        onTranslated: (translation) async {
          await ref
              .read(readerNotifierProvider.notifier)
              .saveTextTranslation(
                originalText: text,
                translatedText: translation.translatedText,
                sourceLanguage: translation.sourceLanguage,
                targetLanguage: translation.targetLanguage,
                provider: translation.provider,
              );
        },
      ),
    );
  }
}

// =============================================================================
// TOOLBAR BUTTON WIDGET
// =============================================================================

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ANIMATED BUILDER HELPER
// =============================================================================

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

// =============================================================================
// READER TOP BAR
// =============================================================================

class _ReaderTopBar extends StatelessWidget {
  final EpubBook book;
  final int currentChapter;
  final int totalChapters;
  final VoidCallback? onBack;
  final VoidCallback? onMenuTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSearchTap;

  const _ReaderTopBar({
    required this.book,
    required this.currentChapter,
    required this.totalChapters,
    this.onBack,
    this.onMenuTap,
    this.onBookmarkTap,
    this.onSettingsTap,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBack,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onMenuTap,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Chapter ${currentChapter + 1} of $totalChapters',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: onSearchTap,
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_border, color: Colors.white),
                onPressed: onBookmarkTap,
              ),
              IconButton(
                onPressed: onSettingsTap,
                icon: const Icon(Icons.settings, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SEARCH SHEET
// =============================================================================

class _SearchSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<_SearchSheet> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Search in book...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchProvider.notifier).clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  ref.read(searchProvider.notifier).search(value);
                },
              ),
            ),

            // Results
            Expanded(child: _buildSearchResults(searchState)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(SearchState state) {
    if (state.query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Type to search', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    if (state.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Text(
          'Search error: ${state.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No results found', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final result = state.results[index];
        return ListTile(
          title: Text(
            result.context,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Chapter ${result.chapterIndex + 1}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          onTap: () async {
            Navigator.pop(context);
            await ref
                .read(readerNotifierProvider.notifier)
                .goToChapter(result.chapterIndex);
          },
        );
      },
    );
  }
}

// =============================================================================
// IMAGE VIEWER DIALOG
// =============================================================================

class _ImageViewerDialog extends StatelessWidget {
  final ChapterImage image;

  const _ImageViewerDialog({required this.image});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Image
          Center(
            child: InteractiveViewer(
              child: image.localPath != null && image.localPath!.isNotEmpty
                  ? Image.file(
                      File(image.localPath!),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white54),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.image, color: Colors.white54, size: 64),
                    ),
            ),
          ),

          // Close button
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Alt text
          if (image.alt != null)
            Positioned(
              bottom: 40,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  image.alt!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// ADD NOTE DIALOG
// =============================================================================

class _AddNoteDialog extends StatefulWidget {
  final String quotedText;
  final void Function(String content) onSave;

  const _AddNoteDialog({required this.quotedText, required this.onSave});

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Note'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quoted text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                '"${widget.quotedText}"',
                style: const TextStyle(fontStyle: FontStyle.italic),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),

            // Note input
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your note...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              widget.onSave(_controller.text);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// =============================================================================
// TRANSLATION SHEET
// =============================================================================

class _TranslationSheet extends StatelessWidget {
  final TextTranslation translation;

  const _TranslationSheet({required this.translation});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Language info
            Row(
              children: [
                Text(
                  translation.sourceLanguage.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                Text(
                  translation.targetLanguage.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Original text
            Text(
              translation.originalText,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            const Divider(),
            const SizedBox(height: 16),

            // Translated text
            Text(
              translation.translatedText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),

            // Pronunciation
            if (translation.pronunciation != null) ...[
              const SizedBox(height: 8),
              Text(
                translation.pronunciation!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: translation.translatedText),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                  tooltip: 'Copy',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TRANSLATE DIALOG
// =============================================================================

class _TranslateDialog extends StatefulWidget {
  final String originalText;
  final void Function(TextTranslation translation) onTranslated;

  const _TranslateDialog({
    required this.originalText,
    required this.onTranslated,
  });

  @override
  State<_TranslateDialog> createState() => _TranslateDialogState();
}

class _TranslateDialogState extends State<_TranslateDialog> {
  String _targetLanguage = 'en';
  bool _isTranslating = false;
  String? _translatedText;
  String? _error;

  // Cache the detected source language
  late String _sourceLanguage;

  // Common languages
  static const Map<String, String> _languages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese',
    'ar': 'Arabic',
    'hi': 'Hindi',
  };

  @override
  void initState() {
    super.initState();

    _sourceLanguage = '';
    TranslationApiService.instance.detectedLanguage(widget.originalText).then((
      value,
    ) {
      setState(() {
        _sourceLanguage = value;
      });
    });

    // If detected is English, default target to Spanish (or Hindi), else English
    if (_sourceLanguage == 'en') {
      _targetLanguage = 'es';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Translate'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.originalText,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Language selector
            DropdownButtonFormField<String>(
              value: _targetLanguage,
              decoration: const InputDecoration(
                labelText: 'Translate to',
                border: OutlineInputBorder(),
              ),
              items: _languages.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _targetLanguage = value;
                    _translatedText = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Translated text or loading
            if (_isTranslating)
              const Center(child: CircularProgressIndicator())
            else if (_translatedText != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _translatedText!,
                  style: const TextStyle(fontSize: 14),
                ),
              )
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isTranslating ? null : _handleTranslate,
          child: Text(_translatedText != null ? 'Save' : 'Translate'),
        ),
      ],
    );
  }

  Future<void> _handleTranslate() async {
    if (_translatedText != null) {
      // Save translation
      final translation = TextTranslation.create(
        originalText: widget.originalText,
        translatedText: _translatedText!,
        sourceLanguage: 'auto',
        targetLanguage: _targetLanguage,
        provider: TranslationProvider.manual,
      );
      widget.onTranslated(translation);
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isTranslating = true;
      _error = null;
    });

    try {
      final apiResponse = await TranslationApiService.instance.translate(
        widget.originalText,
        _targetLanguage,
      );

      if (!apiResponse.isSuccess) {
        setState(() {
          _error = 'Translation failed';
          _isTranslating = false;
        });
        return;
      }

      setState(() {
        _translatedText = 'Translated: ${apiResponse.translatedText}';
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isTranslating = false;
      });
    }
  }
}
