import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;

import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/epub_exceptions.dart';
import '../../../core/utils/safe_async.dart';
import '../../../core/utils/memory_manager.dart';
import '../models/epub_book.dart';
import '../models/epub_chapter.dart';
import '../models/reading_progress.dart';
import 'epub_parser_service.dart';
import 'epub_cache_service.dart';

/// Reading state for the current book
class ReadingState {
  final EpubBook? book;
  final EpubChapter? currentChapter;
  final ReadingProgress? progress;
  final int currentChapterIndex;
  final double chapterScrollPosition;
  final bool isLoading;
  final String? error;
  final List<EpubChapter> loadedChapters;
  final ReaderSettings settings;

  const ReadingState({
    this.book,
    this.currentChapter,
    this.progress,
    this.currentChapterIndex = 0,
    this.chapterScrollPosition = 0.0,
    this.isLoading = false,
    this.error,
    this.loadedChapters = const [],
    this.settings = const ReaderSettings(),
  });

  bool get hasBook => book != null;
  bool get hasChapter => currentChapter != null;
  bool get hasProgress => progress != null;
  bool get hasError => error != null;

  int get totalChapters => book?.chapterCount ?? 0;
  bool get canGoNext => currentChapterIndex < totalChapters - 1;
  bool get canGoPrevious => currentChapterIndex > 0;

  double get overallProgress {
    if (totalChapters == 0) return 0.0;
    return (currentChapterIndex + chapterScrollPosition) / totalChapters;
  }

  ReadingState copyWith({
    EpubBook? book,
    EpubChapter? currentChapter,
    ReadingProgress? progress,
    int? currentChapterIndex,
    double? chapterScrollPosition,
    bool? isLoading,
    String? error,
    List<EpubChapter>? loadedChapters,
    ReaderSettings? settings,
  }) {
    return ReadingState(
      book: book ?? this.book,
      currentChapter: currentChapter ?? this.currentChapter,
      progress: progress ?? this.progress,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      chapterScrollPosition:
          chapterScrollPosition ?? this.chapterScrollPosition,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      loadedChapters: loadedChapters ?? this.loadedChapters,
      settings: settings ?? this.settings,
    );
  }
}

/// Reader settings
class ReaderSettings {
  final double fontSize;
  final double lineHeight;
  final double margin;
  final ReadingTheme theme;
  final ReaderFont fontFamily;
  final bool keepScreenOn;
  final bool showProgressBar;
  final bool enableTapNavigation;
  final bool enableSwipeNavigation;
  final double brightness;
  final bool autoSaveProgress;
  final Duration autoSaveInterval;

  const ReaderSettings({
    this.fontSize = AppConstants.defaultFontSize,
    this.lineHeight = AppConstants.defaultLineHeight,
    this.margin = AppConstants.defaultMargin,
    this.theme = ReadingTheme.light,
    this.fontFamily = ReaderFont.system,
    this.keepScreenOn = true,
    this.showProgressBar = true,
    this.enableTapNavigation = true,
    this.enableSwipeNavigation = true,
    this.brightness = 1.0,
    this.autoSaveProgress = true,
    this.autoSaveInterval = const Duration(seconds: 30),
  });

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? margin,
    ReadingTheme? theme,
    ReaderFont? fontFamily,
    bool? keepScreenOn,
    bool? showProgressBar,
    bool? enableTapNavigation,
    bool? enableSwipeNavigation,
    double? brightness,
    bool? autoSaveProgress,
    Duration? autoSaveInterval,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      margin: margin ?? this.margin,
      theme: theme ?? this.theme,
      fontFamily: fontFamily ?? this.fontFamily,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      showProgressBar: showProgressBar ?? this.showProgressBar,
      enableTapNavigation: enableTapNavigation ?? this.enableTapNavigation,
      enableSwipeNavigation:
          enableSwipeNavigation ?? this.enableSwipeNavigation,
      brightness: brightness ?? this.brightness,
      autoSaveProgress: autoSaveProgress ?? this.autoSaveProgress,
      autoSaveInterval: autoSaveInterval ?? this.autoSaveInterval,
    );
  }

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'margin': margin,
    'theme': theme.name,
    'fontFamily': fontFamily.name,
    'keepScreenOn': keepScreenOn,
    'showProgressBar': showProgressBar,
    'enableTapNavigation': enableTapNavigation,
    'enableSwipeNavigation': enableSwipeNavigation,
    'brightness': brightness,
    'autoSaveProgress': autoSaveProgress,
    'autoSaveInterval': autoSaveInterval.inSeconds,
  };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    return ReaderSettings(
      fontSize:
          (json['fontSize'] as num?)?.toDouble() ??
          AppConstants.defaultFontSize,
      lineHeight:
          (json['lineHeight'] as num?)?.toDouble() ??
          AppConstants.defaultLineHeight,
      margin:
          (json['margin'] as num?)?.toDouble() ?? AppConstants.defaultMargin,
      theme: ReadingTheme.values.firstWhere(
        (e) => e.name == json['theme'],
        orElse: () => ReadingTheme.light,
      ),
      fontFamily: ReaderFont.values.firstWhere(
        (e) => e.name == json['fontFamily'],
        orElse: () => ReaderFont.system,
      ),
      keepScreenOn: json['keepScreenOn'] as bool? ?? true,
      showProgressBar: json['showProgressBar'] as bool? ?? true,
      enableTapNavigation: json['enableTapNavigation'] as bool? ?? true,
      enableSwipeNavigation: json['enableSwipeNavigation'] as bool? ?? true,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
      autoSaveProgress: json['autoSaveProgress'] as bool? ?? true,
      autoSaveInterval: Duration(
        seconds: json['autoSaveInterval'] as int? ?? 30,
      ),
    );
  }
}

