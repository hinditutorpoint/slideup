import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/tts_request.dart';

enum TtsTaskType { speak, speakPage, speakSelection, preGenerate }

enum TtsTaskStatus {
  queued,
  processing,
  ready,
  playing,
  completed,
  failed,
  cancelled,
}

class TtsTask {
  final String id;
  final TtsTaskType type;
  final String text;
  final String? bookId;
  final int? pageNumber;
  final double speed;
  final int speakerId;
  final bool showUi;
  final bool useCache;
  final DateTime createdAt;

  TtsTaskStatus status;
  String? error;
  String? audioPath;
  Uint8List? audioData;
  double progress;
  Duration? duration;

  // Callbacks (use existing TtsPlaybackState from tts_request.dart)
  final Function(TtsPlaybackState)? onStateChanged;
  final Function(double)? onProgress;
  final Function(String)? onError;
  final VoidCallback? onCompleted;

  TtsTask({
    required this.id,
    required this.type,
    required this.text,
    this.bookId,
    this.pageNumber,
    this.speed = 1.0,
    this.speakerId = 0,
    this.showUi = true,
    this.useCache = true,
    this.status = TtsTaskStatus.queued,
    this.progress = 0,
    this.onStateChanged,
    this.onProgress,
    this.onError,
    this.onCompleted,
  }) : createdAt = DateTime.now();

  String get displayName {
    if (pageNumber != null) return 'Page ${pageNumber! + 1}';
    if (text.length > 30) return '${text.substring(0, 30)}...';
    return text;
  }

  String get shortText {
    if (text.length > 50) return '${text.substring(0, 50)}...';
    return text;
  }

  /// Convert task status to TtsPlaybackState
  TtsPlaybackState get playbackState {
    switch (status) {
      case TtsTaskStatus.queued:
        return TtsPlaybackState.loading;
      case TtsTaskStatus.processing:
        return TtsPlaybackState.generating;
      case TtsTaskStatus.ready:
        return TtsPlaybackState.idle;
      case TtsTaskStatus.playing:
        return TtsPlaybackState.playing;
      case TtsTaskStatus.completed:
        return TtsPlaybackState.completed;
      case TtsTaskStatus.failed:
        return TtsPlaybackState.error;
      case TtsTaskStatus.cancelled:
        return TtsPlaybackState.idle;
    }
  }
}

enum TtsNotificationType {
  queued,
  processing,
  ready,
  playing,
  completed,
  error,
  cancelled,
}

class TtsQueueNotification {
  final TtsNotificationType type;
  final String message;
  final String? taskId;
  final TtsTask? task;
  final DateTime timestamp;

  TtsQueueNotification({
    required this.type,
    required this.message,
    this.taskId,
    this.task,
  }) : timestamp = DateTime.now();
}

class QueueStatus {
  final int queueLength;
  final int processingCount;
  final int readyCount;
  final int completedCount;
  final bool isProcessing;
  final String? currentTaskId;
  final TtsTask? currentTask;

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

class TtsQueueManager {
  static final TtsQueueManager _instance = TtsQueueManager._internal();
  factory TtsQueueManager() => _instance;
  TtsQueueManager._internal();

  // Queue and tasks
  final Queue<TtsTask> _queue = Queue();
  final Map<String, TtsTask> _allTasks = {};
  final List<TtsTask> _readyTasks = [];
  TtsTask? _currentTask;

  // State
  bool _isProcessing = false;
  bool _isDisposed = false;
  bool _isPaused = false;

  // Stream controllers
  final _taskStatusController = StreamController<TtsTask>.broadcast();
  final _queueStatusController = StreamController<QueueStatus>.broadcast();
  final _notificationController =
      StreamController<TtsQueueNotification>.broadcast();

  // Streams
  Stream<TtsTask> get taskStream => _taskStatusController.stream;
  Stream<QueueStatus> get queueStream => _queueStatusController.stream;
  Stream<TtsQueueNotification> get notificationStream =>
      _notificationController.stream;

  // Callbacks - set by TtsController
  Future<String?> Function(TtsTask task)? onGenerateAudio;
  Future<void> Function(TtsTask task, String audioPath)? onPlayAudio;
  Function(TtsTask task)? onTaskReady;
  Function(TtsTask task)? onTaskFailed;

  // Getters
  int get queueLength => _queue.length;
  int get readyCount => _readyTasks.length;
  bool get isProcessing => _isProcessing;
  bool get isPaused => _isPaused;
  TtsTask? get currentTask => _currentTask;
  List<TtsTask> get readyTasks => List.unmodifiable(_readyTasks);
  List<TtsTask> get allTasks => _allTasks.values.toList();
  List<TtsTask> get pendingTasks => _queue.toList();

