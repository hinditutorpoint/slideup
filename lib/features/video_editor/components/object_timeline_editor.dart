import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import '../../../services/file_picker_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/timeline_provider.dart';
import '../providers/video_editor_provider.dart';
import '../services/waveform_service.dart';
import '../sheets/transition_sheet.dart';
import '../sheets/solid_color_sheet.dart';
import '../sheets/pixabay_video_picker_sheet.dart';
import '../sheets/local_video_browser_sheet.dart';
import '../tabs/ai_tab.dart';

class _CompactDims {
  final double screenHeight;
  final double screenWidth;

  _CompactDims(this.screenHeight, this.screenWidth);

  bool get isVerySmall => screenHeight < 600;
  bool get isSmall => screenHeight < 700;

  double get trackHeight => isVerySmall ? 24 : (isSmall ? 28 : 32);
  double get trackSpacing => 2;
  double get rulerHeight => isVerySmall ? 14 : (isSmall ? 16 : 18);
  double get trackLabelWidth => isVerySmall ? 40 : (isSmall ? 44 : 48);
  double get toolbarHeight => isVerySmall ? 22 : (isSmall ? 24 : 26);

  double get iconXS => isVerySmall ? 10 : 11;
  double get iconS => isVerySmall ? 11 : 12;
  double get iconM => isVerySmall ? 12 : 14;

  double get fontXS => isVerySmall ? 7 : 8;
  double get fontS => isVerySmall ? 8 : 9;
  double get fontM => isVerySmall ? 9 : 10;
  double get fontL => isVerySmall ? 10 : 11;

  double get paddingXS => 2;
  double get paddingS => 3;
  double get paddingM => 4;

  double get resizeHandleWidth => 6;
  double get resizeHandleIndicatorWidth => 2;
  double get resizeHandleIndicatorHeight => 10;

  double get playheadWidth => 1.5;
  double get playheadDotSize => 8;

  double get minItemWidth => 20;
}

class ObjectTimelineEditor extends ConsumerStatefulWidget {
  final Duration totalDuration;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<String>? onItemSelect;

  const ObjectTimelineEditor({
    super.key,
    required this.totalDuration,
    this.onSeek,
    this.onItemSelect,
  });

  @override
  ConsumerState<ObjectTimelineEditor> createState() =>
      _ObjectTimelineEditorState();
}

class _ObjectTimelineEditorState extends ConsumerState<ObjectTimelineEditor> {
  final ScrollController _scrollController = ScrollController();
  late _CompactDims _dims;

  String? _draggingItemId;
  TimelineItemType? _draggingItemType;
  _DragMode _dragMode = _DragMode.none;
  double _dragStartX = 0;
  Duration _originalStartTime = Duration.zero;
  Duration _originalDuration = Duration.zero;
  bool _isMultiDrag = false;

  // Snap state
  static const double _snapThresholdPx = 6.0;
  double? _snapLineX;

  double get _pixelsPerSecond {
    final zoom = ref.watch(timelineProvider).zoomLevel;
    return 50.0 * zoom;
  }

