import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/epub_exceptions.dart';
import '../../../core/utils/download_location_helper.dart';
import '../../../core/utils/safe_async.dart';
import '../models/download_task.dart';

/// Download service for EPUB files with pause/resume/cancel support
class EpubDownloadService {
  EpubDownloadService._();

  static final EpubDownloadService _instance = EpubDownloadService._();
  static EpubDownloadService get instance => _instance;

  // Dio client for HTTP requests
  late Dio _dio;

  // Download queue
  final DownloadQueue _queue = DownloadQueue(
    maxConcurrent: AppConstants.maxConcurrentDownloads,
  );

  // Active cancel tokens
  final Map<String, CancelToken> _cancelTokens = {};

  // Progress stream controllers
  final Map<String, StreamController<DownloadProgress>> _progressControllers =
      {};

  // Event stream controller
  final StreamController<DownloadEvent> _eventController =
      StreamController<DownloadEvent>.broadcast();

  // Connectivity subscription
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Is service initialized
  bool _isInitialized = false;

  // Download directory
  String? _downloadDirectory;

  // Getters
  bool get isInitialized => _isInitialized;
  Stream<DownloadEvent> get eventStream => _eventController.stream;
  List<DownloadTask> get allTasks => _queue.tasks;
  List<DownloadTask> get activeTasks => _queue.activeTasks;
  List<DownloadTask> get queuedTasks => _queue.queuedTasks;
  List<DownloadTask> get completedTasks => _queue.completedTasks;
  List<DownloadTask> get failedTasks => _queue.failedTasks;
  int get activeCount => _queue.activeCount;
  double get overallProgress => _queue.overallProgress;

  /// Initialize download service
  Future<Result<void>> initialize() async {
    if (_isInitialized) return Result.success(null);

    return SafeAsync.run(() async {
      // Initialize Dio
      _dio = Dio(
        BaseOptions(
          connectTimeout: AppConstants.connectionTimeout,
          receiveTimeout: AppConstants.downloadTimeout,
          sendTimeout: AppConstants.connectionTimeout,
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // Add interceptors
      _dio.interceptors.add(_createLoggingInterceptor());
      _dio.interceptors.add(_createRetryInterceptor());

      // Get download directory
      final configured =
          await DownloadLocationHelper.configuredDirectory();
      _downloadDirectory = configured?.path ??
          path.join(
            (await getExternalStorageDirectory() ??
                    await getApplicationDocumentsDirectory())
                .path,
            AppConstants.downloadDir,
          );

      // Create directory if not exists
      final downloadDir = Directory(_downloadDirectory!);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // Listen for connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        _handleConnectivityChange,
      );

      _isInitialized = true;
      debugPrint('EpubDownloadService initialized');
    }, operationName: 'EpubDownloadService.initialize');
  }

  /// Dispose service
  Future<void> dispose() async {
    try {
      // Cancel all active downloads
      await cancelAll();

      // Close stream controllers
      for (final controller in _progressControllers.values) {
        await controller.close();
      }
      _progressControllers.clear();

      await _eventController.close();
      await _connectivitySubscription?.cancel();

      _dio.close();
      _isInitialized = false;

      debugPrint('EpubDownloadService disposed');
    } catch (e) {
      debugPrint('EpubDownloadService dispose error: $e');
    }
  }

  // ===========================================================================
  // DOWNLOAD OPERATIONS
  // ===========================================================================

  /// Start download from URL
  /// Start download from URL
  Future<Result<DownloadTask>> downloadFromUrl({
    required String url,
    required String bookId,
    String? fileName,
    int priority = 0,
    Map<String, String>? headers,
    bool startImmediately = true,
  }) async {
    return SafeAsync.run(() async {
      // Validate URL
      debugPrint('📥 downloadFromUrl: $url');
      if (!_isValidUrl(url)) {
        throw ValidationException.invalidUrl(url: url);
      }

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        throw DownloadException.networkError(url: url);
      }

      // Generate file name if not provided
      final effectiveFileName = fileName ?? _extractFileName(url);
      debugPrint('📥 File name: $effectiveFileName');

      // Create download task
      var task = DownloadTask.create(
        bookId: bookId,
        url: url,
        fileName: effectiveFileName,
        localPath: path.join(_downloadDirectory!, effectiveFileName),
        priority: priority,
        headers: headers,
      );

      // ✅ FIX: Set status to queued
      task = task.queue();

      debugPrint('📥 Task created: ${task.id}, status: ${task.status}');

      // Add to queue
      _queue.add(task);

      // Emit queued event
      _emitEvent(DownloadEvent(type: DownloadEventType.queued, task: task));
      debugPrint('📥 Task queued, emitted event');

      if (startImmediately) {
        debugPrint('📥 Processing queue immediately');
        // Start download if capacity available
        await _processQueue();
      }

      return task;
    }, operationName: 'downloadFromUrl');
  }

