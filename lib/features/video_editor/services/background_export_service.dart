import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/video_edit_settings.dart';
import 'package:slideup/core/utils/safe_async.dart';
import 'package:slideup/core/utils/isolate_helper.dart';

// ═══════════════════════════════════════════════════════
// ✅ CONSTANTS
// ═══════════════════════════════════════════════════════

const String kExportTaskName = 'video_export_task';
const String kExportChannelId = 'video_export_channel';
const String kExportChannelName = 'Video Export';
const int kExportNotificationId = 1001;
const int kExportCompleteNotificationId = 1002;
const String kExportJobsBox = 'export_jobs_box';

// ═══════════════════════════════════════════════════════
// ✅ BACKGROUND CALLBACK
// ═══════════════════════════════════════════════════════

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == kExportTaskName && inputData != null) {
        final service = BackgroundExportService._();
        await service._executeExportInBackground(inputData);
        return true;
      }
    } catch (e) {
      debugPrint('❌ Background task error: $e');
    }
    return false;
  });
}

// ═══════════════════════════════════════════════════════
// ✅ EXPORT JOB ERROR
// ═══════════════════════════════════════════════════════

enum ExportJobErrorType {
  invalidProject,
  processingFailed,
  cancelled,
  timeout,
  storageError,
  unknown,
}

class ExportJobError implements Exception {
  final ExportJobErrorType type;
  final String message;
  final String? details;
  final Object? originalError;

  const ExportJobError({
    required this.type,
    required this.message,
    this.details,
    this.originalError,
  });

  @override
  String toString() =>
      'ExportJobError($type): $message${details != null ? ' - $details' : ''}';

  factory ExportJobError.invalidProject(String reason) => ExportJobError(
    type: ExportJobErrorType.invalidProject,
    message: 'Invalid project',
    details: reason,
  );

  factory ExportJobError.processingFailed(String operation, [Object? error]) =>
      ExportJobError(
        type: ExportJobErrorType.processingFailed,
        message: 'Export failed',
        details: operation,
        originalError: error,
      );

  factory ExportJobError.cancelled() => const ExportJobError(
    type: ExportJobErrorType.cancelled,
    message: 'Export cancelled',
  );
}

// ═══════════════════════════════════════════════════════
// ✅ EXPORT JOB
// ═══════════════════════════════════════════════════════

class ExportJob {
  final String id;
  final String projectId;
  final String inputPath;
  final String outputPath;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  ExportJobStatus status;
  double progress;
  String? error;

