import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';

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
  final bool isSilent;

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
    this.isSilent = false,
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
// NOTIFICATION IDS
// ═══════════════════════════════════════════════════════════════════════════

class _NotificationIds {
  static const int queue = 0; // Global queue notification
  static const int summary = 999999;
  static int chapter(int index) => 1000 + index; // Individual chapters
}

// ═══════════════════════════════════════════════════════════════════════════
// QUEUE STATUS
// ═══════════════════════════════════════════════════════════════════════════

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

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  final _jobStatusController = StreamController<GenerationJob>.broadcast();
  final _queueStatusController = StreamController<QueueStatus>.broadcast();

  // Keep-alive player
  final AudioPlayer _silentPlayer = AudioPlayer();
  String? _silentWavPath;

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

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_notificationsInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_notification',
      );

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      _notificationsInitialized = true;
      debugPrint('✓ Notification service initialized');

      await requestPermission();
    } catch (e, stack) {
      debugPrint('⚠️ Failed to initialize notifications: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<bool> requestPermission() async {
    try {
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        final bool? granted = await androidPlugin
            ?.requestNotificationsPermission();

        return granted ?? true;
      }

      if (Platform.isIOS) {
        final iosPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();

        final bool? granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

        return granted ?? false;
      }

      return false;
    } catch (e, stack) {
      debugPrint('Failed to request permission: $e');
      debugPrintStack(stackTrace: stack);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION ACTIONS HANDLER
  // ═══════════════════════════════════════════════════════════════════════════

  void _onNotificationTap(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;

    debugPrint('📲 Notification action: $actionId, payload: $payload');

    if (actionId == null) {
      // User tapped notification body
      debugPrint('Notification tapped: $payload');
      return;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // QUEUE CONTROLS
    // ═══════════════════════════════════════════════════════════════════════

    if (actionId == 'queue_toggle_pause') {
      if (_isPaused) {
        resume();
      } else {
        pause();
      }
      _showQueueNotification();
      return;
    }

    if (actionId == 'queue_cancel_all') {
      cancelAll();
      _cancelNotification(_NotificationIds.queue);

      // Cancel all chapter notifications
      for (final job in _allJobs.values) {
        _cancelNotification(_NotificationIds.chapter(job.chapterIndex));
      }
      return;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // INDIVIDUAL CHAPTER CONTROLS
    // ═══════════════════════════════════════════════════════════════════════

    if (actionId.startsWith('chapter_cancel_')) {
      if (payload != null) {
        cancelJob(payload);
        final job = _allJobs[payload];
        if (job != null) {
          _cancelNotification(_NotificationIds.chapter(job.chapterIndex));
        }
        _showQueueNotification();
      }
      return;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SUMMARY CONTROLS
    // ═══════════════════════════════════════════════════════════════════════

    if (actionId == 'summary_clear') {
      clearCompleted();
      _cancelNotification(_NotificationIds.summary);
      return;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADD JOBS
  // ═══════════════════════════════════════════════════════════════════════════

  String addJob({
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    required String text,
    bool isSilent = false,
  }) {
    final jobId =
        '${bookId}_ch${chapterIndex}_${DateTime.now().millisecondsSinceEpoch}';

    final job = GenerationJob(
      id: jobId,
      bookId: bookId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      text: text,
      isSilent: isSilent,
    );

    _allJobs[jobId] = job;
    _jobQueue.add(job);

    debugPrint(
      '[BgGenerator] ✚ Job queued: Chapter ${chapterIndex + 1} (Silent: $isSilent)',
    );

    _emitJobStatus(job);
    _emitQueueStatus();

    if (!_isProcessing && !_isPaused) {
      _processQueue();
    }

    return jobId;
  }

  List<String> addMultipleJobs({
    required String bookId,
    required Map<int, String> chapters,
    required Map<int, String> chapterTitles,
    bool isSilent = true,
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
          isSilent: isSilent,
        );

        jobIds.add(jobId);
      }

      debugPrint(
        '[BgGenerator] ✚ Added ${jobIds.length} jobs (Silent: $isSilent)',
      );
      return jobIds;
    } catch (e) {
      debugPrint('[BgGenerator] Error adding multiple jobs: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUEUE PROCESSING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _processQueue() async {
    try {
      if (_isProcessing || _isPaused || _isDisposed) return;
      if (_jobQueue.isEmpty) {
        _emitQueueStatus();
        return;
      }

      await _startSilentAudio();

      _isProcessing = true;
      _emitQueueStatus();

      _showQueueNotification();

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

        _showQueueNotification();

        try {
          debugPrint('[BgGenerator] 📝 Processing: Ch.${job.chapterIndex + 1}');

          // Check cache first
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

            _showQueueNotification();

            continue;
          }

          // Show individual chapter notification
          _showProgressNotification(job);

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

              // Update notification every 10%
              final currentPercent = (progress * 10).floor();
              final lastPercent = ((progress - 0.1) * 10).floor();

              if (currentPercent != lastPercent) {
                _showProgressNotification(job);
              }
            },
          );

          if (_isDisposed || job.status == JobStatus.cancelled) continue;

          if (audioPath != null) {
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
        _showQueueNotification();

        await Future.delayed(const Duration(milliseconds: 500));
      }

      await _stopSilentAudio();

      _currentJob = null;
      _isProcessing = false;
      _emitQueueStatus();

      debugPrint('[BgGenerator] ✓ Queue processing complete');

      if (_jobQueue.isEmpty && !_isDisposed) {
        _showSummaryNotification();
      } else {
        _showQueueNotification();
      }
    } catch (e) {
      debugPrint('[BgGenerator] Error: $e');
      _isProcessing = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showQueueNotification() {
    if (!_notificationsInitialized) return;

    try {
      final current = _currentJob;
      final remaining = _jobQueue.length;
      final completed = completedCount;
      final total = _allJobs.length;

      if (current == null && remaining == 0) {
        _cancelNotification(_NotificationIds.queue);
        return;
      }

      final title = _isPaused
          ? '⏸ Queue Paused'
          : '📚 Processing Audiobook Queue';

      final body = current != null
          ? 'Ch.${current.chapterIndex + 1}: ${current.chapterTitle}\n$completed/$total done • $remaining remaining'
          : '$completed/$total chapters ready';

      _notifications.show(
        _NotificationIds.queue,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'audiobook_queue',
            'Audiobook Queue',
            channelDescription: 'Overall queue progress',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: !_isPaused && _isProcessing,
            autoCancel: false,
            playSound: false,
            enableVibration: false,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'queue_toggle_pause',
                _isPaused ? 'Resume All' : 'Pause All',
                showsUserInterface: false,
                cancelNotification: false,
              ),
              AndroidNotificationAction(
                'queue_cancel_all',
                'Cancel All',
                showsUserInterface: false,
                cancelNotification: false,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            presentSound: false,
          ),
        ),
        payload: 'queue_control',
      );
    } catch (e) {
      debugPrint('[BgGenerator] Queue notification error: $e');
    }
  }

  void _showProgressNotification(GenerationJob job) {
    if (job.isSilent) return;
    if (!_notificationsInitialized) return;

    try {
      final percentage = (job.progress * 100).toInt();

      _notifications.show(
        _NotificationIds.chapter(job.chapterIndex),
        '📖 Chapter ${job.chapterIndex + 1}',
        '${job.chapterTitle} - $percentage%',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'audiobook_generation',
            'Audiobook Generation',
            channelDescription: 'Individual chapter progress',
            importance: Importance.low,
            priority: Priority.low,
            showProgress: true,
            maxProgress: 100,
            progress: percentage,
            ongoing: true,
            autoCancel: false,
            playSound: false,
            enableVibration: false,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'chapter_cancel_${job.id}',
                'Cancel This',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            presentSound: false,
          ),
        ),
        payload: job.id,
      );
    } catch (e) {
      debugPrint('[BgGenerator] Chapter notification error: $e');
    }
  }

  void _showCompletionNotification(GenerationJob job) {
    if (job.isSilent) return;
    if (!_notificationsInitialized) return;

    try {
      _notifications.show(
        _NotificationIds.chapter(job.chapterIndex),
        '✓ Chapter ${job.chapterIndex + 1} Ready',
        job.chapterTitle,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'audiobook_generation',
            'Audiobook Generation',
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        _cancelNotification(_NotificationIds.chapter(job.chapterIndex));
      });
    } catch (e) {
      debugPrint('[BgGenerator] Notification error: $e');
    }
  }

  void _showErrorNotification(GenerationJob job) {
    if (job.isSilent) return;
    if (!_notificationsInitialized) return;

    try {
      _notifications.show(
        _NotificationIds.chapter(job.chapterIndex),
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
    if (!_notificationsInitialized) return;

    try {
      final completed = completedCount;
      final failed = failedCount;
      final skipped = _allJobs.values
          .where((j) => j.status == JobStatus.skipped)
          .length;

      _notifications.show(
        _NotificationIds.summary,
        '📚 Audiobook Generation Complete',
        '✓ $completed ready${skipped > 0 ? ', ⊘ $skipped skipped' : ''}${failed > 0 ? ', ✗ $failed failed' : ''}',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'audiobook_generation',
            'Audiobook Generation',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'summary_clear',
                'Clear',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
        ),
        payload: 'summary',
      );

      _cancelNotification(_NotificationIds.queue);

      Future.delayed(const Duration(seconds: 5), () {
        _cancelNotification(_NotificationIds.summary);
      });
    } catch (e) {
      debugPrint('[BgGenerator] Notification error: $e');
    }
  }

  void _cancelNotification(int id) {
    try {
      _notifications.cancel(id);
    } catch (e) {
      debugPrint('[BgGenerator] Cancel notification error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTROL METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  void pause() {
    _isPaused = true;
    debugPrint('[BgGenerator] Queue paused');
    _emitQueueStatus();
    _showQueueNotification();
  }

  void resume() {
    _isPaused = false;
    debugPrint('[BgGenerator] Queue resumed');
    _showQueueNotification();
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

    _notifications.cancel(_NotificationIds.chapter(job.chapterIndex));

    debugPrint('[BgGenerator] Job cancelled: $jobId');

    _showQueueNotification();
  }

  void cancelAll() {
    for (final job in _allJobs.values) {
      if (job.status == JobStatus.queued ||
          job.status == JobStatus.generating) {
        job.status = JobStatus.cancelled;
        _notifications.cancel(_NotificationIds.chapter(job.chapterIndex));
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

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAM EMITTERS
  // ═══════════════════════════════════════════════════════════════════════════

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
          currentTask: null,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // KEEP ALIVE LOGIC (Silent Audio)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startSilentAudio() async {
    try {
      if (_silentPlayer.playing) return;

      debugPrint('[BgGenerator] Starting silent audio (Keep-Alive)...');

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      await session.setActive(true);

      _silentWavPath ??= await _createSilentWav();
      if (_silentWavPath != null && _silentWavPath!.isNotEmpty) {
        await _silentPlayer.setFilePath(_silentWavPath!);
        await _silentPlayer.setLoopMode(LoopMode.one);
        await _silentPlayer.setVolume(0.0);
        await _silentPlayer.play();
      }
    } catch (e) {
      debugPrint('[BgGenerator] Failed to start silent audio: $e');
    }
  }

  Future<void> _stopSilentAudio() async {
    try {
      if (!_silentPlayer.playing) return;
      debugPrint('[BgGenerator] Stopping silent audio...');
      await _silentPlayer.stop();
    } catch (e) {
      debugPrint('[BgGenerator] Failed to stop silent audio: $e');
    }
  }

  Future<String> _createSilentWav() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/silent_keep_alive.wav');

      if (!await file.exists()) {
        final totalDataLen = 8000;
        final totalFileSize = 36 + totalDataLen;

        final bytes = <int>[
          0x52, 0x49, 0x46, 0x46, // RIFF
          totalFileSize & 0xFF,
          (totalFileSize >> 8) & 0xFF,
          (totalFileSize >> 16) & 0xFF,
          (totalFileSize >> 24) & 0xFF,
          0x57, 0x41, 0x56, 0x45, // WAVE
          0x66, 0x6D, 0x74, 0x20, // fmt
          0x10, 0x00, 0x00, 0x00, // Subchunk1Size (16)
          0x01, 0x00, // AudioFormat (1 = PCM)
          0x01, 0x00, // NumChannels (1)
          0x40, 0x1F, 0x00, 0x00, // SampleRate (8000)
          0x40, 0x1F, 0x00, 0x00, // ByteRate (8000)
          0x01, 0x00, // BlockAlign (1)
          0x08, 0x00, // BitsPerSample (8)
          0x64, 0x61, 0x74, 0x61, // data
          totalDataLen & 0xFF,
          (totalDataLen >> 8) & 0xFF,
          (totalDataLen >> 16) & 0xFF,
          (totalDataLen >> 24) & 0xFF,
        ];

        bytes.addAll(List.filled(totalDataLen, 0x80));

        await file.writeAsBytes(bytes);
      }
      return file.path;
    } catch (e) {
      debugPrint('[BgGenerator] Error creating silent wav: $e');
      return '';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════════════════

  void dispose() {
    _isDisposed = true;
    _stopSilentAudio();
    _silentPlayer.dispose();
    cancelAll();
    _jobStatusController.close();
    _queueStatusController.close();
  }
}