  /// Add task to queue (returns immediately - non-blocking)
  String addTask(TtsTask task) {
    if (_isDisposed) return '';

    _allTasks[task.id] = task;
    _queue.add(task);

    _emitTaskStatus(task);
    _emitQueueStatus();

    _notify(
      TtsQueueNotification(
        type: TtsNotificationType.queued,
        message: 'Added: ${task.displayName}',
        taskId: task.id,
        task: task,
      ),
    );

    debugPrint('[TtsQueue] Task queued: ${task.id} (queue: ${_queue.length})');

    // Start processing if not already
    if (!_isProcessing && !_isPaused) {
      _processQueue();
    }

    return task.id;
  }

  /// Create and add a speak task
  String speak({
    required String text,
    String? bookId,
    int? pageNumber,
    double speed = 1.0,
    int speakerId = 0,
    bool showUi = true,
    bool useCache = true,
    Function(TtsPlaybackState)? onStateChanged,
    Function(double)? onProgress,
    Function(String)? onError,
    VoidCallback? onCompleted,
  }) {
    final task = TtsTask(
      id: _generateTaskId(text),
      type: pageNumber != null ? TtsTaskType.speakPage : TtsTaskType.speak,
      text: text,
      bookId: bookId,
      pageNumber: pageNumber,
      speed: speed,
      speakerId: speakerId,
      showUi: showUi,
      useCache: useCache,
      onStateChanged: onStateChanged,
      onProgress: onProgress,
      onError: onError,
      onCompleted: onCompleted,
    );

    return addTask(task);
  }

  String _generateTaskId(String text) {
    return 'tts_${DateTime.now().millisecondsSinceEpoch}_${text.hashCode.abs()}';
  }

  /// Get task by ID
  TtsTask? getTask(String taskId) => _allTasks[taskId];

  /// Cancel a specific task
  void cancelTask(String taskId) {
    final task = _allTasks[taskId];
    if (task == null) return;

    task.status = TtsTaskStatus.cancelled;
    _queue.removeWhere((t) => t.id == taskId);
    _readyTasks.removeWhere((t) => t.id == taskId);

    task.onStateChanged?.call(TtsPlaybackState.idle);
    task.onError?.call('Cancelled');

    _emitTaskStatus(task);
    _emitQueueStatus();

    _notify(
      TtsQueueNotification(
        type: TtsNotificationType.cancelled,
        message: 'Cancelled: ${task.displayName}',
        taskId: taskId,
        task: task,
      ),
    );

    debugPrint('[TtsQueue] Task cancelled: $taskId');
  }

  /// Cancel all tasks
  void cancelAll() {
    for (final task in _allTasks.values) {
      if (task.status == TtsTaskStatus.queued ||
          task.status == TtsTaskStatus.processing) {
        task.status = TtsTaskStatus.cancelled;
        task.onStateChanged?.call(TtsPlaybackState.idle);
        task.onError?.call('Cancelled');
        _emitTaskStatus(task);
      }
    }

    _queue.clear();
    _readyTasks.clear();
    _currentTask = null;
    _isProcessing = false;

    _emitQueueStatus();
    debugPrint('[TtsQueue] All tasks cancelled');
  }

  /// Pause queue processing
  void pauseQueue() {
    _isPaused = true;
    debugPrint('[TtsQueue] Queue paused');
  }

  /// Resume queue processing
  void resumeQueue() {
    _isPaused = false;
    if (!_isProcessing && _queue.isNotEmpty) {
      _processQueue();
    }
    debugPrint('[TtsQueue] Queue resumed');
  }

  /// Clear completed/failed/cancelled tasks
  void clearFinishedTasks() {
    _allTasks.removeWhere(
      (id, task) =>
          task.status == TtsTaskStatus.completed ||
          task.status == TtsTaskStatus.failed ||
          task.status == TtsTaskStatus.cancelled,
    );
    _readyTasks.clear();
    _emitQueueStatus();
  }