  /// Check if book is already downloaded
  Future<Result<bool>> isDownloaded(String bookId) async {
    return SafeAsync.run(() async {
      final task = _queue.getByBookId(bookId);
      if (task != null && task.isCompleted && task.localPath != null) {
        final file = File(task.localPath!);
        return await file.exists();
      }
      return false;
    }, operationName: 'isDownloaded');
  }

  /// Get local path for downloaded book
  Future<Result<String?>> getLocalPath(String bookId) async {
    return SafeAsync.run(() async {
      final task = _queue.getByBookId(bookId);
      if (task != null && task.isCompleted && task.localPath != null) {
        final file = File(task.localPath!);
        if (await file.exists()) {
          return task.localPath;
        }
      }
      return null;
    }, operationName: 'getLocalPath');
  }

  /// Pause download
  Future<Result<DownloadTask>> pause(String taskId) async {
    return SafeAsync.run(() async {
      final task = _queue.getById(taskId);
      if (task == null) {
        throw FileException.notFound(path: taskId);
      }

      if (!task.canPause) {
        throw DownloadException(
          message: 'Download cannot be paused in current state',
          code: 'CANNOT_PAUSE',
        );
      }

      // Cancel the current request
      _cancelTokens[taskId]?.cancel('Paused by user');
      _cancelTokens.remove(taskId);

      // Update task state
      final pausedTask = task.pause();
      _queue.update(pausedTask);

      _emitEvent(DownloadEvent.paused(pausedTask));

      return pausedTask;
    }, operationName: 'pause');
  }

