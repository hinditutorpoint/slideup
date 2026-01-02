import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../speaker_player/tts_controller.dart';
import '../../speaker_player/models/tts_request.dart';
import '../../speaker_player/providers/model_download_provider.dart';
import '../../speaker_player/providers/tts_provider.dart';
import '../../../core/constants/api.dart';

import '../../speaker_player/controllers/audiobook_controller.dart';
import '../utils/reader_utils.dart';
import '../widgets/left_panel.dart';
import '../widgets/reader_content.dart';
import '../widgets/reader_controls.dart';
import '../widgets/tool_panel.dart';
import '../widgets/language_selector.dart';
import '../widgets/reader_overlay.dart';
import '../widgets/go_to_page_dialog.dart';
import '../../speaker_player/widgets/audiobook_controls.dart';

/// Configuration constants
class TxtReaderConfig {
  const TxtReaderConfig._();

  static const Duration controlsAutoHide = Duration(seconds: 3);
  static const Duration positionSaveDebounce = Duration(seconds: 2);
  static const Duration httpTimeout = Duration(minutes: 2);
  static const int maxTranslationChars = 5000;

  static const double leftPanelZone = 0.08;
  static const double edgeZone = 0.15;
  static const double bottomSwipeZone = 0.10;

  static const double minZoom = 1.0;
  static const double maxZoom = 3.0;

  static const double panelWidthRatio = 0.85;
  static const double maxPanelWidth = 400.0;
}

/// TTS Initialization State for UI feedback
enum TtsInitState { idle, initializingSherpa, loadingModel, ready, error }

class TxtReaderScreen extends ConsumerStatefulWidget {
  final String txtUrl;
  final String title;
  final String? identifier;
  final int? initialPosition;

  const TxtReaderScreen({
    super.key,
    required this.txtUrl,
    required this.title,
    this.identifier,
    this.initialPosition,
  });

  @override
  ConsumerState<TxtReaderScreen> createState() => TxtReaderScreenState();
}

