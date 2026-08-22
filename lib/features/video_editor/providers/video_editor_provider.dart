import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/video_edit_settings.dart';
import '../services/video_edit_service.dart';
import '../services/audio_edit_service.dart';
import '../services/image_edit_service.dart';
import '../services/hive_service.dart';
import 'project_provider.dart';
import 'timeline_provider.dart';
import 'package:slideup/core/utils/safe_async.dart';

// ═══════════════════════════════════════════════════════
// ✅ EDITOR TOOL TYPES
// ═══════════════════════════════════════════════════════

enum EditorTool {
  none,
  trim,
  razor,
  colorGrade,
  text,
  image,
  audio,
  music,
  aiImage,
  aiVideo,
  merge,
  extract,
  export,
  library,
}

enum EditorPanel { none, properties, layers, effects, presets }

// ═══════════════════════════════════════════════════════
// ✅ VIDEO EDITOR STATE
// ═══════════════════════════════════════════════════════

@immutable
class VideoEditorState {
  final bool isInitialized;
  final bool isLoading;
  final String? error;
  final EditorTool currentTool;
  final EditorPanel currentPanel;
  final VideoInfo? videoInfo;
  final List<Uint8List> thumbnails;
  final bool isPreviewPlaying;
  final Duration previewPosition;
  final double volume;
  final bool isMuted;
  final bool showGrid;
  final bool showSafeArea;
  final bool snapToGrid;
  final ColorGradeSettings previewColorGrade;
  final ExportPreset selectedPreset;

  const VideoEditorState({
    this.isInitialized = false,
    this.isLoading = false,
    this.error,
    this.currentTool = EditorTool.none,
    this.currentPanel = EditorPanel.none,
    this.videoInfo,
    this.thumbnails = const [],
    this.isPreviewPlaying = false,
    this.previewPosition = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.showGrid = false,
    this.showSafeArea = false,
    this.snapToGrid = true,
    this.previewColorGrade = const ColorGradeSettings(),
    this.selectedPreset = const ExportPreset(
      id: 'high_1080p',
      name: '1080p HD',
    ),
  });

  VideoEditorState copyWith({
    bool? isInitialized,
    bool? isLoading,
    String? error,
    EditorTool? currentTool,
    EditorPanel? currentPanel,
    VideoInfo? videoInfo,
    List<Uint8List>? thumbnails,
    bool? isPreviewPlaying,
    Duration? previewPosition,
    double? volume,
    bool? isMuted,
    bool? showGrid,
    bool? showSafeArea,
    bool? snapToGrid,
    ColorGradeSettings? previewColorGrade,
    ExportPreset? selectedPreset,
  }) {
    return VideoEditorState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentTool: currentTool ?? this.currentTool,
      currentPanel: currentPanel ?? this.currentPanel,
      videoInfo: videoInfo ?? this.videoInfo,
      thumbnails: thumbnails ?? this.thumbnails,
      isPreviewPlaying: isPreviewPlaying ?? this.isPreviewPlaying,
      previewPosition: previewPosition ?? this.previewPosition,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      showGrid: showGrid ?? this.showGrid,
      showSafeArea: showSafeArea ?? this.showSafeArea,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      previewColorGrade: previewColorGrade ?? this.previewColorGrade,
      selectedPreset: selectedPreset ?? this.selectedPreset,
    );
  }

  VideoEditorState clearError() {
    return VideoEditorState(
      isInitialized: isInitialized,
      isLoading: isLoading,
      error: null,
      currentTool: currentTool,
      currentPanel: currentPanel,
      videoInfo: videoInfo,
      thumbnails: thumbnails,
      isPreviewPlaying: isPreviewPlaying,
      previewPosition: previewPosition,
      volume: volume,
      isMuted: isMuted,
      showGrid: showGrid,
      showSafeArea: showSafeArea,
      snapToGrid: snapToGrid,
      previewColorGrade: previewColorGrade,
      selectedPreset: selectedPreset,
    );
  }

  VideoEditorState reset() {
    return const VideoEditorState(isInitialized: true);
  }
}