/// EPUB Reader Service - Main reading functionality
class EpubReaderService {
  EpubReaderService._();

  static final EpubReaderService _instance = EpubReaderService._();
  static EpubReaderService get instance => _instance;

  // Dependencies
  final EpubParserService _parserService = EpubParserService.instance;
  final EpubCacheService _cacheService = EpubCacheService.instance;
  final MemoryManager _memoryManager = MemoryManager.instance;

  // Hive boxes
  Box<dynamic>? _booksBox;
  Box<dynamic>? _progressBox;
  Box<dynamic>? _settingsBox;

  // Current reading state
  ReadingState _currentState = const ReadingState();
  final StreamController<ReadingState> _stateController =
      StreamController<ReadingState>.broadcast();

  // Reading session tracking
  DateTime? _sessionStartTime;
  int _sessionStartChapter = 0;
  int _wordsReadInSession = 0;

  // Auto-save timer
  Timer? _autoSaveTimer;

  // Preload queue
  final Set<int> _preloadingChapters = {};

  // Is initialized
  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;
  ReadingState get currentState => _currentState;
  Stream<ReadingState> get stateStream => _stateController.stream;
  EpubBook? get currentBook => _currentState.book;
  EpubChapter? get currentChapter => _currentState.currentChapter;
  ReadingProgress? get currentProgress => _currentState.progress;
  ReaderSettings get settings => _currentState.settings;

  /// Initialize reader service
  Future<Result<void>> initialize() async {
    if (_isInitialized) return Result.success(null);

    return SafeAsync.run(() async {
      // Initialize Hive boxes
      _booksBox = await Hive.openBox(AppConstants.hiveBooksBox);
      _progressBox = await Hive.openBox(AppConstants.hiveProgressBox);
      _settingsBox = await Hive.openBox(AppConstants.hiveSettingsBox);

      // Load saved settings
      final savedSettings = _settingsBox?.get('reader_settings');
      if (savedSettings != null) {
        try {
          final settings = ReaderSettings.fromJson(
            Map<String, dynamic>.from(savedSettings as Map),
          );
          _updateState(_currentState.copyWith(settings: settings));
        } catch (e) {
          debugPrint('Failed to load settings: $e');
        }
      }

      // Initialize dependencies
      await _parserService.initialize();
      await _cacheService.initialize();

      // Setup memory pressure listener
      _memoryManager.addListener(_handleMemoryPressure);

      _isInitialized = true;
      debugPrint('EpubReaderService initialized');
    }, operationName: 'EpubReaderService.initialize');
  }

  /// Dispose service
  Future<void> dispose() async {
    try {
      // End any active session
      await _endReadingSession();

      // Cancel auto-save
      _autoSaveTimer?.cancel();

      // Close state stream
      await _stateController.close();

      // Remove memory listener
      _memoryManager.removeListener(_handleMemoryPressure);

      // Close Hive boxes
      await _booksBox?.close();
      await _progressBox?.close();
      await _settingsBox?.close();

      _isInitialized = false;
      debugPrint('EpubReaderService disposed');
    } catch (e) {
      debugPrint('EpubReaderService dispose error: $e');
    }
  }

  // ===========================================================================
  // BOOK OPERATIONS
  // ===========================================================================

