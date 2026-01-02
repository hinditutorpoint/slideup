import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/epub_exceptions.dart';
import '../../../core/utils/safe_async.dart';
import '../../../core/utils/memory_manager.dart';
import '../../../core/utils/isolate_helper.dart';
import '../models/epub_book.dart';
import '../models/epub_chapter.dart';
import '../models/download_task.dart';
import '../models/reading_progress.dart';
import '../services/epub_download_service.dart';
import '../services/epub_parser_service.dart';
import '../services/epub_reader_service.dart';
import '../services/epub_cache_service.dart';
import '../services/notification_service.dart';
import '../services/background_service.dart';

// =============================================================================
// SERVICE PROVIDERS
// =============================================================================

/// Memory manager provider
final memoryManagerProvider = Provider<MemoryManager>((ref) {
  return MemoryManager.instance;
});

/// Isolate helper provider
final isolateHelperProvider = Provider<IsolateHelper>((ref) {
  return IsolateHelper.instance;
});

/// Download service provider
final downloadServiceProvider = Provider<EpubDownloadService>((ref) {
  return EpubDownloadService.instance;
});

/// Parser service provider
final parserServiceProvider = Provider<EpubParserService>((ref) {
  return EpubParserService.instance;
});

/// Reader service provider
final readerServiceProvider = Provider<EpubReaderService>((ref) {
  return EpubReaderService.instance;
});

/// Cache service provider
final cacheServiceProvider = Provider<EpubCacheService>((ref) {
  return EpubCacheService.instance;
});

/// Notification service provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Background service provider
final backgroundServiceProvider = Provider<BackgroundService>((ref) {
  return BackgroundService.instance;
});

// =============================================================================
// INITIALIZATION PROVIDER
// =============================================================================

/// Initialization state
class InitializationState {
  final bool isInitialized;
  final bool isInitializing;
  final String? error;
  final double progress;
  final String currentStep;

  const InitializationState({
    this.isInitialized = false,
    this.isInitializing = false,
    this.error,
    this.progress = 0.0,
    this.currentStep = '',
  });

  InitializationState copyWith({
    bool? isInitialized,
    bool? isInitializing,
    String? error,
    double? progress,
    String? currentStep,
  }) {
    return InitializationState(
      isInitialized: isInitialized ?? this.isInitialized,
      isInitializing: isInitializing ?? this.isInitializing,
      error: error,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
    );
  }
}

/// Initialization notifier
class InitializationNotifier extends StateNotifier<InitializationState> {
  final Ref _ref;

  InitializationNotifier(this._ref) : super(const InitializationState());

  Future<void> initialize() async {
    if (state.isInitialized || state.isInitializing) return;

    state = state.copyWith(isInitializing: true, progress: 0.0);

    try {
      // Initialize memory manager
      state = state.copyWith(
        currentStep: 'Initializing memory manager...',
        progress: 0.1,
      );
      _ref.read(memoryManagerProvider).initialize();

      // Initialize isolate helper
      state = state.copyWith(
        currentStep: 'Initializing background workers...',
        progress: 0.2,
      );
      await _ref.read(isolateHelperProvider).initialize();

      // Initialize cache service
      state = state.copyWith(
        currentStep: 'Initializing cache...',
        progress: 0.3,
      );
      final cacheResult = await _ref.read(cacheServiceProvider).initialize();
      if (cacheResult.isFailure) {
        throw cacheResult.error!;
      }

      // Initialize parser service
      state = state.copyWith(
        currentStep: 'Initializing parser...',
        progress: 0.4,
      );
      final parserResult = await _ref.read(parserServiceProvider).initialize();
      if (parserResult.isFailure) {
        throw parserResult.error!;
      }

      // Initialize download service
      state = state.copyWith(
        currentStep: 'Initializing download manager...',
        progress: 0.5,
      );
      final downloadResult = await _ref
          .read(downloadServiceProvider)
          .initialize();
      if (downloadResult.isFailure) {
        throw downloadResult.error!;
      }

      // Initialize reader service
      state = state.copyWith(
        currentStep: 'Initializing reader...',
        progress: 0.6,
      );
      final readerResult = await _ref.read(readerServiceProvider).initialize();
      if (readerResult.isFailure) {
        throw readerResult.error!;
      }

      // Initialize notification service
      state = state.copyWith(
        currentStep: 'Initializing notifications...',
        progress: 0.7,
      );
      final notificationResult = await _ref
          .read(notificationServiceProvider)
          .initialize();
      if (notificationResult.isFailure) {
        debugPrint('Notification init warning: ${notificationResult.error}');
        // Don't fail on notification init error
      }

      // Initialize background service
      state = state.copyWith(
        currentStep: 'Initializing background service...',
        progress: 0.8,
      );
      final backgroundResult = await _ref
          .read(backgroundServiceProvider)
          .initialize();
      if (backgroundResult.isFailure) {
        debugPrint('Background init warning: ${backgroundResult.error}');
        // Don't fail on background init error
      }

      // Setup notification action handler
      state = state.copyWith(
        currentStep: 'Setting up handlers...',
        progress: 0.9,
      );
      _setupNotificationHandler();

      state = state.copyWith(
        isInitialized: true,
        isInitializing: false,
        progress: 1.0,
        currentStep: 'Ready',
      );

      debugPrint('EPUB Reader fully initialized');
    } catch (e, st) {
      debugPrint('Initialization error: $e\n$st');
      state = state.copyWith(isInitializing: false, error: e.toString());
    }
  }