class TxtReaderScreenState extends ConsumerState<TxtReaderScreen>
    with TickerProviderStateMixin {
  // ========== Disposal State ==========
  bool _isDisposing = false;
  bool _isDisposed = false;

  // ========== Content ==========
  String? _content;
  List<String> _pages = [];
  Map<int, String> _translatedPages = {};
  int _currentPage = 0;
  int _totalPages = 0;

  // ========== State ==========
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  bool _isTranslatingPage = false;
  bool _showTranslatedView = false;
  bool _showLeftPanel = false;

  // ========== Zoom & Pan ==========
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  Offset _panOffset = Offset.zero;
  Offset _basePanOffset = Offset.zero;
  bool _isZooming = false;

  // ========== Gesture Detection ==========
  Offset? _swipeStartPosition;
  bool _isSwipingUp = false;

  // ========== Text Selection & Tool Panel ==========
  String? _selectedText;
  Offset _toolPanelPosition = const Offset(16, 100);
  bool _showToolPanel = false;

  // ========== Translation ==========
  String _targetLanguage = 'en';
  String? _selectionTranslation;
  bool _isTranslatingSelection = false;
  final TranslationCacheManager _translationCache = TranslationCacheManager();

  // ========== Controllers ==========
  PageController? _pageController;
  AnimationController? _controlsAnimationController;
  Animation<double>? _controlsAnimation;
  AnimationController? _toolPanelAnimationController;
  Animation<double>? _toolPanelAnimation;
  AnimationController? _leftPanelAnimationController;
  Animation<double>? _leftPanelAnimation;

  // ========== Settings & Storage ==========
  ReaderSettings _settings = const ReaderSettings();
  final ReaderStorageManager _storageManager = ReaderStorageManager();
  final DocumentCacheManager _cacheManager = DocumentCacheManager();

  // ========== Timers ==========
  Timer? _hideControlsTimer;
  Timer? _savePositionTimer;

  // ========== Search ==========
  String _searchQuery = '';
  List<int> _searchResults = [];
  int _currentSearchIndex = 0;
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // ========== Screen Size ==========
  Size _screenSize = Size.zero;
  EdgeInsets _safeArea = EdgeInsets.zero;

  // ========== Page Physics Control ==========
  bool _allowPageTurn = true;

  // ========== TTS State ==========
  bool _isTtsInitialized = false;
  TtsInitState _ttsInitState = TtsInitState.idle;
  String _ttsInitMessage = '';
  bool _isSpeaking = false;
  bool _isGeneratingAudio = false;
  String _generatingMessage = '';

  // ========== Audiobook State ==========
  AudiobookController? _audiobookController;
  AudiobookStatus _audiobookStatus = const AudiobookStatus();
  bool _showAudiobookControls = false;
  StreamSubscription<AudiobookStatus>? _audiobookSubscription;

  // ========== Getters ==========
  String get identifier => widget.identifier ?? widget.txtUrl;
  String get title => widget.title;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get showControls => _showControls;
  bool get showTranslatedView => _showTranslatedView;
  bool get isTranslatingPage => _isTranslatingPage;
  bool get showLeftPanel => _showLeftPanel;
  bool get showToolPanel => _showToolPanel;
  bool get showSearchBar => _showSearchBar;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  String get targetLanguage => _targetLanguage;
  String? get selectedText => _selectedText;
  String? get selectionTranslation => _selectionTranslation;
  bool get isTranslatingSelection => _isTranslatingSelection;
  ReaderSettings get settings => _settings;
  List<String> get pages => _pages;
  Map<int, String> get translatedPages => _translatedPages;
  Size get screenSize => _screenSize;
  EdgeInsets get safeArea => _safeArea;
  double get currentZoom => _currentZoom;
  bool get allowPageTurn => _allowPageTurn;
  Offset get toolPanelPosition => _toolPanelPosition;
  Animation<double>? get controlsAnimation => _controlsAnimation;
  Animation<double>? get toolPanelAnimation => _toolPanelAnimation;
  Animation<double>? get leftPanelAnimation => _leftPanelAnimation;
  PageController? get pageController => _pageController;
  TextEditingController get searchController => _searchController;
  FocusNode get searchFocusNode => _searchFocusNode;
  List<int> get searchResults => _searchResults;
  int get currentSearchIndex => _currentSearchIndex;
  String get searchQuery => _searchQuery;
  ReaderStorageManager get storageManager => _storageManager;
  bool get isSpeaking => _isSpeaking;
  bool get isTtsInitialized => _isTtsInitialized;
  bool get isAudiobookActive =>
      _audiobookStatus.isActive || _audiobookStatus.isPaused;
  AudiobookStatus get audiobookStatus => _audiobookStatus;
  bool get isGeneratingAudio => _isGeneratingAudio;
  TtsInitState get ttsInitState => _ttsInitState;
  String get ttsInitMessage => _ttsInitMessage;
  String get generatingMessage => _generatingMessage;

  /// Check if we should continue async operations
  bool get _shouldContinue => mounted && !_isDisposing && !_isDisposed;

  @override
  void initState() {
    super.initState();
    _safeInit();
  }

  Future<void> _safeInit() async {
    try {
      _pageController = PageController();
      _initAnimations();
      await _initializeReader();

      // Initialize TTS in background (non-blocking)
      _initTtsInBackground();

      await _enableScreenOnSafe();
    } catch (e, stack) {
      _logError('Init error', e, stack);
      if (_shouldContinue) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to initialize reader';
        });
      }
    }
  }

  /// Initialize TTS in background without blocking UI
  void _initTtsInBackground() {
    if (!_shouldContinue) return;

    Future.microtask(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_shouldContinue) return;
      await _initTts();
    });
  }

  Future<void> _initTts() async {
    if (!_shouldContinue) return;
    if (_ttsInitState == TtsInitState.initializingSherpa ||
        _ttsInitState == TtsInitState.loadingModel) {
      return; // Already initializing
    }

    try {
      _updateTtsInitState(
        TtsInitState.initializingSherpa,
        'Initializing speech engine...',
      );

      debugPrint('[TxtReader] Starting TTS initialization...');

      final modelService = ref.read(modelDownloadServiceProvider);

      // Ensure model service is ready
      if (!modelService.isInitialized) {
        _updateTtsInitState(
          TtsInitState.initializingSherpa,
          'Preparing model service...',
        );
        await modelService.ensureInitialized();
      }

      if (!_shouldContinue) return;

      _updateTtsInitState(TtsInitState.loadingModel, 'Loading TTS model...');

      final ttsController = TtsController.instance;
      await ttsController.init(modelService);

      if (!_shouldContinue) return;

      // Try to initialize with active model (with timeout)
      final initialized = await ttsController
          .initializeWithActiveModel()
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              debugPrint('[TxtReader] TTS initialization timed out');
              return false;
            },
          );

      if (!_shouldContinue) return;

      if (initialized) {
        _updateTtsInitState(TtsInitState.ready, 'TTS ready');
        debugPrint('[TxtReader] TTS initialized successfully');
      } else {
        _updateTtsInitState(TtsInitState.error, 'No TTS model available');
        debugPrint('[TxtReader] TTS not initialized - no active model');
      }

      if (_shouldContinue) {
        setState(() {
          _isTtsInitialized = initialized;
        });
      }
    } catch (e, stack) {
      debugPrint('[TxtReader] TTS initialization error: $e\n$stack');
      _logError('TTS init error', e, stack);

      if (_shouldContinue) {
        _updateTtsInitState(TtsInitState.error, 'TTS initialization failed');
        setState(() {
          _isTtsInitialized = false;
        });
      }
    }
  }

  void _updateTtsInitState(TtsInitState state, String message) {
    if (!_shouldContinue) return;
    setState(() {
      _ttsInitState = state;
      _ttsInitMessage = message;
    });
  }

  void _updateGeneratingState(bool isGenerating, String message) {
    if (!_shouldContinue) return;
    setState(() {
      _isGeneratingAudio = isGenerating;
      _generatingMessage = message;
    });
  }

  Future<void> _enableScreenOnSafe() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Failed to enable wakelock: $e');
    }
  }

  Future<void> _disableScreenOnSafe() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Failed to disable wakelock: $e');
    }
  }

  void _initAnimations() {
    _controlsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimationController!,
      curve: Curves.easeInOut,
    );
    _controlsAnimationController!.forward();

    _toolPanelAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _toolPanelAnimation = CurvedAnimation(
      parent: _toolPanelAnimationController!,
      curve: Curves.easeOutBack,
    );

    _leftPanelAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _leftPanelAnimation = CurvedAnimation(
      parent: _leftPanelAnimationController!,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.of(context);
    _screenSize = mediaQuery.size;
    _safeArea = mediaQuery.padding;
  }

  Future<void> _initializeReader() async {
    try {
      await _storageManager.initialize();
      _settings = await _storageManager.getSettings();
      _targetLanguage = _settings.translationSettings.targetLanguage;
      await _loadContent();
    } catch (e, stack) {
      _logError('Initialize reader error', e, stack);
      if (_shouldContinue) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to initialize. Please try again.';
        });
      }
    }
  }

  Future<void> _loadContent() async {
    if (!_shouldContinue) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _translatedPages = {};
      _showTranslatedView = false;
    });

    try {
      final cachedFile = await _cacheManager.getCachedFileIfValid(
        widget.txtUrl,
        extension: '.txt',
      );

      String content;
      if (cachedFile != null) {
        content = await cachedFile.readAsString();
      } else {
        final response = await http
            .get(
              Uri.parse(widget.txtUrl),
              headers: const {
                'User-Agent': 'Mozilla/5.0 (compatible; ArchiveApp/1.0)',
              },
            )
            .timeout(TxtReaderConfig.httpTimeout);

        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}');
        }

        try {
          content = utf8.decode(response.bodyBytes);
        } catch (_) {
          content = latin1.decode(response.bodyBytes);
        }

        _safeSaveToCache(content);
      }

      if (!_shouldContinue) return;

      _content = content;
      _paginateContent();

      setState(() {
        _isLoading = false;
      });

      await _restorePosition();
      await _loadSavedTranslations();
    } catch (e, stack) {
      _logError('Load content error', e, stack);

      if (!_shouldContinue) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  Future<void> _loadSavedTranslations() async {
    if (!_shouldContinue) return;

    try {
      if (!_settings.translationSettings.cacheTranslations) return;

      for (int i = 0; i < _pages.length; i++) {
        if (!_shouldContinue) return;

        final cached = await _storageManager.getCachedTranslation(
          _pages[i],
          _targetLanguage,
        );
        if (cached != null) {
          _translatedPages[i] = cached;
        }
      }
      if (_shouldContinue) setState(() {});
    } catch (e, stack) {
      _logError('Load saved translations error', e, stack);
    }
  }

  Future<void> _safeSaveToCache(String content) async {
    try {
      final cacheFile = await _cacheManager.getCacheFileForUrl(
        widget.txtUrl,
        extension: '.txt',
      );
      await cacheFile.writeAsString(content, flush: true);
    } catch (e, stack) {
      _logError('Cache save error', e, stack);
    }
  }

  void _paginateContent() {
    if (_content == null || _content!.isEmpty) {
      _pages = [];
      _totalPages = 0;
      return;
    }

    final effectiveHeight = _screenSize.height - 180;
    final effectiveWidth = _screenSize.width - (_settings.margin * 2);

    if (effectiveHeight <= 0 || effectiveWidth <= 0) {
      _pages = [_content!];
      _totalPages = 1;
      return;
    }

    final scaledFontSize = _settings.fontSize * getScaleFactor();
    final charsPerLine = (effectiveWidth / (scaledFontSize * 0.55))
        .floor()
        .clamp(1, 1000);
    final linesPerPage =
        (effectiveHeight / (scaledFontSize * _settings.lineHeight))
            .floor()
            .clamp(1, 1000);
    final charsPerPage = (charsPerLine * linesPerPage * 0.85).floor().clamp(
      100,
      100000,
    );

    _pages = _splitIntoPages(_content!, charsPerPage);
    _totalPages = _pages.length;
  }

  double getScaleFactor() {
    if (_screenSize.width < 360) return 0.85;
    if (_screenSize.width >= 600) return 1.1;
    return 1.0;
  }

  List<String> _splitIntoPages(String content, int charsPerPage) {
    final pages = <String>[];
    final paragraphs = content.split('\n');
    String currentPage = '';

    for (final paragraph in paragraphs) {
      final paragraphWithNewline = '$paragraph\n';

      if ((currentPage.length + paragraphWithNewline.length) > charsPerPage) {
        if (currentPage.isNotEmpty) {
          pages.add(currentPage.trim());
          currentPage = '';
        }

        if (paragraphWithNewline.length > charsPerPage) {
          final words = paragraph.split(' ');
          String tempPage = '';

          for (final word in words) {
            if ((tempPage.length + word.length + 1) > charsPerPage) {
              if (tempPage.isNotEmpty) {
                pages.add(tempPage.trim());
                tempPage = '';
              }
            }
            tempPage += '$word ';
          }

          if (tempPage.isNotEmpty) {
            currentPage = tempPage;
          }
        } else {
          currentPage = paragraphWithNewline;
        }
      } else {
        currentPage += paragraphWithNewline;
      }
    }

    if (currentPage.isNotEmpty) {
      pages.add(currentPage.trim());
    }

    return pages.isEmpty ? ['No content'] : pages;
  }

  Future<void> _restorePosition() async {
    if (!_shouldContinue) return;

    try {
      final position = await _storageManager.getReadingPosition(identifier);

      if (position != null &&
          position.page > 0 &&
          position.page <= _totalPages) {
        goToPage(position.page - 1);
      } else if (widget.initialPosition != null &&
          widget.initialPosition! > 0) {
        goToPage(widget.initialPosition! - 1);
      }
    } catch (e, stack) {
      _logError('Restore position error', e, stack);
    }
  }

  void goToPage(int page) {
    if (!_shouldContinue) return;
    if (page < 0 || page >= _totalPages) return;

    try {
      if (_pageController?.hasClients == true) {
        _pageController!.jumpToPage(page);
      }
      setState(() {
        _currentPage = page;
      });
    } catch (e) {
      debugPrint('[TxtReader] Go to page error: $e');
    }
  }

  void savePosition() {
    try {
      final position = ReadingPosition(
        identifier: identifier,
        page: _currentPage + 1,
        progress: _totalPages > 0 ? (_currentPage + 1) / _totalPages : 0,
        metadata: {'title': widget.title},
      );
      _storageManager.saveReadingPosition(position);
    } catch (e, stack) {
      _logError('Save position error', e, stack);
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is SocketException) return 'No internet connection';
    if (error is TimeoutException) return 'Connection timed out';
    if (error is HttpException) return 'Failed to download text file';
    return 'Failed to load text. Please try again.';
  }

  void _logError(String message, dynamic error, StackTrace? stack) {
    debugPrint('⚠️ TxtReader: $message - $error');
  }

  // ========== Language Detection ==========

  String detectLanguage(String text) {
    if (RegExp(r'[ऀ-ॿ]').hasMatch(text)) return 'hi';
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'ar';
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) return 'zh';
    if (RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(text)) return 'ja';
    if (RegExp(r'[\uac00-\ud7af]').hasMatch(text)) return 'ko';
    if (RegExp(r'[\u0400-\u04FF]').hasMatch(text)) return 'ru';
    if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(text)) return 'th';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hi';
    return 'en';
  }

  String detectLanguageName(String text) {
    final code = detectLanguage(text);
    switch (code) {
      case 'hi':
        return 'Hindi';
      case 'ar':
        return 'Arabic';
      case 'zh':
        return 'Chinese';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'ru':
        return 'Russian';
      case 'th':
        return 'Thai';
      default:
        return 'English';
    }
  }

  // ========== TTS Methods ==========

  /// Get text to speak based on current state
  String _getTextToSpeak() {
    if (_pages.isEmpty || _currentPage >= _pages.length) return '';

    // If translated view is shown and translation exists, use translated text
    if (_showTranslatedView && _translatedPages.containsKey(_currentPage)) {
      return _translatedPages[_currentPage]!;
    }

    // Otherwise use original page text
    return _pages[_currentPage];
  }

  Future<void> playSpeaker() async {
    try {
      final pageText = _getTextToSpeak();
      TtsController.instance.speakPageWithLanguageAsync(
        text: pageText,
        bookId: identifier,
        pageNumber: _currentPage,
      );
    } catch (e) {
      debugPrint('[TxtReader] Play speaker error: $e');
    }
  }

  /// Ensure translation is done before speaking if required
  Future<String?> _ensureTranslationIfRequired(int pageIndex) async {
    if (!_shouldContinue) return null;

    // If translation view is active and auto-translate before speak is enabled
    if (_showTranslatedView &&
        _settings.audiobookSettings!.autoTranslateBeforeSpeak) {
      // Check if already translated
      if (_translatedPages.containsKey(pageIndex) &&
          _translatedPages[pageIndex]!.isNotEmpty) {
        return _translatedPages[pageIndex];
      }

      // Need to translate first
      try {
        _updateGeneratingState(true, 'Translating page ${pageIndex + 1}...');

        final pageContent = _pages[pageIndex];
        final translation = await _translateText(pageContent, _targetLanguage);

        if (!_shouldContinue) return null;

        setState(() {
          _translatedPages[pageIndex] = translation;
        });

        // Cache translation
        if (_settings.translationSettings.cacheTranslations) {
          await _storageManager.cacheTranslation(
            pageContent,
            _targetLanguage,
            translation,
          );
        }

        _updateGeneratingState(false, '');
        return translation;
      } catch (e) {
        debugPrint('[TxtReader] Translation before speak failed: $e');
        _updateGeneratingState(false, '');
        // Fall back to original text
        return _pages[pageIndex];
      }
    }

    // Check if we have existing translation
    if (_showTranslatedView && _translatedPages.containsKey(pageIndex)) {
      return _translatedPages[pageIndex];
    }

    // Return original text
    return _pages[pageIndex];
  }

  /// Speak current page (translated if translation view is active)
  Future<void> speakCurrentPage() async {
    if (!_shouldContinue) return;

    try {
      // Check TTS initialization
      if (!_isTtsInitialized) {
        if (_ttsInitState == TtsInitState.initializingSherpa ||
            _ttsInitState == TtsInitState.loadingModel) {
          showSnackBar('TTS is initializing, please wait...');
          return;
        }

        showSnackBar('Initializing TTS...');
        await _initTts();

        if (!_isTtsInitialized) {
          showSnackBar('TTS not available. Please download a TTS model.');
          return;
        }
      }

      if (_pages.isEmpty || _currentPage >= _pages.length) return;

      // Get text (with translation if required)
      final text = await _ensureTranslationIfRequired(_currentPage);
      if (text == null || text.isEmpty || !_shouldContinue) return;

      await _speakText(
        text: text,
        bookId: identifier,
        pageNumber: _currentPage,
      );
    } catch (e, stack) {
      debugPrint('[TxtReader] Speak current page error: $e\n$stack');
      _logError('Speak current page error', e, stack);
      if (_shouldContinue) {
        showSnackBar('Error speaking page');
      }
    }
  }

  /// Speak selected text
  Future<void> speakSelectedText() async {
    if (!_shouldContinue) return;

    try {
      if (_selectedText == null || _selectedText!.isEmpty) return;

      // Check TTS initialization
      if (!_isTtsInitialized) {
        if (_ttsInitState == TtsInitState.initializingSherpa ||
            _ttsInitState == TtsInitState.loadingModel) {
          showSnackBar('TTS is initializing, please wait...');
          return;
        }

        showSnackBar('Initializing TTS...');
        await _initTts();

        if (!_isTtsInitialized) {
          showSnackBar('TTS not available. Please download a TTS model.');
          return;
        }
      }

      await _speakText(text: _selectedText!);
      hideToolPanel();
    } catch (e, stack) {
      debugPrint('[TxtReader] Speak selected text error: $e\n$stack');
      _logError('Speak selected text error', e, stack);
      if (_shouldContinue) {
        showSnackBar('Error speaking selected text');
      }
    }
  }

  /// Core speak method
  Future<void> _speakText({
    required String text,
    String? bookId,
    int? pageNumber,
  }) async {
    if (!_shouldContinue || text.isEmpty) return;

    try {
      setState(() {
        _isSpeaking = true;
      });

      _updateGeneratingState(true, 'Generating audio...');

      final speed = ref.read(ttsSpeedProvider);

      TtsController.instance.speakWithLanguageAsync(
        text: text,
        context: context,
        showUi: true,
        bookId: bookId,
        pageNumber: pageNumber,
        speed: speed,
        onStateChanged: (state) {
          if (!_shouldContinue) return;

          setState(() {
            _isSpeaking =
                state == TtsPlaybackState.playing ||
                state == TtsPlaybackState.loading ||
                state == TtsPlaybackState.generating;

            if (state == TtsPlaybackState.playing) {
              _updateGeneratingState(false, '');
            } else if (state == TtsPlaybackState.generating) {
              _updateGeneratingState(true, 'Generating audio...');
            }
          });
        },
        onError: (error) {
          if (_shouldContinue) {
            showSnackBar('TTS Error: $error');
            setState(() {
              _isSpeaking = false;
            });
            _updateGeneratingState(false, '');
          }
        },
        onCompleted: () {
          if (_shouldContinue) {
            setState(() {
              _isSpeaking = false;
            });
            _updateGeneratingState(false, '');

            // Auto-play next page if enabled (not in audiobook mode)
            if (_settings.autoPlayNextPage &&
                bookId != null &&
                !isAudiobookActive) {
              _autoPlayNextPage();
            }
          }
        },
      );
    } catch (e) {
      if (_shouldContinue) {
        setState(() {
          _isSpeaking = false;
        });
        _updateGeneratingState(false, '');
        showSnackBar('Failed to speak text');
      }
    }
  }

  /// Auto-play next page
  void _autoPlayNextPage() {
    if (!_shouldContinue) return;
    if (_currentPage < _totalPages - 1) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_shouldContinue && !_isSpeaking) {
          goToPage(_currentPage + 1);
          speakCurrentPage();
        }
      });
    }
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    try {
      if (mounted) {
        await TtsController.instance.stop(context);
      } else {
        TtsController.instance.forceStop();
      }

      if (_shouldContinue) {
        setState(() {
          _isSpeaking = false;
        });
        _updateGeneratingState(false, '');
      }
    } catch (e) {
      debugPrint('[TxtReader] Stop speaking error: $e');
    }
  }

  /// Pre-generate audio for upcoming pages
  Future<void> preGenerateAudio({int pagesToGenerate = 5}) async {
    if (!_shouldContinue) return;
    if (!_isTtsInitialized || _pages.isEmpty) {
      showSnackBar('TTS not available');
      return;
    }

    final startPage = _currentPage;
    final endPage = (_currentPage + pagesToGenerate).clamp(0, _totalPages - 1);

    _updateGeneratingState(true, 'Pre-generating audio...');

    try {
      for (int i = startPage; i <= endPage; i++) {
        if (!_shouldContinue) break;

        _updateGeneratingState(
          true,
          'Generating page ${i + 1} of ${endPage + 1}...',
        );

        // Get text (with translation if required)
        final text = await _ensureTranslationIfRequired(i);
        if (text == null || text.isEmpty) continue;

        await TtsController.instance.generateOnly(
          text: text,
          bookId: identifier,
          pageNumber: i,
          useCache: true,
        );
      }

      if (_shouldContinue) {
        showSnackBar('Pre-generated ${endPage - startPage + 1} pages');
      }
    } catch (e) {
      if (_shouldContinue) {
        showSnackBar('Failed to pre-generate audio');
      }
    } finally {
      _updateGeneratingState(false, '');
    }
  }

  /// Check if current page is cached
  Future<bool> isCurrentPageCached() async {
    try {
      return await TtsController.instance.isPageCached(
        bookId: identifier,
        pageNumber: _currentPage,
      );
    } catch (e) {
      return false;
    }
  }

  // ========== Audiobook Methods ==========

  /// Start audiobook mode
  Future<void> startAudiobook({int? fromPage}) async {
    if (!_shouldContinue) return;

    try {
      // Check TTS initialization
      if (!_isTtsInitialized) {
        if (_ttsInitState == TtsInitState.initializingSherpa ||
            _ttsInitState == TtsInitState.loadingModel) {
          showSnackBar('TTS is initializing, please wait...');
          return;
        }

        _updateGeneratingState(true, 'Initializing TTS...');
        await _initTts();

        if (!_isTtsInitialized) {
          showSnackBar('TTS not available. Please download a TTS model.');
          _updateGeneratingState(false, '');
          return;
        }
      }

      // Stop any existing playback
      await _stopAudiobookSafe();

      // Create new controller with function references
      _audiobookController = AudiobookController(
        getPages: () => _pages,
        getTranslatedPages: () => _translatedPages,
        isTranslationViewActive: () => _showTranslatedView,
        bookId: identifier,
        settings: _settings.audiobookSettings!,
        targetLanguage: _targetLanguage,
        detectLanguage: detectLanguageName,
        onTranslatePage: (pageIndex) async {
          if (!_shouldContinue) return null;

          try {
            if (_pages.isEmpty || pageIndex >= _pages.length) return null;

            final pageContent = _pages[pageIndex];
            final translation = await _translateText(
              pageContent,
              _targetLanguage,
            );

            if (_shouldContinue) {
              setState(() {
                _translatedPages[pageIndex] = translation;
              });
            }

            // Cache translation
            if (_settings.translationSettings.cacheTranslations) {
              await _storageManager.cacheTranslation(
                pageContent,
                _targetLanguage,
                translation,
              );
            }

            return translation;
          } catch (e) {
            debugPrint('[Audiobook] Translation error: $e');
            return null;
          }
        },
        onPageChanged: (pageIndex) {
          if (_shouldContinue && pageIndex >= 0 && pageIndex < _totalPages) {
            try {
              goToPage(pageIndex);
            } catch (e) {
              debugPrint('[Audiobook] Page change error: $e');
            }
          }
        },
        onMessage: (message) {
          if (_shouldContinue) {
            try {
              showSnackBar(message);
            } catch (e) {
              debugPrint('[Audiobook] Message error: $e');
            }
          }
        },
        onStatusChanged: (status) {
          if (_shouldContinue) {
            try {
              setState(() {
                _audiobookStatus = status;
                _isSpeaking = status.isActive;
                _isGeneratingAudio =
                    status.isGenerating || status.isTranslating;
                _generatingMessage = status.isTranslating
                    ? 'Translating page ${status.currentPage + 1}...'
                    : status.isGenerating
                    ? 'Generating audio...'
                    : '';
              });
            } catch (e) {
              debugPrint('[Audiobook] Status change error: $e');
            }
          }
        },
      );

      // Subscribe to status updates
      _audiobookSubscription?.cancel();
      _audiobookSubscription = _audiobookController!.statusStream.listen(
        (status) {
          if (_shouldContinue) {
            try {
              setState(() {
                _audiobookStatus = status;
                _isSpeaking = status.isActive;
                _isGeneratingAudio =
                    status.isGenerating || status.isTranslating;
                _generatingMessage = status.isTranslating
                    ? 'Translating page ${status.currentPage + 1}...'
                    : status.isGenerating
                    ? 'Generating audio...'
                    : '';
              });

              // Auto dispose when completed
              if (status.state == AudiobookState.completed) {
                _handleAudiobookCompleted();
              }
            } catch (e) {
              debugPrint('[Audiobook] Subscription error: $e');
            }
          }
        },
        onError: (e) {
          debugPrint('[Audiobook] Stream error: $e');
        },
      );

      setState(() {
        _showAudiobookControls = true;
      });

      // Start from current page or specified page
      if (_shouldContinue && mounted) {
        await _audiobookController!.start(
          fromPage: fromPage ?? _currentPage,
          context: context,
        );
      }
    } catch (e, stack) {
      debugPrint('[TxtReader] Start audiobook error: $e\n$stack');
      if (_shouldContinue) {
        showSnackBar('Failed to start audiobook');
        setState(() {
          _audiobookStatus = const AudiobookStatus();
          _showAudiobookControls = false;
          _isSpeaking = false;
        });
        _updateGeneratingState(false, '');
      }
    }
  }

  /// Handle audiobook completion
  void _handleAudiobookCompleted() {
    if (!_shouldContinue) return;

    // Delay a bit then clean up
    Future.delayed(const Duration(seconds: 2), () {
      if (_shouldContinue &&
          _audiobookStatus.state == AudiobookState.completed) {
        stopAudiobook();
      }
    });
  }

  /// Stop audiobook mode
  Future<void> stopAudiobook() async {
    await _stopAudiobookSafe();

    if (_shouldContinue) {
      setState(() {
        _audiobookStatus = const AudiobookStatus();
        _showAudiobookControls = false;
        _isSpeaking = false;
      });
      _updateGeneratingState(false, '');
    }
  }

  Future<void> _stopAudiobookSafe() async {
    try {
      _audiobookSubscription?.cancel();
      _audiobookSubscription = null;

      if (_audiobookController != null) {
        _audiobookController!.forceStop();
        _audiobookController!.dispose();
        _audiobookController = null;
      }
    } catch (e) {
      debugPrint('[TxtReader] Stop audiobook safe error: $e');
    }
  }

  /// Toggle audiobook play/pause
  void toggleAudiobookPlayPause() {
    try {
      _audiobookController?.togglePlayPause();
    } catch (e) {
      debugPrint('[TxtReader] Toggle play/pause error: $e');
    }
  }

  /// Audiobook next page
  Future<void> audiobookNextPage() async {
    if (!_shouldContinue) return;

    try {
      await _audiobookController?.nextPage(context);
    } catch (e) {
      debugPrint('[TxtReader] Next page error: $e');
    }
  }

  /// Audiobook previous page
  Future<void> audiobookPreviousPage() async {
    if (!_shouldContinue) return;

    try {
      await _audiobookController?.previousPage(context);
    } catch (e) {
      debugPrint('[TxtReader] Previous page error: $e');
    }
  }

  /// Toggle audiobook mode (start/stop)
  Future<void> toggleAudiobookMode() async {
    if (isAudiobookActive) {
      await stopAudiobook();
    } else {
      await startAudiobook();
    }
  }

  // ========== Gesture Handling ==========

  void onPointerDown(PointerDownEvent event) {
    _swipeStartPosition = event.position;
  }

  void onPointerUp(PointerUpEvent event) {}

  void onPointerMove(PointerMoveEvent event) {
    if (_swipeStartPosition != null) {
      final startY = _swipeStartPosition!.dy;
      final currentY = event.position.dy;
      final bottomThreshold =
          _screenSize.height * (1 - TxtReaderConfig.bottomSwipeZone);

      if (startY > bottomThreshold && (startY - currentY) > 50) {
        if (!_isSwipingUp) {
          _isSwipingUp = true;
          showControlsWithFeedback();
        }
      }

      final startX = _swipeStartPosition!.dx;
      final currentX = event.position.dx;
      final leftThreshold = _screenSize.width * TxtReaderConfig.leftPanelZone;

      if (startX < leftThreshold && (currentX - startX) > 50) {
        toggleLeftPanel(true);
      }
    }
  }

  void onPointerCancel(PointerCancelEvent event) {
    _isSwipingUp = false;
    _swipeStartPosition = null;
  }

  void onTapUp(TapUpDetails details) {
    _isSwipingUp = false;
    _swipeStartPosition = null;

    final position = details.globalPosition;

    if (_showToolPanel) {
      hideToolPanel();
      return;
    }

    if (_showLeftPanel) {
      final panelWidth = _screenSize.width * TxtReaderConfig.panelWidthRatio;
      if (position.dx > panelWidth.clamp(280, TxtReaderConfig.maxPanelWidth)) {
        toggleLeftPanel(false);
        return;
      }
    }

    final tapZone = _getTapZone(position);

    switch (tapZone) {
      case _TapZone.leftEdge:
        if (!_showLeftPanel) toggleLeftPanel(true);
        break;
      case _TapZone.left:
        if (_allowPageTurn && _currentPage > 0) goToPage(_currentPage - 1);
        break;
      case _TapZone.right:
        if (_allowPageTurn && _currentPage < _totalPages - 1) {
          goToPage(_currentPage + 1);
        }
        break;
      case _TapZone.center:
      case _TapZone.top:
      case _TapZone.bottom:
        toggleControls();
        break;
    }
  }

  _TapZone _getTapZone(Offset position) {
    final width = _screenSize.width;
    final height = _screenSize.height;
    final leftPanelZone = width * TxtReaderConfig.leftPanelZone;
    final edgeWidth = width * TxtReaderConfig.edgeZone;

    if (position.dx < leftPanelZone) return _TapZone.leftEdge;
    if (position.dx < edgeWidth) return _TapZone.left;
    if (position.dx > width - edgeWidth) return _TapZone.right;
    if (position.dy < height * 0.15) return _TapZone.top;
    if (position.dy > height * 0.85) return _TapZone.bottom;
    return _TapZone.center;
  }

  void onDoubleTap() {
    if (_currentZoom > 1.1) {
      resetZoom();
    } else {
      setState(() {
        _currentZoom = 2.0;
        _allowPageTurn = false;
      });
    }
  }

  // ========== Zoom Handling ==========

  void onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
    _basePanOffset = _panOffset;

    if (details.pointerCount >= 2) {
      setState(() {
        _isZooming = true;
        _allowPageTurn = false;
      });
    }
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2 || _isZooming) {
      setState(() {
        _currentZoom = (_baseZoom * details.scale).clamp(
          TxtReaderConfig.minZoom,
          TxtReaderConfig.maxZoom,
        );

        if (_currentZoom > 1.0) {
          _panOffset = _basePanOffset + details.focalPointDelta;

          final maxPanX = (_screenSize.width * (_currentZoom - 1)) / 2;
          final maxPanY = (_screenSize.height * (_currentZoom - 1)) / 2;

          _panOffset = Offset(
            _panOffset.dx.clamp(-maxPanX, maxPanX),
            _panOffset.dy.clamp(-maxPanY, maxPanY),
          );
        }

        _allowPageTurn = false;
      });
    }
  }

  void onScaleEnd(ScaleEndDetails details) {
    setState(() {
      _isZooming = false;

      if (_currentZoom < 1.1) {
        _currentZoom = 1.0;
        _panOffset = Offset.zero;
        _allowPageTurn = true;
      } else {
        _allowPageTurn = false;
      }
    });
  }

  void resetZoom() {
    setState(() {
      _currentZoom = 1.0;
      _panOffset = Offset.zero;
      _allowPageTurn = true;
    });
  }

  // ========== Controls ==========

  void toggleControls() {
    if (!_shouldContinue) return;

    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _controlsAnimationController?.forward();
      _resetHideControlsTimer();
      HapticFeedback.selectionClick();
    } else {
      _controlsAnimationController?.reverse();
      _hideControlsTimer?.cancel();
    }
  }

  void showControlsWithFeedback() {
    if (!_showControls && _shouldContinue) {
      setState(() {
        _showControls = true;
      });
      _controlsAnimationController?.forward();
      _resetHideControlsTimer();
      HapticFeedback.lightImpact();
    }
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(TxtReaderConfig.controlsAutoHide, () {
      if (_shouldContinue &&
          _showControls &&
          !_showToolPanel &&
          !_showSearchBar &&
          !_showLeftPanel) {
        toggleControls();
      }
    });
  }

  void onPageChanged(int page) {
    if (!_shouldContinue) return;

    setState(() {
      _currentPage = page;
      _currentZoom = 1.0;
      _panOffset = Offset.zero;
      _allowPageTurn = true;
    });

    _savePositionTimer?.cancel();
    _savePositionTimer = Timer(
      TxtReaderConfig.positionSaveDebounce,
      savePosition,
    );

    if (_showControls) _resetHideControlsTimer();

    if (_settings.translationSettings.autoTranslateOnPageChange) {
      translateCurrentPage();
    }
  }

  // ========== Left Panel ==========

  void toggleLeftPanel(bool show) {
    if (show == _showLeftPanel || !_shouldContinue) return;

    setState(() {
      _showLeftPanel = show;
    });

    if (show) {
      _leftPanelAnimationController?.forward();
      HapticFeedback.lightImpact();
    } else {
      _leftPanelAnimationController?.reverse();
    }
  }

  // ========== Text Selection & Tool Panel ==========

  void onTextSelectionChanged(String text) {
    if (text.isEmpty || !_shouldContinue) return;

    setState(() {
      _selectedText = text;
      _selectionTranslation = null;
    });

    _showToolPanelForSelection();
  }

  void _showToolPanelForSelection() {
    if (_showToolPanel || !_shouldContinue) return;

    try {
      setState(() {
        _showToolPanel = true;
        _toolPanelPosition = Offset(
          ((_screenSize.width - 300) / 2).clamp(16, _screenSize.width - 316),
          _safeArea.top + 80,
        );
      });
      _toolPanelAnimationController?.forward();
    } catch (e, stack) {
      debugPrint('[TxtReader] Tool panel show error: $e\n$stack');
      _logError('Tool panel show error', e, stack);
    }
  }

  void hideToolPanel() {
    if (!_shouldContinue) return;

    try {
      _toolPanelAnimationController?.reverse().then((_) {
        if (_shouldContinue) {
          setState(() {
            _showToolPanel = false;
            _selectedText = null;
            _selectionTranslation = null;
          });
        }
      });
    } catch (e, stack) {
      debugPrint('[TxtReader] Tool panel hide error: $e\n$stack');
      _logError('Tool panel hide error', e, stack);
    }
  }

  void updateToolPanelPosition(Offset delta) {
    if (!_shouldContinue) return;

    try {
      setState(() {
        _toolPanelPosition += delta;

        final panelWidth = _screenSize.width < 360 ? 280.0 : 310.0;

        _toolPanelPosition = Offset(
          _toolPanelPosition.dx.clamp(8, _screenSize.width - panelWidth - 8),
          _toolPanelPosition.dy.clamp(
            _safeArea.top + 8,
            _screenSize.height - _safeArea.bottom - 280,
          ),
        );
      });
    } catch (e, stack) {
      debugPrint('[TxtReader] Tool panel position update error: $e\n$stack');
      _logError('Tool panel position update error', e, stack);
    }
  }

  Future<void> copySelectedText() async {
    if (_selectedText == null) return;

    try {
      await Clipboard.setData(ClipboardData(text: _selectedText!));
      showSnackBar('Copied to clipboard');
    } catch (e) {
      debugPrint('[TxtReader] Copy error: $e');
    }
  }

  Future<void> shareSelectedText() async {
    if (_selectedText == null) return;

    try {
      await Clipboard.setData(ClipboardData(text: _selectedText!));
      showSnackBar('Text copied for sharing');
    } catch (e) {
      debugPrint('[TxtReader] Share error: $e');
    }
  }

  Future<void> translateSelectedText() async {
    if (_selectedText == null || _selectedText!.isEmpty || !_shouldContinue) {
      return;
    }

    setState(() {
      _isTranslatingSelection = true;
    });

    try {
      final cached = _translationCache.get(_selectedText!, _targetLanguage);
      if (cached != null) {
        if (_shouldContinue) {
          setState(() {
            _selectionTranslation = cached;
            _isTranslatingSelection = false;
          });
        }
        return;
      }

      final translation = await _translateText(_selectedText!, _targetLanguage);

      if (!_shouldContinue) return;

      _translationCache.set(_selectedText!, _targetLanguage, translation);

      setState(() {
        _selectionTranslation = translation;
        _isTranslatingSelection = false;
      });
    } catch (e, stack) {
      _logError('Translate selection error', e, stack);

      if (!_shouldContinue) return;

      setState(() {
        _isTranslatingSelection = false;
      });
      showSnackBar('Translation failed');
    }
  }

  // ========== Page Translation ==========

  Future<void> translateCurrentPage() async {
    if (!_shouldContinue) return;
    if (_pages.isEmpty || _currentPage >= _pages.length) return;

    if (_translatedPages.containsKey(_currentPage) &&
        _translatedPages[_currentPage]!.isNotEmpty) {
      setState(() {
        _showTranslatedView = true;
      });
      return;
    }

    setState(() {
      _isTranslatingPage = true;
    });

    try {
      final pageContent = _pages[_currentPage];

      final cached = await _storageManager.getCachedTranslation(
        pageContent,
        _targetLanguage,
      );

      String translation;
      if (cached != null) {
        translation = cached;
      } else {
        translation = await _translateText(pageContent, _targetLanguage);

        if (_settings.translationSettings.cacheTranslations) {
          await _storageManager.cacheTranslation(
            pageContent,
            _targetLanguage,
            translation,
          );
        }
      }

      if (!_shouldContinue) return;

      setState(() {
        _translatedPages[_currentPage] = translation;
        _showTranslatedView = true;
        _isTranslatingPage = false;
      });
    } catch (e, stack) {
      _logError('Page translation error', e, stack);

      if (!_shouldContinue) return;

      setState(() {
        _isTranslatingPage = false;
      });
      showSnackBar('Page translation failed');
    }
  }

  void toggleTranslatedView() {
    if (!_shouldContinue) return;

    if (!_translatedPages.containsKey(_currentPage) ||
        _translatedPages[_currentPage]!.isEmpty) {
      translateCurrentPage();
      return;
    }

    setState(() {
      _showTranslatedView = !_showTranslatedView;
    });
  }

  void cancelTranslation() {
    if (_shouldContinue) {
      setState(() {
        _isTranslatingPage = false;
      });
    }
  }

  // ========== Translation API ==========

  Future<String> _translateText(String text, String targetLang) async {
    final sourceLang = detectLanguage(text);

    try {
      // 1️⃣ Primary: MyMemory
      final uri = Uri.https('api.mymemory.translated.net', '/get', {
        'q': text,
        'langpair': '$sourceLang|$targetLang',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['responseData']?['responseStatus'] != 200) {
          return _translateTextFallback(text, targetLang);
        }
        final translatedText =
            data['responseData']?['translatedText'] as String?;
        if (translatedText != null && translatedText.isNotEmpty) {
          return translatedText;
        }
        // fallback automatically
      }
      // fallback on non-200
      return _translateTextFallback(text, targetLang);
    } catch (e) {
      // fallback on exception
      return _translateTextFallback(text, targetLang);
    }
  }

  Future<String> _translateTextFallback(String text, String targetLang) async {
    final sourceLang = detectLanguage(text);
    final Uri url = Uri.parse('${Api.baseUrl}/translation');

    final Map<String, dynamic> payload = {
      'text': text,
      'source': sourceLang,
      'target': targetLang,
    };

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${Api.apiKey}',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final translated = data['translated'] as String?;
        if (data['success'] == true &&
            translated != null &&
            translated.isNotEmpty) {
          return translated;
        }
        throw Exception('Fallback returned empty translation');
      }

      throw Exception(
        'Fallback translation failed: ${response.statusCode} ${response.body}',
      );
    } catch (e, stack) {
      _logError('Fallback translation error', e, stack);
      throw Exception('Fallback translation failed');
    }
  }

  Future<void> showLanguageSelector() async {
    if (!_shouldContinue) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LanguageSelectorSheet(
        currentLanguage: _targetLanguage,
        screenSize: _screenSize,
      ),
    );

    if (selected != null && selected != _targetLanguage && _shouldContinue) {
      setState(() {
        _targetLanguage = selected;
        _selectionTranslation = null;
      });

      final newSettings = _settings.copyWith(
        translationSettings: _settings.translationSettings.copyWith(
          targetLanguage: selected,
        ),
      );
      _settings = newSettings;
      await _storageManager.saveSettings(newSettings);
    }
  }

  // ========== Settings ==========

  void updateSettings(ReaderSettings newSettings) {
    if (!_shouldContinue) return;

    setState(() {
      _settings = newSettings;
      _paginateContent();
    });
    _storageManager.saveSettings(newSettings);
  }

  // ========== Search ==========

  void toggleSearchBar() {
    if (!_shouldContinue) return;

    setState(() {
      _showSearchBar = !_showSearchBar;
      if (_showSearchBar) {
        _searchFocusNode.requestFocus();
      } else {
        clearSearch();
      }
    });
  }

  void performSearch(String query) {
    if (query.isEmpty || !_shouldContinue) return;

    _searchQuery = query;
    _searchResults = [];
    _currentSearchIndex = 0;

    final lowerQuery = query.toLowerCase();

    for (int i = 0; i < _pages.length; i++) {
      if (_pages[i].toLowerCase().contains(lowerQuery)) {
        _searchResults.add(i);
      }
    }

    if (_searchResults.isNotEmpty) {
      goToPage(_searchResults[0]);
      showSnackBar('Found ${_searchResults.length} pages');
    } else {
      showSnackBar('No results found');
    }

    setState(() {});
  }

  void nextSearchResult() {
    if (_searchResults.isEmpty || !_shouldContinue) return;
    _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    goToPage(_searchResults[_currentSearchIndex]);
    setState(() {});
  }

  void previousSearchResult() {
    if (_searchResults.isEmpty || !_shouldContinue) return;
    _currentSearchIndex =
        (_currentSearchIndex - 1 + _searchResults.length) %
        _searchResults.length;
    goToPage(_searchResults[_currentSearchIndex]);
    setState(() {});
  }

  void clearSearch() {
    if (!_shouldContinue) return;

    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _currentSearchIndex = 0;
      _searchController.clear();
    });
  }

  // ========== Bookmarks ==========

  Future<void> addBookmark() async {
    if (!_shouldContinue) return;

    try {
      final bookmark = Bookmark(
        identifier: identifier,
        page: _currentPage + 1,
        title: 'Page ${_currentPage + 1}',
      );

      await _storageManager.addBookmark(bookmark);
      showSnackBar('Bookmark added');
    } catch (e, stack) {
      _logError('Add bookmark error', e, stack);
      showSnackBar('Failed to add bookmark');
    }
  }

  // ========== Go to Page Dialog ==========

  void showGoToPageDialog() {
    if (!_shouldContinue) return;

    showDialog(
      context: context,
      builder: (context) => GoToPageDialog(
        currentPage: _currentPage,
        totalPages: _totalPages,
        onPageSelected: (page) {
          goToPage(page);
        },
      ),
    );
  }

  // ========== Utilities ==========

  void showSnackBar(String message) {
    if (!_shouldContinue) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: EdgeInsets.only(
            bottom: _screenSize.height - 150,
            left: 16,
            right: 16,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[TxtReader] Snackbar error: $e');
    }
  }

  void reload() {
    _loadContent();
  }

  Color getBackgroundColor() {
    switch (_settings.theme) {
      case 'light':
        return Colors.white;
      case 'sepia':
        return const Color(0xFFF5E6C8);
      case 'dark':
      default:
        return const Color(0xFF1A1A1A);
    }
  }

  Color getTextColor() {
    switch (_settings.theme) {
      case 'light':
        return Colors.black87;
      case 'sepia':
        return const Color(0xFF5B4636);
      case 'dark':
      default:
        return Colors.grey[300]!;
    }
  }

  Color getControlsBackgroundColor() {
    switch (_settings.theme) {
      case 'light':
        return Colors.white.withValues(alpha: 0.98);
      case 'sepia':
        return const Color(0xFFF5E6C8).withValues(alpha: 0.98);
      case 'dark':
      default:
        return const Color(0xFF252525).withValues(alpha: 0.98);
    }
  }

  // ========== Back Button Handler ==========

  Future<bool> _handleBackPress() async {
    // If audiobook is active, confirm before exit
    if (isAudiobookActive) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stop Audiobook?'),
          content: const Text('Audiobook is playing. Stop and exit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Stop & Exit'),
            ),
          ],
        ),
      );

      if (shouldExit == true) {
        await stopAudiobook();
        return true;
      }
      return false;
    } else if (_isSpeaking) {
      await stopSpeaking();
      return true;
    }

    return true;
  }

  // ========== Dispose ==========

  @override
  void dispose() {
    _isDisposing = true;
    _isDisposed = true;

    // Safe dispose
    _safeDispose();

    super.dispose();
  }

  void _safeDispose() {
    try {
      // 1. Stop audiobook first
      _stopAudiobookSafe();

      // 2. Stop any TTS playback
      _stopTtsSafe();

      // 3. Save position
      _savePositionSafe();

      // 4. Disable screen
      _disableScreenOnSafe();
    } catch (e) {
      debugPrint('[TxtReader] Dispose error: $e');
    } finally {
      // 5. Cancel timers
      _hideControlsTimer?.cancel();
      _savePositionTimer?.cancel();

      // 6. Dispose controllers
      _controlsAnimationController?.dispose();
      _toolPanelAnimationController?.dispose();
      _leftPanelAnimationController?.dispose();
      _pageController?.dispose();
      _searchController.dispose();
      _searchFocusNode.dispose();
    }
  }

  void _stopTtsSafe() {
    try {
      if (_isSpeaking) {
        TtsController.instance.forceStop();
      }
    } catch (e) {
      debugPrint('[TxtReader] Stop TTS safe error: $e');
    }
  }

  void _savePositionSafe() {
    try {
      savePosition();
    } catch (e) {
      debugPrint('[TxtReader] Save position error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final canPop = await _handleBackPress();
        if (canPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: getBackgroundColor(),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Listener(
            onPointerDown: onPointerDown,
            onPointerUp: onPointerUp,
            onPointerMove: onPointerMove,
            onPointerCancel: onPointerCancel,
            child: Stack(
              children: [
                // Main Content
                if (!_hasError && !_isLoading && _pages.isNotEmpty)
                  ReaderContent(readerState: this)
                else if (_hasError)
                  ReaderErrorView(
                    errorMessage: _errorMessage,
                    textColor: getTextColor(),
                    onRetry: reload,
                    onBack: () => Navigator.pop(context),
                  )
                else if (_isLoading)
                  ReaderLoadingOverlay(
                    textColor: getTextColor(),
                    message: 'Loading document...',
                  ),

                // ========== TTS INITIALIZATION INDICATOR ==========
                if (_ttsInitState == TtsInitState.initializingSherpa ||
                    _ttsInitState == TtsInitState.loadingModel)
                  _buildTtsInitIndicatorTopRight(),

                // ========== GENERATION/TRANSLATION INDICATOR ==========
                if (_isGeneratingAudio && !isAudiobookActive)
                  _buildGeneratingIndicator(),

                // Zoom indicator
                if (_currentZoom > 1.0)
                  ZoomIndicator(
                    zoom: _currentZoom,
                    isZooming: _isZooming,
                    onReset: resetZoom,
                    safeArea: _safeArea,
                    showControls: _showControls,
                  ),

                // Top Controls
                if (_controlsAnimation != null)
                  ReaderTopControls(readerState: this),

                // Search Bar
                if (_showSearchBar) ReaderSearchBar(readerState: this),

                // Bottom Controls
                if (_controlsAnimation != null)
                  ReaderBottomControls(readerState: this),

                // Controls hint
                if (!_showControls &&
                    !_isLoading &&
                    !_hasError &&
                    !isAudiobookActive)
                  ControlsHint(safeArea: _safeArea),

                // Search Navigation
                if (_searchResults.isNotEmpty && !_showSearchBar)
                  SearchNavigationBar(
                    query: _searchQuery,
                    currentIndex: _currentSearchIndex,
                    totalResults: _searchResults.length,
                    onPrevious: previousSearchResult,
                    onNext: nextSearchResult,
                    onClear: clearSearch,
                    safeArea: _safeArea,
                  ),

                // Floating Tool Panel
                if (_showToolPanel && _toolPanelAnimation != null)
                  FloatingToolPanel(readerState: this),

                // Page Translation Loading
                if (_isTranslatingPage)
                  TranslatingOverlay(
                    targetLanguage:
                        TranslationLanguage.fromCode(_targetLanguage)?.name ??
                        _targetLanguage,
                    onCancel: cancelTranslation,
                  ),

                // Left Panel
                if (_leftPanelAnimation != null) LeftPanel(readerState: this),

                // ========== AUDIOBOOK DRAGGABLE CONTROLS ==========
                if (_showAudiobookControls && isAudiobookActive)
                  DraggableAudiobookControls(
                    status: _audiobookStatus,
                    onPlayPause: toggleAudiobookPlayPause,
                    onStop: stopAudiobook,
                    onPrevious: audiobookPreviousPage,
                    onNext: audiobookNextPage,
                    onClose: stopAudiobook,
                    backgroundColor: getControlsBackgroundColor(),
                    textColor: getTextColor(),
                    screenSize: _screenSize,
                    safeArea: _safeArea,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build TTS initialization indicator
  Widget _buildTtsInitIndicatorTopRight() {
    final isLoadingModel = _ttsInitState == TtsInitState.loadingModel;
    final color = isLoadingModel ? Colors.blue : Colors.orange;
    final icon = isLoadingModel ? Icons.download : Icons.settings;

    return Positioned(
      top: _safeArea.top + 12,
      right: 12,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                isLoadingModel ? 'Loading model...' : 'Initializing...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build generating audio indicator
  Widget _buildGeneratingIndicator() {
    return Positioned(
      top: _safeArea.top + 70,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _generatingMessage.contains('Translating')
                ? Colors.purple.withValues(alpha: 0.95)
                : Colors.amber.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _generatingMessage.isEmpty
                      ? 'Processing...'
                      : _generatingMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  stopSpeaking();
                  _updateGeneratingState(false, '');
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tap zone enum
enum _TapZone { leftEdge, left, right, center, top, bottom }
