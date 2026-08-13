import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

// Import the service to access Constants and Models
import 'background_service.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/epub_exceptions.dart';
import 'notification_service.dart';

// =============================================================================
// WORKMANAGER CALLBACK DISPATCHER (MUST BE TOP-LEVEL)
// =============================================================================

/// Workmanager callback dispatcher - must be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      debugPrint('Background task started: $taskName');

      switch (taskName) {
        case BackgroundTasks.downloadTask:
          return await _executeDownloadTask(inputData);

        case BackgroundTasks.cleanupTask:
          return await _executeCleanupTask();

        case BackgroundTasks.syncTask:
          return await _executeSyncTask();

        default:
          debugPrint('Unknown task: $taskName');
          return Future.value(true);
      }
    } catch (e, st) {
      debugPrint('Background task error: $e\n$st');
      return Future.value(false);
    }
  });
}

/// Execute download task in background - FIXED VERSION
Future<bool> _executeDownloadTask(Map<String, dynamic>? inputData) async {
  if (inputData == null) return false;

  final taskId = inputData[TaskInputKeys.taskId] as String?;
  final bookId = inputData[TaskInputKeys.bookId] as String?;
  final url = inputData[TaskInputKeys.url] as String?;
  final fileName = inputData[TaskInputKeys.fileName] as String?;
  final localPath = inputData[TaskInputKeys.localPath] as String?;
  final bookTitle =
      inputData[TaskInputKeys.bookTitle] as String? ?? fileName ?? 'Book';
  final startBytes = inputData[TaskInputKeys.downloadedBytes] as int? ?? 0;

  if (taskId == null || url == null || localPath == null) {
    debugPrint('❌ Invalid download task input');
    return false;
  }

  debugPrint('🚀 Background download starting: $fileName');

  // ============================================
  // IMPORTANT: Initialize Hive in background isolate
  // ============================================
  await Hive.initFlutter();

  Box<dynamic>? backgroundTasksBox;
  try {
    backgroundTasksBox = await Hive.openBox('background_tasks');
  } catch (e) {
    debugPrint('Failed to open Hive box: $e');
  }

  // Initialize notification service
  final notificationService = NotificationService.instance;
  await notificationService.initialize();

  // Get SendPort - MAY BE NULL if app is killed!
  final sendPort = IsolateNameServer.lookupPortByName(
    BackgroundService.portName,
  );
  debugPrint('📡 SendPort available: ${sendPort != null}');

  /// Persist status to Hive AND send via port
  Future<void> sendStatus(BackgroundDownloadStatus status) async {
    // 1. Always persist to Hive (survives app kill)
    try {
      await backgroundTasksBox?.put(status.taskId, status.toJson());
    } catch (e) {
      debugPrint('Hive persist error: $e');
    }

    // 2. Send via port if available (real-time updates)
    try {
      sendPort?.send(status.toJson());
    } catch (e) {
      debugPrint('SendPort error: $e');
    }
  }

  try {
    // Initial status
    await notificationService.showDownloadStarted(
      taskId: taskId,
      bookTitle: bookTitle,
      bookId: bookId,
    );

    await sendStatus(
      BackgroundDownloadStatus(
        taskId: taskId,
        bookId: bookId ?? '',
        status: DownloadStatus.downloading,
        progress: 0.0,
        downloadedBytes: startBytes,
        totalBytes: 0,
      ),
    );

    // Setup Dio
    final dio = Dio(
      BaseOptions(
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.downloadTimeout,
      ),
    );

    // Get total bytes with HEAD request
    int totalBytes = inputData[TaskInputKeys.totalBytes] as int? ?? 0;
    if (totalBytes == 0) {
      try {
        final headResponse = await dio.head(url);
        totalBytes =
            int.tryParse(headResponse.headers.value('content-length') ?? '0') ??
            0;
        debugPrint('📊 Total bytes: $totalBytes');
      } catch (e) {
        debugPrint('HEAD request failed: $e');
      }
    }

    // Prepare resume headers
    final headers = <String, dynamic>{};
    if (startBytes > 0) {
      headers['Range'] = 'bytes=$startBytes-';
    }

    // Start download
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(responseType: ResponseType.stream, headers: headers),
    );

    // Fallback total bytes from response
    if (totalBytes == 0) {
      totalBytes =
          int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
    }

    if (response.statusCode != 200 && response.statusCode != 206) {
      throw DownloadException.serverError(
        url: url,
        statusCode: response.statusCode,
      );
    }

    final responseBody = response.data;
    if (responseBody == null) {
      throw DownloadException(
        message: 'Empty response body',
        code: 'EMPTY_RESPONSE',
      );
    }

    // Create file
    final file = File(localPath);
    await file.parent.create(recursive: true);

    final sink = file.openWrite(
      mode: startBytes > 0 ? FileMode.append : FileMode.write,
    );

    int downloadedBytes = startBytes;
    int lastProgressPercent = 0;
    DateTime lastUpdateTime = DateTime.now();
    int bytesSinceLastUpdate = 0;

    try {
      await for (final chunk in responseBody.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        bytesSinceLastUpdate += chunk.length;

        final now = DateTime.now();
        final progressPercent = totalBytes > 0
            ? ((downloadedBytes / totalBytes) * 100).clamp(0, 100).round()
            : 0;

        final timeSinceUpdate = now.difference(lastUpdateTime).inMilliseconds;

        // Update every 1% or every second
        final shouldUpdate =
            progressPercent > lastProgressPercent || timeSinceUpdate >= 1000;

        if (shouldUpdate) {
          final speed = timeSinceUpdate > 0
              ? (bytesSinceLastUpdate * 1000 ~/ timeSinceUpdate)
              : 0;

          lastProgressPercent = progressPercent;
          lastUpdateTime = now;
          bytesSinceLastUpdate = 0;

          // Update notification
          await notificationService.updateDownloadProgress(
            taskId: taskId,
            bookTitle: bookTitle,
            progress: progressPercent,
            progressText: totalBytes > 0
                ? '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}'
                : _formatBytes(downloadedBytes),
            speedText: '${_formatBytes(speed)}/s',
            bookId: bookId,
          );

          // Send status update
          await sendStatus(
            BackgroundDownloadStatus(
              taskId: taskId,
              bookId: bookId ?? '',
              status: DownloadStatus.downloading,
              progress: totalBytes > 0 ? downloadedBytes / totalBytes : 0.0,
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
            ),
          );

          debugPrint(
            '📥 Progress: $progressPercent% ($downloadedBytes / $totalBytes)',
          );
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    // Verify file
    if (!await file.exists()) {
      throw DownloadException(
        message: 'Downloaded file not found',
        code: 'FILE_NOT_FOUND',
      );
    }

    final finalSize = await file.length();
    debugPrint('✅ Download complete: $finalSize bytes');

    // Success notification
    await notificationService.showDownloadCompleted(
      taskId: taskId,
      bookTitle: bookTitle,
      bookId: bookId,
    );

    // Final status
    await sendStatus(
      BackgroundDownloadStatus(
        taskId: taskId,
        bookId: bookId ?? '',
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedBytes: finalSize,
        totalBytes: totalBytes > 0 ? totalBytes : finalSize,
        localPath: localPath,
      ),
    );

    await backgroundTasksBox?.close();
    return true;
  } catch (e, st) {
    debugPrint('❌ Background download error: $e\n$st');

    final errorMessage = e is DownloadException ? e.message : e.toString();

    await notificationService.showDownloadFailed(
      taskId: taskId,
      bookTitle: bookTitle,
      errorMessage: errorMessage,
      bookId: bookId,
    );

    await sendStatus(
      BackgroundDownloadStatus(
        taskId: taskId,
        bookId: bookId ?? '',
        status: DownloadStatus.failed,
        error: errorMessage,
      ),
    );

    await backgroundTasksBox?.close();
    return false;
  }
}

/// Execute cleanup task
Future<bool> _executeCleanupTask() async {
  try {
    debugPrint('Executing cleanup task');

    // Get app directory
    final appDir = await getApplicationDocumentsDirectory();

    // Clean temp directory
    final tempDir = Directory(path.join(appDir.path, AppConstants.tempDir));
    if (await tempDir.exists()) {
      await for (final entity in tempDir.list()) {
        final stat = await entity.stat();
        // Delete files older than 24 hours
        if (DateTime.now().difference(stat.modified).inHours > 24) {
          await entity.delete(recursive: true);
        }
      }
    }

    // Clean cache directory
    final cacheDir = Directory(
      path.join(appDir.path, AppConstants.epubCacheDir),
    );
    if (await cacheDir.exists()) {
      int totalSize = 0;
      final files = <FileSystemEntity>[];

      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
          files.add(entity);
        }
      }

      // If cache exceeds max size, delete oldest files
      if (totalSize > AppConstants.maxCacheSizeMB * 1024 * 1024) {
        files.sort((a, b) {
          final aTime = a.statSync().modified;
          final bTime = b.statSync().modified;
          return aTime.compareTo(bTime);
        });

        for (final file in files) {
          if (totalSize <= AppConstants.maxCacheSizeMB * 1024 * 1024 * 0.8) {
            break;
          }
          final size = await (file as File).length();
          await file.delete();
          totalSize -= size;
        }
      }
    }

    debugPrint('Cleanup task completed');
    return true;
  } catch (e) {
    debugPrint('Cleanup task error: $e');
    return false;
  }
}

