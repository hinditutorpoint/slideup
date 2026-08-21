// LEGACY STUB — kept for export_sheet.dart / merge_sheet.dart compatibility
// Real export now via reel_editor/engine/export/ffmpeg_engine.dart
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/utils/safe_async.dart';
import '../models/video_edit_settings.dart';

class ExportNotifier extends StateNotifier<ExportState> {
  ExportNotifier() : super(const ExportState());
  Future<Result<String>> startTimelineExport({required ExportPreset preset, bool includeTextOverlays=true, bool includeImageOverlays=true, bool includeAudioTracks=true, bool applyColorGrading=true}) async {
    state = state.copyWith(status: ExportStatus.completed, progress: 1.0, message: 'Stub export completed');
    return Result.success('');
  }
  Future<void> cancelExport() async { state = state.copyWith(status: ExportStatus.cancelled); }
  void deleteExport(String jobId) { state = state.copyWith(recentExports: state.recentExports.where((j)=>j.id!=jobId).toList()); }
  void reset() { state = const ExportState(); }
}

final exportProvider = StateNotifierProvider<ExportNotifier, ExportState>((ref) => ExportNotifier());
