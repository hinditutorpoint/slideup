import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';

part 'download_task.g.dart';

/// Download task model for managing EPUB downloads
@HiveType(typeId: 9)
class DownloadTask extends Equatable {
  /// Unique task identifier
  @HiveField(0)
  final String id;

  /// Book ID this download is for
  @HiveField(1)
  final String bookId;

  /// Download URL
  @HiveField(2)
  final String url;

  /// Local file path for saving
  @HiveField(3)
  final String? localPath;

  /// File name
  @HiveField(4)
  final String fileName;

  /// Current download status
  @HiveField(5)
  final DownloadStatus status;

  /// Downloaded bytes
  @HiveField(6)
  final int downloadedBytes;

  /// Total file size in bytes
  @HiveField(7)
  final int totalBytes;

  /// Download progress (0.0 to 1.0)
  @HiveField(8)
  final double progress;

  /// Download speed in bytes per second
  @HiveField(9)
  final int speedBytesPerSecond;

  /// Time when download was created
  @HiveField(10)
  final DateTime createdAt;

  /// Time when download started
  @HiveField(11)
  final DateTime? startedAt;

  /// Time when download completed
  @HiveField(12)
  final DateTime? completedAt;

  /// Time when download was paused
  @HiveField(13)
  final DateTime? pausedAt;

  /// Error message if download failed
  @HiveField(14)
  final String? errorMessage;

  /// Error code if download failed
  @HiveField(15)
  final String? errorCode;

  /// Number of retry attempts
  @HiveField(16)
  final int retryCount;

  /// Maximum retry attempts allowed
  @HiveField(17)
  final int maxRetries;

  /// Priority (higher = more important)
  @HiveField(18)
  final int priority;

  /// HTTP headers for the request
  @HiveField(19)
  final Map<String, String>? headers;

  /// Resume data for partial downloads
  @HiveField(20)
  final String? resumeData;

  /// Supports resume/range requests
  @HiveField(21)
  final bool supportsResume;

  /// ETag for validation
  @HiveField(22)
  final String? etag;

  /// Last modified timestamp from server
  @HiveField(23)
  final DateTime? lastModified;

  /// Notification ID for this download
  @HiveField(24)
  final int? notificationId;

  /// Is running in background
  @HiveField(25)
  final bool isBackground;

  /// Additional metadata
  @HiveField(26)
  final Map<String, String>? metadata;

  const DownloadTask({
    required this.id,
    required this.bookId,
    required this.url,
    this.localPath,
    required this.fileName,
    this.status = DownloadStatus.idle,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.progress = 0.0,
    this.speedBytesPerSecond = 0,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.pausedAt,
    this.errorMessage,
    this.errorCode,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.priority = 0,
    this.headers,
    this.resumeData,
    this.supportsResume = true,
    this.etag,
    this.lastModified,
    this.notificationId,
    this.isBackground = false,
    this.metadata,
  });

  // ===========================================================================
  // COMPUTED PROPERTIES
  // ===========================================================================

  /// Check if download is active
  bool get isActive => status == DownloadStatus.downloading;

  /// Check if download can be paused
  bool get canPause => status.isPausable;

  /// Check if download can be resumed
  bool get canResume => status.isResumable && supportsResume;

  /// Check if download can be cancelled
  bool get canCancel => status.isCancellable;

  /// Check if download can be retried
  bool get canRetry => status.isRetryable && retryCount < maxRetries;

  /// Check if download is completed
  bool get isCompleted => status == DownloadStatus.completed;

  /// Check if download has failed
  bool get hasFailed => status == DownloadStatus.failed;

  /// Check if download is waiting
  bool get isWaiting => status == DownloadStatus.queued;

  /// Check if download is paused
  bool get isPaused => status == DownloadStatus.paused;

  /// Get remaining bytes
  int get remainingBytes => totalBytes > 0 ? totalBytes - downloadedBytes : 0;

  /// Get progress percentage
  int get progressPercentage => (progress * 100).round();

  /// Get formatted downloaded size
  String get formattedDownloadedSize => _formatBytes(downloadedBytes);

  /// Get formatted total size
  String get formattedTotalSize =>
      totalBytes > 0 ? _formatBytes(totalBytes) : 'Unknown';

  /// Get formatted speed
  String get formattedSpeed => '${_formatBytes(speedBytesPerSecond)}/s';

