import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/video_edit_settings.dart';
import '../services/background_export_service.dart';
import '../services/timeline_export_service.dart';
import 'project_provider.dart';
import 'package:slideup/core/utils/safe_async.dart';

// ═══════════════════════════════════════════════════════
// ✅ EXPORT STATE
// ═══════════════════════════════════════════════════════

@immutable
class ExportState {
  final ExportStatus status;
  final double progress;
  final String? message;
  final String? outputPath;
  final String? error;
  final Duration elapsed;
  final Duration? estimated;
  final List<ExportJob> recentExports;
  final ExportJob? currentJob;

  const ExportState({
    this.status = ExportStatus.idle,
    this.progress = 0.0,
    this.message,
    this.outputPath,
    this.error,
    this.elapsed = Duration.zero,
    this.estimated,
    this.recentExports = const [],
    this.currentJob,
  });

  bool get isExporting =>
      status == ExportStatus.preparing ||
      status == ExportStatus.processing ||
      status == ExportStatus.encoding ||
      status == ExportStatus.saving;

  bool get isCompleted => status == ExportStatus.completed;
  bool get isFailed => status == ExportStatus.failed;
  bool get isCancelled => status == ExportStatus.cancelled;

  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  String get etaFormatted {
    if (estimated == null) return '--:--';
    final minutes = estimated!.inMinutes;
    final seconds = estimated!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  ExportState copyWith({
    ExportStatus? status,
    double? progress,
    String? message,
    String? outputPath,
    String? error,
    Duration? elapsed,
    Duration? estimated,
    List<ExportJob>? recentExports,
    ExportJob? currentJob,
  }) {
    return ExportState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      outputPath: outputPath ?? this.outputPath,
      error: error,
      elapsed: elapsed ?? this.elapsed,
      estimated: estimated ?? this.estimated,
      recentExports: recentExports ?? this.recentExports,
      currentJob: currentJob ?? this.currentJob,
    );
  }

  ExportState reset() {
    return ExportState(recentExports: recentExports);
  }
}

// ═══════════════════════════════════════════════════════
// ✅ EXPORT NOTIFIER
// ═══════════════════════════════════════════════════════

class ExportNotifier extends StateNotifier<ExportState> {
  ExportNotifier(
    this._backgroundExportService,
    this._timelineExportService,
    this._projectNotifier,
  ) : super(const ExportState()) {
    _init();
  }

  final BackgroundExportService _backgroundExportService;
  final TimelineExportService _timelineExportService;
  final ProjectNotifier _projectNotifier;

  void _init() {
    // Listen to progress stream
    _backgroundExportService.progressStream.listen((progress) {
      state = state.copyWith(
        status: progress.status,
        progress: progress.progress,
        message: progress.message,
        outputPath: progress.outputPath,
        error: progress.error,
        elapsed: progress.elapsed,
        estimated: progress.estimated,
      );
    });

    // Listen to jobs stream
    _backgroundExportService.jobsStream.listen((jobs) {
      state = state.copyWith(recentExports: jobs);
    });

    // Load initial exports
    _loadRecentExports();
  }