  ExportJob({
    required this.id,
    required this.projectId,
    required this.inputPath,
    required this.outputPath,
    required this.settings,
    DateTime? createdAt,
    this.status = ExportJobStatus.pending,
    this.progress = 0.0,
    this.error,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'inputPath': inputPath,
    'outputPath': outputPath,
    'settings': settings,
    'createdAt': createdAt.toIso8601String(),
    'status': status.index,
    'progress': progress,
    'error': error,
  };

  factory ExportJob.fromJson(Map<String, dynamic> json) {
    return ExportJob(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      inputPath: json['inputPath'] as String,
      outputPath: json['outputPath'] as String,
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: ExportJobStatus.values[json['status'] as int? ?? 0],
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
    );
  }

  ExportJob copyWith({
    String? id,
    String? projectId,
    String? inputPath,
    String? outputPath,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    ExportJobStatus? status,
    double? progress,
    String? error,
  }) {
    return ExportJob(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      inputPath: inputPath ?? this.inputPath,
      outputPath: outputPath ?? this.outputPath,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ BACKGROUND EXPORT SERVICE
// ═══════════════════════════════════════════════════════

class BackgroundExportService {
  static final BackgroundExportService _instance =
      BackgroundExportService._internal();
  factory BackgroundExportService() => _instance;
  BackgroundExportService._internal();

  BackgroundExportService._();

  final _uuid = const Uuid();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Box<String>? _jobsBox;
  bool _isInitialized = false;
  ExportJob? _currentJob;
  bool _isCancelled = false;
  int? _currentSessionId;

  final _progressController = StreamController<ExportProgress>.broadcast();
  final _jobsController = StreamController<List<ExportJob>>.broadcast();

  Stream<ExportProgress> get progressStream => _progressController.stream;
  Stream<List<ExportJob>> get jobsStream => _jobsController.stream;

  ExportJob? get currentJob => _currentJob;
  bool get isExporting =>
      _currentJob != null && _currentJob!.status == ExportStatus.processing;
  bool get isInitialized => _isInitialized;

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> initialize() async {
    if (_isInitialized) return Result.success(null);

    return SafeAsync.run(() async {
      await _initializeHive();
      await _initializeNotifications();
      await Workmanager().initialize(callbackDispatcher);

      _isInitialized = true;
      debugPrint('✅ BackgroundExportService initialized');
    }, operationName: 'BackgroundExportService.initialize');
  }

  Future<void> _initializeHive() async {
    try {
      _jobsBox = await Hive.openBox<String>(kExportJobsBox);
    } catch (e) {
      debugPrint('❌ Hive init error: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            kExportChannelId,
            kExportChannelName,
            description: 'Video export progress notifications',
            importance: Importance.low,
            showBadge: false,
            playSound: false,
            enableVibration: false,
          ),
        );
      }

      await _requestNotificationPermissions();
    } catch (e) {
      debugPrint('❌ Notification init error: $e');
    }
  }

  Future<void> _requestNotificationPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        final iosPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('❌ Permission request error: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Notification tapped: ${response.payload}');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ START EXPORT
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> startExport({
    required VideoProject project,
    bool runInBackground = true,
    void Function(ExportProgress)? onProgress,
  }) async {
    if (!_isInitialized) {
      final initResult = await initialize();
      if (initResult.isFailure) {
        return Result.failure(initResult.error!);
      }
    }

    // Cancel any existing export
    if (_currentJob != null && _currentJob!.status == ExportStatus.processing) {
      await cancelExport();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _isCancelled = false;

    return SafeAsync.run(
      () async {
        final outputDir = await _getOutputDirectory();
        final fileName =
            'export_${DateTime.now().millisecondsSinceEpoch}.${project.exportPreset.extension}';
        final outputPath = p.join(outputDir.path, fileName);

        final job = ExportJob(
          id: _uuid.v4(),
          projectId: project.id,
          inputPath: project.videoPath,
          outputPath: outputPath,
          settings: _buildExportSettings(project),
        );

        _currentJob = job;
        await _saveJob(job);

        _updateProgress(
          const ExportProgress(
            status: ExportStatus.preparing,
            progress: 0.0,
            message: 'Preparing export...',
          ),
        );

        await _showProgressNotification(0, 'Preparing export...');

        final result = await _executeExport(
          job: job,
          project: project,
          onProgress: (progress) {
            onProgress?.call(progress);
            _updateProgress(progress);
          },
        );

        return result;
      },
      operationName: 'startExport',
      timeout: const Duration(hours: 2),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXECUTE EXPORT
  // ═══════════════════════════════════════════════════════

  Future<String> _executeExport({
    required ExportJob job,
    required VideoProject project,
    void Function(ExportProgress)? onProgress,
  }) async {
    final startTime = DateTime.now();

    job.status = ExportJobStatus.running;
    await _saveJob(job);

    // Build command in isolate
    final commandResult = await IsolateHelper.instance.compute(
      _buildFFmpegCommandIsolate,
      _CommandParams(project: project, outputPath: job.outputPath),
    );

    final command = commandResult.getOrElse('');
    if (command.isEmpty) {
      throw ExportJobError.processingFailed('Failed to build FFmpeg command');
    }

    debugPrint('📹 FFmpeg command: $command');

    final totalDuration = project.effectiveDuration;
    final completer = Completer<bool>();

    // Setup progress callback
    FFmpegKitConfig.enableStatisticsCallback((statistics) {
      try {
        if (_isCancelled) return;

        final time = statistics.getTime();
        if (time > 0 && totalDuration.inMilliseconds > 0) {
          final progress = (time / totalDuration.inMilliseconds).clamp(
            0.0,
            0.99,
          );
          final elapsed = DateTime.now().difference(startTime);
          final estimated = progress > 0.01
              ? Duration(
                  milliseconds: (elapsed.inMilliseconds / progress).toInt(),
                )
              : null;

          job.progress = progress;

          final exportProgress = ExportProgress(
            status: ExportStatus.processing,
            progress: progress,
            message: 'Exporting... ${(progress * 100).toInt()}%',
            elapsed: elapsed,
            estimated: estimated,
          );

          onProgress?.call(exportProgress);
          _showProgressNotification(
            (progress * 100).toInt(),
            'Exporting video... ${(progress * 100).toInt()}%',
          );
        }
      } catch (e) {
        debugPrint('❌ Statistics callback error: $e');
      }
    });

    // Execute FFmpeg with async callback
    final session = await FFmpegKit.executeAsync(
      command,
      (session) async {
        try {
          final returnCode = await session.getReturnCode();
          if (!completer.isCompleted) {
            completer.complete(ReturnCode.isSuccess(returnCode));
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        }
      },
      (log) {
        if (log.getLevel() <= 16) {
          debugPrint('FFmpeg: ${log.getMessage()}');
        }
      },
      null,
    );

    _currentSessionId = session.getSessionId();

    // Wait for completion with timeout
    final success = await completer.future.timeout(
      const Duration(hours: 1),
      onTimeout: () {
        debugPrint('⚠️ Export timeout');
        return false;
      },
    );

    // Clear callbacks
    FFmpegKitConfig.enableStatisticsCallback(null);
    _currentSessionId = null;

    if (_isCancelled) {
      await _handleExportCancelled(job);
      throw ExportJobError.cancelled();
    }

    if (success) {
      // Verify output file
      final outputFile = File(job.outputPath);
      if (await outputFile.exists() && await outputFile.length() > 0) {
        await _handleExportSuccess(job, onProgress, startTime);
        return job.outputPath;
      } else {
        await _handleExportFailure('Output file is empty or missing');
        throw ExportJobError.processingFailed('Output file validation failed');
      }
    } else {
      final logs = await session.getAllLogsAsString();
      final errorMsg = _extractErrorFromLogs(logs);
      await _handleExportFailure(errorMsg);
      throw ExportJobError.processingFailed(errorMsg);
    }
  }

  String _extractErrorFromLogs(String? logs) {
    if (logs == null || logs.isEmpty) return 'Unknown error';

    final lines = logs.split('\n');
    for (final line in lines.reversed) {
      if (line.toLowerCase().contains('error') ||
          line.toLowerCase().contains('failed') ||
          line.toLowerCase().contains('invalid')) {
        return line.length > 100 ? '${line.substring(0, 100)}...' : line;
      }
    }

    return 'Export failed - check video file';
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXPORT STATE HANDLERS
  // ═══════════════════════════════════════════════════════

  Future<void> _handleExportSuccess(
    ExportJob job,
    void Function(ExportProgress)? onProgress,
    DateTime startTime,
  ) async {
    job.status = ExportJobStatus.completed;
    job.progress = 1.0;
    await _saveJob(job);

    final finalProgress = ExportProgress(
      status: ExportStatus.completed,
      progress: 1.0,
      message: 'Export completed!',
      outputPath: job.outputPath,
      elapsed: DateTime.now().difference(startTime),
    );

    onProgress?.call(finalProgress);
    _updateProgress(finalProgress);
    await _showCompletionNotification(true, outputPath: job.outputPath);

    _currentJob = null;
  }

  Future<void> _handleExportFailure(String error) async {
    debugPrint('❌ Export failed: $error');

    if (_currentJob != null) {
      _currentJob!.status = ExportJobStatus.failed;
      _currentJob!.error = error;
      await _saveJob(_currentJob!);
      await _cleanupFile(_currentJob!.outputPath);
    }

    _updateProgress(
      ExportProgress(
        status: ExportStatus.failed,
        progress: 0,
        message: 'Export failed',
        error: error,
      ),
    );

    await _cancelNotification();
    await _showCompletionNotification(false, error: error);

    _currentJob = null;
    _currentSessionId = null;
  }

  Future<void> _handleExportCancelled(ExportJob job) async {
    await _cleanupFile(job.outputPath);
    job.status = ExportJobStatus.cancelled;
    await _saveJob(job);

    _updateProgress(
      const ExportProgress(
        status: ExportStatus.cancelled,
        message: 'Export cancelled',
      ),
    );

    await _cancelNotification();
    _currentJob = null;
    _currentSessionId = null;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CANCEL EXPORT
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> cancelExport() async {
    _isCancelled = true;

    return SafeAsync.run(() async {
      if (_currentSessionId != null) {
        await FFmpegKit.cancel(_currentSessionId!);
        _currentSessionId = null;
      } else {
        await FFmpegKit.cancel();
      }

      if (_currentJob != null) {
        await Workmanager().cancelByUniqueName(_currentJob!.id);
        _currentJob!.status = ExportJobStatus.cancelled;
        await _cleanupFile(_currentJob!.outputPath);
      }

      _updateProgress(
        const ExportProgress(
          status: ExportStatus.cancelled,
          message: 'Export cancelled',
        ),
      );

      await _cancelNotification();
      _currentJob = null;
    }, operationName: 'cancelExport');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ NOTIFICATIONS
  // ═══════════════════════════════════════════════════════

  Future<void> _showProgressNotification(int progress, String message) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        kExportChannelId,
        kExportChannelName,
        channelDescription: 'Video export progress',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: 100,
        progress: progress,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        category: AndroidNotificationCategory.progress,
        visibility: NotificationVisibility.public,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        kExportNotificationId,
        'Exporting Video',
        message,
        details,
        payload: 'export_progress',
      );
    } catch (e) {
      debugPrint('❌ Show progress notification error: $e');
    }
  }

  Future<void> _showCompletionNotification(
    bool success, {
    String? outputPath,
    String? error,
  }) async {
    try {
      await _notifications.cancel(kExportNotificationId);

      final androidDetails = AndroidNotificationDetails(
        kExportChannelId,
        kExportChannelName,
        channelDescription: 'Video export completion',
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        kExportCompleteNotificationId,
        success ? 'Export Complete! ✅' : 'Export Failed ❌',
        success
            ? 'Your video is ready'
            : (error ?? 'An error occurred during export'),
        details,
        payload: success ? outputPath : null,
      );
    } catch (e) {
      debugPrint('❌ Show completion notification error: $e');
    }
  }

  Future<void> _cancelNotification() async {
    try {
      await _notifications.cancel(kExportNotificationId);
    } catch (e) {
      debugPrint('❌ Cancel notification error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BACKGROUND EXECUTION
  // ═══════════════════════════════════════════════════════

  Future<void> _executeExportInBackground(
    Map<String, dynamic> inputData,
  ) async {
    try {
      final job = ExportJob.fromJson(inputData);
      debugPrint('🔄 Resuming export in background: ${job.id}');

      await _showProgressNotification(
        (job.progress * 100).toInt(),
        'Exporting in background...',
      );

      final command = job.settings['ffmpegCommand'] as String?;
      if (command != null) {
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          await _showCompletionNotification(true, outputPath: job.outputPath);
        } else {
          await _showCompletionNotification(false, error: 'Export failed');
        }
      }
    } catch (e) {
      debugPrint('❌ Background export error: $e');
      await _showCompletionNotification(false, error: e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PERSISTENCE WITH HIVE
  // ═══════════════════════════════════════════════════════

  Future<void> _saveJob(ExportJob job) async {
    try {
      final jsonStr = jsonEncode(job.toJson());
      await _jobsBox?.put(job.id, jsonStr);
      _notifyJobsChanged();
    } catch (e) {
      debugPrint('❌ Save job error: $e');
    }
  }

  Future<void> deleteJob(String jobId) async {
    try {
      await _jobsBox?.delete(jobId);
      _notifyJobsChanged();
    } catch (e) {
      debugPrint('❌ Delete job error: $e');
    }
  }

  Future<List<ExportJob>> getAllJobs() async {
    try {
      final jobs = <ExportJob>[];
      final keys = _jobsBox?.keys ?? [];

      for (final key in keys) {
        final jsonStr = _jobsBox?.get(key);
        if (jsonStr != null) {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          jobs.add(ExportJob.fromJson(json));
        }
      }

      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return jobs;
    } catch (e) {
      debugPrint('❌ Get all jobs error: $e');
      return [];
    }
  }

  Future<ExportJob?> getJob(String jobId) async {
    try {
      final jsonStr = _jobsBox?.get(jobId);
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return ExportJob.fromJson(json);
      }
    } catch (e) {
      debugPrint('❌ Get job error: $e');
    }
    return null;
  }

  void _notifyJobsChanged() async {
    final jobs = await getAllJobs();
    if (!_jobsController.isClosed) {
      _jobsController.add(jobs);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  Map<String, dynamic> _buildExportSettings(VideoProject project) {
    return {
      'trimStart': project.trimStart.inMilliseconds,
      'trimEnd': project.trimEnd.inMilliseconds,
      'preset': project.exportPreset.id,
      'colorGrade': !project.colorGrade.isDefault,
      'textCount': project.textItems.length,
      'imageCount': project.imageItems.length,
      'audioCount': project.audioItems.length,
    };
  }

  Future<Directory> _getOutputDirectory() async {
    final appDir = await getExternalStorageDirectory();
    final outputDir = Directory(p.join(appDir!.path, 'exports'));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    return outputDir;
  }

  Future<void> _cleanupFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('❌ Cleanup error: $e');
    }
  }

  void _updateProgress(ExportProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  void dispose() {
    _progressController.close();
    _jobsController.close();
    _jobsBox?.close();
  }
}

// ═══════════════════════════════════════════════════════
// ✅ ISOLATE FUNCTIONS
// ═══════════════════════════════════════════════════════

class _CommandParams {
  final VideoProject project;
  final String outputPath;

  _CommandParams({required this.project, required this.outputPath});
}

String _buildFFmpegCommandIsolate(_CommandParams params) {
  final project = params.project;
  final outputPath = params.outputPath;

  final parts = <String>['-y'];

  // Input with trim
  if (project.trimStart > Duration.zero) {
    parts.add('-ss ${_formatDurationIsolate(project.trimStart)}');
  }

  final escapedInput = _escapePathForShellIsolate(project.videoPath);
  parts.add('-i $escapedInput');

  if (project.trimEnd < project.videoDuration) {
    final duration = project.trimEnd - project.trimStart;
    parts.add('-t ${_formatDurationIsolate(duration)}');
  }

  // Build video filters
  final videoFilters = <String>[];

  // Color grading
  if (!project.colorGrade.isDefault) {
    videoFilters.add(_buildColorFilterIsolate(project.colorGrade));
  }

  // Resolution scaling
  final preset = project.exportPreset;
  if (preset.width != null && preset.height != null) {
    videoFilters.add(
      'scale=${preset.width}:${preset.height}:force_original_aspect_ratio=decrease',
    );
  }

  // Apply video filters
  if (videoFilters.isNotEmpty) {
    parts.add('-vf "${videoFilters.join(',')}"');
  }

  // Video encoding
  if (preset.quality != VideoQuality.original) {
    parts.add('-c:v libx264');
    parts.add('-preset medium');
    parts.add('-crf 23');

    if (preset.bitrate != null) {
      parts.add('-b:v ${preset.bitrate}k');
    }
    if (preset.fps != null) {
      parts.add('-r ${preset.fps}');
    }
  } else {
    parts.add('-c:v copy');
  }

  // Audio
  if (preset.removeAudio) {
    parts.add('-an');
  } else {
    parts.add('-c:a aac');
    parts.add('-b:a ${preset.audioBitrate ?? 128}k');
  }

  // Output
  parts.add('-movflags +faststart');
  parts.add(_escapePathForShellIsolate(outputPath));

  return parts.join(' ');
}

String _buildColorFilterIsolate(ColorGradeSettings settings) {
  final filters = <String>[];

  final eqParts = <String>[];
  if (settings.brightness != 0.0) {
    eqParts.add('brightness=${settings.brightness}');
  }
  if (settings.contrast != 1.0) {
    eqParts.add('contrast=${settings.contrast}');
  }
  if (settings.saturation != 1.0) {
    eqParts.add('saturation=${settings.saturation}');
  }

  if (eqParts.isNotEmpty) {
    filters.add('eq=${eqParts.join(':')}');
  }

  if (settings.hue != 0.0) {
    filters.add('hue=h=${settings.hue}');
  }

  return filters.isEmpty ? 'null' : filters.join(',');
}

String _escapePathForShellIsolate(String path) {
  return '"${path.replaceAll('"', '\\"').replaceAll("'", "\\'")}"';
}

String _formatDurationIsolate(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
  return '$h:$m:$s.$ms';
}