  /// Get estimated time remaining
  Duration? get estimatedTimeRemaining {
    if (speedBytesPerSecond <= 0 || remainingBytes <= 0) return null;
    return Duration(seconds: remainingBytes ~/ speedBytesPerSecond);
  }

  /// Get formatted time remaining
  String get formattedTimeRemaining {
    final remaining = estimatedTimeRemaining;
    if (remaining == null) return 'Calculating...';

    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    }
    if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
    }
    return '${remaining.inSeconds}s';
  }

  /// Get elapsed time
  Duration? get elapsedTime {
    if (startedAt == null) return null;
    final endTime = completedAt ?? pausedAt ?? DateTime.now();
    return endTime.difference(startedAt!);
  }

  /// Get formatted progress text
  String get progressText {
    if (totalBytes > 0) {
      return '$formattedDownloadedSize / $formattedTotalSize';
    }
    return formattedDownloadedSize;
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case DownloadStatus.idle:
        return 'Ready to download';
      case DownloadStatus.queued:
        return 'Waiting in queue';
      case DownloadStatus.downloading:
        return 'Downloading $progressPercentage%';
      case DownloadStatus.paused:
        return 'Paused at $progressPercentage%';
      case DownloadStatus.completed:
        return 'Download complete';
      case DownloadStatus.failed:
        return errorMessage ?? 'Download failed';
      case DownloadStatus.cancelled:
        return 'Download cancelled';
    }
  }

  // ===========================================================================
  // FACTORY CONSTRUCTORS
  // ===========================================================================

  /// Create from JSON
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    try {
      return DownloadTask(
        id: json['id'] as String? ?? _generateId(),
        bookId: json['bookId'] as String? ?? '',
        url: json['url'] as String? ?? '',
        localPath: json['localPath'] as String?,
        fileName: json['fileName'] as String? ?? 'download.epub',
        status: DownloadStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => DownloadStatus.idle,
        ),
        downloadedBytes: json['downloadedBytes'] as int? ?? 0,
        totalBytes: json['totalBytes'] as int? ?? 0,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        speedBytesPerSecond: json['speedBytesPerSecond'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        startedAt: json['startedAt'] != null
            ? DateTime.tryParse(json['startedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse(json['completedAt'] as String)
            : null,
        pausedAt: json['pausedAt'] != null
            ? DateTime.tryParse(json['pausedAt'] as String)
            : null,
        errorMessage: json['errorMessage'] as String?,
        errorCode: json['errorCode'] as String?,
        retryCount: json['retryCount'] as int? ?? 0,
        maxRetries: json['maxRetries'] as int? ?? 3,
        priority: json['priority'] as int? ?? 0,
        headers: (json['headers'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ),
        resumeData: json['resumeData'] as String?,
        supportsResume: json['supportsResume'] as bool? ?? true,
        etag: json['etag'] as String?,
        lastModified: json['lastModified'] != null
            ? DateTime.tryParse(json['lastModified'] as String)
            : null,
        notificationId: json['notificationId'] as int?,
        isBackground: json['isBackground'] as bool? ?? false,
        metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ),
      );
    } catch (e) {
      return DownloadTask.create(
        bookId: json['bookId'] as String? ?? '',
        url: json['url'] as String? ?? '',
        fileName: json['fileName'] as String? ?? 'download.epub',
      );
    }
  }

  /// Create a new download task
  factory DownloadTask.create({
    required String bookId,
    required String url,
    required String fileName,
    String? localPath,
    int priority = 0,
    Map<String, String>? headers,
    Map<String, String>? metadata,
  }) {
    return DownloadTask(
      id: _generateId(),
      bookId: bookId,
      url: url,
      fileName: fileName,
      localPath: localPath,
      priority: priority,
      headers: headers,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
  }

  // ===========================================================================
  // SERIALIZATION
  // ===========================================================================

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'url': url,
      'localPath': localPath,
      'fileName': fileName,
      'status': status.name,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'progress': progress,
      'speedBytesPerSecond': speedBytesPerSecond,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'pausedAt': pausedAt?.toIso8601String(),
      'errorMessage': errorMessage,
      'errorCode': errorCode,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'priority': priority,
      'headers': headers,
      'resumeData': resumeData,
      'supportsResume': supportsResume,
      'etag': etag,
      'lastModified': lastModified?.toIso8601String(),
      'notificationId': notificationId,
      'isBackground': isBackground,
      'metadata': metadata,
    };
  }

  // ===========================================================================
  // COPY WITH
  // ===========================================================================

  DownloadTask copyWith({
    String? id,
    String? bookId,
    String? url,
    String? localPath,
    String? fileName,
    DownloadStatus? status,
    int? downloadedBytes,
    int? totalBytes,
    double? progress,
    int? speedBytesPerSecond,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? pausedAt,
    String? errorMessage,
    String? errorCode,
    int? retryCount,
    int? maxRetries,
    int? priority,
    Map<String, String>? headers,
    String? resumeData,
    bool? supportsResume,
    String? etag,
    DateTime? lastModified,
    int? notificationId,
    bool? isBackground,
    Map<String, String>? metadata,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      progress: progress ?? this.progress,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      errorCode: errorCode ?? this.errorCode,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      priority: priority ?? this.priority,
      headers: headers ?? this.headers,
      resumeData: resumeData ?? this.resumeData,
      supportsResume: supportsResume ?? this.supportsResume,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      notificationId: notificationId ?? this.notificationId,
      isBackground: isBackground ?? this.isBackground,
      metadata: metadata ?? this.metadata,
    );
  }

  // ===========================================================================
  // STATE TRANSITIONS
  // ===========================================================================

  /// Start the download
  DownloadTask start() {
    return copyWith(
      status: DownloadStatus.downloading,
      startedAt: DateTime.now(),
      errorMessage: null,
      errorCode: null,
    );
  }

  /// Pause the download
  DownloadTask pause() {
    return copyWith(
      status: DownloadStatus.paused,
      pausedAt: DateTime.now(),
      speedBytesPerSecond: 0,
    );
  }

  /// Resume the download
  DownloadTask resume() {
    return copyWith(
      status: DownloadStatus.downloading,
      startedAt: DateTime.now(),
    );
  }

  /// Cancel the download
  DownloadTask cancel() {
    return copyWith(status: DownloadStatus.cancelled, speedBytesPerSecond: 0);
  }

  /// Complete the download
  DownloadTask complete(String localPath) {
    return copyWith(
      status: DownloadStatus.completed,
      localPath: localPath,
      progress: 1.0,
      completedAt: DateTime.now(),
      speedBytesPerSecond: 0,
    );
  }

  /// Fail the download
  DownloadTask fail(String message, [String? code]) {
    return copyWith(
      status: DownloadStatus.failed,
      errorMessage: message,
      errorCode: code,
      speedBytesPerSecond: 0,
    );
  }

  /// Queue the download
  DownloadTask queue() {
    return copyWith(status: DownloadStatus.queued);
  }

  /// Retry the download
  DownloadTask retry() {
    return copyWith(
      status: DownloadStatus.queued,
      retryCount: retryCount + 1,
      errorMessage: null,
      errorCode: null,
    );
  }

  /// Update progress
  DownloadTask updateProgress({
    required int downloadedBytes,
    required int totalBytes,
    int? speedBytesPerSecond,
  }) {
    final newProgress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
    return copyWith(
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      progress: newProgress.clamp(0.0, 1.0),
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  static String _generateId() {
    return 'download_${DateTime.now().millisecondsSinceEpoch}_${_randomString(6)}';
  }

  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    return List.generate(
      length,
      (index) => chars[(random + index * 7) % chars.length],
    ).join();
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  List<Object?> get props => [
    id,
    bookId,
    url,
    status,
    progress,
    downloadedBytes,
    totalBytes,
  ];

  @override
  String toString() =>
      'DownloadTask(id: $id, status: $status, progress: $progressPercentage%)';
}

/// Download queue manager
class DownloadQueue {
  final List<DownloadTask> _tasks = [];
  final int maxConcurrent;

  DownloadQueue({this.maxConcurrent = 3});

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.isActive).toList();
  List<DownloadTask> get queuedTasks =>
      _tasks.where((t) => t.isWaiting).toList();
  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.isCompleted).toList();
  List<DownloadTask> get failedTasks =>
      _tasks.where((t) => t.hasFailed).toList();

  int get activeCount => activeTasks.length;
  bool get hasCapacity => activeCount < maxConcurrent;
  bool get isEmpty => _tasks.isEmpty;
  int get length => _tasks.length;

  /// Add task to queue
  void add(DownloadTask task) {
    debugPrint('Starting download for URL task: que added');
    _tasks.add(task);
    _sortByPriority();
  }

  /// Remove task from queue
  bool remove(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks.removeAt(index);
      return true;
    }
    return false;
  }

  /// Get task by ID
  DownloadTask? getById(String taskId) {
    try {
      return _tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return null;
    }
  }

  /// Get task by book ID
  DownloadTask? getByBookId(String bookId) {
    try {
      return _tasks.firstWhere((t) => t.bookId == bookId);
    } catch (_) {
      return null;
    }
  }

  /// Update task
  void update(DownloadTask task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
    }
  }

  /// Get next task to start
  DownloadTask? getNextTask() {
    if (!hasCapacity) {
      debugPrint('📋 getNextTask: No capacity');
      return null;
    }

    try {
      final task = _tasks.firstWhere((t) => t.status == DownloadStatus.queued);
      debugPrint('📋 getNextTask: Found ${task.id}');
      return task;
    } catch (_) {
      debugPrint(
        '📋 getNextTask: No queued tasks. Tasks: ${_tasks.map((t) => '${t.id}:${t.status}').join(', ')}',
      );
      return null;
    }
  }

  /// Clear completed tasks
  void clearCompleted() {
    _tasks.removeWhere((t) => t.isCompleted);
  }

  /// Clear failed tasks
  void clearFailed() {
    _tasks.removeWhere((t) => t.hasFailed);
  }

  /// Clear all tasks
  void clear() {
    _tasks.clear();
  }

  /// Sort by priority (higher priority first)
  void _sortByPriority() {
    _tasks.sort((a, b) {
      // Active downloads first
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;

      // Then by priority
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;

      // Then by creation time
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  /// Get overall progress
  double get overallProgress {
    if (_tasks.isEmpty) return 0.0;
    final total = _tasks.fold<double>(0, (sum, t) => sum + t.progress);
    return total / _tasks.length;
  }

  /// Get total downloaded bytes
  int get totalDownloadedBytes =>
      _tasks.fold<int>(0, (sum, t) => sum + t.downloadedBytes);

  /// Get total bytes
  int get totalBytes => _tasks.fold<int>(0, (sum, t) => sum + t.totalBytes);
}

/// Download progress update
class DownloadProgress {
  final String taskId;
  final int downloadedBytes;
  final int totalBytes;
  final int speedBytesPerSecond;
  final double progress;
  final DateTime timestamp;

  DownloadProgress({
    required this.taskId,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedBytesPerSecond,
  }) : progress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0,
       timestamp = DateTime.now();

  int get progressPercentage => (progress * 100).round();

  Duration? get estimatedTimeRemaining {
    if (speedBytesPerSecond <= 0) return null;
    final remaining = totalBytes - downloadedBytes;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: remaining ~/ speedBytesPerSecond);
  }
}

/// Download event types
enum DownloadEventType {
  started,
  progress,
  paused,
  resumed,
  completed,
  failed,
  cancelled,
  queued,
  retrying,
}

/// Download event
class DownloadEvent {
  final DownloadEventType type;
  final DownloadTask task;
  final DownloadProgress? progress;
  final String? message;
  final DateTime timestamp;

  DownloadEvent({
    required this.type,
    required this.task,
    this.progress,
    this.message,
  }) : timestamp = DateTime.now();

  factory DownloadEvent.started(DownloadTask task) {
    return DownloadEvent(type: DownloadEventType.started, task: task);
  }

  factory DownloadEvent.progress(DownloadTask task, DownloadProgress progress) {
    return DownloadEvent(
      type: DownloadEventType.progress,
      task: task,
      progress: progress,
    );
  }

  factory DownloadEvent.completed(DownloadTask task) {
    return DownloadEvent(type: DownloadEventType.completed, task: task);
  }

  factory DownloadEvent.failed(DownloadTask task, String message) {
    return DownloadEvent(
      type: DownloadEventType.failed,
      task: task,
      message: message,
    );
  }

  factory DownloadEvent.paused(DownloadTask task) {
    return DownloadEvent(type: DownloadEventType.paused, task: task);
  }

  factory DownloadEvent.resumed(DownloadTask task) {
    return DownloadEvent(type: DownloadEventType.resumed, task: task);
  }

  factory DownloadEvent.cancelled(DownloadTask task) {
    return DownloadEvent(type: DownloadEventType.cancelled, task: task);
  }

  factory DownloadEvent.removed(DownloadTask task) {
    return DownloadEvent(type: DownloadEventType.queued, task: task);
  }
}
