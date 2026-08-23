import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../../services/file_picker_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'models/video_edit_settings.dart';
import 'providers/video_editor_provider.dart';
import 'providers/timeline_provider.dart';
import 'providers/project_provider.dart';
import 'components/preview_component.dart';
import 'components/object_canvas_overlay.dart';
import 'components/sync_text_field.dart';
import 'services/preview_audio_mixer.dart';

import 'components/object_timeline_editor.dart';
import 'sheets/trim_sheet.dart';
import 'sheets/text_sheet.dart';
import 'sheets/audio_sheet.dart';
import 'sheets/color_sheet.dart';
import 'sheets/library_sheet.dart';
import 'sheets/export_sheet.dart'; // Keep this for export dialog
import 'sheets/effects_sheet.dart';
import 'sheets/image_picker_sheet.dart';
import 'sheets/image_edit_sheet.dart';
import 'sheets/merge_sheet.dart';
import 'sheets/transition_sheet.dart';
import 'sheets/pixabay_video_picker_sheet.dart';
import 'tabs/ai_tab.dart';

// ═══════════════════════════════════════════════════════
// ✅ PROVIDERS
// ═══════════════════════════════════════════════════════

final isLoopingProvider = StateProvider<bool>((ref) => false);

final projectHistoryProvider =
    StateNotifierProvider<ProjectHistoryNotifier, ProjectHistoryState>((ref) {
      return ProjectHistoryNotifier();
    });

class ProjectHistoryState {
  final List<VideoProject> undoStack;
  final List<VideoProject> redoStack;

  const ProjectHistoryState({
    this.undoStack = const [],
    this.redoStack = const [],
  });

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
}

class ProjectHistoryNotifier extends StateNotifier<ProjectHistoryState> {
  ProjectHistoryNotifier() : super(const ProjectHistoryState());

  void pushState(VideoProject project) {
    state = ProjectHistoryState(
      undoStack: [...state.undoStack, project],
      redoStack: [],
    );
  }

  VideoProject? undo() {
    if (!state.canUndo) return null;
    final current = state.undoStack.last;
    state = ProjectHistoryState(
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      redoStack: [...state.redoStack, current],
    );
    return state.undoStack.lastOrNull;
  }

  VideoProject? redo() {
    if (!state.canRedo) return null;
    final next = state.redoStack.last;
    state = ProjectHistoryState(
      undoStack: [...state.undoStack, next],
      redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
    );
    return next;
  }
}

// ═══════════════════════════════════════════════════════
// ✅ VIDEO EDITOR SCREEN
// ═══════════════════════════════════════════════════════

class VideoEditorScreen extends ConsumerStatefulWidget {
  final String? videoPath;

  const VideoEditorScreen({super.key, this.videoPath});

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<PreviewComponentState> _previewKey = GlobalKey();
  late AnimationController _animationController;
  Timer? _positionTimer;
  DateTime? _lastTickTime;
  late final PreviewAudioMixer _audioMixer;

