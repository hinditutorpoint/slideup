import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/epub_exceptions.dart';
import '../../../core/utils/safe_async.dart';
import '../models/download_task.dart';

/// Background task identifiers
class BackgroundTasks {
  static const String downloadTask = 'epub_download_task';
  static const String cleanupTask = 'epub_cleanup_task';
  static const String syncTask = 'epub_sync_task';
  static const String uniqueDownload = 'epub_unique_download';
}

/// Background task input keys
class TaskInputKeys {
  static const String taskId = 'taskId';
  static const String bookId = 'bookId';
  static const String url = 'url';
  static const String fileName = 'fileName';
  static const String localPath = 'localPath';
  static const String headers = 'headers';
  static const String downloadedBytes = 'downloadedBytes';
  static const String totalBytes = 'totalBytes';
  static const String bookTitle = 'bookTitle';
}

/// Background download status
class BackgroundDownloadStatus {
  final String taskId;
  final String bookId;
  final DownloadStatus status;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;
  final String? localPath;

  const BackgroundDownloadStatus({
    required this.taskId,
    required this.bookId,
    required this.status,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
    this.localPath,
  });

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'bookId': bookId,
    'status': status.name,
    'progress': progress,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'error': error,
    'localPath': localPath,
  };

  factory BackgroundDownloadStatus.fromJson(Map<String, dynamic> json) {
    return BackgroundDownloadStatus(
      taskId: json['taskId'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.idle,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      error: json['error'] as String?,
      localPath: json['localPath'] as String?,
    );
  }
}

/// Background Service for managing background downloads
class BackgroundService {
  BackgroundService._();
  static final BackgroundService _instance = BackgroundService._();
  static BackgroundService get instance => _instance;

  // Port name known by worker_dispatcher.dart
  static const String portName = 'epub_background_port';
  ReceivePort? _receivePort;

  final StreamController<BackgroundDownloadStatus> _statusController =
      StreamController<BackgroundDownloadStatus>.broadcast();

  final Map<String, String> _activeTasks = {}; // taskId -> workManagerTaskId

  bool _isInitialized = false;
  bool _isWorkmanagerAvailable = false;

  Box<dynamic>? _backgroundTasksBox;

  bool get isInitialized => _isInitialized;
  bool get isWorkmanagerAvailable => _isWorkmanagerAvailable;
  Stream<BackgroundDownloadStatus> get statusStream => _statusController.stream;
  Map<String, String> get activeTasks => Map.unmodifiable(_activeTasks);

  /// Whether this platform supports Workmanager (Android/iOS only; not web)
  bool get _supportsWorkmanager =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initialize background service
  ///
  /// NOTE: Workmanager itself is initialized in main().
  Future<Result<void>> initialize() async {
    if (_isInitialized) return Result.success(null);

    return SafeAsync.run(() async {
      try {
        _isWorkmanagerAvailable = _supportsWorkmanager;
        if (!_isWorkmanagerAvailable) {
          debugPrint(
            'Workmanager not supported on this platform; background tasks disabled.',
          );
        }

        // Open Hive box for background tasks
        _backgroundTasksBox = await Hive.openBox('background_tasks');

        // Setup communication port
        _setupCommunicationPort();

        // Restore active tasks
        await _restoreActiveTasks();

        _isInitialized = true;
        debugPrint('BackgroundService initialized');
      } catch (e, st) {
        _isInitialized = false;
        debugPrint('BackgroundService initialization failed: $e\n$st');
        throw BackgroundException.initializationFailed(details: e.toString());
      }
    }, operationName: 'BackgroundService.initialize');
  }

  /// Dispose service
  Future<void> dispose() async {
    try {
      _receivePort?.close();
      await _statusController.close();
      await _backgroundTasksBox?.close();
      _isInitialized = false;
      debugPrint('BackgroundService disposed');
    } catch (e) {
      debugPrint('BackgroundService dispose error: $e');
    }
  }

  /// Setup communication port for receiving updates from background tasks
  void _setupCommunicationPort() {
    _receivePort = ReceivePort();

    IsolateNameServer.removePortNameMapping(portName);
    IsolateNameServer.registerPortWithName(_receivePort!.sendPort, portName);

    _receivePort!.listen((message) {
      try {
        if (message is Map<String, dynamic>) {
          final status = BackgroundDownloadStatus.fromJson(message);
          if (!_statusController.isClosed) {
            _statusController.add(status);
          }
          _handleStatusUpdate(status);
        }
      } catch (e) {
        debugPrint('Failed to process background message: $e');
      }
    });
  }

