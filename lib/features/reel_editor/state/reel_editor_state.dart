import 'package:flutter/foundation.dart';
import '../models/reel_project.dart';
import '../models/canvas_preset.dart';

/// Separated states md:173-188 — Editor/Timeline/Playback/Selection/Canvas/Export/History/Persistence
@immutable
class ReelEditorState {
  final ReelProject? project;
  final bool isLoading;
  final String? error;
  final EditorTool currentTool;
  final EditorPanel currentPanel;
  const ReelEditorState({this.project, this.isLoading = false, this.error, this.currentTool = EditorTool.none, this.currentPanel = EditorPanel.none});
  ReelEditorState copyWith({ReelProject? project, bool? isLoading, String? error, EditorTool? currentTool, EditorPanel? currentPanel, bool clearError=false, bool clearProject=false}) =>
      ReelEditorState(project: clearProject? null : project ?? this.project, isLoading: isLoading ?? this.isLoading, error: clearError? null : error ?? this.error, currentTool: currentTool ?? this.currentTool, currentPanel: currentPanel ?? this.currentPanel);
}

@immutable
class TimelineState {
  final Duration currentPosition;
  final double zoomLevel; // 0.5-5
  final bool isPlaying;
  const TimelineState({this.currentPosition = Duration.zero, this.zoomLevel = 1.0, this.isPlaying = false});
  TimelineState copyWith({Duration? currentPosition, double? zoomLevel, bool? isPlaying}) => TimelineState(currentPosition: currentPosition ?? this.currentPosition, zoomLevel: zoomLevel ?? this.zoomLevel, isPlaying: isPlaying ?? this.isPlaying);
}

@immutable
class SelectionState {
  final String? selectedId;
  final String? selectedType;
  final Set<String> selectedIds;
  final Set<String> lockedIds;
  final Set<String> hiddenIds;
  const SelectionState({this.selectedId, this.selectedType, this.selectedIds = const {}, this.lockedIds = const {}, this.hiddenIds = const {}});
  SelectionState copyWith({String? selectedId, String? selectedType, Set<String>? selectedIds, Set<String>? lockedIds, Set<String>? hiddenIds, bool clear=false}) =>
      SelectionState(selectedId: clear? null : selectedId ?? this.selectedId, selectedType: clear? null : selectedType ?? this.selectedType, selectedIds: selectedIds ?? this.selectedIds, lockedIds: lockedIds ?? this.lockedIds, hiddenIds: hiddenIds ?? this.hiddenIds);
}

@immutable
class PlaybackState {
  final Duration position;
  final bool isPlaying;
  final bool isMuted;
  final double volume;
  const PlaybackState({this.position = Duration.zero, this.isPlaying = false, this.isMuted = false, this.volume = 1.0});
  PlaybackState copyWith({Duration? position, bool? isPlaying, bool? isMuted, double? volume}) => PlaybackState(position: position ?? this.position, isPlaying: isPlaying ?? this.isPlaying, isMuted: isMuted ?? this.isMuted, volume: volume ?? this.volume);
}

@immutable
class CanvasState {
  final CanvasConfig config;
  final bool showGrid;
  final bool showSafeArea;
  const CanvasState({this.config = const CanvasConfig(), this.showGrid = false, this.showSafeArea = false});
  CanvasState copyWith({CanvasConfig? config, bool? showGrid, bool? showSafeArea}) => CanvasState(config: config ?? this.config, showGrid: showGrid ?? this.showGrid, showSafeArea: showSafeArea ?? this.showSafeArea);
}

@immutable
class HistoryState {
  final List<ReelProject> undoStack;
  final List<ReelProject> redoStack;
  const HistoryState({this.undoStack = const [], this.redoStack = const []});
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
}

@immutable
class ExportState {
  final ExportStatus status;
  final double progress; // 0-1
  final String? message;
  final String? outputPath;
  final String? error;
  const ExportState({this.status = ExportStatus.idle, this.progress = 0, this.message, this.outputPath, this.error});
  bool get isExporting => status == ExportStatus.exporting;
}

enum EditorTool { none, trim, text, sticker, audio, filter, speed, crop }
enum EditorPanel { none, properties, layers, effects }
enum ExportStatus { idle, preparing, exporting, completed, failed, cancelled }
