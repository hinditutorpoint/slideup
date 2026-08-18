import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database_helper.dart';
import '../services/download_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../features/documents/models/download_task.dart';

// Service providers
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService.instance;
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  final service = DownloadService(
    dbHelper: dbHelper,
    notificationService: notificationService,
  );

  ref.onDispose(() => service.dispose());

  return service;
});

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

// Downloads state
class DownloadsState {
  final List<DownloadTask> downloads;
  final bool isLoading;
  final String? error;

  const DownloadsState({
    this.downloads = const [],
    this.isLoading = false,
    this.error,
  });

  DownloadsState copyWith({
    List<DownloadTask>? downloads,
    bool? isLoading,
    String? error,
  }) {
    return DownloadsState(
      downloads: downloads ?? this.downloads,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<DownloadTask> get activeDownloads => downloads
      .where((d) => d.isActive || d.status == DownloadStatus.paused)
      .toList();

  List<DownloadTask> get completedDownloads =>
      downloads.where((d) => d.status == DownloadStatus.completed).toList();

  List<DownloadTask> get failedDownloads =>
      downloads.where((d) => d.status == DownloadStatus.failed).toList();
}

// Downloads notifier
class DownloadsNotifier extends Notifier<DownloadsState> {
  late final DownloadService _downloadService;
  late final PermissionService _permissionService;
  late final NotificationService _notificationService;

  StreamSubscription<List<DownloadTask>>? _subscription;

  @override
  DownloadsState build() {
    _downloadService = ref.watch(downloadServiceProvider);
    _permissionService = ref.watch(permissionServiceProvider);
    _notificationService = ref.watch(notificationServiceProvider);

    _initialize();

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return const DownloadsState();
  }

  Future<void> _initialize() async {
    await _notificationService.initialize();
    await loadDownloads();

    _subscription?.cancel();
    _subscription = _downloadService.allDownloadsStream.listen((downloads) {
      state = state.copyWith(downloads: downloads);
    });
  }

  Future<void> loadDownloads() async {
    state = state.copyWith(isLoading: true);

    try {
      final downloads = await _downloadService.getAllDownloads();
      state = state.copyWith(
        downloads: downloads,
        isLoading: false,
        error: null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load downloads',
      );
    }
  }

  Future<DownloadTask?> startDownload({
    required String identifier,
    required String title,
    required String url,
    required String mediaType,
    String? thumbnailUrl,
  }) async {
    try {
      final hasPermission = await _permissionService
          .requestAllDownloadPermissions();

      if (!hasPermission) {
        state = state.copyWith(error: 'Storage permission denied');
        return null;
      }

      final task = await _downloadService.startDownload(
        identifier: identifier,
        title: title,
        url: url,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
      );

      await loadDownloads();
      return task;
    } catch (_) {
      state = state.copyWith(error: 'Failed to start download');
      return null;
    }
  }

  Future<void> pauseDownload(String taskId) async {
    await _safeCall(
      () => _downloadService.pauseDownload(taskId),
      'Failed to pause download',
    );
  }

  Future<void> resumeDownload(String taskId) async {
    await _safeCall(
      () => _downloadService.resumeDownload(taskId),
      'Failed to resume download',
    );
  }

  Future<void> cancelDownload(String taskId) async {
    await _safeCall(
      () => _downloadService.cancelDownload(taskId),
      'Failed to cancel download',
    );
  }

  Future<void> retryDownload(String taskId) async {
    await _safeCall(
      () => _downloadService.retryDownload(taskId),
      'Failed to retry download',
    );
  }

  Future<void> deleteDownload(String taskId, {bool deleteFile = false}) async {
    await _safeCall(
      () => _downloadService.deleteDownload(taskId, deleteFile: deleteFile),
      'Failed to delete download',
    );

    await loadDownloads();
  }

  Future<void> updateTask(DownloadTask task) async {
    await _safeCall(
      () => _downloadService.updateTask(task),
      'Failed to update download task',
    );
    await loadDownloads();
  }

  Future<DownloadTask?> getDownloadByIdentifier(String identifier) async {
    return _downloadService.getDownloadByIdentifier(identifier);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> _safeCall(
    Future<void> Function() action,
    String errorMessage,
  ) async {
    try {
      await action();
    } catch (_) {
      state = state.copyWith(error: errorMessage);
    }
  }
}

final downloadsProvider = NotifierProvider<DownloadsNotifier, DownloadsState>(
  DownloadsNotifier.new,
);

// Individual download progress provider
final downloadProgressProvider = StreamProvider.family<DownloadTask, String>((
  ref,
  taskId,
) {
  final downloadService = ref.watch(downloadServiceProvider);
  return downloadService.getProgressStream(taskId);
});

// Check if item is downloaded provider
final isDownloadedProvider = FutureProvider.family<DownloadTask?, String>((
  ref,
  identifier,
) async {
  final downloadService = ref.watch(downloadServiceProvider);
  return await downloadService.getDownloadByIdentifier(identifier);
});