  void _setupNotificationHandler() {
    final notificationService = _ref.read(notificationServiceProvider);
    final downloadService = _ref.read(downloadServiceProvider);

    notificationService.actionStream.listen((payload) async {
      try {
        switch (payload.action) {
          case NotificationActions.pause:
            if (payload.taskId != null) {
              await downloadService.pause(payload.taskId!);
            }
            break;
          case NotificationActions.resume:
            if (payload.taskId != null) {
              await downloadService.resume(payload.taskId!);
            }
            break;
          case NotificationActions.cancel:
            if (payload.taskId != null) {
              await downloadService.cancel(payload.taskId!);
            }
            break;
          case NotificationActions.retry:
            if (payload.taskId != null) {
              await downloadService.retry(payload.taskId!);
            }
            break;
          case NotificationActions.open:
            // Handled by UI layer
            break;
        }
      } catch (e) {
        debugPrint('Notification action error: $e');
      }
    });
  }

  void _disposeSafely() {
    SafeAsync.run<void>(() async {
      await Future.wait([
        _ref.read(readerServiceProvider).dispose(),
        _ref.read(downloadServiceProvider).dispose(),
        _ref.read(notificationServiceProvider).dispose(),
        _ref.read(backgroundServiceProvider).dispose(),
        _ref.read(cacheServiceProvider).dispose(),
        _ref.read(parserServiceProvider).dispose(),
        _ref.read(isolateHelperProvider).dispose(),
      ]);

      _ref.read(memoryManagerProvider).dispose();
    }, operationName: 'AppProvider.dispose');
  }

  @override
  Future<void> dispose() async {
    _disposeSafely();
    super.dispose();
  }
}

final initializationProvider =
    StateNotifierProvider<InitializationNotifier, InitializationState>((ref) {
      return InitializationNotifier(ref);
    });

// =============================================================================
// LIBRARY PROVIDERS
// =============================================================================

/// Library state
class LibraryState {
  final List<EpubBook> books;
  final bool isLoading;
  final String? error;
  final BookSortOption sortOption;
  final BookFilterOption filterOption;
  final String searchQuery;

  const LibraryState({
    this.books = const [],
    this.isLoading = false,
    this.error,
    this.sortOption = BookSortOption.dateAdded,
    this.filterOption = BookFilterOption.all,
    this.searchQuery = '',
  });

  List<EpubBook> get filteredBooks {
    var result = books.filter(filterOption);
    if (searchQuery.isNotEmpty) {
      result = result.search(searchQuery);
    }
    return result.sortBy(
      sortOption,
      ascending: sortOption == BookSortOption.title,
    );
  }

  int get totalBooks => books.length;
  int get downloadedBooks => books.where((b) => b.isDownloaded).length;
  int get favoriteBooks => books.where((b) => b.isFavorite).length;

