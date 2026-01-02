import 'dart:async';
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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/video_edit_settings.dart';

// ═══════════════════════════════════════════════════════
// ✅ CONSTANTS
// ═══════════════════════════════════════════════════════

const String kExportTaskName = 'video_export_task';
const String kExportChannelId = 'video_export_channel';
const String kExportChannelName = 'Video Export';
const int kExportNotificationId = 1001;
const int kExportCompleteNotificationId = 1002;

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
// ✅ EXPORT JOB
// ═══════════════════════════════════════════════════════

class ExportJob {
  final String id;
  final String projectId;
  final String inputPath;
  final String outputPath;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  ExportStatus status;
  double progress;
  String? error;

  ExportJob({
    required this.id,
    required this.projectId,
    required this.inputPath,
    required this.outputPath,
    required this.settings,
    DateTime? createdAt,
    this.status = ExportStatus.idle,
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
      id: json['id'],
      projectId: json['projectId'],
      inputPath: json['inputPath'],
      outputPath: json['outputPath'],
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      status: ExportStatus.values[json['status'] ?? 0],
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      error: json['error'],
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

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  bool _isInitialized = false;
  ExportJob? _currentJob;
  bool _isCancelled = false;
  int? _currentSessionId;

  // Stream controllers
  final _progressController = StreamController<ExportProgress>.broadcast();
  final _jobsController = StreamController<List<ExportJob>>.broadcast();

  Stream<ExportProgress> get progressStream => _progressController.stream;
  Stream<List<ExportJob>> get jobsStream => _jobsController.stream;

  ExportJob? get currentJob => _currentJob;
  bool get isExporting =>
      _currentJob != null && _currentJob!.status == ExportStatus.processing;

  final String _currentJobKey = 'background_export_current_job';

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initializeNotifications();

      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      _isInitialized = true;
      debugPrint('✅ BackgroundExportService initialized');
    } catch (e) {
      debugPrint('❌ Initialize error: $e');
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

  Future<String?> startExport({
    required VideoProject project,
    bool runInBackground = true,
    Function(ExportProgress)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    // Cancel any existing export
    if (_currentJob != null && _currentJob!.status == ExportStatus.processing) {
      await cancelExport();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _isCancelled = false;

    try {
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
      await _saveCurrentJob(job);

      _updateProgress(
        ExportProgress(
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
    } catch (e) {
      debugPrint('❌ Start export error: $e');

      // IMPORTANT: Clear the notification and update state on error
      await _handleExportFailure(e.toString());

      return null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXECUTE EXPORT - FIXED ERROR HANDLING
  // ═══════════════════════════════════════════════════════

  Future<String?> _executeExport({
    required ExportJob job,
    required VideoProject project,
    Function(ExportProgress)? onProgress,
  }) async {
    final startTime = DateTime.now();

    try {
      job.status = ExportStatus.processing;
      await _saveCurrentJob(job);

      final command = await _buildFFmpegCommand(project, job.outputPath);
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
        const Duration(minutes: 30),
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
        return null;
      }

      if (success) {
        // Verify output file exists and has content
        final outputFile = File(job.outputPath);
        if (await outputFile.exists() && await outputFile.length() > 0) {
          await _handleExportSuccess(job, onProgress, startTime);
          return job.outputPath;
        } else {
          await _handleExportFailure('Output file is empty or missing');
          return null;
        }
      } else {
        final logs = await session.getAllLogsAsString();
        final errorMsg = _extractErrorFromLogs(logs);
        await _handleExportFailure(errorMsg);
        return null;
      }
    } catch (e) {
      debugPrint('❌ Execute export error: $e');
      await _handleExportFailure(e.toString());
      return null;
    }
  }

  String _extractErrorFromLogs(String? logs) {
    if (logs == null || logs.isEmpty) return 'Unknown error';

    // Look for common error patterns
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
    Function(ExportProgress)? onProgress,
    DateTime startTime,
  ) async {
    job.status = ExportStatus.completed;
    job.progress = 1.0;
    await _saveCurrentJob(job);

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
    await _clearCurrentJob();
  }

  Future<void> _handleExportFailure(String error) async {
    debugPrint('❌ Export failed: $error');

    if (_currentJob != null) {
      _currentJob!.status = ExportStatus.failed;
      _currentJob!.error = error;
      await _saveCurrentJob(_currentJob!);

      // Clean up partial output file
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

    // IMPORTANT: Cancel the progress notification and show failure
    await _cancelNotification();
    await _showCompletionNotification(false, error: error);

    _currentJob = null;
    _currentSessionId = null;
    await _clearCurrentJob();
  }

  Future<void> _handleExportCancelled(ExportJob job) async {
    await _cleanupFile(job.outputPath);
    job.status = ExportStatus.cancelled;
    await _saveCurrentJob(job);

    _updateProgress(
      const ExportProgress(
        status: ExportStatus.cancelled,
        message: 'Export cancelled',
      ),
    );

    await _cancelNotification();
    _currentJob = null;
    _currentSessionId = null;
    await _clearCurrentJob();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BUILD FFMPEG COMMAND - FIXED
  // ═══════════════════════════════════════════════════════

  Future<String> _buildFFmpegCommand(
    VideoProject project,
    String outputPath,
  ) async {
    final parts = <String>['-y'];

    // Input with trim
    if (project.trimStart > Duration.zero) {
      parts.add('-ss ${_formatDuration(project.trimStart)}');
    }

    final escapedInput = _escapePathForShell(project.videoPath);
    parts.add('-i $escapedInput');

    if (project.trimEnd < project.videoDuration) {
      final duration = project.trimEnd - project.trimStart;
      parts.add('-t ${_formatDuration(duration)}');
    }

    // Build video filters
    final videoFilters = <String>[];

    // Color grading
    if (!project.colorGrade.isDefault) {
      videoFilters.add(_buildColorFilter(project.colorGrade));
    }

    // Resolution scaling (without padding to avoid dimension issues)
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
    parts.add(_escapePathForShell(outputPath));

    return parts.join(' ');
  }

  String _buildColorFilter(ColorGradeSettings settings) {
    final filters = <String>[];

    // Brightness, contrast, saturation
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

    // Hue
    if (settings.hue != 0.0) {
      filters.add('hue=h=${settings.hue}');
    }

    return filters.isEmpty ? 'null' : filters.join(',');
  }

  String _escapePathForShell(String path) {
    if (Platform.isWindows) {
      return '"${path.replaceAll('"', '\\"')}"';
    } else {
      return '"${path.replaceAll('"', '\\"').replaceAll("'", "\\'")}"';
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CANCEL EXPORT - FIXED
  // ═══════════════════════════════════════════════════════

  Future<void> cancelExport() async {
    _isCancelled = true;

    try {
      // Cancel FFmpeg session
      if (_currentSessionId != null) {
        await FFmpegKit.cancel(_currentSessionId!);
        _currentSessionId = null;
      } else {
        await FFmpegKit.cancel();
      }

      // Cancel background task
      if (_currentJob != null) {
        await Workmanager().cancelByUniqueName(_currentJob!.id);
      }

      // Update state
      if (_currentJob != null) {
        _currentJob!.status = ExportStatus.cancelled;
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
      await _clearCurrentJob();
    } catch (e) {
      debugPrint('❌ Cancel export error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ NOTIFICATIONS - FIXED
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
      // ALWAYS cancel progress notification first
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

  Future<void> _startBackgroundTask(ExportJob job) async {
    try {
      await Workmanager().registerOneOffTask(
        job.id,
        kExportTaskName,
        inputData: job.toJson(),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('❌ Start background task error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PERSISTENCE
  // ═══════════════════════════════════════════════════════

  Future<void> _saveCurrentJob(ExportJob job) async {
    try {
      await _storage.write(key: _currentJobKey, value: job.toJson().toString());
    } catch (e) {
      debugPrint('❌ Save job error: $e');
    }
  }

  Future<void> _clearCurrentJob() async {
    try {
      await _storage.delete(key: _currentJobKey);
    } catch (e) {
      debugPrint('❌ Clear job error: $e');
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

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  void _updateProgress(ExportProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DISPOSE
  // ═══════════════════════════════════════════════════════

  void dispose() {
    _progressController.close();
    _jobsController.close();
  }
}
