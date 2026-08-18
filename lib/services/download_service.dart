import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/archive_constants.dart';
import '../core/database/database_helper.dart';
import '../core/utils/download_location_helper.dart';
import '../features/documents/models/download_task.dart';
import 'notification_service.dart';

typedef DownloadProgressCallback = void Function(DownloadTask task);
typedef DownloadCompleteCallback = void Function(DownloadTask task);
typedef DownloadErrorCallback = void Function(DownloadTask task, String error);

class DownloadService {
  static DownloadService? _instance;

  final Dio _dio;
  final DatabaseHelper _dbHelper;
  final NotificationService _notificationService;
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, StreamController<DownloadTask>> _progressControllers = {};

  // Track notification IDs for proper cleanup
  final Map<String, int> _activeNotificationIds = {};

  final _allDownloadsController =
      StreamController<List<DownloadTask>>.broadcast();
  Stream<List<DownloadTask>> get allDownloadsStream =>
      _allDownloadsController.stream;

  int _activeDownloads = 0;
  final List<DownloadTask> _pendingQueue = [];

  // Throttle progress notifications to reduce overhead
  final Map<String, DateTime> _lastNotificationUpdate = {};
  static const _notificationThrottleDuration = Duration(milliseconds: 500);

  DownloadService._internal({
    required DatabaseHelper dbHelper,
    required NotificationService notificationService,
  }) : _dbHelper = dbHelper,
       _notificationService = notificationService,
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 30),
           receiveTimeout: const Duration(minutes: 30),
           sendTimeout: const Duration(seconds: 30),
         ),
       );

  factory DownloadService({
    required DatabaseHelper dbHelper,
    required NotificationService notificationService,
  }) {
    _instance ??= DownloadService._internal(
      dbHelper: dbHelper,
      notificationService: notificationService,
    );
    return _instance!;
  }

  Stream<DownloadTask> getProgressStream(String taskId) {
    _progressControllers[taskId] ??= StreamController<DownloadTask>.broadcast();
    return _progressControllers[taskId]!.stream;
  }

  Future<String> getDownloadDirectory() async {
    try {
      final configured = await DownloadLocationHelper.configuredDirectory();
      if (configured != null) return configured.path;

      Directory? directory;

      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        directory ??= await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final downloadDir = Directory(
        '${directory.path}/${ArchiveConstants.downloadFolder}',
      );

      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      return downloadDir.path;
    } catch (e) {
      debugPrint('Failed to get download directory: $e');
      final appDir = await getApplicationDocumentsDirectory();
      return appDir.path;
    }
  }

  /// Generate a consistent notification ID for a task
  int _getNotificationId(String taskId) {
    // Use absolute value to ensure positive ID
    return taskId.hashCode.abs() % 2147483647;
  }

  Future<DownloadTask> startDownload({
    required String identifier,
    required String title,
    required String url,
    required String mediaType,
    String? thumbnailUrl,
  }) async {
    try {
      final id = const Uuid().v4();
      final fileName = _extractFileName(url, identifier, mediaType);

      final task = DownloadTask(
        id: id,
        identifier: identifier,
        title: title,
        url: url,
        fileName: fileName,
        thumbnailUrl: thumbnailUrl,
        status: DownloadStatus.pending,
        createdAt: DateTime.now(),
        mediaType: mediaType,
      );

      await _saveTask(task);

      if (_activeDownloads >= ArchiveConstants.maxConcurrentDownloads) {
        _pendingQueue.add(task);
        _notifyAllDownloads();
        return task;
      }

      _executeDownload(task);

      return task;
    } catch (e) {
      debugPrint('Failed to start download: $e');
      rethrow;
    }
  }

  Future<void> _executeDownload(DownloadTask task) async {
    _activeDownloads++;

    final notificationId = _getNotificationId(task.id);
    _activeNotificationIds[task.id] = notificationId;

    try {
      final downloadDir = await getDownloadDirectory();
      final filePath = '$downloadDir/${task.fileName}';

      final file = File(filePath);
      int downloadedBytes = 0;

      if (await file.exists()) {
        downloadedBytes = await file.length();
      }

      final cancelToken = CancelToken();
      _cancelTokens[task.id] = cancelToken;

      var updatedTask = task.copyWith(
        status: DownloadStatus.downloading,
        filePath: filePath,
        downloadedBytes: downloadedBytes,
      );
      await _saveTask(updatedTask);
      _notifyProgress(updatedTask);

      // Show initial progress notification
      await _notificationService.showDownloadProgress(
        id: notificationId,
        title: task.title,
        progress: downloadedBytes,
        maxProgress: 100,
      );

      await _dio.download(
        task.url,
        filePath,
        cancelToken: cancelToken,
        deleteOnError: false,
        options: Options(
          headers: downloadedBytes > 0
              ? {'Range': 'bytes=$downloadedBytes-'}
              : null,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final actualReceived = downloadedBytes + received;
            final actualTotal = downloadedBytes + total;

            updatedTask = updatedTask.copyWith(
              downloadedBytes: actualReceived,
              totalBytes: actualTotal,
            );

            _notifyProgress(updatedTask);

            // Throttle notification updates to reduce overhead
            _updateProgressNotification(
              taskId: task.id,
              notificationId: notificationId,
              title: task.title,
              progress: actualReceived,
              maxProgress: actualTotal,
            );
          }
        },
      );

      // ═══════════════════════════════════════════════════════
      // FIX: Cancel progress notification BEFORE showing complete
      // ═══════════════════════════════════════════════════════

      // First, cancel the progress notification
      await _cancelProgressNotification(task.id);

      // Small delay to ensure notification is cleared
      await Future.delayed(const Duration(milliseconds: 100));

      // Update task status
      updatedTask = updatedTask.copyWith(
        status: DownloadStatus.completed,
        completedAt: DateTime.now(),
        downloadedBytes: updatedTask.totalBytes,
      );
      await _saveTask(updatedTask);
      _notifyProgress(updatedTask);
      _notifyAllDownloads();

      // Show completion notification with a DIFFERENT ID
      // to avoid conflicts with progress notification
      final completeNotificationId = notificationId + 100000;
      await _notificationService.showDownloadComplete(
        id: completeNotificationId,
        title: task.title,
        filePath: filePath,
      );

      // Auto-dismiss completion notification after delay (optional)
      _scheduleNotificationDismissal(completeNotificationId);
    } on DioException catch (e) {
      await _handleDownloadError(task, e);
    } catch (e) {
      await _handleGeneralError(task, e);
    } finally {
      await _cleanupDownload(task.id);
    }
  }

  /// Throttled progress notification update
  void _updateProgressNotification({
    required String taskId,
    required int notificationId,
    required String title,
    required int progress,
    required int maxProgress,
  }) {
    final now = DateTime.now();
    final lastUpdate = _lastNotificationUpdate[taskId];

    if (lastUpdate != null &&
        now.difference(lastUpdate) < _notificationThrottleDuration) {
      return;
    }

    _lastNotificationUpdate[taskId] = now;

    _notificationService.showDownloadProgress(
      id: notificationId,
      title: title,
      progress: progress,
      maxProgress: maxProgress,
    );
  }

  /// Cancel progress notification for a task
  Future<void> _cancelProgressNotification(String taskId) async {
    try {
      final notificationId = _activeNotificationIds[taskId];
      if (notificationId != null) {
        await _notificationService.cancelNotification(notificationId);
        _activeNotificationIds.remove(taskId);
        _lastNotificationUpdate.remove(taskId);
        debugPrint('✓ Cancelled progress notification for task: $taskId');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to cancel notification: $e');
    }
  }

  /// Schedule auto-dismissal of completion notification
  void _scheduleNotificationDismissal(
    int notificationId, {
    Duration delay = const Duration(seconds: 5),
  }) {
    Future.delayed(delay, () async {
      try {
        // Only auto-dismiss if user hasn't interacted with it
        // This is optional - remove if you want persistent notifications
        // await _notificationService.cancelNotification(notificationId);
      } catch (e) {
        debugPrint('⚠️ Failed to auto-dismiss notification: $e');
      }
    });
  }

  Future<void> _handleDownloadError(DownloadTask task, DioException e) async {
    await _cancelProgressNotification(task.id);

    if (e.type == DioExceptionType.cancel) {
      final cancelledTask = task.copyWith(status: DownloadStatus.cancelled);
      await _saveTask(cancelledTask);
      _notifyProgress(cancelledTask);
    } else {
      final errorMessage = _getErrorMessage(e);
      final failedTask = task.copyWith(
        status: DownloadStatus.failed,
        error: errorMessage,
      );
      await _saveTask(failedTask);
      _notifyProgress(failedTask);

      // Show error notification with different ID
      final errorNotificationId = _getNotificationId(task.id) + 200000;
      await _notificationService.showDownloadFailed(
        id: errorNotificationId,
        title: task.title,
        error: errorMessage,
      );
    }
  }

  Future<void> _handleGeneralError(DownloadTask task, dynamic e) async {
    await _cancelProgressNotification(task.id);

    final failedTask = task.copyWith(
      status: DownloadStatus.failed,
      error: e.toString(),
    );
    await _saveTask(failedTask);
    _notifyProgress(failedTask);

    final errorNotificationId = _getNotificationId(task.id) + 200000;
    await _notificationService.showDownloadFailed(
      id: errorNotificationId,
      title: task.title,
      error: e.toString(),
    );
  }

  Future<void> _cleanupDownload(String taskId) async {
    _activeDownloads--;
    _cancelTokens.remove(taskId);
    _activeNotificationIds.remove(taskId);
    _lastNotificationUpdate.remove(taskId);
    _notifyAllDownloads();
    _processQueue();
  }

  void _processQueue() {
    while (_pendingQueue.isNotEmpty &&
        _activeDownloads < ArchiveConstants.maxConcurrentDownloads) {
      final nextTask = _pendingQueue.removeAt(0);
      _executeDownload(nextTask);
    }
  }

  Future<void> pauseDownload(String taskId) async {
    try {
      final cancelToken = _cancelTokens[taskId];
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('Paused by user');
      }

      // Cancel progress notification
      await _cancelProgressNotification(taskId);

      final taskMap = await _dbHelper.getById(
        ArchiveConstants.downloadsTable,
        taskId,
      );
      if (taskMap != null) {
        final task = DownloadTask.fromMap(taskMap);
        final pausedTask = task.copyWith(status: DownloadStatus.paused);
        await _saveTask(pausedTask);
        _notifyProgress(pausedTask);
        _notifyAllDownloads();
      }
    } catch (e) {
      debugPrint('Failed to pause download: $e');
    }
  }

  Future<void> resumeDownload(String taskId) async {
    try {
      final taskMap = await _dbHelper.getById(
        ArchiveConstants.downloadsTable,
        taskId,
      );
      if (taskMap != null) {
        final task = DownloadTask.fromMap(taskMap);

        if (task.canResume) {
          if (_activeDownloads >= ArchiveConstants.maxConcurrentDownloads) {
            final pendingTask = task.copyWith(status: DownloadStatus.pending);
            await _saveTask(pendingTask);
            _pendingQueue.add(pendingTask);
            _notifyProgress(pendingTask);
          } else {
            _executeDownload(task);
          }
          _notifyAllDownloads();
        }
      }
    } catch (e) {
      debugPrint('Failed to resume download: $e');
    }
  }

  Future<void> cancelDownload(String taskId) async {
    try {
      final cancelToken = _cancelTokens[taskId];
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('Cancelled by user');
      }

      _pendingQueue.removeWhere((task) => task.id == taskId);

      // Cancel all related notifications
      await _cancelAllNotificationsForTask(taskId);

      final taskMap = await _dbHelper.getById(
        ArchiveConstants.downloadsTable,
        taskId,
      );
      if (taskMap != null) {
        final task = DownloadTask.fromMap(taskMap);
        final cancelledTask = task.copyWith(status: DownloadStatus.cancelled);
        await _saveTask(cancelledTask);
        _notifyProgress(cancelledTask);
        _notifyAllDownloads();

        if (task.filePath != null) {
          final file = File(task.filePath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to cancel download: $e');
    }
  }

  /// Cancel all notifications related to a task
  Future<void> _cancelAllNotificationsForTask(String taskId) async {
    try {
      final baseId = _getNotificationId(taskId);

      // Cancel progress notification
      await _notificationService.cancelNotification(baseId);

      // Cancel complete notification
      await _notificationService.cancelNotification(baseId + 100000);

      // Cancel error notification
      await _notificationService.cancelNotification(baseId + 200000);

      _activeNotificationIds.remove(taskId);
      _lastNotificationUpdate.remove(taskId);
    } catch (e) {
      debugPrint('⚠️ Failed to cancel notifications for task: $e');
    }
  }

  Future<void> retryDownload(String taskId) async {
    try {
      // Cancel any existing notifications first
      await _cancelAllNotificationsForTask(taskId);

      final taskMap = await _dbHelper.getById(
        ArchiveConstants.downloadsTable,
        taskId,
      );
      if (taskMap != null) {
        final task = DownloadTask.fromMap(taskMap);

        final resetTask = task.copyWith(
          status: DownloadStatus.pending,
          error: null,
          downloadedBytes: 0,
        );
        await _saveTask(resetTask);

        if (_activeDownloads >= ArchiveConstants.maxConcurrentDownloads) {
          _pendingQueue.add(resetTask);
          _notifyProgress(resetTask);
        } else {
          _executeDownload(resetTask);
        }
        _notifyAllDownloads();
      }
    } catch (e) {
      debugPrint('Failed to retry download: $e');
    }
  }

  Future<void> deleteDownload(String taskId, {bool deleteFile = false}) async {
    try {
      await cancelDownload(taskId);

      if (deleteFile) {
        final taskMap = await _dbHelper.getById(
          ArchiveConstants.downloadsTable,
          taskId,
        );
        if (taskMap != null) {
          final task = DownloadTask.fromMap(taskMap);
          if (task.filePath != null) {
            final file = File(task.filePath!);
            if (await file.exists()) {
              await file.delete();
            }
          }
        }
      }

      await _dbHelper.delete(
        ArchiveConstants.downloadsTable,
        where: 'id = ?',
        whereArgs: [taskId],
      );

      _progressControllers[taskId]?.close();
      _progressControllers.remove(taskId);
      _notifyAllDownloads();
    } catch (e) {
      debugPrint('Failed to delete download: $e');
    }
  }

  /// Cancel all active notifications (useful for app cleanup)
  Future<void> cancelAllNotifications() async {
    try {
      for (final taskId in _activeNotificationIds.keys.toList()) {
        await _cancelAllNotificationsForTask(taskId);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to cancel all notifications: $e');
    }
  }

  Future<List<DownloadTask>> getAllDownloads() async {
    try {
      final results = await _dbHelper.query(
        ArchiveConstants.downloadsTable,
        orderBy: 'created_at DESC',
      );
      return results.map((map) => DownloadTask.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Failed to get all downloads: $e');
      return [];
    }
  }

  Future<List<DownloadTask>> getActiveDownloads() async {
    try {
      final results = await _dbHelper.query(
        ArchiveConstants.downloadsTable,
        where: 'status IN (?, ?, ?)',
        whereArgs: [
          DownloadStatus.pending.index,
          DownloadStatus.downloading.index,
          DownloadStatus.paused.index,
        ],
        orderBy: 'created_at DESC',
      );
      return results.map((map) => DownloadTask.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Failed to get active downloads: $e');
      return [];
    }
  }

  Future<List<DownloadTask>> getCompletedDownloads() async {
    try {
      final results = await _dbHelper.query(
        ArchiveConstants.downloadsTable,
        where: 'status = ?',
        whereArgs: [DownloadStatus.completed.index],
        orderBy: 'completed_at DESC',
      );
      return results.map((map) => DownloadTask.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Failed to get completed downloads: $e');
      return [];
    }
  }

  Future<DownloadTask?> getDownloadByIdentifier(String identifier) async {
    try {
      final results = await _dbHelper.query(
        ArchiveConstants.downloadsTable,
        where: 'identifier = ?',
        whereArgs: [identifier],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return DownloadTask.fromMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get download by identifier: $e');
      return null;
    }
  }

  Future<void> updateTask(DownloadTask task) async {
    await _saveTask(task);
    _notifyProgress(task);
    _notifyAllDownloads();
  }

  Future<void> _saveTask(DownloadTask task) async {
    await _dbHelper.insert(ArchiveConstants.downloadsTable, task.toMap());
  }

  void _notifyProgress(DownloadTask task) {
    _progressControllers[task.id]?.add(task);
  }

  void _notifyAllDownloads() async {
    final downloads = await getAllDownloads();
    _allDownloadsController.add(downloads);
  }

  String _extractFileName(String url, String identifier, String mediaType) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        if (lastSegment.contains('.')) {
          return lastSegment;
        }
      }

      final extension = _getExtension(mediaType);
      return '${identifier}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    } catch (e) {
      return '${identifier}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }
  }

  String _getExtension(String mediaType) {
    switch (mediaType) {
      case ArchiveConstants.mediaTypePdf:
        return 'pdf';
      case ArchiveConstants.mediaTypeAudio:
        return 'mp3';
      case ArchiveConstants.mediaTypeVideo:
        return 'mp4';
      default:
        return 'pdf';
    }
  }

  String _getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out';
      case DioExceptionType.connectionError:
        return 'No internet connection';
      case DioExceptionType.badResponse:
        return 'Server error: ${e.response?.statusCode}';
      default:
        return e.message ?? 'Download failed';
    }
  }

  void dispose() {
    // Cancel all notifications on dispose
    cancelAllNotifications();

    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) {
        token.cancel('Service disposed');
      }
    }
    _cancelTokens.clear();
    _activeNotificationIds.clear();
    _lastNotificationUpdate.clear();

    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();

    _allDownloadsController.close();
    _dio.close();
    _instance = null;
  }
}