  LibraryState copyWith({
    List<EpubBook>? books,
    bool? isLoading,
    String? error,
    BookSortOption? sortOption,
    BookFilterOption? filterOption,
    String? searchQuery,
  }) {
    return LibraryState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sortOption: sortOption ?? this.sortOption,
      filterOption: filterOption ?? this.filterOption,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Library notifier
class LibraryNotifier extends StateNotifier<LibraryState> {
  final Ref _ref;

  LibraryNotifier(this._ref) : super(const LibraryState());

  EpubReaderService get _readerService => _ref.read(readerServiceProvider);
  EpubDownloadService get _downloadService =>
      _ref.read(downloadServiceProvider);

  /// Load library
  Future<void> loadLibrary() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _readerService.getLibrary();
      if (result.isSuccess) {
        state = state.copyWith(books: result.requireData, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.error.toString(),
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh library
  Future<void> refresh() async {
    await loadLibrary();
  }

  /// Add book from file
  Future<Result<EpubBook>> addBookFromFile(String filePath) async {
    try {
      final result = await _ref.read(parserServiceProvider).parseBook(filePath);
      if (result.isSuccess) {
        final book = result.requireData;

        // ✅ Check if book is already in state
        final existingIndex = state.books.indexWhere((b) => b.id == book.id);
        if (existingIndex != -1) {
          debugPrint('📚 Book already exists, updating...');
          final updatedBooks = List<EpubBook>.from(state.books);
          updatedBooks[existingIndex] = book;
          state = state.copyWith(books: updatedBooks);
        } else {
          debugPrint('📚 Adding new book to library...');
          state = state.copyWith(books: [...state.books, book]);
        }

        debugPrint('📚 Library now has ${state.books.length} books');

        final saveResult = await _readerService.saveBookToLibrary(book);
        if (saveResult.isFailure) {
          debugPrint('❌ Failed to save book: ${saveResult.error}');
        }
      }
      return result;
    } catch (e, st) {
      debugPrint('❌ addBookFromFile error: $e');
      return Result.failure(e, st);
    }
  }

  /// Add book from URL
  Future<Result<EpubBook>> addBookFromUrl(String url, {String? title}) async {
    try {
      final book = EpubBook.fromUrl(url, title: title);
      // Start download
      final downloadResult = await _downloadService.downloadFromUrl(
        url: url,
        bookId: book.id,
        fileName: '${book.id}.epub',
      );

      if (downloadResult.isSuccess) {
        await loadLibrary();
        return Result.success(book);
      } else {
        return Result.failure(downloadResult.error!);
      }
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Delete book
  Future<Result<void>> deleteBook(String bookId) async {
    try {
      final result = await _readerService.deleteBook(bookId);
      if (result.isSuccess) {
        state = state.copyWith(
          books: state.books.where((b) => b.id != bookId).toList(),
        );
      }
      return result;
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Toggle favorite
  Future<void> toggleFavorite(String bookId) async {
    try {
      final bookIndex = state.books.indexWhere((b) => b.id == bookId);
      if (bookIndex != -1) {
        final updatedBook = state.books[bookIndex].toggleFavorite();
        final updatedBooks = List<EpubBook>.from(state.books);
        updatedBooks[bookIndex] = updatedBook;
        state = state.copyWith(books: updatedBooks);
      }
    } catch (e) {
      debugPrint('Toggle favorite error: $e');
    }
  }

  /// Set sort option
  void setSortOption(BookSortOption option) {
    state = state.copyWith(sortOption: option);
  }

  /// Set filter option
  void setFilterOption(BookFilterOption option) {
    state = state.copyWith(filterOption: option);
  }

  /// Set search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clear search
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  /// Get book by ID
  EpubBook? getBook(String bookId) {
    try {
      return state.books.firstWhere((b) => b.id == bookId);
    } catch (_) {
      return null;
    }
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((
  ref,
) {
  return LibraryNotifier(ref);
});

/// Filtered books provider
final filteredBooksProvider = Provider<List<EpubBook>>((ref) {
  return ref.watch(libraryProvider).filteredBooks;
});

// =============================================================================
// DOWNLOAD PROVIDERS
// =============================================================================

/// Download state
class DownloadState {
  final List<DownloadTask> tasks;
  final bool isLoading;
  final String? error;

  const DownloadState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
  });

  List<DownloadTask> get activeTasks =>
      tasks.where((t) => t.status == DownloadStatus.downloading).toList();

  List<DownloadTask> get queuedTasks =>
      tasks.where((t) => t.status == DownloadStatus.queued).toList();

  List<DownloadTask> get pausedTasks =>
      tasks.where((t) => t.status == DownloadStatus.paused).toList();

  List<DownloadTask> get completedTasks =>
      tasks.where((t) => t.status == DownloadStatus.completed).toList();

  List<DownloadTask> get failedTasks =>
      tasks.where((t) => t.status == DownloadStatus.failed).toList();

  int get activeCount => activeTasks.length;
  double get overallProgress {
    if (tasks.isEmpty) return 0.0;
    final downloading = tasks
        .where(
          (t) =>
              t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.queued,
        )
        .toList();
    if (downloading.isEmpty) return 1.0;
    return downloading.fold<double>(0, (sum, t) => sum + t.progress) /
        downloading.length;
  }

  DownloadState copyWith({
    List<DownloadTask>? tasks,
    bool? isLoading,
    String? error,
  }) {
    return DownloadState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Download notifier - FIXED to listen to both foreground AND background
class DownloadNotifier extends StateNotifier<DownloadState> {
  final Ref _ref;
  StreamSubscription<DownloadEvent>? _foregroundSubscription;
  StreamSubscription<BackgroundDownloadStatus>? _backgroundSubscription;

  DownloadNotifier(this._ref) : super(const DownloadState()) {
    _init();
  }

  EpubDownloadService get _downloadService =>
      _ref.read(downloadServiceProvider);
  BackgroundService get _backgroundService =>
      _ref.read(backgroundServiceProvider);
  NotificationService get _notificationService =>
      _ref.read(notificationServiceProvider);
  LibraryNotifier get _libraryNotifier => _ref.read(libraryProvider.notifier);

  void _init() {
    // Listen to FOREGROUND download events
    _foregroundSubscription = _downloadService.eventStream.listen(
      _handleDownloadEvent,
    );

    // Listen to BACKGROUND download status updates
    if (_backgroundService.isInitialized) {
      _backgroundSubscription = _backgroundService.statusStream.listen(
        _handleBackgroundStatus,
      );
    }

    // Load initial state
    state = state.copyWith(tasks: _downloadService.allTasks);

    // Sync with background tasks
    _syncBackgroundTasks();
  }

  /// Sync tasks from background service storage
  Future<void> _syncBackgroundTasks() async {
    try {
      if (!_backgroundService.isInitialized) {
        await _backgroundService.initialize();
      }

      // Subscribe to background stream if not already
      _backgroundSubscription ??= _backgroundService.statusStream.listen(
        _handleBackgroundStatus,
      );

      final result = await _backgroundService.getAllDownloadStatuses();
      if (result.isSuccess && result.data != null) {
        for (final status in result.data!) {
          _applyBackgroundStatus(status);
        }
      }
    } catch (e) {
      debugPrint('Failed to sync background tasks: $e');
    }
  }

  /// Handle background status updates from BackgroundService.statusStream
  void _handleBackgroundStatus(BackgroundDownloadStatus status) {
    debugPrint(
      '📥 Background status: ${status.taskId} - ${status.status.name} - ${(status.progress * 100).round()}%',
    );
    _applyBackgroundStatus(status);
  }

  /// Apply background status to state
  void _applyBackgroundStatus(BackgroundDownloadStatus status) {
    final tasks = List<DownloadTask>.from(state.tasks);

    // Find task by ID or bookId
    int index = tasks.indexWhere((t) => t.id == status.taskId);
    if (index == -1 && status.bookId.isNotEmpty) {
      index = tasks.indexWhere((t) => t.bookId == status.bookId);
    }

    if (index != -1) {
      // Update existing task
      final existing = tasks[index];
      tasks[index] = existing.copyWith(
        status: status.status,
        progress: status.progress,
        downloadedBytes: status.downloadedBytes,
        totalBytes: status.totalBytes > 0
            ? status.totalBytes
            : existing.totalBytes,
        localPath: status.localPath ?? existing.localPath,
        errorMessage: status.error,
      );
      debugPrint('✅ Task updated: ${tasks[index].progressPercentage}%');
    } else if (status.bookId.isNotEmpty &&
        status.status != DownloadStatus.completed) {
      // Only add if not completed (completed goes to library)
      tasks.add(
        DownloadTask(
          id: status.taskId,
          bookId: status.bookId,
          url: '',
          fileName: 'download.epub',
          status: status.status,
          progress: status.progress,
          downloadedBytes: status.downloadedBytes,
          totalBytes: status.totalBytes,
          localPath: status.localPath,
          errorMessage: status.error,
          createdAt: DateTime.now(),
          isBackground: true,
        ),
      );
      debugPrint('➕ New task added from background');
    }

    state = state.copyWith(tasks: tasks);

    // ✅ Handle completion
    if (status.status == DownloadStatus.completed) {
      debugPrint('📚 Download completed, refreshing library...');
      _libraryNotifier.loadLibrary();

      // Remove from downloads after delay
      Future.delayed(const Duration(seconds: 2), () {
        _removeTaskFromState(status.taskId);
      });
    }
  }

  @override
  void dispose() {
    _foregroundSubscription?.cancel();
    _backgroundSubscription?.cancel();
    super.dispose();
  }

  void _handleDownloadEvent(DownloadEvent event) async {
    try {
      // Update task in state
      _updateTaskInState(event.task);

      // Handle notifications
      switch (event.type) {
        case DownloadEventType.started:
          final book = _libraryNotifier.getBook(event.task.bookId);
          await _notificationService.showDownloadStarted(
            taskId: event.task.id,
            bookTitle: book?.title ?? event.task.fileName,
            bookId: event.task.bookId,
          );
          break;

        case DownloadEventType.progress:
          if (event.progress != null) {
            final book = _libraryNotifier.getBook(event.task.bookId);
            await _notificationService.updateDownloadProgress(
              taskId: event.task.id,
              bookTitle: book?.title ?? event.task.fileName,
              progress: event.task.progressPercentage,
              progressText: event.task.progressText,
              speedText: event.task.formattedSpeed,
              bookId: event.task.bookId,
            );
          }
          break;

        case DownloadEventType.paused:
          final book = _libraryNotifier.getBook(event.task.bookId);
          await _notificationService.showDownloadPaused(
            taskId: event.task.id,
            bookTitle: book?.title ?? event.task.fileName,
            progress: event.task.progressPercentage,
            bookId: event.task.bookId,
          );
          break;

        case DownloadEventType.completed:
          debugPrint('📥 Download completed: ${event.task.fileName}');
          debugPrint('📂 Local path: ${event.task.localPath}'); // ADD THIS

          final book = _libraryNotifier.getBook(event.task.bookId);
          await _notificationService.showDownloadCompleted(
            taskId: event.task.id,
            bookTitle: book?.title ?? event.task.fileName,
            bookId: event.task.bookId,
          );

          if (event.task.localPath != null) {
            final file = File(event.task.localPath!);
            final exists = await file.exists();
            debugPrint('📄 File exists: $exists'); // ADD THIS

            if (exists) {
              debugPrint('📚 Parsing downloaded EPUB: ${event.task.localPath}');
              final result = await _libraryNotifier.addBookFromFile(
                event.task.localPath!,
              );
              debugPrint('📚 Parse result: ${result.isSuccess}'); // ADD THIS
              if (result.isFailure) {
                debugPrint('❌ Parse error: ${result.error}'); // ADD THIS
              }
            }
          } else {
            debugPrint('⚠️ localPath is null!'); // ADD THIS
          }

          // Verify library after refresh
          await _libraryNotifier.loadLibrary();
          debugPrint(
            '📚 Library count: ${_libraryNotifier.state.books.length}',
          );
          // Remove completed task after delay
          Future.delayed(const Duration(seconds: 2), () {
            _removeTaskFromState(event.task.id);
          });
          break;

        case DownloadEventType.failed:
          final book = _libraryNotifier.getBook(event.task.bookId);
          await _notificationService.showDownloadFailed(
            taskId: event.task.id,
            bookTitle: book?.title ?? event.task.fileName,
            errorMessage: event.task.errorMessage ?? 'Download failed',
            canRetry: event.task.canRetry,
            bookId: event.task.bookId,
          );
          break;

        case DownloadEventType.cancelled:
          await _notificationService.cancelNotification(event.task.id);
          break;

        default:
          break;
      }
    } catch (e) {
      debugPrint('Handle download event error: $e');
    }
  }

  void _removeTaskFromState(String taskId) {
    final tasks = List<DownloadTask>.from(state.tasks);
    tasks.removeWhere((t) => t.id == taskId);
    state = state.copyWith(tasks: tasks);
  }

  void _updateTaskInState(DownloadTask task) {
    final tasks = List<DownloadTask>.from(state.tasks);
    final index = tasks.indexWhere((t) => t.id == task.id);

    if (index != -1) {
      tasks[index] = task;
    } else {
      tasks.add(task);
    }

    state = state.copyWith(tasks: tasks);
  }

  /// Refresh state - call when app resumes from background
  Future<void> refresh() async {
    debugPrint('🔄 Refreshing download state...');

    // Reload from foreground service
    state = state.copyWith(tasks: _downloadService.allTasks);

    // Sync with background service
    await _syncBackgroundTasks();

    debugPrint('✅ Download state refreshed: ${state.tasks.length} tasks');
  }

  /// Start download
  Future<Result<DownloadTask>> startDownload({
    required String url,
    required String bookId,
    String? fileName,
  }) async {
    try {
      debugPrint('🚀 Starting download: $url');
      final result = await _downloadService.downloadFromUrl(
        url: url,
        bookId: bookId,
        fileName: fileName,
      );

      if (result.isSuccess) {
        _updateTaskInState(result.requireData);
        debugPrint('✅ Download started: ${result.requireData.id}');
      }

      return result;
    } catch (e, st) {
      debugPrint('❌ Start download failed: $e');
      return Result.failure(e, st);
    }
  }

  /// Pause download
  Future<Result<void>> pauseDownload(String taskId) async {
    try {
      final result = await _downloadService.pause(taskId);
      if (result.isSuccess) {
        _updateTaskInState(result.requireData);
      }
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Resume download
  Future<Result<void>> resumeDownload(String taskId) async {
    try {
      final result = await _downloadService.resume(taskId);
      if (result.isSuccess) {
        _updateTaskInState(result.requireData);
      }
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Cancel download
  /// Cancel download
  Future<Result<void>> cancelDownload(String taskId) async {
    try {
      debugPrint('🛑 Cancelling download: $taskId');

      // Cancel in foreground service
      try {
        await _downloadService.cancel(taskId);
      } catch (e) {
        debugPrint('Foreground cancel error: $e');
      }

      // Also cancel in background service
      try {
        await _backgroundService.cancelBackgroundDownload(taskId);
      } catch (e) {
        debugPrint('Background cancel error: $e');
      }

      // ✅ FIX: Remove from state instead of updating
      final tasks = List<DownloadTask>.from(state.tasks);
      tasks.removeWhere((t) => t.id == taskId);
      state = state.copyWith(tasks: tasks);

      debugPrint('✅ Download cancelled and removed: $taskId');
      return Result.success(null);
    } catch (e, st) {
      debugPrint('Cancel download error: $e');
      return Result.failure(e, st);
    }
  }

  /// Retry download
  Future<Result<void>> retryDownload(String taskId) async {
    try {
      final result = await _downloadService.retry(taskId);
      if (result.isSuccess) {
        _updateTaskInState(result.requireData);
      }
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  Future<Result<void>> removeTask(String taskId) async {
    try {
      final result = await _downloadService.remove(taskId);
      if (result.isSuccess) {
        _removeTaskFromState(taskId);
      }
      return Result.success(null);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Pause all downloads
  Future<void> pauseAll() async {
    await _downloadService.pauseAll();
  }

  /// Resume all downloads
  Future<void> resumeAll() async {
    await _downloadService.resumeAll();
  }

  /// Cancel all downloads
  Future<void> cancelAll() async {
    await _downloadService.cancelAll();
    await _backgroundService.cancelAllBackgroundDownloads();
  }

  /// Clear completed downloads
  void clearCompleted() {
    _downloadService.clearCompleted();
    _backgroundService.clearCompletedStatuses();
    state = state.copyWith(tasks: _downloadService.allTasks);
  }

  /// Clear failed downloads
  void clearFailed() {
    _downloadService.clearFailed();
    state = state.copyWith(tasks: _downloadService.allTasks);
  }

  /// Clear all downloads
  void clearAll() {
    _downloadService.clearAll();
    _backgroundService.clearAllStatuses();
    state = state.copyWith(tasks: _downloadService.allTasks);
  }

  /// Get task by ID
  DownloadTask? getTask(String taskId) {
    try {
      return state.tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return null;
    }
  }

  /// Get task by book ID
  DownloadTask? getTaskByBookId(String bookId) {
    try {
      return state.tasks.firstWhere((t) => t.bookId == bookId);
    } catch (_) {
      return null;
    }
  }

  /// Check if book is downloading
  bool isDownloading(String bookId) {
    final task = getTaskByBookId(bookId);
    return task != null &&
        (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued);
  }

  /// Check if book is downloaded
  Future<bool> isDownloaded(String bookId) async {
    final result = await _downloadService.isDownloaded(bookId);
    return result.getOrElse(false);
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>(
  (ref) {
    return DownloadNotifier(ref);
  },
);

/// Active downloads count provider
final activeDownloadsCountProvider = Provider<int>((ref) {
  return ref.watch(downloadProvider).activeCount;
});

/// Overall download progress provider
final overallDownloadProgressProvider = Provider<double>((ref) {
  return ref.watch(downloadProvider).overallProgress;
});

// =============================================================================
// READER PROVIDERS
// =============================================================================

/// Reader state provider (streams from ReaderService)
final readerStateProvider = StreamProvider<ReadingState>((ref) {
  return ref.read(readerServiceProvider).stateStream;
});

/// Current reading state provider
final currentReadingStateProvider = Provider<ReadingState>((ref) {
  return ref.read(readerServiceProvider).currentState;
});

/// Reader notifier for actions
class ReaderNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ReaderNotifier(this._ref) : super(const AsyncValue.data(null));

  EpubReaderService get _readerService => _ref.read(readerServiceProvider);

  /// Open book
  Future<Result<EpubBook>> openBook(String filePath) async {
    state = const AsyncValue.loading();
    try {
      final result = await _readerService.openBook(filePath);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e, st);
    }
  }

  /// Open book from model
  Future<Result<void>> openBookFromModel(EpubBook book) async {
    state = const AsyncValue.loading();
    try {
      final result = await _readerService.openBookFromModel(book);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(e, st);
    }
  }

  /// Close book
  Future<Result<void>> closeBook() async {
    try {
      return await _readerService.closeBook();
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Go to next chapter
  Future<Result<EpubChapter>> nextChapter() async {
    try {
      return await _readerService.nextChapter();
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Go to previous chapter
  Future<Result<EpubChapter>> previousChapter() async {
    try {
      return await _readerService.previousChapter();
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Go to chapter
  Future<Result<EpubChapter>> goToChapter(int index) async {
    try {
      return await _readerService.goToChapter(index);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Go to TOC entry
  Future<Result<EpubChapter>> goToTocEntry(TocEntry entry) async {
    try {
      return await _readerService.goToTocEntry(entry);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Go to chapter by href
  Future<Result<EpubChapter>> goToChapterByHref(String href) async {
    try {
      return await _readerService.goToChapterByHref(href);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Update reading position
  Future<void> updatePosition(double scrollProgress) async {
    await _readerService.updatePosition(scrollProgress: scrollProgress);
  }

  /// Save progress
  Future<Result<void>> saveProgress() async {
    try {
      return await _readerService.saveProgress();
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Add bookmark
  Future<Result<Bookmark>> addBookmark({String? note}) async {
    try {
      return await _readerService.addBookmark(note: note);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Remove bookmark
  Future<Result<void>> removeBookmark(String bookmarkId) async {
    try {
      return await _readerService.removeBookmark(bookmarkId);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Go to bookmark
  Future<Result<void>> goToBookmark(Bookmark bookmark) async {
    try {
      return await _readerService.goToBookmark(bookmark);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Add highlight
  Future<Result<Highlight>> addHighlight({
    required String selectedText,
    required int startOffset,
    required int endOffset,
    HighlightColor color = HighlightColor.yellow,
    String? note,
  }) async {
    try {
      return await _readerService.addHighlight(
        selectedText: selectedText,
        startOffset: startOffset,
        endOffset: endOffset,
        color: color,
        note: note,
      );
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Remove highlight
  Future<Result<void>> removeHighlight(String highlightId) async {
    try {
      return await _readerService.removeHighlight(highlightId);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Update highlight color
  Future<Result<void>> updateHighlightColor(
    String highlightId,
    HighlightColor color,
  ) async {
    try {
      return await _readerService.updateHighlightColor(highlightId, color);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Add note
  Future<Result<Note>> addNote({
    required String content,
    String? title,
    String? quotedText,
    NoteType type = NoteType.note,
  }) async {
    try {
      return await _readerService.addNote(
        content: content,
        title: title,
        quotedText: quotedText,
        type: type,
      );
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Remove note
  Future<Result<void>> removeNote(String noteId) async {
    try {
      return await _readerService.removeNote(noteId);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Save text translation
  Future<Result<TextTranslation>> saveTextTranslation({
    required String originalText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
    TranslationProvider? provider,
  }) async {
    try {
      return await _readerService.saveTextTranslation(
        originalText: originalText,
        translatedText: translatedText,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        provider: provider,
      );
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Get cached translation
  Future<Result<TextTranslation?>> getCachedTranslation({
    required String originalText,
    required String targetLanguage,
  }) async {
    try {
      return await _readerService.getCachedTranslation(
        originalText: originalText,
        targetLanguage: targetLanguage,
      );
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Search in book
  Future<Result<List<SearchResult>>> searchInBook(String query) async {
    try {
      return await _readerService.searchInBook(query);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Update settings
  Future<Result<void>> updateSettings(ReaderSettings settings) async {
    try {
      return await _readerService.updateSettings(settings);
    } catch (e, st) {
      return Result.failure(e, st);
    }
  }

  /// Increase font size
  Future<void> increaseFontSize() async {
    await _readerService.increaseFontSize();
  }

  /// Decrease font size
  Future<void> decreaseFontSize() async {
    await _readerService.decreaseFontSize();
  }

  /// Set theme
  Future<void> setTheme(ReadingTheme theme) async {
    await _readerService.setTheme(theme);
  }

  /// Set font
  Future<void> setFont(ReaderFont font) async {
    await _readerService.setFont(font);
  }
}

final readerNotifierProvider =
    StateNotifierProvider<ReaderNotifier, AsyncValue<void>>((ref) {
      return ReaderNotifier(ref);
    });

/// Current book provider
final currentBookProvider = Provider<EpubBook?>((ref) {
  return ref.read(readerServiceProvider).currentBook;
});

/// Current chapter provider
final currentChapterProvider = Provider<EpubChapter?>((ref) {
  return ref.read(readerServiceProvider).currentChapter;
});

/// Current progress provider
final currentProgressProvider = Provider<ReadingProgress?>((ref) {
  return ref.read(readerServiceProvider).currentProgress;
});

/// Reader settings provider
final readerSettingsProvider = Provider<ReaderSettings>((ref) {
  return ref.read(readerServiceProvider).settings;
});

/// Bookmarks provider
final bookmarksProvider = Provider<List<Bookmark>>((ref) {
  ref.watch(readerStateProvider); // Watch for changes
  return ref.read(readerServiceProvider).getBookmarks();
});

/// Current chapter highlights provider
final currentChapterHighlightsProvider = Provider<List<Highlight>>((ref) {
  ref.watch(readerStateProvider);
  return ref.read(readerServiceProvider).getCurrentChapterHighlights();
});

/// All highlights provider
final allHighlightsProvider = Provider<List<Highlight>>((ref) {
  ref.watch(readerStateProvider);
  return ref.read(readerServiceProvider).getAllHighlights();
});

/// All notes provider
final allNotesProvider = Provider<List<Note>>((ref) {
  ref.watch(readerStateProvider);
  return ref.read(readerServiceProvider).getAllNotes();
});

/// Translation stats provider
final translationStatsProvider = Provider<TranslationStats?>((ref) {
  ref.watch(readerStateProvider);
  return ref.read(readerServiceProvider).getTranslationStats();
});

// =============================================================================
// CACHE PROVIDERS
// =============================================================================

/// Cache stats provider
final cacheStatsProvider = Provider<CacheStats>((ref) {
  return ref.read(cacheServiceProvider).getCacheStats();
});

/// Disk cache size provider
final diskCacheSizeProvider = FutureProvider<int>((ref) async {
  final result = await ref.read(cacheServiceProvider).getDiskCacheSize();
  return result.getOrElse(0);
});

/// Clear cache action provider
final clearCacheProvider = Provider<Future<Result<void>> Function()>((ref) {
  return () => ref.read(cacheServiceProvider).clearAllCache();
});

// =============================================================================
// COMBINED/UTILITY PROVIDERS
// =============================================================================

/// Book with download status
class BookWithStatus {
  final EpubBook book;
  final DownloadTask? downloadTask;
  final bool isDownloading;
  final bool isDownloaded;

  const BookWithStatus({
    required this.book,
    this.downloadTask,
    this.isDownloading = false,
    this.isDownloaded = false,
  });
}

/// Book with status provider (family)
final bookWithStatusProvider = Provider.family<BookWithStatus?, String>((
  ref,
  bookId,
) {
  final libraryState = ref.watch(libraryProvider);
  final downloadState = ref.watch(downloadProvider);

  final book = libraryState.books.cast<EpubBook?>().firstWhere(
    (b) => b?.id == bookId,
    orElse: () => null,
  );

  if (book == null) return null;

  final downloadTask = downloadState.tasks.cast<DownloadTask?>().firstWhere(
    (t) => t?.bookId == bookId,
    orElse: () => null,
  );

  final isDownloading =
      downloadTask != null &&
      (downloadTask.status == DownloadStatus.downloading ||
          downloadTask.status == DownloadStatus.queued);

  return BookWithStatus(
    book: book,
    downloadTask: downloadTask,
    isDownloading: isDownloading,
    isDownloaded: book.isDownloaded,
  );
});

/// Search provider
class SearchState {
  final String query;
  final List<SearchResult> results;
  final bool isSearching;
  final String? error;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
    this.error,
  });

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    bool? isSearching,
    String? error,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      error: error,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  Timer? _debounceTimer;

  SearchNotifier(this._ref) : super(const SearchState());

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void search(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      state = const SearchState();
      return;
    }

    state = state.copyWith(query: query, isSearching: true);

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final result = await _ref
            .read(readerServiceProvider)
            .searchInBook(query);
        if (result.isSuccess) {
          state = state.copyWith(
            results: result.requireData,
            isSearching: false,
          );
        } else {
          state = state.copyWith(
            isSearching: false,
            error: result.error.toString(),
          );
        }
      } catch (e) {
        state = state.copyWith(isSearching: false, error: e.toString());
      }
    });
  }

  void clear() {
    _debounceTimer?.cancel();
    state = const SearchState();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  return SearchNotifier(ref);
});

// =============================================================================
// ERROR HANDLING PROVIDER
// =============================================================================

/// Global error state
class ErrorState {
  final List<EpubException> errors;
  final EpubException? lastError;

  const ErrorState({this.errors = const [], this.lastError});

  ErrorState addError(EpubException error) {
    return ErrorState(errors: [...errors, error], lastError: error);
  }

  ErrorState clearErrors() {
    return const ErrorState();
  }
}

class ErrorNotifier extends StateNotifier<ErrorState> {
  ErrorNotifier() : super(const ErrorState()) {
    ExceptionHandler.addListener(_handleException);
  }

  @override
  void dispose() {
    ExceptionHandler.removeListener(_handleException);
    super.dispose();
  }

  void _handleException(EpubException exception) {
    state = state.addError(exception);
  }

  void addError(dynamic error) {
    final epubException = ExceptionHandler.wrap(error);
    state = state.addError(epubException);
  }

  void clearErrors() {
    state = state.clearErrors();
  }

  void dismissLastError() {
    if (state.errors.isEmpty) return;
    state = ErrorState(
      errors: state.errors.sublist(0, state.errors.length - 1),
      lastError: state.errors.length > 1
          ? state.errors[state.errors.length - 2]
          : null,
    );
  }
}

final errorProvider = StateNotifierProvider<ErrorNotifier, ErrorState>((ref) {
  return ErrorNotifier();
});

// =============================================================================
// MEMORY MANAGEMENT PROVIDER
// =============================================================================

/// Memory pressure state provider
final memoryPressureProvider = StreamProvider<MemoryPressure>((ref) {
  final controller = StreamController<MemoryPressure>();

  void listener(MemoryPressure pressure) {
    controller.add(pressure);
  }

  ref.read(memoryManagerProvider).addListener(listener);

  ref.onDispose(() {
    ref.read(memoryManagerProvider).removeListener(listener);
    controller.close();
  });

  return controller.stream;
});

/// Memory stats provider
final memoryStatsProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.read(memoryManagerProvider).getCacheStats();
});
