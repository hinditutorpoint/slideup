import 'dart:async';
import 'package:file_picker/file_picker.dart';
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
import 'components/timeline_thumbnails.dart';
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
    with SingleTickerProviderStateMixin {
  final GlobalKey<PreviewComponentState> _previewKey = GlobalKey();
  late AnimationController _animationController;
  Timer? _positionTimer;

  // Fixed heights
  static const double _topBarHeight = 38.0;
  static const double _bottomToolbarHeight = 60.0;
  static const double _playbackControlsHeight = 34.0;
  static const double _thumbnailTimelineHeight = 48.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
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

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final editorState = ref.read(videoEditorProvider);
      if (editorState.isPreviewPlaying) {
        final position = _previewKey.currentState?.getCurrentPosition();
        if (position != null) {
          ref.read(videoEditorProvider.notifier).setPreviewPosition(position);
          ref.read(timelineProvider.notifier).setCurrentPosition(position);
        }
      }
    });
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
    _positionTimer?.cancel();
    _animationController.dispose();
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
                      _playbackControlsHeight -
                      _thumbnailTimelineHeight;

                  final editorHeight = remainingHeight;

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

                      // THUMBNAIL TIMELINE
                      if (project != null)
                        SizedBox(
                          height: _thumbnailTimelineHeight,
                          child: _buildTimeline(state, project),
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
                              totalDuration: project.videoDuration,
                              onSeek: (position) {
                                _previewKey.currentState?.seekTo(position);
                                ref
                                    .read(timelineProvider.notifier)
                                    .setCurrentPosition(position);
                              },
                              onItemSelect: (itemId) {
                                ref
                                    .read(videoEditorProvider.notifier)
                                    .togglePanel(EditorPanel.properties);
                              },
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
              child: PreviewComponent(
                key: _previewKey,
                videoPath: project.videoPath,
                showControls: false,
                showOverlays: true,
                enableInteraction: true,
                colorGrade: state.previewColorGrade,
                volume: state.isMuted ? 0 : state.volume,
                showGrid: state.showGrid,
                showSafeArea: state.showSafeArea,
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
                    _formatTime(project.effectiveDuration),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey[400],
                    ),
                  ),
              ],
            ),
          ),

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
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TIMELINE
  // ═══════════════════════════════════════════════════════

  Widget _buildTimeline(VideoEditorState state, VideoProject? project) {
    if (project == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Stack(
        children: [
          if (state.thumbnails.isNotEmpty)
            TimelineThumbnails(
              project: project,
              thumbnails: state.thumbnails,
              trimStart: project.trimStart,
              trimEnd: project.trimEnd,
              onSeek: (position) {
                _previewKey.currentState?.seekTo(position);
                ref
                    .read(timelineProvider.notifier)
                    .setCurrentPosition(position);
                ref
                    .read(videoEditorProvider.notifier)
                    .setPreviewPosition(position);
              },
              onTrimChange: (start, end) {
                ref.read(projectProvider.notifier).updateTrim(start, end);
              },
            )
          else
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading...',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
        ],
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

  Widget _buildTextProperties(TextTimelineItem item) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          controller: TextEditingController(text: item.text),
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
          value: item.style.fontSize,
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
          value: item.scale,
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
          value: item.opacity,
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
          Icon(Icons.video_library_outlined, color: Colors.grey[600], size: 64),
          const SizedBox(height: 20),
          Text(
            'No video loaded',
            style: TextStyle(fontSize: 16, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickVideo,
            icon: const Icon(Icons.add),
            label: const Text('Select Video'),
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
        _showAiImageTab();
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
      final result = await FilePicker.platform.pickFiles(
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
          .extractAudio(inputPath: project.videoPath);
      if (!mounted) return;

      if (result.isFailure) {
        _showError('Extract failed: ${result.error}');
        return;
      }

      final audioPath = result.requireData;
      final infoResult = await ref
          .read(audioEditServiceProvider)
          .getAudioInfo(audioPath);
      if (!mounted) return;

      ref
          .read(timelineProvider.notifier)
          .addAudioItem(
            audioPath: audioPath,
            title: 'Extracted audio',
            startTime: ref.read(currentPositionProvider),
            audioDuration:
                infoResult.isSuccess ? infoResult.requireData.duration : project.videoDuration,
          );
      HapticFeedback.mediumImpact();
      _showSuccess('Audio extracted and added to timeline');
    } catch (e) {
      if (mounted) _showError('Extract failed: $e');
    }
  }

  void _showAiImageTab() {
    final videoDuration = ref.read(currentProjectProvider)?.videoDuration ??
        const Duration(seconds: 30);
    final currentPosition = ref.read(currentPositionProvider);

    _showSheet(
      AiTab(
        videoDuration: videoDuration,
        currentPosition: currentPosition,
        onImageGenerated: (item) {
          ref.read(timelineProvider.notifier).addGeneratedImage(item);
          HapticFeedback.mediumImpact();
          _showSuccess('AI image added to timeline');
        },
      ),
    );
  }

  Future<void> _saveProject() async {
    try {
      await ref.read(projectProvider.notifier).saveProject();
      if (mounted) {
        _showSuccess('Project saved successfully');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save project: $e');
      }
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
    final isPlaying = ref.read(timelineProvider).isPlaying;
    ref.read(timelineProvider.notifier).setPlaying(!isPlaying);
    ref.read(videoEditorProvider.notifier).setPreviewPlaying(!isPlaying);

    if (!isPlaying) {
      _previewKey.currentState?.play();
    } else {
      _previewKey.currentState?.pause();
    }
  }

  void _previousFrame() {
    final current = ref.read(timelineProvider).currentPosition;
    final newPosition = current - const Duration(milliseconds: 33);
    if (newPosition >= Duration.zero) {
      _previewKey.currentState?.seekTo(newPosition);
      ref.read(timelineProvider.notifier).setCurrentPosition(newPosition);
    }
  }

  void _nextFrame() {
    final current = ref.read(timelineProvider).currentPosition;
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    final newPosition = current + const Duration(milliseconds: 33);
    if (newPosition <= project.videoDuration) {
      _previewKey.currentState?.seekTo(newPosition);
      ref.read(timelineProvider.notifier).setCurrentPosition(newPosition);
    }
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
      final result = await FilePicker.platform.pickFiles(
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