  /// Handle status updates from background tasks
  void _handleStatusUpdate(BackgroundDownloadStatus status) {
    _backgroundTasksBox?.put(status.taskId, status.toJson());

    if (status.status == DownloadStatus.completed ||
        status.status == DownloadStatus.failed ||
        status.status == DownloadStatus.cancelled) {
      _activeTasks.remove(status.taskId);
    }
  }

  /// Restore active tasks from storage
  Future<void> _restoreActiveTasks() async {
    try {
      final keys = _backgroundTasksBox?.keys ?? [];
      for (final key in keys) {
        final data = _backgroundTasksBox?.get(key);
        if (data is Map) {
          final status = BackgroundDownloadStatus.fromJson(
            Map<String, dynamic>.from(data),
          );

          if (status.status == DownloadStatus.downloading ||
              status.status == DownloadStatus.queued) {
            final pausedStatus = BackgroundDownloadStatus(
              taskId: status.taskId,
              bookId: status.bookId,
              status: DownloadStatus.paused,
              progress: status.progress,
              downloadedBytes: status.downloadedBytes,
              totalBytes: status.totalBytes,
            );
            _backgroundTasksBox?.put(key, pausedStatus.toJson());
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to restore active tasks: $e');
    }
  }

  // ===========================================================================
  // DOWNLOAD OPERATIONS
  // ===========================================================================

  /// Start background download
  Future<Result<String>> startBackgroundDownload({
    required DownloadTask task,
    required String bookTitle,
  }) async {
    return SafeAsync.run(() async {
      if (!_isWorkmanagerAvailable) {
        throw BackgroundException.workmanagerUnavailable();
      }

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        throw DownloadException.networkError(url: task.url);
      }

      final inputData = <String, dynamic>{
        TaskInputKeys.taskId: task.id,
        TaskInputKeys.bookId: task.bookId,
        TaskInputKeys.url: task.url,
        TaskInputKeys.fileName: task.fileName,
        TaskInputKeys.localPath: task.localPath,
        TaskInputKeys.downloadedBytes: task.downloadedBytes,
        TaskInputKeys.totalBytes: task.totalBytes,
        TaskInputKeys.bookTitle: bookTitle,
      };

      if (task.headers != null) {
        inputData[TaskInputKeys.headers] = task.headers;
      }

      final uniqueTaskName = '${BackgroundTasks.uniqueDownload}_${task.id}';

      await Workmanager().registerOneOffTask(
        uniqueTaskName,
        BackgroundTasks.downloadTask,
        inputData: inputData,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: Duration(seconds: 10),
        tag: 'epub_download',
      );

      _activeTasks[task.id] = uniqueTaskName;
      await _backgroundTasksBox?.put(
        task.id,
        BackgroundDownloadStatus(
          taskId: task.id,
          bookId: task.bookId,
          status: DownloadStatus.queued,
          downloadedBytes: task.downloadedBytes,
          totalBytes: task.totalBytes,
        ).toJson(),
      );

      debugPrint('Background download started: ${task.fileName}');
      return uniqueTaskName;
    }, operationName: 'startBackgroundDownload');
  }

  /// Cancel background download
  Future<Result<void>> cancelBackgroundDownload(String taskId) async {
    return SafeAsync.run(() async {
      if (_isWorkmanagerAvailable) {
        final workManagerTaskId = _activeTasks[taskId];
        if (workManagerTaskId != null) {
          await Workmanager().cancelByUniqueName(workManagerTaskId);
          _activeTasks.remove(taskId);
        }
      }

      await _backgroundTasksBox?.put(
        taskId,
        BackgroundDownloadStatus(
          taskId: taskId,
          bookId: '',
          status: DownloadStatus.cancelled,
        ).toJson(),
      );

      debugPrint('Background download cancelled: $taskId');
    }, operationName: 'cancelBackgroundDownload');
  }

  /// Cancel all background downloads
  Future<Result<void>> cancelAllBackgroundDownloads() async {
    return SafeAsync.run(() async {
      if (_isWorkmanagerAvailable) {
        await Workmanager().cancelByTag('epub_download');
        _activeTasks.clear();
      }

      for (final key in _backgroundTasksBox?.keys ?? []) {
        final data = _backgroundTasksBox?.get(key);
        if (data is Map) {
          final status = BackgroundDownloadStatus.fromJson(
            Map<String, dynamic>.from(data),
          );
          if (status.status == DownloadStatus.downloading ||
              status.status == DownloadStatus.queued) {
            await _backgroundTasksBox?.put(
              key,
              BackgroundDownloadStatus(
                taskId: status.taskId,
                bookId: status.bookId,
                status: DownloadStatus.cancelled,
              ).toJson(),
            );
          }
        }
      }

      debugPrint('All background downloads cancelled');
    }, operationName: 'cancelAllBackgroundDownloads');
  }

  /// Get background download status
  Future<Result<BackgroundDownloadStatus?>> getDownloadStatus(
    String taskId,
  ) async {
    return SafeAsync.run(() async {
      final data = _backgroundTasksBox?.get(taskId);
      if (data is Map) {
        return BackgroundDownloadStatus.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      return null;
    }, operationName: 'getDownloadStatus');
  }

  /// Get all background download statuses
  Future<Result<List<BackgroundDownloadStatus>>>
  getAllDownloadStatuses() async {
    return SafeAsync.run(() async {
      final statuses = <BackgroundDownloadStatus>[];

      for (final key in _backgroundTasksBox?.keys ?? []) {
        final data = _backgroundTasksBox?.get(key);
        if (data is Map) {
          statuses.add(
            BackgroundDownloadStatus.fromJson(Map<String, dynamic>.from(data)),
          );
        }
      }

      return statuses;
    }, operationName: 'getAllDownloadStatuses');
  }

  /// Clear completed/failed download statuses
  Future<Result<void>> clearCompletedStatuses() async {
    return SafeAsync.run(() async {
      final keysToDelete = <dynamic>[];

      for (final key in _backgroundTasksBox?.keys ?? []) {
        final data = _backgroundTasksBox?.get(key);
        if (data is Map) {
          final status = BackgroundDownloadStatus.fromJson(
            Map<String, dynamic>.from(data),
          );
          if (status.status == DownloadStatus.completed ||
              status.status == DownloadStatus.failed ||
              status.status == DownloadStatus.cancelled) {
            keysToDelete.add(key);
          }
        }
      }

      for (final key in keysToDelete) {
        await _backgroundTasksBox?.delete(key);
      }
    }, operationName: 'clearCompletedStatuses');
  }

  /// Clear all download statuses
  Future<Result<void>> clearAllStatuses() async {
    return SafeAsync.run(() async {
      if (_backgroundTasksBox != null) {
        await _backgroundTasksBox!.clear();
      }
    }, operationName: 'clearAllStatuses');
  }

  // ===========================================================================
  // PERIODIC TASKS
  // ===========================================================================

  Future<Result<void>> scheduleCleanupTask() async {
    return SafeAsync.run(() async {
      if (!_isWorkmanagerAvailable) return;

      await Workmanager().registerPeriodicTask(
        'epub_cleanup_periodic',
        BackgroundTasks.cleanupTask,
        frequency: const Duration(days: 1),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresDeviceIdle: true,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        tag: 'epub_maintenance',
      );

      debugPrint('Cleanup task scheduled');
    }, operationName: 'scheduleCleanupTask');
  }

  Future<Result<void>> scheduleSyncTask() async {
    return SafeAsync.run(() async {
      if (!_isWorkmanagerAvailable) return;

      await Workmanager().registerPeriodicTask(
        'epub_sync_periodic',
        BackgroundTasks.syncTask,
        frequency: const Duration(hours: 12),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        tag: 'epub_sync',
      );

      debugPrint('Sync task scheduled');
    }, operationName: 'scheduleSyncTask');
  }

  Future<Result<void>> cancelPeriodicTasks() async {
    return SafeAsync.run(() async {
      if (!_isWorkmanagerAvailable) return;

      await Workmanager().cancelByTag('epub_maintenance');
      await Workmanager().cancelByTag('epub_sync');
      debugPrint('Periodic tasks cancelled');
    }, operationName: 'cancelPeriodicTasks');
  }

  // ===========================================================================
  // UTILITIES
  // ===========================================================================

  bool isDownloadRunning(String taskId) => _activeTasks.containsKey(taskId);

  int get activeDownloadCount => _activeTasks.length;

  void sendMessageToBackground(String taskId, Map<String, dynamic> message) {
    try {
      final port = IsolateNameServer.lookupPortByName('${portName}_$taskId');
      port?.send(message);
    } catch (e) {
      debugPrint('Failed to send message to background: $e');
    }
  }
}
