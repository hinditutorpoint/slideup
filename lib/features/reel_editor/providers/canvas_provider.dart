import 'package:flutter_riverpod/legacy.dart';
import '../models/canvas_preset.dart';
import '../state/reel_editor_state.dart';

class CanvasNotifier extends StateNotifier<CanvasState> {
  CanvasNotifier() : super(const CanvasState());

  void setPreset(CanvasPreset preset) {
    state = state.copyWith(config: CanvasConfig(preset: preset, backgroundColor: state.config.backgroundColor));
  }

  void setCustomRatio(double ratio) {
    if (ratio.isNaN || ratio.isInfinite || ratio <= 0) return;
    final r = ratio.clamp(0.1, 4.0);
    state = state.copyWith(config: CanvasConfig(preset: CanvasPreset.custom, customAspectRatio: r, backgroundColor: state.config.backgroundColor));
  }

  void setBackgroundColor(int argb) {
    state = state.copyWith(config: state.config.copyWith(backgroundColor: argb));
  }

  void toggleGrid() => state = state.copyWith(showGrid: !state.showGrid);
  void toggleSafeArea() => state = state.copyWith(showSafeArea: !state.showSafeArea);
}

final canvasProvider = StateNotifierProvider<CanvasNotifier, CanvasState>((ref) => CanvasNotifier());