  double get _totalWidth {
    return widget.totalDuration.inMilliseconds / 1000 * _pixelsPerSecond;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    _dims = _CompactDims(size.height, size.width);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TimelineState>(timelineProvider, (prev, next) {
      if (!mounted || _dragMode != _DragMode.none) return;

      if (_scrollController.hasClients) {
        final playheadX =
            next.currentPosition.inMilliseconds / 1000 * _pixelsPerSecond +
            _dims.trackLabelWidth;
        final viewportWidth = _scrollController.position.viewportDimension;
        final currentOffset = _scrollController.offset;
        final maxScroll = _scrollController.position.maxScrollExtent;

        if (next.isPlaying) {
          // Keep playhead comfortably visible in viewport during playback
          if (playheadX > currentOffset + viewportWidth - 80 ||
              playheadX < currentOffset) {
            final targetOffset =
                (playheadX - viewportWidth * 0.3).clamp(0.0, maxScroll);
            _scrollController.jumpTo(targetOffset);
          }
        } else if (prev?.currentPosition != next.currentPosition) {
          // If seek position jumps offscreen while paused, scroll to reveal it
          if (playheadX < currentOffset ||
              playheadX > currentOffset + viewportWidth - 40) {
            final targetOffset =
                (playheadX - viewportWidth * 0.5).clamp(0.0, maxScroll);
            _scrollController.jumpTo(targetOffset);
          }
        }
      }
    });

    final timelineState = ref.watch(timelineProvider);
    final hasItems =
        timelineState.primaryVideoClips.isNotEmpty ||
        timelineState.textItems.isNotEmpty ||
        timelineState.imageItems.isNotEmpty ||
        timelineState.audioItems.isNotEmpty;

    return Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          // Toolbar - fixed height
          SizedBox(
            height: _dims.toolbarHeight,
            child: _buildToolbar(timelineState),
          ),

          // Tracks - takes remaining space
          Expanded(
            child: hasItems ? _buildTracks(timelineState) : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(TimelineState state) {
    final hasMultiSelection = state.selectedItemIds.isNotEmpty;
    final hasSelection = hasMultiSelection ||
        state.selectedItemId != null ||
        state.selectedPrimaryClipId != null;
    final canGroup = hasMultiSelection && state.selectedItemIds.length > 1;
    final canUngroup = state.selectedItems.any((e) => e.groupId != null);
    final canCopy = hasMultiSelection ||
        state.selectedItemId != null ||
        state.selectedPrimaryClipId != null;
    final canPaste =
        state.copiedItem != null || state.copiedPrimaryClip != null;
    final canDelete = hasSelection;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Marker toggle
          SizedBox(
            width: 18,
            height: 18,
            child: IconButton(
              icon: Icon(
                Icons.flag,
                size: _dims.iconXS,
                color: _hasMarkerAt(state.currentPosition)
                    ? Colors.amber
                    : Colors.grey[400],
              ),
              onPressed: _toggleMarker,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Add/remove marker',
            ),
          ),
          const SizedBox(width: 2),

          // Razor / blade tool toggle
          SizedBox(
            width: 18,
            height: 18,
            child: IconButton(
              icon: Icon(
                Icons.content_cut,
                size: _dims.iconXS,
                color: ref.watch(videoEditorProvider).currentTool == EditorTool.razor
                    ? Colors.redAccent
                    : Colors.grey[400],
              ),
              onPressed: () {
                final current = ref.read(videoEditorProvider).currentTool;
                ref.read(videoEditorProvider.notifier).selectTool(
                      current == EditorTool.razor ? EditorTool.none : EditorTool.razor,
                    );
                HapticFeedback.selectionClick();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Razor / blade tool',
            ),
          ),
          const SizedBox(width: 4),

          // Zoom controls - compact
          SizedBox(
            width: 16,
            height: 16,
            child: IconButton(
              icon: Icon(Icons.remove, size: _dims.iconXS - 1),
              onPressed: () => _adjustZoom(-0.2),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          SizedBox(
            width: 40,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3.5),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: state.zoomLevel,
                min: 0.5,
                max: 5.0,
                onChanged: (v) =>
                    ref.read(timelineProvider.notifier).setZoomLevel(v),
              ),
            ),
          ),
          SizedBox(
            width: 16,
            height: 16,
            child: IconButton(
              icon: Icon(Icons.add, size: _dims.iconXS - 1),
              onPressed: () => _adjustZoom(0.2),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '${(state.zoomLevel * 100).toInt()}%',
            style: TextStyle(fontSize: _dims.fontXS, color: Colors.grey[400]),
          ),
          const Spacer(),

          // Group button
          if (canGroup) ...[
            SizedBox(
              width: 22,
              height: 22,
              child: IconButton(
                icon: Icon(
                  Icons.group,
                  size: _dims.iconS,
                  color: Colors.grey[300],
                ),
                onPressed: () {
                  ref.read(timelineProvider.notifier).groupSelectedItems();
                  HapticFeedback.selectionClick();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Group selected',
              ),
            ),
            const SizedBox(width: 2),
          ],

          // Ungroup button
          if (canUngroup) ...[
            SizedBox(
              width: 22,
              height: 22,
              child: IconButton(
                icon: Icon(
                  Icons.group_off,
                  size: _dims.iconS,
                  color: Colors.grey[300],
                ),
                onPressed: () {
                  ref.read(timelineProvider.notifier).ungroupSelectedItems();
                  HapticFeedback.selectionClick();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Ungroup selected',
              ),
            ),
            const SizedBox(width: 2),
          ],

          // Delete button (visible when selection active)
          if (canDelete) ...[
            SizedBox(
              width: 22,
              height: 22,
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: _dims.iconS,
                  color: Colors.red[300],
                ),
                onPressed: () {
                  ref.read(timelineProvider.notifier).deleteSelected();
                  HapticFeedback.mediumImpact();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete',
              ),
            ),
            const SizedBox(width: 2),
          ],

          // Copy button (visible when selection active)
          if (canCopy) ...[
            SizedBox(
              width: 22,
              height: 22,
              child: IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  size: _dims.iconXS + 1,
                  color: Colors.white70,
                ),
                onPressed: () {
                  ref.read(timelineProvider.notifier).copySelected();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Item copied'),
                      duration: Duration(milliseconds: 700),
                    ),
                  );
                  HapticFeedback.selectionClick();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Copy',
              ),
            ),
            const SizedBox(width: 2),
          ],

          // Paste button (visible when clipboard has item/clip)
          if (canPaste) ...[
            SizedBox(
              width: 22,
              height: 22,
              child: IconButton(
                icon: Icon(
                  Icons.paste_rounded,
                  size: _dims.iconXS + 1,
                  color: Colors.white70,
                ),
                onPressed: () {
                  ref.read(timelineProvider.notifier).pasteCopied();
                  HapticFeedback.selectionClick();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Paste',
              ),
            ),
            const SizedBox(width: 2),
          ],
          const SizedBox(width: 2),

          // Add button - compact
          GestureDetector(
            onTap: _showAddItemDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: _dims.iconXS, color: Colors.blue),
                  const SizedBox(width: 2),
                  Text(
                    'Add',
                    style: TextStyle(
                      fontSize: _dims.fontXS,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTracks(TimelineState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(
              _totalWidth + _dims.trackLabelWidth,
              constraints.maxWidth,
            ),
            height: constraints.maxHeight,
            child: Stack(
              children: [
                // Scrollable content
                SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time ruler
                      SizedBox(
                        height: _dims.rulerHeight,
                        child: _buildTimeRuler(),
                      ),

                      // Primary Magnetic Video Track
                      if (state.primaryVideoClips.isNotEmpty)
                        _buildPrimaryMagneticTrack(state.primaryVideoClips),

                      // Text track
                      if (state.textItems.isNotEmpty)
                        _buildTrack(
                          label: 'Text',
                          icon: Icons.text_fields,
                          color: Colors.orange,
                          items: state.textItems,
                          itemType: TimelineItemType.text,
                          selectedIds: state.selectedItemIds,
                        ),

                      // Image track
                      if (state.imageItems.isNotEmpty)
                        _buildTrack(
                          label: 'Img',
                          icon: Icons.image,
                          color: Colors.green,
                          items: state.imageItems,
                          itemType: TimelineItemType.image,
                          selectedIds: state.selectedItemIds,
                        ),

                      // Audio track
                      if (state.audioItems.isNotEmpty)
                        _buildTrack(
                          label: 'Audio',
                          icon: Icons.audiotrack,
                          color: Colors.purple,
                          items: state.audioItems,
                          itemType: TimelineItemType.audio,
                          selectedIds: state.selectedItemIds,
                        ),

                      // Video overlay track (PiP layers)
                      if (state.videoOverlayItems.isNotEmpty)
                        _buildTrack(
                          label: 'Vid Layer',
                          icon: Icons.layers,
                          color: const Color(0xFFE040FB),
                          items: state.videoOverlayItems,
                          itemType: TimelineItemType.video,
                          selectedIds: state.selectedItemIds,
                        ),

                      // Solid color layer track
                      if (state.solidColorItems.isNotEmpty)
                        _buildTrack(
                          label: 'Color',
                          icon: Icons.color_lens,
                          color: Colors.teal,
                          items: state.solidColorItems,
                          itemType: TimelineItemType.solidColor,
                          selectedIds: state.selectedItemIds,
                        ),
                    ],
                  ),
                ),

                // Playhead
                _buildPlayhead(state.currentPosition),

                // Snap indicator line
                if (_snapLineX != null)
                  Positioned(
                    left: _snapLineX,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1,
                      color: const Color(0xFF00E5FF),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeRuler() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _seekFromRulerX(details.localPosition.dx),
      onHorizontalDragUpdate: (details) =>
          _seekFromRulerX(details.localPosition.dx),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          border: Border(
            bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
          ),
        ),
        child: CustomPaint(
          size: Size(_totalWidth + _dims.trackLabelWidth, _dims.rulerHeight),
          painter: _TimeRulerPainter(
            pixelsPerSecond: _pixelsPerSecond,
            totalDuration: widget.totalDuration,
            trackLabelWidth: _dims.trackLabelWidth,
            fontSize: _dims.fontXS,
            markers: ref.watch(timelineProvider).markers,
          ),
        ),
      ),
    );
  }

  void _seekFromRulerX(double localX) {
    final x = localX - _dims.trackLabelWidth;
    if (x < 0) return;
    final ms = (x / _pixelsPerSecond * 1000).toInt();
    final newPos = Duration(milliseconds: ms);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > widget.totalDuration ? widget.totalDuration : newPos);
    ref.read(timelineProvider.notifier).setCurrentPosition(clamped);
    widget.onSeek?.call(clamped);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PRIMARY MAGNETIC TRACK RENDERER
  // ═══════════════════════════════════════════════════════

  Widget _buildPrimaryMagneticTrack(List<PrimaryVideoClip> clips) {
    Duration offset = Duration.zero;
    final selectedId = ref.watch(timelineProvider).selectedPrimaryClipId;

    return Container(
      height: _dims.trackHeight + 6,
      margin: EdgeInsets.only(top: _dims.trackSpacing),
      child: Row(
        children: [
          // Track label
          Container(
            width: _dims.trackLabelWidth,
            padding: EdgeInsets.symmetric(horizontal: _dims.paddingXS),
            child: Row(
              children: [
                Icon(
                  Icons.video_collection,
                  size: _dims.iconXS,
                  color: Colors.blueAccent,
                ),
                SizedBox(width: _dims.paddingXS),
                Expanded(
                  child: Text(
                    'Video',
                    style: TextStyle(
                      fontSize: _dims.fontXS,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Track content
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Background track line
                Container(
                  height: _dims.trackHeight + 6,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),

                // Sequential Clip Blocks & Inter-Clip Transition Node Buttons
                ...List.generate(clips.length, (index) {
                  final clip = clips[index];
                  final clipStart = offset;
                  final startX =
                      clipStart.inMilliseconds / 1000 * _pixelsPerSecond;
                  final width = math.max(
                    _dims.minItemWidth,
                    clip.effectiveDuration.inMilliseconds /
                        1000 *
                        _pixelsPerSecond,
                  );

                  final t = clip.transitionOut;
                  offset += clip.effectiveDuration;
                  if (t.hasTransition && index < clips.length - 1) {
                    offset -= t.duration;
                  }

                  final isLast = index == clips.length - 1;
                  final isSelected = clip.id == selectedId;

                  return Positioned(
                    left: startX,
                    top: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Magnetic video clip block (tap to select or razor split)
                        GestureDetector(
                          onTap: () {
                            final tool = ref.read(videoEditorProvider).currentTool;
                            if (tool == EditorTool.razor) {
                              final pos = ref.read(timelineProvider).currentPosition;
                              ref.read(timelineProvider.notifier).splitPrimaryClipAt(
                                    clip.id,
                                    pos,
                                  );
                            } else {
                              ref
                                  .read(timelineProvider.notifier)
                                  .selectPrimaryClip(clip.id);
                            }
                          },
                          child: Container(
                            width: width,
                            height: _dims.trackHeight + 6,
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[900],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.blueAccent.withValues(alpha: 0.8),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Frame Filmstrip / Thumbnails directly inside the clip
                                  _buildPrimaryClipThumbnails(clip, width),

                                  // Contrast gradient overlay for label visibility
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.5),
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.6),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Clip info
                                  Row(
                                    children: [
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.movie_outlined,
                                        size: _dims.iconXS,
                                        color: Colors.white,
                                        shadows: const [
                                          Shadow(blurRadius: 3, color: Colors.black),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Clip ${index + 1}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: _dims.fontXS,
                                            fontWeight: FontWeight.bold,
                                            shadows: const [
                                              Shadow(blurRadius: 3, color: Colors.black),
                                              Shadow(blurRadius: 6, color: Colors.black),
                                            ],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Speed keyframe dots on primary clip
                        ..._buildPrimaryClipSpeedDots(clip, width),

                        // Inter-clip transition (+) button
                        if (!isLast)
                          GestureDetector(
                            onTap: () {
                              TransitionSheet.show(
                                context,
                                ref,
                                clipIndex: index,
                                current: t,
                              );
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: t.hasTransition
                                    ? const Color(0xFF6C63FF)
                                    : Colors.white24,
                                shape: BoxShape.circle,
                                boxShadow: t.hasTransition
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF6C63FF)
                                              .withValues(alpha: 0.5),
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  t.hasTransition ? t.type.emoji : '➕',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrack<T extends TimelineItem>({
    required String label,
    required IconData icon,
    required Color color,
    required List<T> items,
    required TimelineItemType itemType,
    required Set<String> selectedIds,
  }) {
    final tl = ref.watch(timelineProvider);
    final isMuted = tl.mutedTracks.contains(label);
    final isSolo = tl.soloTracks.contains(label);
    final isLocked = tl.lockedTracks.contains(label);
    final hasSolo = tl.soloTracks.isNotEmpty;
    final effectivelyMuted = isMuted || (hasSolo && !isSolo);

    return Container(
      height: _dims.trackHeight,
      margin: EdgeInsets.only(top: _dims.trackSpacing),
      child: Row(
        children: [
          // Track label + controls
          SizedBox(
            width: _dims.trackLabelWidth + 36,
            child: Row(
              children: [
                SizedBox(width: _dims.paddingXS),
                Icon(icon, size: _dims.iconXS, color: color),
                SizedBox(width: 2),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: _dims.fontXS,
                      color: effectivelyMuted ? Colors.grey[600] : color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Mute button
                GestureDetector(
                  onTap: () => ref.read(timelineProvider.notifier).toggleMuteTrack(label),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isMuted ? Colors.red[800] : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      size: 9,
                      color: isMuted ? Colors.white : Colors.grey[500],
                    ),
                  ),
                ),
                SizedBox(width: 1),
                // Solo button
                GestureDetector(
                  onTap: () => ref.read(timelineProvider.notifier).toggleSoloTrack(label),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isSolo ? Colors.amber[800] : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(
                      child: Text(
                        'S',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: isSolo ? Colors.white : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 1),
                // Lock button
                GestureDetector(
                  onTap: () => ref.read(timelineProvider.notifier).toggleLockTrack(label),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isLocked ? Colors.blue[800] : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Icon(
                      isLocked ? Icons.lock : Icons.lock_open,
                      size: 9,
                      color: isLocked ? Colors.white : Colors.grey[500],
                    ),
                  ),
                ),
                SizedBox(width: _dims.paddingXS),
              ],
            ),
          ),

          // Track content
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Track background
                Container(
                  height: _dims.trackHeight,
                  decoration: BoxDecoration(
                    color: effectivelyMuted
                        ? Colors.white.withValues(alpha: 0.01)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Items
                ...items.map(
                  (item) => _buildTrackItem(
                    item: item,
                    color: effectivelyMuted ? Colors.grey[700]! : color,
                    isSelected: selectedIds.contains(item.id),
                    itemType: itemType,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackItem({
    required TimelineItem item,
    required Color color,
    required bool isSelected,
    required TimelineItemType itemType,
  }) {
    final startX = item.startTime.inMilliseconds / 1000 * _pixelsPerSecond;
    final width = math.max(
      _dims.minItemWidth,
      item.duration.inMilliseconds / 1000 * _pixelsPerSecond,
    );

    final label = _getItemLabel(item);

    return Positioned(
      left: startX,
      top: 0,
      child: GestureDetector(
        onTap: () => _selectItem(item.id, itemType),
        onLongPress: () => _toggleSelectItem(item.id, itemType),
        onDoubleTap: () => _showEditTimingDialog(item, itemType),
        onPanStart: (details) => _onItemDragStart(item, details, itemType),
        onPanUpdate: (details) => _onItemDragUpdate(details),
        onPanEnd: (_) => _onItemDragEnd(),
        child: Container(
          width: width,
          height: _dims.trackHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSelected
                  ? [color.withValues(alpha: 0.6), color.withValues(alpha: 0.4)]
                  : [
                      color.withValues(alpha: 0.4),
                      color.withValues(alpha: 0.25),
                    ],
            ),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Stack(
            children: [
              // Audio waveform background
              if (itemType == TimelineItemType.audio &&
                  item is AudioTimelineItem &&
                  item.waveformData != null &&
                  item.waveformData!.isNotEmpty)
                Positioned.fill(
                  child: CustomPaint(
                    painter: WaveformPainter(
                      peaks: WaveformService.bytesToPeaks(item.waveformData!),
                      color: color,
                      playedColor: Colors.white,
                    ),
                  ),
                ),

              // Video Overlay frame thumbnail background
              if (itemType == TimelineItemType.video &&
                  item is VideoOverlayTimelineItem &&
                  item.thumbnail != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Opacity(
                      opacity: 0.55,
                      child: Image.memory(
                        item.thumbnail!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),

              // Content - centered
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: _dims.paddingS),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _dims.fontXS,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),

              // Left resize handle
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onPanStart: (d) => _onResizeStart(item, d, itemType, true),
                    onPanUpdate: (d) => _onResizeUpdate(d, true),
                    onPanEnd: (_) => _onItemDragEnd(),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: Container(
                        width: _dims.resizeHandleWidth,
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            width: _dims.resizeHandleIndicatorWidth,
                            height: _dims.resizeHandleIndicatorHeight,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Right resize handle
              if (isSelected)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onPanStart: (d) => _onResizeStart(item, d, itemType, false),
                    onPanUpdate: (d) => _onResizeUpdate(d, false),
                    onPanEnd: (_) => _onItemDragEnd(),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: Container(
                        width: _dims.resizeHandleWidth,
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            width: _dims.resizeHandleIndicatorWidth,
                            height: _dims.resizeHandleIndicatorHeight,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Keyframe dots
              if (item.duration.inMilliseconds > 0)
                ..._buildKeyframeDots(item, width),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildKeyframeDots(TimelineItem item, double blockWidth) {
    final kfs = ref.read(timelineProvider).keyframes[item.id];
    if (kfs == null || kfs.isEmpty) return [];
    final durMs = item.duration.inMilliseconds;
    if (durMs <= 0) return [];
    return kfs.map((kf) {
      final dx = (kf.time.inMilliseconds / durMs) * blockWidth;
      final hasPos = kf.x != null || kf.y != null;
      final hasScale = kf.scale != null;
      final hasRot = kf.rotation != null;
      final hasOp = kf.opacity != null;
      final hasVol = kf.volume != null;
      final hasSpd = kf.speed != null;
      final count = [hasPos, hasScale, hasRot, hasOp, hasVol, hasSpd].where((b) => b).length;
      final dotColor = count > 1
          ? Colors.amber
          : hasPos
              ? const Color(0xFF00E5FF)
              : hasScale
                  ? const Color(0xFF76FF03)
                  : hasRot
                      ? const Color(0xFFFF6D00)
                      : hasOp
                          ? Colors.white
                          : hasSpd
                              ? Colors.orangeAccent
                              : Colors.orange;
      return Positioned(
        left: dx - 3,
        bottom: 2,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black54, width: 0.5),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildPrimaryClipSpeedDots(PrimaryVideoClip clip, double blockWidth) {
    final kfs = ref.read(timelineProvider).keyframes[clip.id];
    if (kfs == null || kfs.isEmpty) return [];
    final speedKfs = kfs.where((k) => k.speed != null).toList();
    if (speedKfs.isEmpty) return [];
    final durMs = clip.effectiveDuration.inMilliseconds;
    if (durMs <= 0) return [];
    return speedKfs.map((kf) {
      final dx = (kf.time.inMilliseconds / durMs) * blockWidth;
      final speed = kf.speed ?? 1.0;
      final dotColor = speed < 1.0
          ? Colors.blueAccent
          : speed > 1.0
              ? Colors.orangeAccent
              : Colors.grey;
      return Positioned(
        left: dx - 3,
        bottom: 2,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black54, width: 0.5),
          ),
        ),
      );
    }).toList();
  }

  /// Builds a filmstrip of frame thumbnails directly across the width of the clip.
  Widget _buildPrimaryClipThumbnails(PrimaryVideoClip clip, double width) {
    if (width <= 0) return const SizedBox.shrink();
    final editorState = ref.watch(videoEditorProvider);
    final globalThumbs = editorState.thumbnails;

    if (clip.thumbnail != null) {
      final frameWidth = (_dims.trackHeight + 6) * 1.33;
      final count = math.max(1, (width / frameWidth).ceil());

      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(count, (i) {
                return SizedBox(
                  width: frameWidth,
                  height: double.infinity,
                  child: Image.memory(
                    clip.thumbnail!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                );
              }),
            ),
          ),
        ),
      );
    }

    if (globalThumbs.isNotEmpty) {
      final frameWidth = (_dims.trackHeight + 6) * 1.33;
      final count = math.max(1, (width / frameWidth).ceil());

      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(count, (i) {
                final thumbIdx = i % globalThumbs.length;
                final thumb = globalThumbs[thumbIdx];
                return SizedBox(
                  width: frameWidth,
                  height: double.infinity,
                  child: Image.memory(
                    thumb,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                );
              }),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPlayhead(Duration position) {
    final x =
        position.inMilliseconds / 1000 * _pixelsPerSecond +
        _dims.trackLabelWidth;

    return Positioned(
      left: x,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final newX = x + details.delta.dx - _dims.trackLabelWidth;
          final newPosition = Duration(
            milliseconds: (newX / _pixelsPerSecond * 1000).toInt(),
          );

          if (newPosition >= Duration.zero &&
              newPosition <= widget.totalDuration) {
            ref.read(timelineProvider.notifier).setCurrentPosition(newPosition);
            widget.onSeek?.call(newPosition);
          }
        },
        child: Container(
          width: _dims.playheadWidth,
          color: Colors.red,
          child: Column(
            children: [
              Container(
                width: _dims.playheadDotSize,
                height: _dims.playheadDotSize,
                transform: Matrix4.translationValues(
                  -(_dims.playheadDotSize / 2) + (_dims.playheadWidth / 2),
                  0,
                  0,
                ),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, size: 24, color: Colors.grey[600]),
          SizedBox(height: _dims.paddingS),
          Text(
            'No objects',
            style: TextStyle(color: Colors.grey[500], fontSize: _dims.fontS),
          ),
          SizedBox(height: _dims.paddingS),
          GestureDetector(
            onTap: _showAddItemDialog,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _dims.paddingM * 2,
                vertical: _dims.paddingS,
              ),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Add Object',
                style: TextStyle(fontSize: _dims.fontS),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // DRAG HANDLERS
  // ═══════════════════════════════════════════════════════

  String _trackLabelForType(TimelineItemType type) {
    switch (type) {
      case TimelineItemType.text: return 'Text';
      case TimelineItemType.image: return 'Img';
      case TimelineItemType.audio: return 'Audio';
      case TimelineItemType.video: return 'Vid Layer';
      case TimelineItemType.solidColor: return 'Color';
      default: return '';
    }
  }

  void _onItemDragStart(
    TimelineItem item,
    DragStartDetails details,
    TimelineItemType type,
  ) {
    final lockedTracks = ref.read(timelineProvider).lockedTracks;
    final itemLocked = ref.read(timelineProvider).lockedItems.contains(item.id);
    if (itemLocked || lockedTracks.contains(_trackLabelForType(type))) return;

    _draggingItemId = item.id;
    _draggingItemType = type;
    _dragStartX = details.globalPosition.dx;
    _originalStartTime = item.startTime;
    _originalDuration = item.duration;
    _dragMode = _DragMode.move;

    final selectedIds = ref.read(timelineProvider).selectedItemIds;
    _isMultiDrag =
        selectedIds.length > 1 && selectedIds.contains(item.id);

    HapticFeedback.lightImpact();
  }

  void _onItemDragUpdate(DragUpdateDetails details) {
    if (_draggingItemId == null || _dragMode != _DragMode.move) return;

    final delta = details.globalPosition.dx - _dragStartX;
    final timeDelta = Duration(
      milliseconds: (delta / _pixelsPerSecond * 1000).toInt(),
    );

    if (_isMultiDrag) {
      ref
          .read(timelineProvider.notifier)
          .moveSelectedItems(timeDelta);
      _snapLineX = null;
      return;
    }

    var newStart = _originalStartTime + timeDelta;

    if (newStart >= Duration.zero &&
        newStart + _originalDuration <= widget.totalDuration) {
      newStart = _snapTo(newStart, _draggingItemId);
      _updateItemTiming(_draggingItemId!, newStart, _originalDuration);
    }
  }

  void _onResizeStart(
    TimelineItem item,
    DragStartDetails details,
    TimelineItemType type,
    bool isLeft,
  ) {
    final lockedTracks = ref.read(timelineProvider).lockedTracks;
    final itemLocked = ref.read(timelineProvider).lockedItems.contains(item.id);
    if (itemLocked || lockedTracks.contains(_trackLabelForType(type))) return;

    _draggingItemId = item.id;
    _draggingItemType = type;
    _dragStartX = details.globalPosition.dx;
    _originalStartTime = item.startTime;
    _originalDuration = item.duration;
    _dragMode = isLeft ? _DragMode.resizeLeft : _DragMode.resizeRight;
    HapticFeedback.lightImpact();
  }

  void _onResizeUpdate(DragUpdateDetails details, bool isLeft) {
    if (_draggingItemId == null) return;

    final delta = details.globalPosition.dx - _dragStartX;
    final timeDelta = Duration(
      milliseconds: (delta / _pixelsPerSecond * 1000).toInt(),
    );

    if (isLeft) {
      var newStart = _originalStartTime + timeDelta;
      var newDuration = _originalDuration - timeDelta;

      if (newStart >= Duration.zero &&
          newDuration >= const Duration(milliseconds: 200)) {
        // Snap the new start edge
        newStart = _snapTo(newStart, _draggingItemId);
        newDuration = _originalStartTime + _originalDuration - newStart;
        if (newDuration >= const Duration(milliseconds: 200)) {
          _updateItemTimingWithDuration(_draggingItemId!, newStart, newDuration);
        }
      }
    } else {
      var newDuration = _originalDuration + timeDelta;

      if (newDuration >= const Duration(milliseconds: 200) &&
          _originalStartTime + newDuration <= widget.totalDuration) {
        // Snap the new end edge
        final candidateEnd = _originalStartTime + newDuration;
        final snappedEnd = _snapTo(candidateEnd, _draggingItemId);
        newDuration = snappedEnd - _originalStartTime;
        if (newDuration >= const Duration(milliseconds: 200)) {
          _updateItemTimingWithDuration(
            _draggingItemId!,
            _originalStartTime,
            newDuration,
          );
        }
      }
    }
  }

  void _onItemDragEnd() {
    _draggingItemId = null;
    _draggingItemType = null;
    _dragMode = _DragMode.none;
    _isMultiDrag = false;
    _snapLineX = null;
    HapticFeedback.lightImpact();
  }

  // ═══════════════════════════════════════════════════════
  // SNAP TO PLAYHEAD + CLIP EDGES
  // ═══════════════════════════════════════════════════════

  List<Duration> _buildSnapPoints(String? excludeItemId) {
    final state = ref.read(timelineProvider);
    final points = <Duration>[];

    // Playhead
    points.add(state.currentPosition);

    // Total duration boundaries
    points.add(Duration.zero);
    points.add(widget.totalDuration);

    // Clip start/end edges (all item types)
    for (final item in state.textItems) {
      if (item.id == excludeItemId) continue;
      points.add(item.startTime);
      points.add(item.endTime);
    }
    for (final item in state.imageItems) {
      if (item.id == excludeItemId) continue;
      points.add(item.startTime);
      points.add(item.endTime);
    }
    for (final item in state.audioItems) {
      if (item.id == excludeItemId) continue;
      points.add(item.startTime);
      points.add(item.endTime);
    }
    for (final item in state.videoOverlayItems) {
      if (item.id == excludeItemId) continue;
      points.add(item.startTime);
      points.add(item.endTime);
    }
    // Primary clip edges
    for (final clip in state.primaryVideoClips) {
      if (clip.id == excludeItemId) continue;
      // primary clips are sequential; compute their absolute positions
      // (handled by object_timeline_editor's _calcStartTimeAt)
    }

    return points;
  }

  Duration _snapTo(Duration candidate, String? excludeItemId) {
    final points = _buildSnapPoints(excludeItemId);
    final thresholdMs = (_snapThresholdPx / _pixelsPerSecond * 1000).toInt();
    final threshold = Duration(milliseconds: thresholdMs);

    Duration best = candidate;
    double bestDist = double.infinity;
    double? bestLineX;

    for (final pt in points) {
      final dist = (candidate - pt).inMilliseconds.abs().toDouble();
      if (dist < threshold.inMilliseconds && dist < bestDist) {
        bestDist = dist;
        best = pt;
        bestLineX = _durationToPx(pt);
      }
    }

    if (bestLineX != null && bestLineX != _snapLineX) {
      _snapLineX = bestLineX;
      HapticFeedback.selectionClick();
    } else if (bestLineX == null) {
      _snapLineX = null;
    }

    return best;
  }

  double _durationToPx(Duration d) =>
      d.inMilliseconds / 1000 * _pixelsPerSecond + _dims.trackLabelWidth;

  void _updateItemTiming(String itemId, Duration newStart, Duration duration) {
    final newEnd = newStart + duration;
    final state = ref.read(timelineProvider);

    switch (_draggingItemType) {
      case TimelineItemType.text:
        final item = _findItemInList(state.textItems, itemId);
        if (item == null) return;
        ref
            .read(timelineProvider.notifier)
            .updateTextItem(itemId, item.copyWith(startTime: newStart, endTime: newEnd));
        break;
      case TimelineItemType.image:
        final item = _findItemInList(state.imageItems, itemId);
        if (item == null) return;
        ref
            .read(timelineProvider.notifier)
            .updateImageItem(itemId, item.copyWith(startTime: newStart, endTime: newEnd));
        break;
      case TimelineItemType.audio:
        final item = _findItemInList(state.audioItems, itemId);
        if (item == null) return;
        ref
            .read(timelineProvider.notifier)
            .updateAudioItem(itemId, item.copyWith(startTime: newStart, endTime: newEnd));
        break;
      case TimelineItemType.video:
        final item = _findItemInList(state.videoOverlayItems, itemId);
        if (item == null) return;
        ref
            .read(timelineProvider.notifier)
            .updateVideoOverlayItem(itemId, item.copyWith(startTime: newStart, endTime: newEnd));
        break;
      default:
        break;
    }
  }

  void _updateItemTimingWithDuration(
    String itemId,
    Duration newStart,
    Duration newDuration,
  ) {
    final newEnd = newStart + newDuration;
    final state = ref.read(timelineProvider);

    switch (_draggingItemType) {
      case TimelineItemType.text:
        final item = _findItemInList(state.textItems, itemId);
        if (item == null) return;
        ref
            .read(timelineProvider.notifier)
            .updateTextItem(itemId, item.copyWith(startTime: newStart, endTime: newEnd));
        break;
      case TimelineItemType.image:
        final item = _findItemInList(state.imageItems, itemId);
        if (item == null) return;
        ref
            .read(timelineProvider.notifier)
            .updateImageItem(itemId, item.copyWith(startTime: newStart, endTime: newEnd));
        break;
      case TimelineItemType.audio:
        final item = _findItemInList(state.audioItems, itemId);
        if (item == null) return;
        ref
            .read(timelineProvider.notifier)
            .updateAudioItem(itemId, item.copyWith(startTime: newStart, endTime: newEnd));
        break;
      case TimelineItemType.video:
        final item = _findItemInList(state.videoOverlayItems, itemId);
        if (item == null) return;
        ref
            .read(timelineProvider.notifier)
            .updateVideoOverlayItem(itemId, item.copyWith(startTime: newStart, endTime: newEnd));
        break;
      default:
        break;
    }
  }

  T? _findItemInList<T extends TimelineItem>(List<T> items, String itemId) {
    for (final item in items) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════
  // DIALOGS - COMPACT
  // ═══════════════════════════════════════════════════════

  void _showAddItemDialog() {
    final currentPosition = ref.read(timelineProvider).currentPosition;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(_dims.paddingM * 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 3,
                margin: EdgeInsets.only(bottom: _dims.paddingM),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              Text(
                'Add at ${_formatTime(currentPosition)}',
                style: TextStyle(
                  fontSize: _dims.fontL,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: _dims.paddingM),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactAddButton(
                    icon: Icons.video_library_rounded,
                    label: 'Video',
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.pop(context);
                      LocalVideoBrowserSheet.show(context);
                    },
                  ),
                  _buildCompactAddButton(
                    icon: Icons.movie_creation,
                    label: 'Stock Vid',
                    color: const Color(0xFF6C63FF),
                    onTap: () {
                      Navigator.pop(context);
                      PixabayVideoPickerSheet.show(context);
                    },
                  ),
                  _buildCompactAddButton(
                    icon: Icons.text_fields,
                    label: 'Text',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _showAddTextDialog(currentPosition);
                    },
                  ),
                  _buildCompactAddButton(
                    icon: Icons.image,
                    label: 'Image',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndAddImage(currentPosition);
                    },
                  ),
                ],
              ),
              SizedBox(height: _dims.paddingS),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactAddButton(
                    icon: Icons.audiotrack,
                    label: 'Audio',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndAddAudio(currentPosition);
                    },
                  ),
                  _buildCompactAddButton(
                    icon: Icons.color_lens,
                    label: 'Blank',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pop(context);
                      SolidColorSheet.show(context);
                    },
                  ),
                  _buildCompactAddButton(
                    icon: Icons.auto_awesome,
                    label: 'AI Gen',
                    color: Colors.pinkAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _showAiSheet(currentPosition);
                    },
                  ),
                ],
              ),
              SizedBox(height: _dims.paddingM),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactAddButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.all(_dims.paddingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: _dims.iconM + 2),
            ),
            SizedBox(height: _dims.paddingS),
            Text(label, style: TextStyle(fontSize: _dims.fontS)),
          ],
        ),
      ),
    );
  }

  void _showAddTextDialog(Duration startTime) {
    final textController = TextEditingController();
    final durationController = TextEditingController(text: '3');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Text at ${_formatTime(startTime)}',
          style: TextStyle(fontSize: _dims.fontL + 2),
        ),
        contentPadding: EdgeInsets.all(_dims.paddingM * 2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: InputDecoration(
                labelText: 'Text',
                labelStyle: TextStyle(fontSize: _dims.fontM),
                isDense: true,
                contentPadding: EdgeInsets.all(_dims.paddingM),
              ),
              style: TextStyle(fontSize: _dims.fontM),
              autofocus: true,
            ),
            SizedBox(height: _dims.paddingM),
            TextField(
              controller: durationController,
              decoration: InputDecoration(
                labelText: 'Duration (sec)',
                labelStyle: TextStyle(fontSize: _dims.fontM),
                isDense: true,
                contentPadding: EdgeInsets.all(_dims.paddingM),
              ),
              style: TextStyle(fontSize: _dims.fontM),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(fontSize: _dims.fontM)),
          ),
          ElevatedButton(
            onPressed: () {
              final duration = int.tryParse(durationController.text) ?? 3;
              ref
                  .read(timelineProvider.notifier)
                  .addTextItem(
                    text: textController.text.isEmpty
                        ? 'Sample Text'
                        : textController.text,
                    startTime: startTime,
                    duration: Duration(seconds: duration),
                  );
              Navigator.pop(context);
            },
            child: Text('Add', style: TextStyle(fontSize: _dims.fontM)),
          ),
        ],
      ),
    );
  }

  void _showAiSheet(Duration currentPosition) {
    final totalDuration = widget.totalDuration > Duration.zero
        ? widget.totalDuration
        : const Duration(seconds: 10);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AiTab(
              videoDuration: totalDuration,
              currentPosition: currentPosition,
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
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAndAddImage(Duration startTime) async {
    try {
      final result = await FilePickerService.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        _showTimelineError('Could not read the selected image');
        return;
      }
      ref
          .read(timelineProvider.notifier)
          .addImageItem(
            imagePath: path,
            startTime: startTime,
            duration: const Duration(seconds: 3),
          );
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showTimelineError('Failed to add image: $e');
    }
  }

  Future<void> _pickAndAddAudio(Duration startTime) async {
    try {
      final result = await FilePickerService.pickFiles(type: FileType.audio);
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        _showTimelineError('Could not read the selected audio');
        return;
      }
      ref
          .read(timelineProvider.notifier)
          .addAudioItem(
            audioPath: path,
            audioDuration: const Duration(seconds: 5),
            startTime: startTime,
            title: result.files.single.name,
          );
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showTimelineError('Failed to add audio: $e');
    }
  }

  void _showTimelineError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showEditTimingDialog(TimelineItem item, TimelineItemType type) {
    final startController = TextEditingController(
      text: item.startTime.inSeconds.toString(),
    );
    final endController = TextEditingController(
      text: item.endTime.inSeconds.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Timing', style: TextStyle(fontSize: _dims.fontL + 2)),
        contentPadding: EdgeInsets.all(_dims.paddingM * 2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startController,
              decoration: InputDecoration(
                labelText: 'Start (sec)',
                labelStyle: TextStyle(fontSize: _dims.fontM),
                isDense: true,
                contentPadding: EdgeInsets.all(_dims.paddingM),
              ),
              style: TextStyle(fontSize: _dims.fontM),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: _dims.paddingM),
            TextField(
              controller: endController,
              decoration: InputDecoration(
                labelText: 'End (sec)',
                labelStyle: TextStyle(fontSize: _dims.fontM),
                isDense: true,
                contentPadding: EdgeInsets.all(_dims.paddingM),
              ),
              style: TextStyle(fontSize: _dims.fontM),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(fontSize: _dims.fontM)),
          ),
          ElevatedButton(
            onPressed: () {
              final start = int.tryParse(startController.text) ?? 0;
              final end = int.tryParse(endController.text) ?? start + 3;

              if (end > start) {
                _draggingItemType = type;
                _updateItemTimingWithDuration(
                  item.id,
                  Duration(seconds: start),
                  Duration(seconds: end - start),
                );
                _draggingItemType = null;
              }
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(fontSize: _dims.fontM)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════

  void _selectItem(String id, TimelineItemType type) {
    final tool = ref.read(videoEditorProvider).currentTool;
    if (tool == EditorTool.razor) {
      final pos = ref.read(timelineProvider).currentPosition;
      final notifier = ref.read(timelineProvider.notifier);
      if (type == TimelineItemType.audio) {
        notifier.splitAudioItemAt(id, pos);
      } else if (type == TimelineItemType.video) {
        notifier.splitVideoOverlayAt(id, pos);
      } else if (type == TimelineItemType.text) {
        notifier.splitTextItemAt(id, pos);
      } else if (type == TimelineItemType.image) {
        notifier.splitImageItemAt(id, pos);
      } else if (type == TimelineItemType.solidColor) {
        notifier.splitSolidColorItemAt(id, pos);
      }
      return;
    }
    ref.read(timelineProvider.notifier).selectGroup(id);
    widget.onItemSelect?.call(id);
    HapticFeedback.selectionClick();
  }

  void _toggleSelectItem(String id, TimelineItemType type) {
    ref.read(timelineProvider.notifier).toggleSelectItem(id, type);
    widget.onItemSelect?.call(id);
    HapticFeedback.selectionClick();
  }

  bool _hasMarkerAt(Duration position) {
    return ref
        .read(timelineProvider)
        .markers
        .any((m) => (m - position).inMilliseconds.abs() < 500);
  }

  void _toggleMarker() {
    final notifier = ref.read(timelineProvider.notifier);
    final position = ref.read(timelineProvider).currentPosition;
    if (_hasMarkerAt(position)) {
      notifier.removeMarkerAt(position);
    } else {
      notifier.addMarker(position);
    }
    HapticFeedback.selectionClick();
  }

  void _adjustZoom(double delta) {
    final current = ref.read(timelineProvider).zoomLevel;
    ref
        .read(timelineProvider.notifier)
        .setZoomLevel((current + delta).clamp(0.5, 5.0));
  }

  String _getItemLabel(TimelineItem item) {
    if (item is TextTimelineItem) {
      return item.text.length > 8
          ? '${item.text.substring(0, 8)}...'
          : item.text;
    }
    if (item is ImageTimelineItem) return 'Img';
    if (item is VideoOverlayTimelineItem) return 'Vid';
    if (item is AudioTimelineItem) {
      return item.title.isEmpty ? 'Audio' : item.title;
    }
    return 'Item';
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

enum _DragMode { none, move, resizeLeft, resizeRight }

class _TimeRulerPainter extends CustomPainter {
  final double pixelsPerSecond;
  final Duration totalDuration;
  final double trackLabelWidth;
  final double fontSize;
  final List<Duration> markers;

  _TimeRulerPainter({
    required this.pixelsPerSecond,
    required this.totalDuration,
    required this.trackLabelWidth,
    required this.fontSize,
    this.markers = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 0.5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= totalDuration.inSeconds; i++) {
      final x = i * pixelsPerSecond + trackLabelWidth;
      if (x > size.width) break;

      if (i % 5 == 0) {
        paint.color = Colors.white38;
        canvas.drawLine(
          Offset(x, size.height - 6),
          Offset(x, size.height),
          paint,
        );

        textPainter.text = TextSpan(
          text: _formatTime(Duration(seconds: i)),
          style: TextStyle(color: Colors.white54, fontSize: fontSize),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, 0));
      } else {
        paint.color = Colors.white12;
        canvas.drawLine(
          Offset(x, size.height - 3),
          Offset(x, size.height),
          paint,
        );
      }
    }

    // Draw markers as amber flags
    final markerPaint = Paint()
      ..color = Colors.amber
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final flagPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;

    for (final marker in markers) {
      final x = marker.inMilliseconds / 1000 * pixelsPerSecond +
          trackLabelWidth;
      if (x < 0 || x > size.width) continue;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        markerPaint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + 5, 3)
          ..lineTo(x, 6),
        flagPaint,
      );
    }
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) {
    return oldDelegate.pixelsPerSecond != pixelsPerSecond ||
        oldDelegate.totalDuration != totalDuration ||
        oldDelegate.trackLabelWidth != trackLabelWidth ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.markers.length != markers.length;
  }
}