// ═══════════════════════════════════════════════════════
// ✅ VIDEO EDITOR NOTIFIER
// ═══════════════════════════════════════════════════════

class VideoEditorNotifier extends StateNotifier<VideoEditorState> {
  VideoEditorNotifier(
    this._videoEditService,
    this._audioEditService,
    this._imageEditService,
    this._hiveService,
    this._projectNotifier,
    this._timelineNotifier,
  ) : super(const VideoEditorState());

  final VideoEditService _videoEditService;
  final AudioEditService _audioEditService;
  final ImageEditService _imageEditService;
  final HiveService _hiveService;
  final ProjectNotifier _projectNotifier;
  final TimelineNotifier _timelineNotifier;

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> initialize() async {
    if (state.isInitialized) return Result.success(null);
    try {
      state = state.copyWith(isLoading: true);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return Result.failure(e);
    }

    return SafeAsync.run(() async {
      // Initialize services
      await _hiveService.initialize();
      await _videoEditService.initialize();
      await _audioEditService.initialize();
      await _imageEditService.initialize();

      // Initialize project provider
      await _projectNotifier.initialize();

      state = state.copyWith(isInitialized: true, isLoading: false);

      debugPrint('✅ VideoEditorNotifier initialized');
    }, operationName: 'VideoEditorNotifier.initialize').whenComplete(() {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  // ✅ LOAD VIDEO
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> loadVideo(String videoPath) async {
    state = state.copyWith(isLoading: true);

    return SafeAsync.run(() async {
      // Get video info
      final infoResult = await _videoEditService.getVideoInfo(videoPath);
      if (infoResult.isFailure) {
        throw infoResult.error!;
      }

      final videoInfo = infoResult.requireData;

      // Create project with automatic incremental naming (Project 1, Project 2, etc.)
      final projectResult = await _projectNotifier.createProject(
        videoPath: videoPath,
        videoDuration: videoInfo.duration,
      );

      if (projectResult.isFailure) {
        throw projectResult.error!;
      }

      // Load timeline
      _timelineNotifier.loadFromProject(projectResult.requireData);

      // Extract thumbnails
      final framesResult = await _videoEditService.extractFrames(
        inputPath: videoPath,
        fps: 1,
        maxFrames: 20,
        width: 160,
        height: 90,
      );

      state = state.copyWith(
        isLoading: false,
        videoInfo: videoInfo,
        thumbnails: framesResult.getOrElse([]),
        previewColorGrade: const ColorGradeSettings(),
      );

      debugPrint('✅ Video loaded: ${videoInfo.resolution}');
    }, operationName: 'loadVideo').whenComplete(() {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    });
  }

  Future<Result<void>> createBlankProject({
    String? name,
    Duration defaultDuration = const Duration(seconds: 10),
  }) async {
    state = state.copyWith(isLoading: true);

    return SafeAsync.run(() async {
      final projectResult = await _projectNotifier.createBlankProject(
        name: name,
        defaultDuration: defaultDuration,
      );

      if (projectResult.isFailure) {
        throw projectResult.error!;
      }

      _timelineNotifier.loadFromProject(projectResult.requireData);

      state = state.copyWith(
        isLoading: false,
        videoInfo: null,
        thumbnails: const [],
        previewColorGrade: const ColorGradeSettings(),
      );

      debugPrint('✅ Blank project created successfully');
    }, operationName: 'createBlankProject').whenComplete(() {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TOOL SELECTION
  // ═══════════════════════════════════════════════════════

  void selectTool(EditorTool tool) {
    state = state.copyWith(currentTool: tool);
  }

  void togglePanel(EditorPanel panel) {
    if (state.currentPanel == panel) {
      state = state.copyWith(currentPanel: EditorPanel.none);
    } else {
      state = state.copyWith(currentPanel: panel);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PREVIEW CONTROLS
  // ═══════════════════════════════════════════════════════

  void setPreviewPlaying(bool playing) {
    state = state.copyWith(isPreviewPlaying: playing);
    _timelineNotifier.setPlaying(playing);
  }

  void setPreviewPosition(Duration position) {
    state = state.copyWith(previewPosition: position);
    _timelineNotifier.setCurrentPosition(position);
  }

  void setVolume(double volume) {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ COLOR GRADING PREVIEW
  // ═══════════════════════════════════════════════════════

  void setPreviewColorGrade(ColorGradeSettings colorGrade) {
    state = state.copyWith(previewColorGrade: colorGrade);
  }

  void applyColorGrade() {
    _projectNotifier.updateColorGrade(state.previewColorGrade);
  }

  void resetColorGrade() {
    state = state.copyWith(previewColorGrade: const ColorGradeSettings());
    _projectNotifier.updateColorGrade(const ColorGradeSettings());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PRESET SELECTION
  // ═══════════════════════════════════════════════════════

  void selectPreset(ExportPreset preset) {
    state = state.copyWith(selectedPreset: preset);
    _projectNotifier.updateExportPreset(preset);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VIEW OPTIONS
  // ═══════════════════════════════════════════════════════

  void toggleGrid() {
    state = state.copyWith(showGrid: !state.showGrid);
  }

  void toggleSafeArea() {
    state = state.copyWith(showSafeArea: !state.showSafeArea);
  }

  void toggleSnapToGrid() {
    state = state.copyWith(snapToGrid: !state.snapToGrid);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ERROR HANDLING
  // ═══════════════════════════════════════════════════════

  void setError(String error) {
    state = state.copyWith(error: error);
  }

  void clearError() {
    state = state.clearError();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ RESET
  // ═══════════════════════════════════════════════════════

  void reset() {
    _timelineNotifier.clearAll();
    state = state.reset();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DISPOSE
  // ═══════════════════════════════════════════════════════

  @override
  void dispose() {
    _videoEditService.dispose();
    _audioEditService.dispose();
    _imageEditService.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════
// ✅ SERVICE PROVIDERS
// ═══════════════════════════════════════════════════════

final videoEditServiceProvider = Provider<VideoEditService>((ref) {
  return VideoEditService();
});

final audioEditServiceProvider = Provider<AudioEditService>((ref) {
  return AudioEditService();
});

final imageEditServiceProvider = Provider<ImageEditService>((ref) {
  return ImageEditService();
});

// ═══════════════════════════════════════════════════════
// ✅ MAIN PROVIDER
// ═══════════════════════════════════════════════════════

final videoEditorProvider =
    StateNotifierProvider<VideoEditorNotifier, VideoEditorState>((ref) {
      final videoEditService = ref.watch(videoEditServiceProvider);
      final audioEditService = ref.watch(audioEditServiceProvider);
      final imageEditService = ref.watch(imageEditServiceProvider);
      final hiveService = ref.watch(hiveServiceProvider);
      final projectNotifier = ref.watch(projectProvider.notifier);
      final timelineNotifier = ref.watch(timelineProvider.notifier);

      return VideoEditorNotifier(
        videoEditService,
        audioEditService,
        imageEditService,
        hiveService,
        projectNotifier,
        timelineNotifier,
      );
    });

// ═══════════════════════════════════════════════════════
// ✅ CONVENIENCE PROVIDERS
// ═══════════════════════════════════════════════════════

final isEditorInitializedProvider = Provider<bool>((ref) {
  return ref.watch(videoEditorProvider).isInitialized;
});

final isEditorLoadingProvider = Provider<bool>((ref) {
  return ref.watch(videoEditorProvider).isLoading;
});

final currentToolProvider = Provider<EditorTool>((ref) {
  return ref.watch(videoEditorProvider).currentTool;
});

final currentPanelProvider = Provider<EditorPanel>((ref) {
  return ref.watch(videoEditorProvider).currentPanel;
});

final videoInfoProvider = Provider<VideoInfo?>((ref) {
  return ref.watch(videoEditorProvider).videoInfo;
});

final thumbnailsProvider = Provider<List<Uint8List>>((ref) {
  return ref.watch(videoEditorProvider).thumbnails;
});

final previewColorGradeProvider = Provider<ColorGradeSettings>((ref) {
  return ref.watch(videoEditorProvider).previewColorGrade;
});

final selectedPresetProvider = Provider<ExportPreset>((ref) {
  return ref.watch(videoEditorProvider).selectedPreset;
});