  /// Play a ready task
  Future<void> playReadyTask(String taskId) async {
    final task = _allTasks[taskId];
    if (task == null ||
        task.status != TtsTaskStatus.ready ||
        task.audioPath == null) {
      debugPrint(
        '[TtsQueue] Cannot play task: $taskId (status: ${task?.status})',
      );
      return;
    }

    task.status = TtsTaskStatus.playing;
    task.onStateChanged?.call(TtsPlaybackState.playing);
    _emitTaskStatus(task);

    _notify(
      TtsQueueNotification(
        type: TtsNotificationType.playing,
        message: 'Playing: ${task.displayName}',
        taskId: taskId,
        task: task,
      ),
    );

    try {
      await onPlayAudio?.call(task, task.audioPath!);

      task.status = TtsTaskStatus.completed;
      task.onStateChanged?.call(TtsPlaybackState.completed);
      _readyTasks.remove(task);
      task.onCompleted?.call();

      _notify(
        TtsQueueNotification(
          type: TtsNotificationType.completed,
          message: 'Completed: ${task.displayName}',
          taskId: taskId,
          task: task,
        ),
      );
    } catch (e) {
      task.status = TtsTaskStatus.failed;
      task.error = e.toString();
      task.onStateChanged?.call(TtsPlaybackState.error);
      task.onError?.call(e.toString());

      _notify(
        TtsQueueNotification(
          type: TtsNotificationType.error,
          message: 'Playback failed: ${task.displayName}',
          taskId: taskId,
          task: task,
        ),
      );
    }

    _emitTaskStatus(task);
    _emitQueueStatus();
  }

  /// Process queue in background
  Future<void> _processQueue() async {
    if (_isProcessing || _isDisposed || _isPaused) return;
    if (_queue.isEmpty) {
      _emitQueueStatus();
      return;
    }

    _isProcessing = true;
    _emitQueueStatus();

    while (_queue.isNotEmpty && !_isDisposed && !_isPaused) {
      final task = _queue.removeFirst();

      if (task.status == TtsTaskStatus.cancelled) continue;

      _currentTask = task;
      task.status = TtsTaskStatus.processing;
      task.onStateChanged?.call(TtsPlaybackState.generating);

      _emitTaskStatus(task);
      _emitQueueStatus();

      _notify(
        TtsQueueNotification(
          type: TtsNotificationType.processing,
          message: 'Generating: ${task.displayName}',
          taskId: task.id,
          task: task,
        ),
      );

      try {
        debugPrint('[TtsQueue] Processing: ${task.id}');

        // Generate audio using callback
        final audioPath = await onGenerateAudio?.call(task);

        if (_isDisposed || task.status == TtsTaskStatus.cancelled) continue;

        if (audioPath != null && audioPath.isNotEmpty) {
          task.status = TtsTaskStatus.ready;
          task.audioPath = audioPath;
          _readyTasks.add(task);

          task.onStateChanged?.call(TtsPlaybackState.idle);
          _emitTaskStatus(task);

          _notify(
            TtsQueueNotification(
              type: TtsNotificationType.ready,
              message: 'Ready: ${task.displayName}',
              taskId: task.id,
              task: task,
            ),
          );

          onTaskReady?.call(task);

          // Auto-play if showUi is true and this was the only task
          if (task.showUi && _queue.isEmpty) {
            debugPrint('[TtsQueue] Auto-playing task: ${task.id}');
            await playReadyTask(task.id);
          }
        } else {
          throw Exception('Failed to generate audio');
        }
      } catch (e) {
        debugPrint('[TtsQueue] Task failed: ${task.id} - $e');
        task.status = TtsTaskStatus.failed;
        task.error = e.toString();
        task.onStateChanged?.call(TtsPlaybackState.error);
        task.onError?.call(e.toString());

        _emitTaskStatus(task);

        _notify(
          TtsQueueNotification(
            type: TtsNotificationType.error,
            message: 'Failed: ${task.displayName}',
            taskId: task.id,
            task: task,
          ),
        );

        onTaskFailed?.call(task);
      }

      _emitQueueStatus();
    }

    _currentTask = null;
    _isProcessing = false;
    _emitQueueStatus();
  }

  void _emitTaskStatus(TtsTask task) {
    if (!_taskStatusController.isClosed) {
      _taskStatusController.add(task);
    }
  }

  void _emitQueueStatus() {
    if (!_queueStatusController.isClosed) {
      _queueStatusController.add(
        QueueStatus(
          queueLength: _queue.length,
          processingCount: _currentTask != null ? 1 : 0,
          readyCount: _readyTasks.length,
          completedCount: _allTasks.values
              .where((t) => t.status == TtsTaskStatus.completed)
              .length,
          isProcessing: _isProcessing,
          currentTaskId: _currentTask?.id,
          currentTask: _currentTask,
        ),
      );
    }
  }

  void _notify(TtsQueueNotification notification) {
    if (!_notificationController.isClosed) {
      _notificationController.add(notification);
    }
  }

  void dispose() {
    _isDisposed = true;
    cancelAll();
    _taskStatusController.close();
    _queueStatusController.close();
    _notificationController.close();
  }

  void reset() {
    _isDisposed = false;
    _isPaused = false;
    _allTasks.clear();
    _readyTasks.clear();
    _queue.clear();
    _currentTask = null;
    _isProcessing = false;
  }
}