  Future<void> _loadRecentExports() async {
    final jobs = await _backgroundExportService.getAllJobs();
    state = state.copyWith(recentExports: jobs);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ START EXPORT
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> startExport({
    ExportPreset? preset,
    bool runInBackground = false,
  }) async {
    final project = _projectNotifier.state.currentProject;
    if (project == null) {
      return Result.failure(Exception('No project to export'));
    }

    state = state.copyWith(
      status: ExportStatus.preparing,
      progress: 0.0,
      message: 'Preparing export...',
      error: null,
      outputPath: null,
    );

    final projectToExport = preset != null
        ? project.copyWith(exportPreset: preset)
        : project;

    final result = await _backgroundExportService.startExport(
      project: projectToExport,
      runInBackground: runInBackground,
      onProgress: (progress) {
        state = state.copyWith(
          status: progress.status,
          progress: progress.progress,
          message: progress.message,
          elapsed: progress.elapsed,
          estimated: progress.estimated,
        );
      },
    );

    if (result.isSuccess) {
      state = state.copyWith(
        status: ExportStatus.completed,
        progress: 1.0,
        message: 'Export completed!',
        outputPath: result.requireData,
      );
      await _loadRecentExports();
    } else {
      state = state.copyWith(
        status: ExportStatus.failed,
        error: result.error.toString(),
        message: 'Export failed',
      );
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ START TIMELINE EXPORT (with overlays)
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> startTimelineExport({
    ExportPreset? preset,
    bool includeTextOverlays = true,
    bool includeImageOverlays = true,
    bool includeAudioTracks = true,
    bool applyColorGrading = true,
  }) async {
    final project = _projectNotifier.state.currentProject;
    if (project == null) {
      return Result.failure(Exception('No project to export'));
    }

    state = state.copyWith(
      status: ExportStatus.preparing,
      progress: 0.0,
      message: 'Preparing timeline export...',
      error: null,
      outputPath: null,
    );

    final config = TimelineExportConfig(
      project: preset != null
          ? project.copyWith(exportPreset: preset)
          : project,
      preset: preset ?? project.exportPreset,
      includeTextOverlays: includeTextOverlays,
      includeImageOverlays: includeImageOverlays,
      includeAudioTracks: includeAudioTracks,
      applyColorGrading: applyColorGrading,
    );

    final result = await _timelineExportService.exportTimeline(
      config: config,
      onProgress: (progress) {
        state = state.copyWith(progress: progress);
      },
      onStageChange: (stage) {
        state = state.copyWith(
          message: stage.message,
          progress: stage.progress,
        );
      },
    );

    if (result.isSuccess) {
      state = state.copyWith(
        status: ExportStatus.completed,
        progress: 1.0,
        message: 'Export completed!',
        outputPath: result.requireData,
      );
      await _loadRecentExports();
    } else {
      state = state.copyWith(
        status: ExportStatus.failed,
        error: result.error.toString(),
        message: 'Export failed',
      );
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CANCEL EXPORT
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> cancelExport() async {
    final result = await _backgroundExportService.cancelExport();

    if (result.isSuccess) {
      state = state.copyWith(
        status: ExportStatus.cancelled,
        message: 'Export cancelled',
      );
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DELETE EXPORT
  // ═══════════════════════════════════════════════════════

  Future<void> deleteExport(String jobId) async {
    await _backgroundExportService.deleteJob(jobId);
    await _loadRecentExports();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ RESET
  // ═══════════════════════════════════════════════════════

  void reset() {
    state = state.reset();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ═══════════════════════════════════════════════════════
// ✅ PROVIDERS
// ═══════════════════════════════════════════════════════

final backgroundExportServiceProvider = Provider<BackgroundExportService>((
  ref,
) {
  return BackgroundExportService();
});

final timelineExportServiceProvider = Provider<TimelineExportService>((ref) {
  return TimelineExportService();
});

final exportProvider = StateNotifierProvider<ExportNotifier, ExportState>((
  ref,
) {
  final backgroundService = ref.watch(backgroundExportServiceProvider);
  final timelineService = ref.watch(timelineExportServiceProvider);
  final projectNotifier = ref.watch(projectProvider.notifier);
  return ExportNotifier(backgroundService, timelineService, projectNotifier);
});

// Convenience providers
final isExportingProvider = Provider<bool>((ref) {
  return ref.watch(exportProvider).isExporting;
});

final exportProgressProvider = Provider<double>((ref) {
  return ref.watch(exportProvider).progress;
});

final exportStatusProvider = Provider<ExportStatus>((ref) {
  return ref.watch(exportProvider).status;
});

final recentExportsProvider = Provider<List<ExportJob>>((ref) {
  return ref.watch(exportProvider).recentExports;
});
