import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../tts_controller.dart';

// ═══════════════════════════════════════════════════════════════════════════
// GENERATION JOB
// ═══════════════════════════════════════════════════════════════════════════

enum JobStatus { queued, generating, completed, failed, cancelled, skipped }

class GenerationJob {
  final String id;
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String text;

  JobStatus status;
  double progress;
  String? error;
  String? audioPath;
  DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;

  GenerationJob({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.text,
    this.status = JobStatus.queued,
    this.progress = 0.0,
    this.error,
    this.audioPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Duration? get duration {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICATION PAYLOAD
// ═══════════════════════════════════════════════════════════════════════════

class GenerationNotification {
  final String jobId;
  final String bookId;
  final int chapterIndex;
  final JobStatus status;
  final double progress;
  final String? error;

  GenerationNotification({
    required this.jobId,
    required this.bookId,
    required this.chapterIndex,
    required this.status,
    required this.progress,
    this.error,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// BACKGROUND CHAPTER GENERATOR
// ═══════════════════════════════════════════════════════════════════════════

class BackgroundChapterGenerator {
  static BackgroundChapterGenerator? _instance;
  static BackgroundChapterGenerator get instance =>
      _instance ??= BackgroundChapterGenerator._();

  BackgroundChapterGenerator._();

  final Queue<GenerationJob> _jobQueue = Queue();
  final Map<String, GenerationJob> _allJobs = {};
  GenerationJob? _currentJob;

  bool _isProcessing = false;
  bool _isPaused = false;
  bool _isDisposed = false;

  // ✅ Use global notification plugin
  FlutterLocalNotificationsPlugin? _notifications;
  bool _notificationsInitialized = false;

  final _jobStatusController = StreamController<GenerationJob>.broadcast();
  final _queueStatusController = StreamController<QueueStatus>.broadcast();

  Stream<GenerationJob> get jobStatusStream => _jobStatusController.stream;
  Stream<QueueStatus> get queueStatusStream => _queueStatusController.stream;

  int get queueLength => _jobQueue.length;
  int get completedCount =>
      _allJobs.values.where((j) => j.status == JobStatus.completed).length;
  int get failedCount =>
      _allJobs.values.where((j) => j.status == JobStatus.failed).length;
  bool get isProcessing => _isProcessing;
  bool get isPaused => _isPaused;
  GenerationJob? get currentJob => _currentJob;
  List<GenerationJob> get allJobs => _allJobs.values.toList();
  List<GenerationJob> get queuedJobs => _jobQueue.toList();

  // ✅ Initialize with global notification plugin
  Future<void> initialize() async {
    if (_notificationsInitialized) return;
    await requestPermission();
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

      await _notifications!.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      _notificationsInitialized = true;
      debugPrint('✓ Notification service initialized');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize notifications: $e');
    }
  }

  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notifications!
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await androidPlugin?.requestNotificationsPermission() ?? false;
      } else if (Platform.isIOS) {
        final iosPlugin = _notifications!
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await iosPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to request permission: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ADD JOBS
  // ═══════════════════════════════════════════════════════════════════════

  /// Add a single chapter to generation queue
  String addJob({
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    required String text,
  }) {
    final jobId =
        '${bookId}_ch${chapterIndex}_${DateTime.now().millisecondsSinceEpoch}';

    final job = GenerationJob(
      id: jobId,
      bookId: bookId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      text: text,
    );

    _allJobs[jobId] = job;
    _jobQueue.add(job);

    debugPrint('[BgGenerator] ✚ Job queued: Chapter ${chapterIndex + 1}');

    _emitJobStatus(job);
    _emitQueueStatus();

    // ✅ Start processing independently (non-blocking)
    if (!_isProcessing && !_isPaused) {
      _processQueue();
    }

    return jobId;
  }

  /// Add multiple chapters at once
  List<String> addMultipleJobs({
    required String bookId,
    required Map<int, String> chapters, // chapterIndex -> text
    required Map<int, String> chapterTitles, // chapterIndex -> title
  }) {
    try {
      final jobIds = <String>[];

      for (final entry in chapters.entries) {
        final chapterIndex = entry.key;
        final text = entry.value;
        final title =
            chapterTitles[chapterIndex] ?? 'Chapter ${chapterIndex + 1}';

        final jobId = addJob(
          bookId: bookId,
          chapterIndex: chapterIndex,
          chapterTitle: title,
          text: text,
        );

        jobIds.add(jobId);
      }

      debugPrint('[BgGenerator] ✚ Added ${jobIds.length} jobs');
      return jobIds;
    } catch (e) {
      debugPrint('[BgGenerator] Error adding multiple jobs: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUEUE PROCESSING
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _processQueue() async {
    try {
      if (_isProcessing || _isPaused || _isDisposed) return;
      if (_jobQueue.isEmpty) {
        _emitQueueStatus();
        return;
      }

      _isProcessing = true;
      _emitQueueStatus();

      debugPrint(
        '[BgGenerator] 🔄 Started processing queue (${_jobQueue.length} jobs)',
      );

      while (_jobQueue.isNotEmpty && !_isDisposed && !_isPaused) {
        final job = _jobQueue.removeFirst();

        if (job.status == JobStatus.cancelled) continue;

        _currentJob = job;
        job.status = JobStatus.generating;
        job.startedAt = DateTime.now();
        job.progress = 0.0;

        _emitJobStatus(job);
        _emitQueueStatus();

        try {
          debugPrint('[BgGenerator] 📝 Processing: Ch.${job.chapterIndex + 1}');

          // ✅ CHECK CACHE FIRST
          final isCached = await TtsController.instance.isPageCached(
            bookId: job.bookId,
            pageNumber: job.chapterIndex,
          );

          if (isCached) {
            debugPrint(
              '[BgGenerator] ✓ Ch.${job.chapterIndex + 1} cached, skipping',
            );

            job.status = JobStatus.skipped;
            job.completedAt = DateTime.now();
            job.progress = 1.0;

            _emitJobStatus(job);

            final entries = await TtsController.instance
                .getGeneratedAudioForBook(job.bookId);
            final entry = entries
                .where((e) => e.pageNumber == job.chapterIndex)
                .firstOrNull;
            job.audioPath = entry?.filePath;

            // ✅ Cancel notification for skipped
            _cancelNotification(job.chapterIndex);

            continue;
          }

          // ✅ Show initial notification
          _showProgressNotification(job);

          // ✅ GENERATE IN BACKGROUND (non-blocking for UI)
          debugPrint(
            '[BgGenerator] 🎵 Generating Ch.${job.chapterIndex + 1}...',
          );

          final audioPath = await TtsController.instance.generateAudioSimple(
            text: job.text,
            bookId: job.bookId,
            pageNumber: job.chapterIndex,
            speed: 1.0,
            onProgress: (progress) {
              if (_isDisposed || job.status == JobStatus.cancelled) return;

              job.progress = progress;
              _emitJobStatus(job);

              // ✅ Update notification every 10%
              final currentPercent = (progress * 10).floor();
              final lastPercent = ((progress - 0.1) * 10).floor();

              if (currentPercent != lastPercent) {
                _showProgressNotification(job);
              }
            },
          );

          if (_isDisposed || job.status == JobStatus.cancelled) continue;

          if (audioPath != null) {
            // ✅ SUCCESS
            job.status = JobStatus.completed;
            job.completedAt = DateTime.now();
            job.audioPath = audioPath;
            job.progress = 1.0;

            _emitJobStatus(job);
            _showCompletionNotification(job);

            debugPrint(
              '[BgGenerator] ✓ Ch.${job.chapterIndex + 1} done in ${job.duration?.inSeconds}s',
            );
          } else {
            throw Exception('Generation returned null');
          }
        } catch (e) {
          debugPrint('[BgGenerator] ✗ Ch.${job.chapterIndex + 1} failed: $e');

          job.status = JobStatus.failed;
          job.completedAt = DateTime.now();
          job.error = e.toString();

          _emitJobStatus(job);
          _showErrorNotification(job);
        }

        _emitQueueStatus();

        // ✅ Small delay between jobs (yield to system)
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _currentJob = null;
      _isProcessing = false;
      _emitQueueStatus();

      debugPrint('[BgGenerator] ✓ Queue processing complete');

      if (_jobQueue.isEmpty && !_isDisposed) {
        _showSummaryNotification();
      }
    } catch (e) {
      debugPrint('[BgGenerator] Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════

  void _showProgressNotification(GenerationJob job) {
    if (!_notificationsInitialized || _notifications == null) return;

    try {
      final percentage = (job.progress * 100).toInt();

      _notifications!.show(
        job.chapterIndex, // Unique ID per chapter
        '📖 Generating Chapter ${job.chapterIndex + 1}',
        '${job.chapterTitle} - $percentage%',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'audiobook_generation',
            'Audiobook Generation',
            channelDescription: 'Background chapter audio generation',
            importance: Importance.low,
            priority: Priority.low,
            showProgress: true,
            maxProgress: 100,
            progress: percentage,
            ongoing: true,
            autoCancel: false,
            playSound: false,
            enableVibration: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            presentSound: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[BgGenerator] Notification error: $e');
    }
  }

  void _showCompletionNotification(GenerationJob job) {
    if (!_notificationsInitialized || _notifications == null) return;

    try {
      _notifications!.show(
        job.chapterIndex,
        '✓ Chapter ${job.chapterIndex + 1} Ready',
        job.chapterTitle,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'audiobook_generation',
            'Audiobook Generation',
            channelDescription: 'Chapter ready to play',
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
          ),
        ),
      );

      // Auto-dismiss after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        _cancelNotification(job.chapterIndex);
      });
    } catch (e) {
      debugPrint('[BgGenerator] Notification error: $e');
    }
  }

  void _showErrorNotification(GenerationJob job) {
    if (!_notificationsInitialized || _notifications == null) return;

    try {
      _notifications!.show(
        job.chapterIndex,
        '✗ Chapter ${job.chapterIndex + 1} Failed',
        job.error ?? 'Generation failed',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'audiobook_generation',
            'Audiobook Generation',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[BgGenerator] Notification error: $e');
    }
  }

  void _showSummaryNotification() {
    if (!_notificationsInitialized || _notifications == null) return;

    try {
      final completed = completedCount;
      final failed = failedCount;
      final skipped = _allJobs.values
          .where((j) => j.status == JobStatus.skipped)
          .length;

      _notifications!.show(
        999999, // Summary ID
        '📚 Audiobook Generation Complete',
        '✓ $completed ready${skipped > 0 ? ', ⊘ $skipped skipped' : ''}${failed > 0 ? ', ✗ $failed failed' : ''}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'audiobook_generation',
            'Audiobook Generation',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );

      // Auto-dismiss after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        _cancelNotification(999999);
      });
    } catch (e) {
      debugPrint('[BgGenerator] Notification error: $e');
    }
  }

  void _cancelNotification(int id) {
    try {
      _notifications?.cancel(id);
    } catch (e) {
      debugPrint('[BgGenerator] Cancel notification error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CONTROL METHODS
  // ═══════════════════════════════════════════════════════════════════════

  void pause() {
    _isPaused = true;
    debugPrint('[BgGenerator] Queue paused');
    _emitQueueStatus();
  }

  void resume() {
    _isPaused = false;
    debugPrint('[BgGenerator] Queue resumed');
    if (!_isProcessing && _jobQueue.isNotEmpty) {
      _processQueue();
    }
    _emitQueueStatus();
  }

  void cancelJob(String jobId) {
    final job = _allJobs[jobId];
    if (job == null) return;

    job.status = JobStatus.cancelled;
    _jobQueue.removeWhere((j) => j.id == jobId);

    _emitJobStatus(job);
    _emitQueueStatus();

    // Cancel notification
    _notifications!.cancel(job.chapterIndex);

    debugPrint('[BgGenerator] Job cancelled: $jobId');
  }

  void cancelAll() {
    for (final job in _allJobs.values) {
      if (job.status == JobStatus.queued ||
          job.status == JobStatus.generating) {
        job.status = JobStatus.cancelled;
        _notifications!.cancel(job.chapterIndex);
      }
    }

    _jobQueue.clear();
    _currentJob = null;
    _isProcessing = false;

    _emitQueueStatus();
    debugPrint('[BgGenerator] All jobs cancelled');
  }

  void clearCompleted() {
    _allJobs.removeWhere(
      (id, job) =>
          job.status == JobStatus.completed ||
          job.status == JobStatus.failed ||
          job.status == JobStatus.cancelled ||
          job.status == JobStatus.skipped,
    );

    _emitQueueStatus();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STREAM EMITTERS
  // ═══════════════════════════════════════════════════════════════════════

  void _emitJobStatus(GenerationJob job) {
    if (!_jobStatusController.isClosed) {
      _jobStatusController.add(job);
    }
  }

  void _emitQueueStatus() {
    if (!_queueStatusController.isClosed) {
      _queueStatusController.add(
        QueueStatus(
          queueLength: _jobQueue.length,
          processingCount: _currentJob != null ? 1 : 0,
          readyCount: completedCount,
          completedCount: completedCount,
          isProcessing: _isProcessing,
          currentTaskId: _currentJob?.id,
          currentTask: null, // Not using TtsTask here
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════════════

  void dispose() {
    _isDisposed = true;
    cancelAll();
    _jobStatusController.close();
    _queueStatusController.close();
  }
}

// Reuse QueueStatus from tts_queue_manager.dart
class QueueStatus {
  final int queueLength;
  final int processingCount;
  final int readyCount;
  final int completedCount;
  final bool isProcessing;
  final String? currentTaskId;
  final dynamic currentTask;

  const QueueStatus({
    this.queueLength = 0,
    this.processingCount = 0,
    this.readyCount = 0,
    this.completedCount = 0,
    this.isProcessing = false,
    this.currentTaskId,
    this.currentTask,
  });
}