/// Execute sync task — local-only: consolidates Hive reading-progress data
/// into a human-readable JSON snapshot file on device storage.
Future<bool> _executeSyncTask() async {
  try {
    debugPrint('📂 Executing local sync task');

    // Initialise Hive (safe to call multiple times)
    await Hive.initFlutter();
    final progressBox = await Hive.openBox(AppConstants.hiveProgressBox);

    // Build a lightweight snapshot of every stored reading-progress entry
    final snapshot = <Map<String, dynamic>>[];

    for (final key in progressBox.keys) {
      try {
        final raw = progressBox.get(key);
        if (raw == null) continue;

        // The box stores ReadingProgress serialised as a Map or via Hive adapter.
        // We extract only the fields we need for a compact sync log.
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          snapshot.add({
            'bookId': data['bookId'] ?? key.toString(),
            'chapterIndex': data['chapterIndex'] ?? 0,
            'overallProgress': data['overallProgress'] ?? 0.0,
            'totalReadingTimeSeconds': data['totalReadingTimeSeconds'] ?? 0,
            'bookmarksCount': (data['bookmarks'] as List?)?.length ?? 0,
            'highlightsCount': (data['highlights'] as List?)?.length ?? 0,
            'notesCount': (data['notes'] as List?)?.length ?? 0,
            'isFinished': data['isFinished'] ?? false,
            'lastUpdatedAt': data['lastUpdatedAt']?.toString() ??
                DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        debugPrint('⚠️ Skipping malformed progress entry for key $key: $e');
      }
    }

    await progressBox.close();

    // Write the snapshot to a local sync log file
    final appDir = await getApplicationDocumentsDirectory();
    final syncDir = Directory(path.join(appDir.path, 'epub_sync'));
    await syncDir.create(recursive: true);

    final syncFile = File(path.join(syncDir.path, 'reading_progress_sync.json'));

    final syncPayload = {
      'syncedAt': DateTime.now().toIso8601String(),
      'entryCount': snapshot.length,
      'entries': snapshot,
    };

    // Write as formatted JSON (dart:convert)
    final jsonLines = StringBuffer();
    jsonLines.writeln('{');
    jsonLines.writeln('  "syncedAt": "${syncPayload['syncedAt']}",');
    jsonLines.writeln('  "entryCount": ${syncPayload['entryCount']},');
    jsonLines.writeln('  "entries": [');
    final entries = snapshot;
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final comma = i < entries.length - 1 ? ',' : '';
      jsonLines.writeln('    {');
      jsonLines.writeln('      "bookId": "${e['bookId']}",');
      jsonLines.writeln('      "chapterIndex": ${e['chapterIndex']},');
      jsonLines.writeln('      "overallProgress": ${e['overallProgress']},');
      jsonLines.writeln(
          '      "totalReadingTimeSeconds": ${e['totalReadingTimeSeconds']},');
      jsonLines.writeln('      "bookmarksCount": ${e['bookmarksCount']},');
      jsonLines.writeln('      "highlightsCount": ${e['highlightsCount']},');
      jsonLines.writeln('      "notesCount": ${e['notesCount']},');
      jsonLines.writeln('      "isFinished": ${e['isFinished']},');
      jsonLines.writeln('      "lastUpdatedAt": "${e['lastUpdatedAt']}"');
      jsonLines.writeln('    }$comma');
    }
    jsonLines.writeln('  ]');
    jsonLines.writeln('}');

    await syncFile.writeAsString(jsonLines.toString());

    debugPrint(
      '✅ Local sync complete — ${snapshot.length} entries → ${syncFile.path}',
    );
    return true;
  } catch (e) {
    debugPrint('❌ Sync task error: $e');
    return false;
  }
}

/// Format bytes to human-readable string
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