  /// Resume download
  Future<Result<DownloadTask>> resume(String taskId) async {
    return SafeAsync.run(() async {
      final task = _queue.getById(taskId);
      if (task == null) {
        throw FileException.notFound(path: taskId);
      }

      if (!task.canResume) {
        throw DownloadException(
          message: 'Download cannot be resumed',
          code: 'CANNOT_RESUME',
        );
      }

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        throw DownloadException.networkError(url: task.url);
      }

      // Update task state
      final resumedTask = task.resume();
      _queue.update(resumedTask);

      _emitEvent(DownloadEvent.resumed(resumedTask));

      // Start download
      await _startDownload(resumedTask);

      return resumedTask;
    }, operationName: 'resume');
  }

  /// Cancel download
  Future<Result<DownloadTask>> cancel(String taskId) async {
    return SafeAsync.run(() async {
      final task = _queue.getById(taskId);

      // If task doesn't exist, return a dummy cancelled task
      if (task == null) {
        debugPrint('Task not found for cancel: $taskId');
        return DownloadTask(
          id: taskId,
          bookId: '',
          url: '',
          fileName: 'cancelled',
          status: DownloadStatus.cancelled,
          createdAt: DateTime.now(),
        );
      }

      // Cancel the HTTP request if exists
      try {
        _cancelTokens[taskId]?.cancel('Cancelled by user');
      } catch (e) {
        debugPrint('Cancel token error: $e');
      }
      _cancelTokens.remove(taskId);

      // Close progress controller if exists
      try {
        await _progressControllers[taskId]?.close();
      } catch (e) {
        debugPrint('Progress controller close error: $e');
      }
      _progressControllers.remove(taskId);

      // Delete partial file
      if (task.localPath != null) {
        await _deleteFile(task.localPath!);
      }

      // Create cancelled task for the event
      final cancelledTask = task.cancel();

      // ✅ FIX: Remove from queue instead of updating
      _queue.remove(taskId);

      // Emit cancelled event
      _emitEvent(DownloadEvent.cancelled(cancelledTask));

      // Process next in queue
      await _processQueue();

      debugPrint('✅ Download cancelled and removed: ${task.fileName}');
      return cancelledTask;
    }, operationName: 'cancel');
  }

  /// Retry failed download
  Future<Result<DownloadTask>> retry(String taskId) async {
    return SafeAsync.run(() async {
      final task = _queue.getById(taskId);
      if (task == null) {
        throw FileException.notFound(path: taskId);
      }

      if (!task.canRetry) {
        throw DownloadException(
          message: 'Download cannot be retried',
          code: 'CANNOT_RETRY',
        );
      }

      // Update task state
      final retriedTask = task.retry();
      _queue.update(retriedTask);

      _emitEvent(
        DownloadEvent(type: DownloadEventType.retrying, task: retriedTask),
      );

      // Process queue
      await _processQueue();

      return retriedTask;
    }, operationName: 'retry');
  }

  Future<Result<void>> remove(String taskId) async {
    return SafeAsync.run(() async {
      final task = _queue.getById(taskId);
      if (task == null) {
        throw FileException.notFound(path: taskId);
      }

      _queue.remove(taskId);

      _emitEvent(DownloadEvent.removed(task));
    }, operationName: 'remove');
  }

  /// Cancel all downloads
  Future<Result<void>> cancelAll() async {
    return SafeAsync.run(() async {
      for (final taskId in _cancelTokens.keys.toList()) {
        await cancel(taskId);
      }
    }, operationName: 'cancelAll');
  }

  /// Pause all downloads
  Future<Result<void>> pauseAll() async {
    return SafeAsync.run(() async {
      for (final task in _queue.activeTasks) {
        await pause(task.id);
      }
    }, operationName: 'pauseAll');
  }

  /// Resume all paused downloads
  Future<Result<void>> resumeAll() async {
    return SafeAsync.run(() async {
      for (final task in _queue.tasks.where((t) => t.isPaused)) {
        await resume(task.id);
      }
    }, operationName: 'resumeAll');
  }

  /// Remove completed downloads from queue
  void clearCompleted() {
    final completedIds = _queue.completedTasks.map((t) => t.id).toList();
    for (final id in completedIds) {
      _queue.remove(id);
    }
    debugPrint('✅ Cleared ${completedIds.length} completed tasks');
    _queue.clearCompleted();
  }

  /// Remove failed downloads from queue
  void clearFailed() {
    final failedIds = _queue.failedTasks.map((t) => t.id).toList();
    for (final id in failedIds) {
      _queue.remove(id);
    }
    _queue.clearFailed();
  }

  /// Clear all downloads from queue
  void clearAll() {
    final allIds = _queue.tasks.map((t) => t.id).toList();
    for (final id in allIds) {
      _queue.remove(id);
    }
    _queue.clear();
  }

  /// Get download task by ID
  DownloadTask? getTask(String taskId) {
    return _queue.getById(taskId);
  }

  /// Get download task by book ID
  DownloadTask? getTaskByBookId(String bookId) {
    return _queue.getByBookId(bookId);
  }

  /// Get progress stream for a task
  Stream<DownloadProgress>? getProgressStream(String taskId) {
    return _progressControllers[taskId]?.stream;
  }

  // ===========================================================================
  // INTERNAL METHODS
  // ===========================================================================

  /// Process download queue
  Future<void> _processQueue() async {
    debugPrint(
      '📋 Processing queue. Capacity: ${_queue.hasCapacity}, Active: ${_queue.activeCount}',
    );

    while (_queue.hasCapacity) {
      final nextTask = _queue.getNextTask();
      if (nextTask == null) {
        debugPrint('📋 No more tasks in queue');
        break;
      }

      debugPrint('📋 Starting next task: ${nextTask.id}');
      final startedTask = nextTask.start();
      _queue.update(startedTask);

      // Start download in background
      unawaited(_startDownload(startedTask));
    }
  }

  /// Start actual download
  Future<void> _startDownload(DownloadTask task) async {
    debugPrint('⬇️ _startDownload called for: ${task.fileName}');
    try {
      // Create cancel token
      final cancelToken = CancelToken();
      _cancelTokens[task.id] = cancelToken;

      // Create progress controller
      _progressControllers[task.id] =
          StreamController<DownloadProgress>.broadcast();
      debugPrint('⬇️ Emitting started event');
      _emitEvent(DownloadEvent.started(task));

      // Check if file partially exists (for resume)
      int downloadedBytes = 0;
      if (task.localPath != null && task.supportsResume) {
        final file = File(task.localPath!);
        if (await file.exists()) {
          downloadedBytes = await file.length();
        }
      }

      // Prepare headers
      final headers = <String, dynamic>{...?task.headers};

      // Add range header for resume
      if (downloadedBytes > 0 && task.supportsResume) {
        headers['Range'] = 'bytes=$downloadedBytes-';
      }

      // Get file size first
      int totalBytes = task.totalBytes;
      if (totalBytes == 0) {
        try {
          final headResponse = await _dio.head(
            task.url,
            cancelToken: cancelToken,
          );
          totalBytes =
              int.tryParse(
                headResponse.headers.value('content-length') ?? '0',
              ) ??
              0;

          // Check if resume is supported
          final acceptRanges = headResponse.headers.value('accept-ranges');
          final supportsResume = acceptRanges == 'bytes';

          // Update task with total bytes
          final updatedTask = task.copyWith(
            totalBytes: totalBytes,
            supportsResume: supportsResume,
            etag: headResponse.headers.value('etag'),
          );
          _queue.update(updatedTask);
        } catch (e) {
          debugPrint('Failed to get file size: $e');
        }
      }

      // Track speed calculation
      int lastBytes = downloadedBytes;
      DateTime lastTime = DateTime.now();

      // Start download
      final response = await _dio.get<ResponseBody>(
        task.url,
        options: Options(responseType: ResponseType.stream, headers: headers),
        cancelToken: cancelToken,
      );

      // Check status code
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw DownloadException.serverError(
          url: task.url,
          statusCode: response.statusCode,
        );
      }

      // Get content length from response if not already known
      if (totalBytes == 0) {
        totalBytes =
            int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
      }

      // Open file for writing
      final file = File(task.localPath!);
      final sink = file.openWrite(
        mode: downloadedBytes > 0 ? FileMode.append : FileMode.write,
      );

      try {
        // Stream data to file
        await for (final chunk in response.data!.stream) {
          // Check if cancelled
          if (cancelToken.isCancelled) break;

          // Write chunk
          sink.add(chunk);
          downloadedBytes += chunk.length;

          // Calculate speed
          final now = DateTime.now();
          final elapsed = now.difference(lastTime).inMilliseconds;
          int speed = 0;
          if (elapsed > 500) {
            speed = ((downloadedBytes - lastBytes) * 1000 / elapsed).round();
            lastBytes = downloadedBytes;
            lastTime = now;
          }

          // Create progress update
          final progress = DownloadProgress(
            taskId: task.id,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            speedBytesPerSecond: speed,
          );

          // Update task
          final updatedTask = task.updateProgress(
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            speedBytesPerSecond: speed,
          );
          _queue.update(updatedTask);

          // Emit progress
          _progressControllers[task.id]?.add(progress);
          _emitEvent(DownloadEvent.progress(updatedTask, progress));
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      // Check if download was cancelled
      if (cancelToken.isCancelled) {
        return;
      }

      // Verify file
      final downloadedFile = File(task.localPath!);
      if (!await downloadedFile.exists()) {
        throw DownloadException(
          message: 'Downloaded file not found',
          code: 'FILE_NOT_FOUND',
        );
      }

      final fileSize = await downloadedFile.length();
      if (totalBytes > 0 && fileSize != totalBytes) {
        throw DownloadException(
          message: 'File size mismatch: expected $totalBytes, got $fileSize',
          code: 'SIZE_MISMATCH',
        );
      }

      // Mark as completed
      final completedTask = task.complete(task.localPath!);
      _queue.update(completedTask);

      _emitEvent(DownloadEvent.completed(completedTask));

      debugPrint('Download completed: ${task.fileName}');
    } on DioException catch (e) {
      await _handleDownloadError(task, e);
    } catch (e, st) {
      await _handleDownloadError(task, e, st);
    } finally {
      // Cleanup
      _cancelTokens.remove(task.id);
      await _progressControllers[task.id]?.close();
      _progressControllers.remove(task.id);

      // Process next in queue
      await _processQueue();
    }
  }

  /// Handle download error
  Future<void> _handleDownloadError(
    DownloadTask task,
    Object error, [
    StackTrace? stackTrace,
  ]) async {
    String message;
    String code;

    if (error is DioException) {
      if (error.type == DioExceptionType.cancel) {
        // Cancelled, not an error
        return;
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = 'Connection timed out';
          code = 'TIMEOUT';
          break;
        case DioExceptionType.connectionError:
          message = 'Connection error';
          code = 'CONNECTION_ERROR';
          break;
        default:
          message = error.message ?? 'Download failed';
          code = 'DIO_ERROR';
      }
    } else if (error is DownloadException) {
      message = error.message;
      code = error.code ?? 'DOWNLOAD_ERROR';
    } else {
      message = error.toString();
      code = 'UNKNOWN_ERROR';
    }

    debugPrint('Download error for ${task.fileName}: $message');

    // Check if should retry
    final currentTask = _queue.getById(task.id);
    if (currentTask != null && currentTask.canRetry) {
      // Auto-retry
      final retriedTask = currentTask.retry();
      _queue.update(retriedTask);

      _emitEvent(
        DownloadEvent(
          type: DownloadEventType.retrying,
          task: retriedTask,
          message:
              'Retrying (${retriedTask.retryCount}/${retriedTask.maxRetries})',
        ),
      );

      // Wait before retry
      await Future.delayed(
        AppConstants.downloadRetryDelay * currentTask.retryCount,
      );

      // Retry
      await _startDownload(retriedTask);
    } else {
      // Mark as failed
      final failedTask = task.fail(message, code);
      _queue.update(failedTask);

      _emitEvent(DownloadEvent.failed(failedTask, message));
    }
  }

  /// Handle connectivity change
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      // Lost connection, pause all active downloads
      debugPrint('Connection lost, pausing downloads...');
      pauseAll();
    } else {
      // Connection restored, resume paused downloads
      debugPrint('Connection restored');
      // Don't auto-resume, let user decide
    }
  }

  /// Create logging interceptor
  Interceptor _createLoggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (kDebugMode) {
          debugPrint('→ ${options.method} ${options.uri}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
        }
        handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          debugPrint('✗ ${error.type} ${error.requestOptions.uri}');
        }
        handler.next(error);
      },
    );
  }

  /// Create retry interceptor
  Interceptor _createRetryInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        // Only retry on specific errors
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          // Let the main download handler deal with retries
        }
        handler.next(error);
      },
    );
  }

  /// Emit download event
  void _emitEvent(DownloadEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Validate URL
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  /// Extract file name from URL
  String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        String fileName = pathSegments.last;
        // Ensure it has .epub extension
        if (!fileName.toLowerCase().endsWith('.epub')) {
          fileName = '$fileName.epub';
        }
        // Sanitize filename
        fileName = fileName.replaceAll(RegExp(r'[^\w\-\.]'), '_');
        return fileName;
      }
    } catch (_) {}
    return 'download_${DateTime.now().millisecondsSinceEpoch}.epub';
  }

  /// Delete file safely
  Future<void> _deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete file: $e');
    }
  }

  /// Get storage info
  Future<Result<StorageInfo>> getStorageInfo() async {
    return SafeAsync.run(() async {
      final directory = Directory(_downloadDirectory!);

      int totalSize = 0;
      int fileCount = 0;

      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
            fileCount++;
          }
        }
      }

      return StorageInfo(
        directory: _downloadDirectory!,
        totalSize: totalSize,
        fileCount: fileCount,
      );
    }, operationName: 'getStorageInfo');
  }

  /// Clear all downloaded files
  Future<Result<void>> clearDownloads() async {
    return SafeAsync.run(() async {
      // Cancel all active downloads first
      await cancelAll();

      final directory = Directory(_downloadDirectory!);
      if (await directory.exists()) {
        await for (final entity in directory.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }

      _queue.clear();
    }, operationName: 'clearDownloads');
  }

  /// Delete specific download
  Future<Result<void>> deleteDownload(String bookId) async {
    return SafeAsync.run(() async {
      final task = _queue.getByBookId(bookId);
      if (task != null) {
        // Cancel if active
        if (task.isActive) {
          await cancel(task.id);
        }

        // Delete file
        if (task.localPath != null) {
          await _deleteFile(task.localPath!);
        }

        // Remove from queue
        _queue.remove(task.id);
      }
    }, operationName: 'deleteDownload');
  }
}

/// Storage info
class StorageInfo {
  final String directory;
  final int totalSize;
  final int fileCount;

  const StorageInfo({
    required this.directory,
    required this.totalSize,
    required this.fileCount,
  });

  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