  /// Open a book for reading
  Future<Result<EpubBook>> openBook(String filePath) async {
    return SafeAsync.run(() async {
      _updateState(_currentState.copyWith(isLoading: true, error: null));

      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileException.notFound(path: filePath);
      }

      // Parse the book
      final parseResult = await _parserService.parseBook(filePath);
      if (parseResult.isFailure) {
        throw parseResult.error!;
      }

      final book = parseResult.requireData;

      // Save book to library
      await _saveBook(book);

      // Load or create reading progress
      final progress = await _loadOrCreateProgress(book.id);

      // Load the current chapter
      final chapterResult = await _loadChapter(
        book: book,
        chapterIndex: progress.chapterIndex,
      );

      if (chapterResult.isFailure) {
        throw chapterResult.error!;
      }

      final chapter = chapterResult.requireData;

      // Update state
      _updateState(
        ReadingState(
          book: book,
          currentChapter: chapter,
          progress: progress,
          currentChapterIndex: progress.chapterIndex,
          chapterScrollPosition: progress.chapterProgress,
          isLoading: false,
          loadedChapters: [chapter],
          settings: _currentState.settings,
        ),
      );

      // Start reading session
      _startReadingSession();

      // Start auto-save
      _startAutoSave();

      // Preload adjacent chapters
      _preloadAdjacentChapters(progress.chapterIndex);

      return book;
    }, operationName: 'openBook');
  }

  /// Process chapter images - extract, cache, and update HTML
  Future<EpubChapter> _processChapterImages(
    EpubBook book,
    EpubChapter chapter,
  ) async {
    if (chapter.images.isEmpty || book.filePath == null) {
      debugPrint('No images to process for chapter ${chapter.index}');
      return chapter;
    }

    try {
      debugPrint(
        'Processing ${chapter.images.length} images for chapter ${chapter.index}',
      );

      final imagesResult = await _parserService.extractChapterImages(
        filePath: book.filePath!,
        chapterHref: chapter.href,
      );

      if (imagesResult.isFailure) {
        debugPrint(
          'Failed to extract images for chapter ${chapter.index}: ${imagesResult.error}',
        );
        return chapter;
      }

      final imagesBytes = imagesResult.requireData;
      debugPrint('Extracted ${imagesBytes.length} image bytes');

      final updatedImages = <ChapterImage>[];
      String updatedHtmlContent = chapter.htmlContent ?? '';

      for (final img in chapter.images) {
        debugPrint('Processing image: ${img.src}');

        Uint8List? bytes = _findImageBytes(imagesBytes, img.src, chapter.href);

        if (bytes == null) {
          debugPrint('No bytes found for image: ${img.src}');
          updatedImages.add(img);
          continue;
        }

        debugPrint('Found ${bytes.length} bytes for image: ${img.src}');

        final cacheKey = _buildImageCacheKey(book.id, chapter.index, img.src);

        // Cache image and get the file path directly
        final cacheRes = await _cacheService.cacheImage(cacheKey, bytes);

        if (cacheRes.isFailure) {
          debugPrint('cacheImage error: ${cacheRes.error}');
          updatedImages.add(img);
          continue;
        }

        // Use the returned file path directly (no separate getImagePath call)
        final localPath = cacheRes.requireData;

        debugPrint('Image cached at: $localPath');

        // Update image with local path
        final updatedImage = img.copyWith(localPath: localPath);
        updatedImages.add(updatedImage);

        // Update HTML content to use local file path
        updatedHtmlContent = _replaceImageSrcInHtml(
          updatedHtmlContent,
          img.src,
          localPath,
        );
      }

      debugPrint(
        'Processed ${updatedImages.where((i) => i.localPath != null).length}/${updatedImages.length} images successfully',
      );

      return chapter.copyWith(
        images: updatedImages,
        htmlContent: updatedHtmlContent,
      );
    } catch (e, st) {
      debugPrint('processChapterImages error: $e\n$st');
      return chapter;
    }
  }

  /// Find image bytes with various key formats
  Uint8List? _findImageBytes(
    Map<String, Uint8List> imagesBytes,
    String imageSrc,
    String? chapterHref,
  ) {
    // Try exact match
    if (imagesBytes.containsKey(imageSrc)) {
      return imagesBytes[imageSrc];
    }

    // Try normalized path
    final normalizedSrc = _normalizeImagePath(imageSrc);
    if (imagesBytes.containsKey(normalizedSrc)) {
      return imagesBytes[normalizedSrc];
    }

    // Try with chapter base path
    if (chapterHref != null) {
      final chapterDir = path.dirname(chapterHref);
      final resolvedPath = path.normalize(path.join(chapterDir, imageSrc));
      if (imagesBytes.containsKey(resolvedPath)) {
        return imagesBytes[resolvedPath];
      }
    }

    // Try filename only
    final filename = path.basename(imageSrc);
    for (final entry in imagesBytes.entries) {
      if (path.basename(entry.key) == filename) {
        return entry.value;
      }
    }

    // Try case-insensitive match
    final lowerSrc = imageSrc.toLowerCase();
    for (final entry in imagesBytes.entries) {
      if (entry.key.toLowerCase() == lowerSrc ||
          entry.key.toLowerCase().endsWith(lowerSrc) ||
          lowerSrc.endsWith(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return null;
  }

  /// Normalize image path by removing leading ../ and ./
  String _normalizeImagePath(String imagePath) {
    String normalized = imagePath;

    // Remove leading ../
    while (normalized.startsWith('../')) {
      normalized = normalized.substring(3);
    }

    // Remove leading ./
    while (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }

    // Remove leading /
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }

    return normalized;
  }

  /// Build a cache key for an image
  String _buildImageCacheKey(String bookId, int chapterIndex, String imageSrc) {
    // Use only the filename to avoid path issues
    final filename = path.basename(imageSrc);
    // Sanitize the filename
    final sanitized = filename.replaceAll(RegExp(r'[^\w\.-]'), '_');
    return '${bookId}_${chapterIndex}_$sanitized';
  }

  /// Replace image src in HTML content with local file path
  String _replaceImageSrcInHtml(
    String htmlContent,
    String originalSrc,
    String localPath,
  ) {
    // Escape special regex characters in the src
    final escapedSrc = RegExp.escape(originalSrc);

    // Replace in src="..." attributes
    String updated = htmlContent.replaceAllMapped(
      RegExp('src=["\']([^"\']*$escapedSrc)["\']', caseSensitive: false),
      (match) => 'src="file://$localPath"',
    );

    // Also try to match just the filename
    final filename = path.basename(originalSrc);
    final escapedFilename = RegExp.escape(filename);
    updated = updated.replaceAllMapped(
      RegExp('src=["\']([^"\']*$escapedFilename)["\']', caseSensitive: false),
      (match) {
        // Only replace if not already a file:// URL
        if (match.group(0)?.contains('file://') == true) {
          return match.group(0)!;
        }
        return 'src="file://$localPath"';
      },
    );

    return updated;
  }

  /// Open book from book object (already parsed)
  Future<Result<void>> openBookFromModel(EpubBook book) async {
    return SafeAsync.run(() async {
      if (book.filePath == null) {
        throw FileException.notFound();
      }

      await openBook(book.filePath!);
    }, operationName: 'openBookFromModel');
  }

  /// Close current book
  Future<Result<void>> closeBook() async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook) return;

      // Save progress
      await saveProgress();

      // End reading session
      await _endReadingSession();

      // Cancel auto-save
      _autoSaveTimer?.cancel();

      // Clear loaded chapters from cache
      _clearLoadedChapters();

      // Reset state
      _updateState(ReadingState(settings: _currentState.settings));
    }, operationName: 'closeBook');
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  /// Go to next chapter
  Future<Result<EpubChapter>> nextChapter() async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook || !_currentState.canGoNext) {
        throw ReaderException.navigationError(
          bookId: _currentState.book?.id,
          targetChapter: _currentState.currentChapterIndex + 1,
        );
      }

      return await _goToChapter(_currentState.currentChapterIndex + 1);
    }, operationName: 'nextChapter');
  }

  /// Go to previous chapter
  Future<Result<EpubChapter>> previousChapter() async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook || !_currentState.canGoPrevious) {
        throw ReaderException.navigationError(
          bookId: _currentState.book?.id,
          targetChapter: _currentState.currentChapterIndex - 1,
        );
      }

      return await _goToChapter(_currentState.currentChapterIndex - 1);
    }, operationName: 'previousChapter');
  }

  /// Go to specific chapter
  Future<Result<EpubChapter>> goToChapter(int chapterIndex) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook) {
        throw ReaderException.navigationError(targetChapter: chapterIndex);
      }

      if (chapterIndex < 0 || chapterIndex >= _currentState.totalChapters) {
        throw ReaderException.chapterNotFound(
          bookId: _currentState.book?.id,
          chapterIndex: chapterIndex,
        );
      }

      return await _goToChapter(chapterIndex);
    }, operationName: 'goToChapter');
  }

  /// Go to chapter by href
  Future<Result<EpubChapter>> goToChapterByHref(String href) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook) {
        throw ReaderException.navigationError();
      }

      final book = _currentState.book!;
      final chapterIndex = book.chapters.indexWhere((c) => c.href == href);

      if (chapterIndex == -1) {
        throw ReaderException.chapterNotFound(bookId: book.id, chapterId: href);
      }

      return await _goToChapter(chapterIndex);
    }, operationName: 'goToChapterByHref');
  }

  /// Go to table of contents entry
  Future<Result<EpubChapter>> goToTocEntry(TocEntry entry) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook) {
        throw ReaderException.navigationError();
      }

      // Find chapter by href
      final book = _currentState.book!;
      int chapterIndex = -1;

      // Try exact match first
      chapterIndex = book.chapters.indexWhere((c) => c.href == entry.href);

      // Try partial match
      if (chapterIndex == -1) {
        chapterIndex = book.chapters.indexWhere(
          (c) =>
              c.href?.contains(entry.href) == true ||
              entry.href.contains(c.href ?? ''),
        );
      }

      if (chapterIndex == -1) {
        throw ReaderException.chapterNotFound(
          bookId: book.id,
          chapterId: entry.href,
        );
      }

      final chapter = await _goToChapter(chapterIndex);

      return chapter;
    }, operationName: 'goToTocEntry');
  }

  /// Internal method to navigate to chapter
  Future<EpubChapter> _goToChapter(int chapterIndex) async {
    _updateState(_currentState.copyWith(isLoading: true, error: null));

    try {
      // Check if chapter is already loaded
      EpubChapter? chapter = _currentState.loadedChapters
          .cast<EpubChapter?>()
          .firstWhere((c) => c?.index == chapterIndex, orElse: () => null);

      // Load if not cached
      if (chapter == null) {
        final result = await _loadChapter(
          book: _currentState.book!,
          chapterIndex: chapterIndex,
        );

        if (result.isFailure) {
          throw result.error!;
        }

        chapter = result.requireData;
      }

      // Update loaded chapters list (keep limited number)
      final updatedChapters = _updateLoadedChapters(chapter);

      // Update progress
      final updatedProgress = _currentState.progress?.updatePosition(
        chapterIndex: chapterIndex,
        chapterId: chapter.id,
        chapterProgress: 0.0,
        overallProgress: chapterIndex / _currentState.totalChapters,
      );

      // Track words read
      if (_currentState.currentChapter != null) {
        _wordsReadInSession += _currentState.currentChapter!.wordCount;
      }

      // Update state
      _updateState(
        _currentState.copyWith(
          currentChapter: chapter,
          progress: updatedProgress,
          currentChapterIndex: chapterIndex,
          chapterScrollPosition: 0.0,
          isLoading: false,
          loadedChapters: updatedChapters,
        ),
      );

      // Preload adjacent chapters
      _preloadAdjacentChapters(chapterIndex);

      return chapter;
    } catch (e) {
      _updateState(
        _currentState.copyWith(isLoading: false, error: e.toString()),
      );
      rethrow;
    }
  }

  /// Load chapter content
  Future<Result<EpubChapter>> _loadChapter({
    required EpubBook book,
    required int chapterIndex,
  }) async {
    return SafeAsync.run(() async {
      if (chapterIndex < 0 || chapterIndex >= book.chapters.length) {
        debugPrint('❌ Chapter index out of bounds: $chapterIndex');
        throw ReaderException.chapterNotFound(
          bookId: book.id,
          chapterIndex: chapterIndex,
        );
      }

      final chapterMeta = book.chapters[chapterIndex];

      // Check memory cache first
      final cacheKey = '${book.id}_chapter_$chapterIndex';
      final cachedChapter = await _cacheService.getChapter(cacheKey);
      if (cachedChapter != null) {
        return cachedChapter;
      }

      // ✅ ADD: Check if file exists
      if (book.filePath == null) {
        debugPrint('❌ Book filePath is null!');
        throw FileException.notFound();
      }

      final file = File(book.filePath!);
      if (!await file.exists()) {
        debugPrint('❌ EPUB file not found: ${book.filePath}');
        throw FileException.notFound(path: book.filePath);
      }

      // ✅ ADD: Check href
      if (chapterMeta.href == null || chapterMeta.href!.isEmpty) {
        debugPrint('❌ Chapter href is null or empty!');
        throw ReaderException.chapterNotFound(
          bookId: book.id,
          chapterIndex: chapterIndex,
          chapterId: chapterMeta.id,
        );
      }

      // Parse chapter
      final result = await _parserService.parseChapter(
        filePath: book.filePath!,
        chapterIndex: chapterIndex,
        chapterHref: chapterMeta.href ?? '',
        bookId: book.id,
      );

      if (result.isFailure) {
        debugPrint('❌ Parse chapter failed: ${result.error}');
        throw result.error!;
      }

      var chapter = result.requireData;

      debugPrint(
        'Parsed chapter ${chapter.index}: ${chapter.title}, images: ${chapter.images.length}',
      );

      // Process images - extract, cache, and update HTML
      chapter = await _processChapterImages(book, chapter);

      // Cache chapter
      await _cacheService.cacheChapter(cacheKey, chapter);

      return chapter;
    }, operationName: 'loadChapter');
  }

  /// Preload adjacent chapters for smooth navigation
  void _preloadAdjacentChapters(int currentIndex) {
    if (!_currentState.hasBook) return;

    final book = _currentState.book!;
    final preloadCount = AppConstants.chapterPreloadCount;

    // Preload next chapters
    for (int i = 1; i <= preloadCount; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < book.chapterCount &&
          !_preloadingChapters.contains(nextIndex)) {
        _preloadChapter(book, nextIndex);
      }
    }

    // Preload previous chapters
    for (int i = 1; i <= preloadCount; i++) {
      final prevIndex = currentIndex - i;
      if (prevIndex >= 0 && !_preloadingChapters.contains(prevIndex)) {
        _preloadChapter(book, prevIndex);
      }
    }
  }

  /// Preload a single chapter
  Future<void> _preloadChapter(EpubBook book, int chapterIndex) async {
    if (_preloadingChapters.contains(chapterIndex)) return;

    _preloadingChapters.add(chapterIndex);

    try {
      await _loadChapter(book: book, chapterIndex: chapterIndex);
    } catch (e) {
      debugPrint('Failed to preload chapter $chapterIndex: $e');
    } finally {
      _preloadingChapters.remove(chapterIndex);
    }
  }

  /// Update loaded chapters list (memory management)
  List<EpubChapter> _updateLoadedChapters(EpubChapter newChapter) {
    final chapters = List<EpubChapter>.from(_currentState.loadedChapters);

    // Remove if already exists
    chapters.removeWhere((c) => c.index == newChapter.index);

    // Add new chapter
    chapters.add(newChapter);

    // Keep only limited number of chapters
    if (chapters.length > AppConstants.maxCachedChapters) {
      // Remove chapters farthest from current
      chapters.sort((a, b) {
        final distA = (a.index - newChapter.index).abs();
        final distB = (b.index - newChapter.index).abs();
        return distA.compareTo(distB);
      });

      while (chapters.length > AppConstants.maxCachedChapters) {
        final removed = chapters.removeLast();
        // Unload content to free memory
        _cacheService.removeChapter(
          '${_currentState.book?.id}_chapter_${removed.index}',
        );
      }
    }

    return chapters;
  }

  /// Clear all loaded chapters
  void _clearLoadedChapters() {
    if (_currentState.book != null) {
      for (final chapter in _currentState.loadedChapters) {
        _cacheService.removeChapter(
          '${_currentState.book!.id}_chapter_${chapter.index}',
        );
      }
    }
  }

  // ===========================================================================
  // PROGRESS TRACKING
  // ===========================================================================

  /// Update reading position
  Future<Result<void>> updatePosition({
    required double scrollProgress,
    int? characterOffset,
  }) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook || !_currentState.hasProgress) return;

      final overallProgress =
          (_currentState.currentChapterIndex + scrollProgress) /
          _currentState.totalChapters;

      final updatedProgress = _currentState.progress!.updatePosition(
        chapterIndex: _currentState.currentChapterIndex,
        chapterId: _currentState.currentChapter?.id,
        chapterProgress: scrollProgress,
        overallProgress: overallProgress.clamp(0.0, 1.0),
        characterOffset: characterOffset,
      );

      _updateState(
        _currentState.copyWith(
          progress: updatedProgress,
          chapterScrollPosition: scrollProgress,
        ),
      );
    }, operationName: 'updatePosition');
  }

  /// Save reading progress
  Future<Result<void>> saveProgress() async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook || !_currentState.hasProgress) return;

      final progress = _currentState.progress!;

      // Save to Hive
      await _progressBox?.put(progress.bookId, progress.toJson());

      // Update book's last opened time
      final updatedBook = _currentState.book!.copyWith(
        lastOpenedAt: DateTime.now(),
        readingProgress: progress.overallProgress,
        currentChapterIndex: progress.chapterIndex,
      );

      await _saveBook(updatedBook);

      _updateState(
        _currentState.copyWith(book: updatedBook, progress: progress),
      );

      debugPrint(
        'Progress saved: ${(progress.overallProgress * 100).toStringAsFixed(1)}%',
      );
    }, operationName: 'saveProgress');
  }

  /// Load or create reading progress
  Future<ReadingProgress> _loadOrCreateProgress(String bookId) async {
    try {
      final saved = _progressBox?.get(bookId);
      if (saved != null) {
        return ReadingProgress.fromJson(
          Map<String, dynamic>.from(saved as Map),
        );
      }
    } catch (e) {
      debugPrint('Failed to load progress: $e');
    }

    return ReadingProgress.create(bookId: bookId);
  }

  // ===========================================================================
  // BOOKMARKS
  // ===========================================================================

  /// Add bookmark at current position
  Future<Result<Bookmark>> addBookmark({String? note}) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook || !_currentState.hasChapter) {
        throw ReaderException(message: 'No book open');
      }

      final chapter = _currentState.currentChapter!;
      final bookmark = Bookmark.create(
        chapterIndex: chapter.index,
        chapterId: chapter.id,
        chapterTitle: chapter.title,
        chapterProgress: _currentState.chapterScrollPosition,
        previewText: chapter.previewText,
        note: note,
      );

      final updatedProgress = _currentState.progress!.addBookmark(bookmark);

      _updateState(_currentState.copyWith(progress: updatedProgress));
      await saveProgress();

      return bookmark;
    }, operationName: 'addBookmark');
  }

  /// Remove bookmark
  Future<Result<void>> removeBookmark(String bookmarkId) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasProgress) return;

      final updatedProgress = _currentState.progress!.removeBookmark(
        bookmarkId,
      );

      _updateState(_currentState.copyWith(progress: updatedProgress));
      await saveProgress();
    }, operationName: 'removeBookmark');
  }

  /// Go to bookmark
  Future<Result<void>> goToBookmark(Bookmark bookmark) async {
    return SafeAsync.run(() async {
      await goToChapter(bookmark.chapterIndex);

      // Update scroll position
      _updateState(
        _currentState.copyWith(chapterScrollPosition: bookmark.chapterProgress),
      );
    }, operationName: 'goToBookmark');
  }

  /// Get all bookmarks for current book
  List<Bookmark> getBookmarks() {
    return _currentState.progress?.activeBookmarks ?? [];
  }

  // ===========================================================================
  // HIGHLIGHTS
  // ===========================================================================

  /// Add highlight
  Future<Result<Highlight>> addHighlight({
    required String selectedText,
    required int startOffset,
    required int endOffset,
    HighlightColor color = HighlightColor.yellow,
    String? note,
  }) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook || !_currentState.hasChapter) {
        throw ReaderException(message: 'No book open');
      }

      final chapter = _currentState.currentChapter!;

      // Get context around the highlight
      final textContent = chapter.textContent ?? '';
      final contextStart = (startOffset - 30).clamp(0, textContent.length);
      final contextEnd = (endOffset + 30).clamp(0, textContent.length);

      final highlight = Highlight.create(
        chapterIndex: chapter.index,
        chapterId: chapter.id,
        selectedText: selectedText,
        contextBefore: textContent.substring(contextStart, startOffset),
        contextAfter: textContent.substring(endOffset, contextEnd),
        startOffset: startOffset,
        endOffset: endOffset,
        color: color,
        note: note,
      );

      final updatedProgress = _currentState.progress!.addHighlight(highlight);

      _updateState(_currentState.copyWith(progress: updatedProgress));
      await saveProgress();

      return highlight;
    }, operationName: 'addHighlight');
  }

  /// Remove highlight
  Future<Result<void>> removeHighlight(String highlightId) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasProgress) return;

      final updatedProgress = _currentState.progress!.removeHighlight(
        highlightId,
      );

      _updateState(_currentState.copyWith(progress: updatedProgress));
      await saveProgress();
    }, operationName: 'removeHighlight');
  }

  /// Update highlight color
  Future<Result<void>> updateHighlightColor(
    String highlightId,
    HighlightColor color,
  ) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasProgress) return;

      final highlight = _currentState.progress!.highlights.firstWhere(
        (h) => h.id == highlightId,
        orElse: () => throw ReaderException(message: 'Highlight not found'),
      );

      final updatedHighlight = highlight.updateColor(color);
      final updatedProgress = _currentState.progress!.updateHighlight(
        updatedHighlight,
      );

      _updateState(_currentState.copyWith(progress: updatedProgress));
      await saveProgress();
    }, operationName: 'updateHighlightColor');
  }

  /// Get highlights for current chapter
  List<Highlight> getCurrentChapterHighlights() {
    if (!_currentState.hasChapter) return [];

    return _currentState.progress?.activeHighlights
            .where((h) => h.chapterIndex == _currentState.currentChapterIndex)
            .toList() ??
        [];
  }

  /// Get all highlights
  List<Highlight> getAllHighlights() {
    return _currentState.progress?.activeHighlights ?? [];
  }

  // ===========================================================================
  // NOTES
  // ===========================================================================

  /// Add note
  Future<Result<Note>> addNote({
    required String content,
    String? title,
    String? quotedText,
    int? characterOffset,
    NoteType type = NoteType.note,
  }) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook || !_currentState.hasChapter) {
        throw ReaderException(message: 'No book open');
      }

      final chapter = _currentState.currentChapter!;

      final note = Note.create(
        chapterIndex: chapter.index,
        chapterId: chapter.id,
        content: content,
        title: title,
        quotedText: quotedText,
        characterOffset: characterOffset,
        type: type,
      );

      final updatedProgress = _currentState.progress!.addNote(note);

      _updateState(_currentState.copyWith(progress: updatedProgress));
      await saveProgress();

      return note;
    }, operationName: 'addNote');
  }

  /// Remove note
  Future<Result<void>> removeNote(String noteId) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasProgress) return;

      final updatedProgress = _currentState.progress!.removeNote(noteId);

      _updateState(_currentState.copyWith(progress: updatedProgress));
      await saveProgress();
    }, operationName: 'removeNote');
  }

  /// Update note content
  Future<Result<void>> updateNote(String noteId, String newContent) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasProgress) return;

      final note = _currentState.progress!.notes.firstWhere(
        (n) => n.id == noteId,
        orElse: () => throw ReaderException(message: 'Note not found'),
      );

      final updatedNote = note.updateContent(newContent);
      final updatedProgress = _currentState.progress!.updateNote(updatedNote);

      _updateState(_currentState.copyWith(progress: updatedProgress));
      await saveProgress();
    }, operationName: 'updateNote');
  }

  /// Get all notes
  List<Note> getAllNotes() {
    return _currentState.progress?.activeNotes ?? [];
  }

  // ===========================================================================
  // TRANSLATIONS
  // ===========================================================================

  /// Save text translation
  Future<Result<TextTranslation>> saveTextTranslation({
    required String originalText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
    int? startOffset,
    int? endOffset,
    String? context,
    TranslationProvider? provider,
  }) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook || !_currentState.hasChapter) {
        throw ReaderException(message: 'No book open');
      }

      final chapter = _currentState.currentChapter!;

      final translation = TextTranslation.create(
        originalText: originalText,
        translatedText: translatedText,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        chapterIndex: chapter.index,
        chapterId: chapter.id,
        startOffset: startOffset,
        endOffset: endOffset,
        context: context,
        provider: provider,
      );

      final updatedProgress = _currentState.progress!.addTextTranslation(
        translation,
      );

      _updateState(_currentState.copyWith(progress: updatedProgress));
      await saveProgress();

      // Also cache for quick access
      await _cacheService.cacheTranslation(
        bookId: _currentState.book!.id,
        originalText: originalText,
        targetLanguage: targetLanguage,
        translation: translation,
      );

      return translation;
    }, operationName: 'saveTextTranslation');
  }

  /// Get cached translation
  Future<Result<TextTranslation?>> getCachedTranslation({
    required String originalText,
    required String targetLanguage,
  }) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook) return null;

      // Check progress first
      final cached = _currentState.progress?.findTextTranslation(
        originalText: originalText,
        targetLanguage: targetLanguage,
      );

      if (cached != null) {
        // Update usage count
        final updatedTranslation = cached.markAccessed();
        final updatedProgress = _currentState.progress!.updateTextTranslation(
          updatedTranslation,
        );
        _updateState(_currentState.copyWith(progress: updatedProgress));
        return updatedTranslation;
      }

      // Check cache service
      return await _cacheService.getTranslation(
        bookId: _currentState.book!.id,
        originalText: originalText,
        targetLanguage: targetLanguage,
      );
    }, operationName: 'getCachedTranslation');
  }

  /// Save chapter translation
  Future<Result<ChapterTranslation>> saveChapterTranslation({
    required String translatedTitle,
    required String translatedContent,
    required String sourceLanguage,
    required String targetLanguage,
    TranslationProvider? provider,
  }) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook || !_currentState.hasChapter) {
        throw ReaderException(message: 'No book open');
      }

      final chapter = _currentState.currentChapter!;

      final translation = ChapterTranslation.create(
        chapterIndex: chapter.index,
        chapterId: chapter.id,
        originalTitle: chapter.title,
        translatedTitle: translatedTitle,
        originalContent: chapter.htmlContent ?? '',
        translatedContent: translatedContent,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        provider: provider,
      );

      final updatedProgress = _currentState.progress!.addChapterTranslation(
        translation,
      );

      _updateState(_currentState.copyWith(progress: updatedProgress));
      await saveProgress();

      return translation;
    }, operationName: 'saveChapterTranslation');
  }

  /// Get chapter translation
  ChapterTranslation? getChapterTranslation({
    required int chapterIndex,
    required String targetLanguage,
  }) {
    return _currentState.progress?.findChapterTranslation(
      chapterIndex: chapterIndex,
      targetLanguage: targetLanguage,
    );
  }

  /// Get translation statistics
  TranslationStats? getTranslationStats() {
    return _currentState.progress?.getTranslationStats();
  }

  // ===========================================================================
  // SETTINGS
  // ===========================================================================

  /// Update reader settings
  Future<Result<void>> updateSettings(ReaderSettings settings) async {
    return SafeAsync.run(() async {
      _updateState(_currentState.copyWith(settings: settings));

      // Save settings
      await _settingsBox?.put('reader_settings', settings.toJson());
    }, operationName: 'updateSettings');
  }

  /// Increase font size
  Future<Result<void>> increaseFontSize() async {
    final newSize =
        (_currentState.settings.fontSize + AppConstants.fontSizeStep).clamp(
          AppConstants.minFontSize,
          AppConstants.maxFontSize,
        );
    return updateSettings(_currentState.settings.copyWith(fontSize: newSize));
  }

  /// Decrease font size
  Future<Result<void>> decreaseFontSize() async {
    final newSize =
        (_currentState.settings.fontSize - AppConstants.fontSizeStep).clamp(
          AppConstants.minFontSize,
          AppConstants.maxFontSize,
        );
    return updateSettings(_currentState.settings.copyWith(fontSize: newSize));
  }

  /// Set theme
  Future<Result<void>> setTheme(ReadingTheme theme) async {
    return updateSettings(_currentState.settings.copyWith(theme: theme));
  }

  /// Set font
  Future<Result<void>> setFont(ReaderFont font) async {
    return updateSettings(_currentState.settings.copyWith(fontFamily: font));
  }

  // ===========================================================================
  // LIBRARY OPERATIONS
  // ===========================================================================

  /// Get all books in library
  Future<Result<List<EpubBook>>> getLibrary() async {
    return SafeAsync.run(() async {
      final books = <EpubBook>[];

      for (final key in _booksBox?.keys ?? []) {
        try {
          final data = _booksBox?.get(key);
          if (data != null) {
            books.add(
              EpubBook.fromJson(Map<String, dynamic>.from(data as Map)),
            );
          }
        } catch (e) {
          debugPrint('Failed to load book $key: $e');
        }
      }

      return books;
    }, operationName: 'getLibrary');
  }

  /// Delete book from library
  Future<Result<void>> deleteBook(String bookId) async {
    return SafeAsync.run(() async {
      // Close if currently open
      if (_currentState.book?.id == bookId) {
        await closeBook();
      }

      // Delete from Hive
      await _booksBox?.delete(bookId);
      await _progressBox?.delete(bookId);

      // Clear cache
      await _cacheService.clearBookCache(bookId);
    }, operationName: 'deleteBook');
  }

  /// Save book to library
  Future<void> _saveBook(EpubBook book) async {
    await _booksBox?.put(book.id, book.toJson());
  }

  /// ✅ NEW: Public method to save book to library
  Future<Result<void>> saveBookToLibrary(EpubBook book) async {
    return SafeAsync.run(() async {
      await _saveBook(book);
      debugPrint('📚 Book saved to library: ${book.title}');
    }, operationName: 'saveBookToLibrary');
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  /// Search in current book
  Future<Result<List<SearchResult>>> searchInBook(String query) async {
    return SafeAsync.run(() async {
      if (!_currentState.hasBook) {
        throw ReaderException(message: 'No book open');
      }

      return await _parserService
          .searchInBook(filePath: _currentState.book!.filePath!, query: query)
          .then((r) => r.requireData);
    }, operationName: 'searchInBook');
  }

  // ===========================================================================
  // SESSION TRACKING
  // ===========================================================================

  /// Start reading session
  void _startReadingSession() {
    _sessionStartTime = DateTime.now();
    _sessionStartChapter = _currentState.currentChapterIndex;
    _wordsReadInSession = 0;
  }

  /// End reading session and save stats
  Future<void> _endReadingSession() async {
    if (_sessionStartTime == null || !_currentState.hasProgress) return;

    final session = ReadingSession.create(
      startTime: _sessionStartTime!,
      endTime: DateTime.now(),
      startChapterIndex: _sessionStartChapter,
      endChapterIndex: _currentState.currentChapterIndex,
      progressGained: _currentState.overallProgress,
      wordsRead: _wordsReadInSession,
    );

    final updatedProgress = _currentState.progress!.addSession(session);

    _updateState(_currentState.copyWith(progress: updatedProgress));
    await saveProgress();

    _sessionStartTime = null;
    _wordsReadInSession = 0;
  }

  /// Start auto-save timer
  void _startAutoSave() {
    _autoSaveTimer?.cancel();

    if (_currentState.settings.autoSaveProgress) {
      _autoSaveTimer = Timer.periodic(
        _currentState.settings.autoSaveInterval,
        (_) => saveProgress(),
      );
    }
  }

  // ===========================================================================
  // MEMORY MANAGEMENT
  // ===========================================================================

  /// Handle memory pressure
  void _handleMemoryPressure(MemoryPressure pressure) {
    switch (pressure) {
      case MemoryPressure.moderate:
        _unloadDistantChapters(keepCount: 3);
        break;
      case MemoryPressure.high:
        _unloadDistantChapters(keepCount: 2);
        break;
      case MemoryPressure.critical:
        _unloadDistantChapters(keepCount: 1);
        break;
      case MemoryPressure.normal:
        break;
    }
  }

  /// Unload distant chapters to free memory
  void _unloadDistantChapters({required int keepCount}) {
    if (_currentState.loadedChapters.length <= keepCount) return;

    final currentIndex = _currentState.currentChapterIndex;
    final chapters = List<EpubChapter>.from(_currentState.loadedChapters);

    // Sort by distance from current
    chapters.sort((a, b) {
      final distA = (a.index - currentIndex).abs();
      final distB = (b.index - currentIndex).abs();
      return distA.compareTo(distB);
    });

    // Keep only nearest chapters
    final toKeep = chapters.take(keepCount).toList();
    final toUnload = chapters.skip(keepCount);

    // Unload from cache
    for (final chapter in toUnload) {
      _cacheService.removeChapter(
        '${_currentState.book?.id}_chapter_${chapter.index}',
      );
    }

    _updateState(_currentState.copyWith(loadedChapters: toKeep));
  }

  // ===========================================================================
  // STATE MANAGEMENT
  // ===========================================================================

  /// Update state and notify listeners
  void _updateState(ReadingState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }
}
