// Real export via BackgroundExportService (FFmpeg command built in isolate).
// The overlay/grade toggles from ExportSheet are applied to an export-only
// copy of the project — the editing timeline is never modified.
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/utils/safe_async.dart';
import '../models/video_edit_settings.dart';
import '../services/background_export_service.dart' as bg;
import 'project_provider.dart';

class ExportNotifier extends StateNotifier<ExportState> {
  ExportNotifier(this._projectNotifier) : super(const ExportState());

  final ProjectNotifier _projectNotifier;
  final bg.BackgroundExportService _service = bg.BackgroundExportService();

  Future<Result<String>> startTimelineExport({
    required ExportPreset preset,
    bool includeTextOverlays = true,
    bool includeImageOverlays = true,
    bool includeAudioTracks = true,
    bool applyColorGrading = true,
  }) async {
    if (state.isExporting) {
      return Result.failure(StateError('Export already running'));
    }

    final project = _projectNotifier.state.currentProject;
    if (project == null) {
      const err = 'No active project to export';
      state = state.copyWith(
        status: ExportStatus.failed,
        error: err,
        message: err,
      );
      return Result.failure(StateError(err));
    }

    // Persist the chosen preset so the project snapshot carries resolution /
    // bitrate / fps settings into the FFmpeg command builder.
    _projectNotifier.updateExportPreset(preset);
    final base = _projectNotifier.state.currentProject ?? project;

    final exportProject = base.copyWith(
      textItems: includeTextOverlays
          ? base.textItems
          : const <TextTimelineItem>[],
      imageItems: includeImageOverlays
          ? base.imageItems
          : const <ImageTimelineItem>[],
      audioItems: includeAudioTracks
          ? base.audioItems
          : const <AudioTimelineItem>[],
      colorGrade: applyColorGrading
          ? base.colorGrade
          : const ColorGradeSettings(),
    );

    state = state.copyWith(
      status: ExportStatus.preparing,
      progress: 0,
      message: 'Preparing export...',
      error: null,
      outputPath: null,
    );

    final result = await _service.startExport(
      project: exportProject,
      onProgress: (p) {
        if (!mounted) return;
        state = state.copyWith(
          status: p.status,
          progress: p.progress,
          message: p.message,
          outputPath: p.outputPath,
          error: p.error,
          elapsed: p.elapsed,
          estimated: p.estimated,
        );
      },
    );

    if (!mounted) return result;

    if (result.isSuccess) {
      final outPath = result.getOrNull() ?? '';
      final job = ExportJob(
        id: 'export_${DateTime.now().millisecondsSinceEpoch}',
        projectId: base.id,
        outputPath: outPath,
        status: ExportJobStatus.completed,
      );
      state = state.copyWith(
        status: ExportStatus.completed,
        progress: 1.0,
        message: 'Export completed',
        outputPath: outPath,
        error: null,
        recentExports: [job, ...state.recentExports],
      );
    } else {
      final err = '${result.error}';
      state = state.copyWith(
        status: ExportStatus.failed,
        message: err,
        error: err,
      );
    }
    return result;
  }

  Future<void> cancelExport() async {
    await _service.cancelExport();
    if (mounted) {
      state = state.copyWith(status: ExportStatus.cancelled);
    }
  }

  void deleteExport(String jobId) {
    state = state.copyWith(
      recentExports:
          state.recentExports.where((j) => j.id != jobId).toList(),
    );
  }

  void reset() {
    state = const ExportState();
  }
}

final exportProvider = StateNotifierProvider<ExportNotifier, ExportState>((
  ref,
) {
  final projectNotifier = ref.watch(projectProvider.notifier);
  return ExportNotifier(projectNotifier);
});