  // Fixed heights
  static const double _topBarHeight = 38.0;
  static const double _bottomToolbarHeight = 60.0;
  static const double _playbackControlsHeight = 34.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioMixer = PreviewAudioMixer();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    super.didChangeAppLifecycleState(appState);
    if (appState == AppLifecycleState.resumed) {
      WakelockPlus.enable();
    } else if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.inactive ||
        appState == AppLifecycleState.detached) {
      WakelockPlus.disable();
    }
  }

  Future<void> _initialize() async {
    final result = await ref.read(videoEditorProvider.notifier).initialize();

    if (result.isFailure) {
      if (mounted) {
        _showError('Failed to initialize: ${result.error}');
      }
      return;
    }

    if (widget.videoPath != null) {
      final loadResult = await ref
          .read(videoEditorProvider.notifier)
          .loadVideo(widget.videoPath!);

      if (loadResult.isFailure && mounted) {
        _showError('Failed to load video: ${loadResult.error}');
      }
    }

    _setImmersiveMode(true);
    _startPositionTracking();
  }

  void _setImmersiveMode(bool immersive) {
    SystemChrome.setEnabledSystemUIMode(
      immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  Duration _getTotalTimelineDuration(TimelineState tl, VideoProject? project) {
    if (tl.primaryVideoClips.isNotEmpty) {
      if (tl.totalDuration > Duration.zero) return tl.totalDuration;
      final mag = project?.magneticTrackDuration;
      if (mag != null && mag > Duration.zero) return mag;
    }
    return project?.effectiveDuration ??
        project?.videoDuration ??
        Duration.zero;
  }

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _lastTickTime = null;
    _positionTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final editorState = ref.read(videoEditorProvider);
      final tl = ref.read(timelineProvider);
      final project = ref.read(currentProjectProvider);
      final totalDuration = _getTotalTimelineDuration(tl, project);
      final isLooping = ref.read(isLoopingProvider);

      if (editorState.isPreviewPlaying) {
        final now = DateTime.now();
        final elapsed = _lastTickTime == null
            ? const Duration(milliseconds: 50)
            : now.difference(_lastTickTime!);
        _lastTickTime = now;

        final currentPos = tl.currentPosition;
        final clips = tl.primaryVideoClips;
        final activeClip = _activePrimaryClip(clips, currentPos);
        final rate = (activeClip?.speed ?? 1.0).clamp(0.1, 8.0);
        final advancedMs =
            (elapsed.inMicroseconds / 1000.0 * rate).round();
        var nextPos = currentPos + Duration(milliseconds: advancedMs);

        if (totalDuration > Duration.zero && nextPos >= totalDuration) {
          if (isLooping) {
            nextPos = Duration.zero;
            _seekToTimelinePosition(Duration.zero);
          } else {
            nextPos = totalDuration;
            ref.read(timelineProvider.notifier).setPlaying(false);
            ref
                .read(videoEditorProvider.notifier)
                .setPreviewPlaying(false);
            _previewKey.currentState?.pause();
          }
        } else {
          // Sync preview player with active clip's trimmed video file position
          if (clips.isNotEmpty && activeClip != null) {
            final clipStart = _clipTimelineStart(clips, activeClip.id);
            final local = nextPos - clipStart;
            final targetFilePos = activeClip.trimStart + local;
            final playerPos =
                _previewKey.currentState?.getCurrentPosition();
            if (playerPos != null &&
                (playerPos - targetFilePos).inMilliseconds.abs() > 350) {
              _previewKey.currentState?.seekTo(targetFilePos);
            }
          }
        }

        ref.read(videoEditorProvider.notifier).setPreviewPosition(nextPos);
        ref.read(timelineProvider.notifier).setCurrentPosition(nextPos);
        _applySpeedRamping(nextPos);
      } else {
        _lastTickTime = null;
      }
      _syncAudio();
    });
  }

  void _seekToTimelinePosition(Duration seekPos) {
    final tl = ref.read(timelineProvider);
    final project = ref.read(currentProjectProvider);
    final totalDuration = _getTotalTimelineDuration(tl, project);
    final clamped = seekPos < Duration.zero
        ? Duration.zero
        : (totalDuration > Duration.zero && seekPos > totalDuration
            ? totalDuration
            : seekPos);

    ref.read(timelineProvider.notifier).setCurrentPosition(clamped);
    ref.read(videoEditorProvider.notifier).setPreviewPosition(clamped);

    final clips = tl.primaryVideoClips;
    if (clips.isNotEmpty) {
      PrimaryVideoClip? activeClip;
      Duration clipStart = Duration.zero;
      for (final clip in clips) {
        if (clamped < clipStart + clip.effectiveDuration) {
          activeClip = clip;
          break;
        }
        clipStart += clip.effectiveDuration;
      }
      activeClip ??= clips.last;
      final local = clamped - clipStart;
      final filePos = activeClip.trimStart + local;
      _previewKey.currentState?.seekTo(filePos);
    } else {
      final start = project?.trimStart ?? Duration.zero;
      _previewKey.currentState?.seekTo(start + clamped);
    }
    _syncAudio();
  }

  /// Apply speed ramping from keyframes during playback.
  void _applySpeedRamping(Duration position) {
    final tl = ref.read(timelineProvider);
    final clips = tl.primaryVideoClips;
    if (clips.isEmpty) return;

    final activeClip = _activePrimaryClip(clips, position);
    if (activeClip == null) return;

    final kfs = tl.keyframes[activeClip.id];
    if (kfs == null || kfs.isEmpty) {
      // No speed keyframes — use clip's base speed
      _previewKey.currentState?.setPlaybackSpeed(activeClip.speed);
      return;
    }

    // Find speed keyframes
    final speedKfs = kfs.where((k) => k.speed != null).toList();
    if (speedKfs.isEmpty) {
      _previewKey.currentState?.setPlaybackSpeed(activeClip.speed);
      return;
    }

    // Compute position relative to the active clip start
    final clipStart = _clipTimelineStart(clips, activeClip.id);
    final relativePos = position - clipStart;

    // Interpolate speed
    final interpolated = KeyframeData.interpolate(speedKfs, relativePos);
    final speed = interpolated.speed ?? activeClip.speed;
    _previewKey.currentState?.setPlaybackSpeed(speed.clamp(0.1, 8.0));
  }

  /// Keeps background-music items in sync with the playhead.
  Future<void> _syncAudio() async {
    final tl = ref.read(timelineProvider);
    final editor = ref.read(videoEditorProvider);
    final audioTrackMuted = tl.mutedTracks.contains('Audio');
    final hasSolo = tl.soloTracks.isNotEmpty;
    final audioTrackSolo = tl.soloTracks.contains('Audio');

    final sources = tl.audioItems
        .map(
          (a) => PreviewMixSource(
            id: a.id,
            path: a.audioPath,
            start: a.startTime,
            duration: a.audioDuration,
            volume: a.volume,
            isTrackMuted: audioTrackMuted || (hasSolo && !audioTrackSolo),
          ),
        )
        .toList();

    await _audioMixer.sync(
      sources: sources,
      playhead: tl.currentPosition,
      isPlaying: tl.isPlaying,
      masterVolume: editor.isMuted ? 0 : editor.volume,
      muted: editor.isMuted,
    );
  }

  Duration _clipTimelineStart(List<PrimaryVideoClip> clips, String clipId) {
    var offset = Duration.zero;
    for (final clip in clips) {
      if (clip.id == clipId) return offset;
      offset += clip.effectiveDuration;
    }
    return Duration.zero;
  }

  /// The primary clip that should be shown/played at the current playhead.
  PrimaryVideoClip? _activePrimaryClip(
    List<PrimaryVideoClip> clips,
    Duration position,
  ) {
    if (clips.isEmpty) return null;
    var offset = Duration.zero;
    for (final clip in clips) {
      final dur = clip.effectiveDuration;
      if (dur > Duration.zero && position < offset + dur) return clip;
      offset += dur;
    }
    return clips.last;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionTimer?.cancel();
    _animationController.dispose();
    _audioMixer.dispose();
    WakelockPlus.disable();
    _setImmersiveMode(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(videoEditorProvider);
    final project = ref.watch(currentProjectProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: editorState.isLoading && !editorState.isInitialized
            ? _buildLoadingState()
            : editorState.error != null
            ? _buildErrorState(editorState.error!)
            : project == null && widget.videoPath == null
            ? _buildEmptyState()
            : _buildEditorLayout(editorState, project),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MAIN LAYOUT
  // ═══════════════════════════════════════════════════════

  Widget _buildEditorLayout(VideoEditorState state, VideoProject? project) {
    return Stack(
      children: [
        Column(
          children: [
            // TOP BAR
            SizedBox(height: _topBarHeight, child: _buildTopBar(state)),

            // MIDDLE CONTENT
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;
                  final previewHeight = (availableHeight * 0.40).clamp(
                    100.0,
                    availableHeight * 0.50,
                  );

                  final remainingHeight =
                      availableHeight -
                      previewHeight -
                      _playbackControlsHeight;

                  final editorHeight = remainingHeight < 0 ? 0.0 : remainingHeight;

                  return Column(
                    children: [
                      // PREVIEW
                      SizedBox(
                        height: previewHeight,
                        child: _buildPreview(state, project),
                      ),

                      // PLAYBACK CONTROLS
                      SizedBox(
                        height: _playbackControlsHeight,
                        child: _buildPlaybackControls(state),
                      ),

                      // OBJECT TIMELINE EDITOR
                      if (project != null)
                        SizedBox(
                          height: editorHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey[800]!,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: ObjectTimelineEditor(
                              totalDuration: _getTotalTimelineDuration(
                                ref.watch(timelineProvider),
                                project,
                              ),
                              onSeek: _seekToTimelinePosition,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // BOTTOM TOOLBAR
            SizedBox(
              height: _bottomToolbarHeight,
              child: _buildBottomToolbar(state),
            ),
          ],
        ),

        // Loading overlay
        if (state.isLoading && state.isInitialized) _buildLoadingOverlay(),

        // Side panel (Properties, Layers, Effects ONLY)
        if (state.currentPanel != EditorPanel.none &&
            state.currentPanel != EditorPanel.presets)
          _buildSidePanel(state),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TOP BAR
  // ═══════════════════════════════════════════════════════

  Widget _buildTopBar(VideoEditorState state) {
    final hasChanges = ref.watch(hasUnsavedChangesProvider);
    final project = ref.watch(currentProjectProvider);
    final historyState = ref.watch(projectHistoryProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 18,
              color: Colors.white,
            ),
            onPressed: _handleBack,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40),
          ),

          // Project name
          Expanded(
            child: GestureDetector(
              onTap: () => _showRenameDialog(project),
              child: Text(
                project?.name ?? 'Video Editor',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Grid toggle
          IconButton(
            icon: Icon(
              Icons.grid_on,
              size: 18,
              color: state.showGrid ? Colors.blue : Colors.grey[400],
            ),
            onPressed: () =>
                ref.read(videoEditorProvider.notifier).toggleGrid(),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36),
          ),

          // Undo
          IconButton(
            icon: const Icon(Icons.undo, size: 18),
            onPressed: historyState.canUndo ? _undo : null,
            color: historyState.canUndo
                ? Colors.white
                : const Color.fromARGB(255, 146, 139, 139),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36),
          ),

          // Redo
          IconButton(
            icon: const Icon(Icons.redo, size: 18),
            onPressed: historyState.canRedo ? _redo : null,
            color: historyState.canRedo
                ? Colors.white
                : const Color.fromARGB(255, 146, 139, 139),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36),
          ),

          // Unsaved indicator
          if (hasChanges)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),

          // Recent Projects button
          IconButton(
            icon: const Icon(Icons.history, size: 18, color: Colors.white),
            onPressed: _showRecentProjectsPanel,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36),
            tooltip: 'Recent Projects',
          ),

          // Save button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: state.isLoading ? null : _saveProject,
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: const Icon(Icons.save, size: 14),
              label: const Text('Save', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PREVIEW
  // ═══════════════════════════════════════════════════════

  Widget _buildPreview(VideoEditorState state, VideoProject? project) {
    if (project == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video preview
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Builder(
                    builder: (context) {
                      final tlState = ref.watch(timelineProvider);
                      final clips = tlState.primaryVideoClips;
                      final clip = _activePrimaryClip(
                        clips,
                        tlState.currentPosition,
                      );
                      final v = clip ??
                          (clips.isNotEmpty ? clips.first : null);
                      return PreviewComponent(
                        key: _previewKey,
                        videoPath: v?.videoPath ?? project.videoPath,
                        showControls: false,
                        showOverlays: true,
                        enableInteraction: true,
                        colorGrade: state.previewColorGrade,
                        volume: state.isMuted ? 0 : state.volume,
                        showGrid: state.showGrid,
                        showSafeArea: state.showSafeArea,
                        clipVolume: v?.volume ?? 1,
                        speed: v?.speed ?? 1,
                        rotation: v?.rotation ?? 0,
                        flipH: v?.flipH ?? false,
                        flipV: v?.flipV ?? false,
                      );
                    },
                  ),
                  // On-canvas drag / pinch-resize / rotate for overlays
                  const ObjectCanvasOverlay(),
                ],
              ),
            ),
          ),

          // Video info badge
          if (state.videoInfo != null)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${state.videoInfo!.resolution} • ${state.videoInfo!.fps.round()}fps',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),

          // Compact Volume control
          Positioned(right: 6, top: 6, child: _buildCompactVolumeSlider(state)),
        ],
      ),
    );
  }

  Widget _buildCompactVolumeSlider(VideoEditorState state) {
    return Container(
      width: 28,
      height: 112,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              icon: Icon(
                state.isMuted ? Icons.volume_off : Icons.volume_up,
                size: 14,
                color: Colors.white,
              ),
              onPressed: () =>
                  ref.read(videoEditorProvider.notifier).toggleMute(),
              padding: EdgeInsets.zero,
            ),
          ),
          SizedBox(
            height: 60,
            child: RotatedBox(
              quarterTurns: -1,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 4,
                  ),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                ),
                child: Slider(
                  value: state.volume,
                  onChanged: (v) =>
                      ref.read(videoEditorProvider.notifier).setVolume(v),
                  activeColor: Colors.blue,
                  inactiveColor: Colors.grey[700],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${(state.volume * 100).round()}%',
              style: const TextStyle(fontSize: 7),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYBACK CONTROLS
  // ═══════════════════════════════════════════════════════

  Widget _buildPlaybackControls(VideoEditorState state) {
    final project = ref.watch(currentProjectProvider);
    final timelineState = ref.watch(timelineProvider);
    final isLooping = ref.watch(isLoopingProvider);

    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!, width: 0.5),
          bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Play/Pause
            IconButton(
              icon: Icon(
                timelineState.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 22,
                color: Colors.white,
              ),
              onPressed: _togglePlayPause,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),

            // Time display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(timelineState.currentPosition),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    ' / ',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  if (project != null)
                    Text(
                      _formatTime(
                        _getTotalTimelineDuration(timelineState, project),
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey[400],
                      ),
                    ),
                ],
              ),
            ),

            // Zoom slider
            SizedBox(
              width: 60,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: timelineState.zoomLevel,
                  min: 0.5,
                  max: 3.0,
                  onChanged: (v) =>
                      ref.read(timelineProvider.notifier).setZoomLevel(v),
                  activeColor: Colors.grey[400],
                  inactiveColor: Colors.grey[700],
                ),
              ),
            ),
            Icon(Icons.zoom_in, size: 14, color: Colors.grey[500]),

            // Frame navigation
            IconButton(
              icon: const Icon(
                Icons.skip_previous,
                size: 18,
                color: Colors.white,
              ),
              onPressed: _previousFrame,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 18, color: Colors.white),
              onPressed: _nextFrame,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32),
            ),

            // Loop toggle
            IconButton(
              icon: Icon(
                Icons.repeat,
                size: 18,
                color: isLooping ? Colors.blue : Colors.grey[400],
              ),
              onPressed: () =>
                  ref.read(isLoopingProvider.notifier).state = !isLooping,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BOTTOM TOOLBAR - WITH EXPORT IN MORE MENU
  // ═══════════════════════════════════════════════════════

  Widget _buildBottomToolbar(VideoEditorState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[800]!, width: 0.5)),
      ),
      child: Row(
        children: [
          _buildToolButton(
            icon: Icons.content_cut_rounded,
            label: 'Trim',
            tool: EditorTool.trim,
            isActive: state.currentTool == EditorTool.trim,
          ),
          _buildToolButton(
            icon: Icons.text_fields_rounded,
            label: 'Text',
            tool: EditorTool.text,
            isActive: state.currentTool == EditorTool.text,
          ),
          _buildToolButton(
            icon: Icons.color_lens_outlined,
            label: 'Color',
            tool: EditorTool.colorGrade,
            isActive: state.currentTool == EditorTool.colorGrade,
          ),
          _buildToolButton(
            icon: Icons.audiotrack_rounded,
            label: 'Audio',
            tool: EditorTool.audio,
            isActive: state.currentTool == EditorTool.audio,
          ),
          _buildMoreButton(),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required EditorTool tool,
    required bool isActive,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _selectTool(tool);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isActive ? Colors.blue : Colors.grey[300],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? Colors.blue : Colors.grey[400],
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreButton() {
    return SizedBox(
      width: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showMoreToolsMenu,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey[700]!, Colors.grey[800]!],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.apps_rounded, size: 20),
                ),
                const SizedBox(height: 2),
                Text(
                  'More',
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SIDE PANEL - ONLY PROPERTIES, LAYERS, EFFECTS
  // ═══════════════════════════════════════════════════════

  Widget _buildSidePanel(VideoEditorState state) {
    return Positioned(
      right: 0,
      top: _topBarHeight,
      bottom: _bottomToolbarHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 250,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Panel header
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
              ),
              child: Row(
                children: [
                  Text(
                    _getPanelTitle(state.currentPanel),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => ref
                        .read(videoEditorProvider.notifier)
                        .togglePanel(EditorPanel.none),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32),
                  ),
                ],
              ),
            ),

            // Panel content
            Expanded(child: _buildPanelContent(state.currentPanel)),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelContent(EditorPanel panel) {
    switch (panel) {
      case EditorPanel.properties:
        return _buildPropertiesPanel();
      case EditorPanel.layers:
        return _buildLayersPanel();
      case EditorPanel.effects:
        return _buildEffectsPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPropertiesPanel() {
    final selectedPrimary = ref.watch(selectedPrimaryClipProvider);
    if (selectedPrimary != null) {
      return _buildVideoProperties(selectedPrimary);
    }

    final selectedItem = ref.watch(selectedItemProvider);

    if (selectedItem == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 40, color: Colors.grey[600]),
            const SizedBox(height: 12),
            Text(
              'Select an object to edit',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (selectedItem is TextTimelineItem) {
      return _buildTextProperties(selectedItem);
    } else if (selectedItem is ImageTimelineItem) {
      return _buildImageProperties(selectedItem);
    } else if (selectedItem is AudioTimelineItem) {
      return _buildAudioProperties(selectedItem);
    }

    return const SizedBox.shrink();
  }

  Widget _buildVideoProperties(PrimaryVideoClip clip) {
    final notifier = ref.read(timelineProvider.notifier);
    void update(PrimaryVideoClip c) =>
        notifier.updatePrimaryClip(clip.id, c);

    final sourceSec = clip.sourceDuration.inSeconds.toDouble();
    final state = ref.watch(timelineProvider);
    final clipIndex = state.primaryVideoClips.indexWhere((c) => c.id == clip.id);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle('Video · Clip', Icons.movie_outlined, Colors.blueAccent),
        const SizedBox(height: 8),

        // Trim In
        _labeledSlider(
          label: 'Trim In',
          value: clip.trimStart.inSeconds.toDouble(),
          min: 0,
          max: sourceSec,
          display: _fmt(clip.trimStart),
          onChanged: (v) {
            final ts = Duration(seconds: v.round());
            update(clip.copyWith(
              trimStart: ts,
              trimEnd: clip.trimEnd < ts ? ts : clip.trimEnd,
            ));
          },
        ),

        // Trim Out
        _labeledSlider(
          label: 'Trim Out',
          value: clip.trimEnd.inSeconds.toDouble(),
          min: 0,
          max: sourceSec,
          display: _fmt(clip.trimEnd),
          onChanged: (v) {
            final te = Duration(seconds: v.round());
            update(clip.copyWith(
              trimEnd: te < clip.trimStart ? clip.trimStart : te,
            ));
          },
        ),

        const SizedBox(height: 8),
        _sectionTitle('Audio & Playback', Icons.tune, Colors.blueAccent),
        const SizedBox(height: 8),

        // Volume
        _labeledSlider(
          label: 'Volume',
          value: clip.volume,
          min: 0,
          max: 1,
          display: '${(clip.volume * 100).round()}%',
          onChanged: (v) => update(clip.copyWith(volume: v)),
        ),

        // Speed
        _labeledSlider(
          label: 'Speed',
          value: clip.speed,
          min: 0.25,
          max: 4,
          display: '${clip.speed.toStringAsFixed(2)}x',
          onChanged: (v) => update(clip.copyWith(speed: v)),
        ),

        const SizedBox(height: 8),
        _sectionTitle('Transform', Icons.crop_rotate, Colors.blueAccent),
        const SizedBox(height: 8),

        // Rotation
        _labeledSlider(
          label: 'Rotation',
          value: clip.rotation,
          min: -180,
          max: 180,
          display: '${clip.rotation.round()}°',
          onChanged: (v) => update(clip.copyWith(rotation: v)),
        ),

        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _toggleChip(
                label: 'Flip H',
                active: clip.flipH,
                onTap: () => update(clip.copyWith(flipH: !clip.flipH)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _toggleChip(
                label: 'Flip V',
                active: clip.flipV,
                onTap: () => update(clip.copyWith(flipV: !clip.flipV)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── Speed Ramping ──
        _sectionTitle('Speed Ramping', Icons.speed, Colors.orangeAccent),
        const SizedBox(height: 6),
        _buildSpeedRampSection(clip),

        const SizedBox(height: 12),
        // Transition out
        if (clipIndex >= 0 && clipIndex < state.primaryVideoClips.length - 1)
          OutlinedButton.icon(
            onPressed: () => TransitionSheet.show(
              context,
              ref,
              clipIndex: clipIndex,
              current: clip.transitionOut,
            ),
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Transition Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _labeledSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            const Spacer(),
            Text(
              display,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: Colors.blueAccent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _toggleChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.blueAccent : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? Colors.blueAccent : Colors.white24,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildSpeedRampSection(PrimaryVideoClip clip) {
    final tl = ref.watch(timelineProvider);
    final kfs = tl.keyframes[clip.id] ?? [];
    final speedKfs = kfs.where((k) => k.speed != null).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    // Compute clip start position for relative time display
    var clipStart = Duration.zero;
    for (final c in tl.primaryVideoClips) {
      if (c.id == clip.id) break;
      clipStart += c.effectiveDuration;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (speedKfs.isEmpty)
          Text(
            'No speed ramps. Add keyframes to create variable speed.',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          )
        else
          ...speedKfs.map((kf) {
            final relTime = kf.time;
            final speed = kf.speed ?? 1.0;
            final color = speed < 1.0
                ? Colors.blueAccent
                : speed > 1.0
                    ? Colors.orangeAccent
                    : Colors.grey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Icon(Icons.speed, size: 10, color: color),
                  const SizedBox(width: 4),
                  Text(
                    _fmt(relTime),
                    style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${speed.toStringAsFixed(1)}x',
                      style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      ref.read(timelineProvider.notifier).removeKeyframe(clip.id, kf.id);
                    },
                    child: Icon(Icons.close, size: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final pos = ref.read(timelineProvider).currentPosition;
                  final relativePos = pos - clipStart;
                  final kf = KeyframeData(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    time: relativePos < Duration.zero ? Duration.zero : relativePos,
                    speed: clip.speed,
                  );
                  ref.read(timelineProvider.notifier).addKeyframe(clip.id, kf);
                },
                icon: const Icon(Icons.add, size: 12),
                label: const Text('Add Speed Keyframe', style: TextStyle(fontSize: 10)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent, width: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextProperties(TextTimelineItem item) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SyncTextField(
          text: item.text,
          decoration: const InputDecoration(
            labelText: 'Text',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.all(10),
          ),
          style: const TextStyle(fontSize: 12),
          maxLines: 2,
          onChanged: (value) {
            ref
                .read(timelineProvider.notifier)
                .updateTextItem(item.id, item.copyWith(text: value));
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Font Size', style: TextStyle(fontSize: 11)),
            const Spacer(),
            Text(
              '${item.style.fontSize.round()}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        Slider(
          value: item.style.fontSize.clamp(12.0, 72.0),
          min: 12,
          max: 72,
          onChanged: (value) {
            ref
                .read(timelineProvider.notifier)
                .updateTextItem(
                  item.id,
                  item.copyWith(style: item.style.copyWith(fontSize: value)),
                );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Duration: ${_formatTime(item.duration)}',
          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
        ),
        Text(
          'Start: ${_formatTime(item.startTime)}',
          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildImageProperties(ImageTimelineItem item) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const Text('Scale', style: TextStyle(fontSize: 11)),
            const Spacer(),
            Text(
              '${(item.scale * 100).round()}%',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        Slider(
          value: item.scale.clamp(0.1, 2.0),
          min: 0.1,
          max: 2.0,
          onChanged: (value) {
            ref
                .read(timelineProvider.notifier)
                .updateImageItem(item.id, item.copyWith(scale: value));
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Opacity', style: TextStyle(fontSize: 11)),
            const Spacer(),
            Text(
              '${(item.opacity * 100).round()}%',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        Slider(
          value: item.opacity.clamp(0.0, 1.0),
          min: 0.0,
          max: 1.0,
          onChanged: (value) {
            ref
                .read(timelineProvider.notifier)
                .updateImageItem(item.id, item.copyWith(opacity: value));
          },
        ),
      ],
    );
  }

  Widget _buildAudioProperties(AudioTimelineItem item) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const Text('Volume', style: TextStyle(fontSize: 11)),
            const Spacer(),
            Text(
              '${(item.volume * 100).round()}%',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        Slider(
          value: item.volume,
          min: 0.0,
          max: 2.0,
          onChanged: (value) {
            ref
                .read(timelineProvider.notifier)
                .updateAudioItem(item.id, item.copyWith(volume: value));
          },
        ),
      ],
    );
  }

  Widget _buildLayersPanel() {
    final timelineState = ref.watch(timelineProvider);
    final allItems = timelineState.allItems;

    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_outlined, size: 40, color: Colors.grey[600]),
            const SizedBox(height: 12),
            Text(
              'No layers yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: allItems.length,
      onReorder: (oldIndex, newIndex) {
        ref
            .read(timelineProvider.notifier)
            .reorderItems(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final item = allItems[index];
        return ListTile(
          key: ValueKey(item.id),
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(_getItemIcon(item), size: 18),
          title: Text(
            _getItemLabel(item),
            style: const TextStyle(fontSize: 12),
          ),
          subtitle: Text(
            _formatTime(item.duration),
            style: const TextStyle(fontSize: 10),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  timelineState.hiddenItems.contains(item.id)
                      ? Icons.visibility_off
                      : Icons.visibility,
                  size: 16,
                ),
                onPressed: () =>
                    ref.read(timelineProvider.notifier).toggleHideItem(item.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28),
              ),
              IconButton(
                icon: Icon(
                  timelineState.lockedItems.contains(item.id)
                      ? Icons.lock
                      : Icons.lock_open,
                  size: 16,
                ),
                onPressed: () =>
                    ref.read(timelineProvider.notifier).toggleLockItem(item.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28),
              ),
            ],
          ),
          selected: timelineState.selectedItemIds.contains(item.id),
          onTap: () => ref.read(timelineProvider.notifier).selectGroup(item.id),
        );
      },
    );
  }

  Widget _buildEffectsPanel() {
    final current = ref.watch(previewColorGradeProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text(
                'Video Effects',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ref
                    .read(videoEditorProvider.notifier)
                    .setPreviewColorGrade(const ColorGradeSettings()),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Reset', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.1,
            ),
            itemCount: VideoEffect.filters.length,
            itemBuilder: (context, index) {
              final effect = VideoEffect.filters[index];
              final isSelected = current == effect.settings;
              return InkWell(
                onTap: () {
                  ref
                      .read(videoEditorProvider.notifier)
                      .setPreviewColorGrade(effect.settings);
                  HapticFeedback.selectionClick();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[850],
                    border: Border.all(
                      color: isSelected
                          ? effect.color
                          : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(effect.icon, color: effect.color, size: 22),
                      const SizedBox(height: 6),
                      Text(
                        effect.name,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? effect.color : Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ RECENT PROJECTS PANEL
  // ═══════════════════════════════════════════════════════

  void _showRecentProjectsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Recent Projects',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Projects list
              Expanded(child: _buildRecentProjectsList(scrollController)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentProjectsList(ScrollController scrollController) {
    final recentProjects = ref.watch(recentProjectsProvider);

    if (recentProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No recent projects',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: recentProjects.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final project = recentProjects[index];
        return _buildRecentProjectItem(project);
      },
    );
  }

  Widget _buildRecentProjectItem(VideoProject project) {
    final duration = _formatTime(project.videoDuration);
    final modified = _formatDate(project.modifiedAt);

    return ListTile(
      leading: Container(
        width: 56,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.video_library, size: 24, color: Colors.grey[600]),
      ),
      title: Text(
        project.name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$duration • $modified',
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
      trailing: PopupMenuButton(
        icon: const Icon(Icons.more_vert, size: 18),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'open',
            child: Row(
              children: [
                Icon(Icons.folder_open, size: 18),
                SizedBox(width: 8),
                Text('Open', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'duplicate',
            child: Row(
              children: [
                Icon(Icons.copy, size: 18),
                SizedBox(width: 8),
                Text('Duplicate', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          switch (value) {
            case 'open':
              _openProject(project);
              break;
            case 'duplicate':
              _duplicateProject(project);
              break;
            case 'delete':
              _deleteProject(project);
              break;
          }
        },
      ),
      onTap: () {
        Navigator.pop(context);
        _openProject(project);
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ STATE SCREENS
  // ═══════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 12),
          Text(
            'Initializing...',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(videoEditorProvider.notifier).clearError();
                _initialize();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.video_library_outlined,
            color: const Color(0xFF6C63FF),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Start a New Video Project',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose how you would like to start editing',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              // Start Blank Canvas Project
              ElevatedButton.icon(
                onPressed: () {
                  ref
                      .read(videoEditorProvider.notifier)
                      .createBlankProject();
                  HapticFeedback.mediumImpact();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome, size: 20),
                label: const Text(
                  'Blank Project',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              // Import Video Clip
              OutlinedButton.icon(
                onPressed: _pickVideo,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.video_call, size: 20),
                label: const Text('Import Video'),
              ),

              // Stock Pixabay Video
              OutlinedButton.icon(
                onPressed: () => PixabayVideoPickerSheet.show(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF6C63FF)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.movie_creation_outlined,
                    size: 20, color: Color(0xFF6C63FF)),
                label: const Text('Stock Videos'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MORE TOOLS MENU - WITH EXPORT
  // ═══════════════════════════════════════════════════════

  void _showMoreToolsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'More Tools',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
                children: [
                  _buildGridTool(
                    EditorTool.image,
                    Icons.image_rounded,
                    'Image',
                  ),
                  _buildGridTool(
                    EditorTool.music,
                    Icons.music_note_rounded,
                    'Music',
                  ),
                  _buildGridTool(
                    EditorTool.merge,
                    Icons.merge_rounded,
                    'Merge',
                  ),
                  _buildGridTool(
                    EditorTool.extract,
                    Icons.call_split_rounded,
                    'Extract',
                  ),
                  _buildGridTool(
                    EditorTool.aiImage,
                    Icons.auto_awesome_rounded,
                    'AI Image',
                  ),
                  _buildGridTool(
                    EditorTool.aiVideo,
                    Icons.smart_display_rounded,
                    'AI Video',
                  ),
                  _buildGridTool(
                    EditorTool.library,
                    Icons.collections_rounded,
                    'Library',
                  ),
                  // EXPORT BUTTON - IN MORE MENU
                  _buildGridTool(
                    EditorTool.export,
                    Icons.save_alt_rounded,
                    'Export',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridTool(EditorTool tool, IconData icon, String label) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        HapticFeedback.selectionClick();
        _selectTool(tool);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800]?.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(VideoProject? project) {
    if (project == null) return;

    final controller = TextEditingController(text: project.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Project'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Project Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(projectProvider.notifier)
                  .renameProject(project.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTIONS
  // ═══════════════════════════════════════════════════════

  void _selectTool(EditorTool tool) {
    ref.read(videoEditorProvider.notifier).selectTool(tool);

    switch (tool) {
      case EditorTool.trim:
        _showSheet(const TrimSheet());
        break;
      case EditorTool.text:
        _showSheet(const TextSheet());
        break;
      case EditorTool.colorGrade:
        _showSheet(const ColorSheet());
        break;
      case EditorTool.audio:
        _showSheet(const AudioSheet());
        break;
      case EditorTool.library:
        _showSheet(const LibrarySheet());
        break;
      case EditorTool.export:
        _showSheet(const ExportSheet()); // Export opens as bottom sheet
        break;
      case EditorTool.image:
        _addImageFromPicker();
        break;
      case EditorTool.music:
        _pickMusicFile();
        break;
      case EditorTool.merge:
        _showSheet(const MergeSheet());
        break;
      case EditorTool.extract:
        _extractAudioFromVideo();
        break;
      case EditorTool.aiImage:
        _showAiImageSheet();
        break;
      case EditorTool.aiVideo:
        _showSuccess('AI Video coming soon');
        break;
      default:
        break;
    }
  }

  void _showSheet(Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => sheet,
    );
  }

  void _showAiImageSheet() {
    final tl = ref.read(timelineProvider);
    final project = ref.read(currentProjectProvider);
    final totalDuration = _getTotalTimelineDuration(tl, project);
    final currentPos = tl.currentPosition;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: AiTab(
                videoDuration: totalDuration,
                currentPosition: currentPos,
                onImageGenerated: (ImageTimelineItem item) {
                  ref.read(timelineProvider.notifier).addImageItem(
                        imagePath: item.imagePath,
                        startTime: item.startTime,
                        duration: item.endTime - item.startTime,
                        x: item.x,
                        y: item.y,
                        scale: item.scale,
                        width: item.width,
                        height: item.height,
                      );
                  HapticFeedback.mediumImpact();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  _showSuccess('AI image added to timeline');
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _addImageFromPicker() {
    final pos = ref.read(currentPositionProvider);

    showImagePickerSheet(
      context,
      (StockImage image) {
        final path = image.localPath ?? image.fullUrl;
        if (path.isEmpty) {
          _showError('Image not downloaded yet');
          return;
        }
        ref
            .read(timelineProvider.notifier)
            .addImageItem(
              imagePath: path,
              startTime: pos,
              duration: const Duration(seconds: 3),
              width: image.width,
              height: image.height,
            );
        HapticFeedback.mediumImpact();
        if (mounted) {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) navigator.pop();
        }
        if (path.startsWith('http')) {
          _showSuccess('Image added to timeline');
        } else {
          _openImageEditor(path, image.title);
        }
      },
    );
  }

  void _openImageEditor(String path, String name) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ImageEditSheet(
        inputPath: path,
        imageName: name,
        onResult: (outputPath) {
          ref
              .read(timelineProvider.notifier)
              .addImageItem(
                imagePath: outputPath,
                startTime: ref.read(currentPositionProvider),
                duration: const Duration(seconds: 3),
              );
          HapticFeedback.mediumImpact();
          _showSuccess('Edited image added to timeline');
        },
      ),
    );
  }

  Future<void> _pickMusicFile() async {
    try {
      final result = await FilePickerService.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return;
      if (!mounted) return;

      final path = result.files.single.path!;
      final name = result.files.single.name;
      final infoResult = await ref
          .read(audioEditServiceProvider)
          .getAudioInfo(path);
      if (!mounted) return;

      if (infoResult.isFailure) {
        _showError('Could not read audio info');
        return;
      }

      final info = infoResult.requireData;
      ref
          .read(timelineProvider.notifier)
          .addAudioItem(
            audioPath: path,
            title: name,
            startTime: ref.read(currentPositionProvider),
            audioDuration: info.duration,
          );
      HapticFeedback.mediumImpact();
      _showSuccess('Music added to timeline');
    } catch (e) {
      if (mounted) _showError('Failed to pick music: $e');
    }
  }

  Future<void> _extractAudioFromVideo() async {
    final project = ref.read(currentProjectProvider);
    if (project == null || project.videoPath.isEmpty) {
      _showError('Load a video first');
      return;
    }

    try {
      final result = await ref
          .read(videoEditServiceProvider)
          .extractAudio(inputPath: project.videoPath, format: AudioFormat.mp3);
      if (result.isSuccess) {
        _showSuccess('Audio extracted');
      }
    } catch (e) {
      _showError('Failed to extract audio: $e');
    }
  }

  void _openProject(VideoProject project) {
    ref
        .read(projectProvider.notifier)
        .openProject(project.id)
        .then((result) {
          if (result.isSuccess) {
            ref
                .read(timelineProvider.notifier)
                .loadFromProject(result.requireData);
          }
        });
  }

  void _duplicateProject(VideoProject project) {
    ref.read(projectProvider.notifier).duplicateProject(project.id);
    _showSuccess('Project duplicated');
  }

  void _deleteProject(VideoProject project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(projectProvider.notifier).deleteProject(project.id);
              Navigator.pop(context);
              _showSuccess('Project deleted');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _togglePlayPause() {
    final tl = ref.read(timelineProvider);
    final project = ref.read(currentProjectProvider);
    final totalDuration = _getTotalTimelineDuration(tl, project);
    final isPlaying = tl.isPlaying;
    if (!isPlaying) {
      if (totalDuration > Duration.zero &&
          tl.currentPosition >= totalDuration) {
        _seekToTimelinePosition(Duration.zero);
      }
      ref.read(timelineProvider.notifier).setPlaying(true);
      ref.read(videoEditorProvider.notifier).setPreviewPlaying(true);
      _previewKey.currentState?.play();
    } else {
      ref.read(timelineProvider.notifier).setPlaying(false);
      ref.read(videoEditorProvider.notifier).setPreviewPlaying(false);
      _previewKey.currentState?.pause();
    }
    _syncAudio();
  }

  void _previousFrame() {
    final current = ref.read(timelineProvider).currentPosition;
    _seekToTimelinePosition(current - const Duration(milliseconds: 33));


  }

  void _nextFrame() {
    final current = ref.read(timelineProvider).currentPosition;
    _seekToTimelinePosition(current + const Duration(milliseconds: 33));
  }

  void _undo() {
    final project = ref.read(projectHistoryProvider.notifier).undo();
    if (project != null) {
      ref.read(projectProvider.notifier).updateCurrentProject(project);
      ref.read(timelineProvider.notifier).loadFromProject(project);
    }
  }

  void _redo() {
    final project = ref.read(projectHistoryProvider.notifier).redo();
    if (project != null) {
      ref.read(projectProvider.notifier).updateCurrentProject(project);
      ref.read(timelineProvider.notifier).loadFromProject(project);
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePickerService.pickFiles(
        type: FileType.video,
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;
      if (!mounted) return;

      final loadResult = await ref
          .read(videoEditorProvider.notifier)
          .loadVideo(path);
      if (loadResult.isFailure && mounted) {
        _showError('Failed to load video: ${loadResult.error}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to pick video: $e');
      }
    }
  }

  Future<void> _handleBack() async {
    final hasChanges = ref.read(hasUnsavedChangesProvider);

    if (hasChanges) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('Save changes before leaving?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (result == null) return;
      if (result) {
        await _saveProject();
      }
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _saveProject() async {
    final result = await ref.read(projectProvider.notifier).saveProject();
    if (mounted) {
      if (result.isSuccess) {
        _showSuccess('Project saved');
      } else {
        _showError('Failed to save project: ${result.error}');
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getPanelTitle(EditorPanel panel) {
    switch (panel) {
      case EditorPanel.properties:
        return 'Properties';
      case EditorPanel.layers:
        return 'Layers';
      case EditorPanel.effects:
        return 'Effects';
      default:
        return '';
    }
  }

  IconData _getItemIcon(TimelineItem item) {
    if (item is TextTimelineItem) return Icons.text_fields;
    if (item is ImageTimelineItem) return Icons.image;
    if (item is AudioTimelineItem) return Icons.audiotrack;
    return Icons.layers;
  }

  String _getItemLabel(TimelineItem item) {
    if (item is TextTimelineItem) return item.text;
    if (item is ImageTimelineItem) return 'Image';
    if (item is AudioTimelineItem) {
      return item.title.isEmpty ? 'Audio' : item.title;
    }
    return 'Item';
  }
}
