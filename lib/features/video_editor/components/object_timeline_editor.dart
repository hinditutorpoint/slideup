import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/timeline_provider.dart';
import '../sheets/transition_sheet.dart';
import '../sheets/pixabay_video_picker_sheet.dart';

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
    final hasSelection = state.selectedItemIds.isNotEmpty;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: _dims.paddingS),
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
            width: 20,
            height: 20,
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
          SizedBox(width: _dims.paddingXS),

          // Group / ungroup for multi-selection
          if (hasSelection) ...[
            IconButton(
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
            IconButton(
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
          ],

          // Delete selected
          if (hasSelection)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: _dims.iconS,
                color: Colors.red[300],
              ),
              onPressed: () {
                ref.read(timelineProvider.notifier).deleteSelectedItems();
                HapticFeedback.mediumImpact();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Delete selected',
            ),

          // Zoom controls - compact
          SizedBox(
            width: 20,
            height: 20,
            child: IconButton(
              icon: Icon(Icons.remove, size: _dims.iconXS),
              onPressed: () => _adjustZoom(-0.2),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          SizedBox(
            width: 50,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
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
            width: 20,
            height: 20,
            child: IconButton(
              icon: Icon(Icons.add, size: _dims.iconXS),
              onPressed: () => _adjustZoom(0.2),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          Text(
            '${(state.zoomLevel * 100).toInt()}%',
            style: TextStyle(fontSize: _dims.fontXS, color: Colors.grey[400]),
          ),
          const Spacer(),

          // Add button - compact
          GestureDetector(
            onTap: _showAddItemDialog,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _dims.paddingM,
                vertical: _dims.paddingXS,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: _dims.iconXS, color: Colors.blue),
                  SizedBox(width: _dims.paddingXS),
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
                    ],
                  ),
                ),

                // Playhead
                _buildPlayhead(state.currentPosition),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeRuler() {
    return Container(
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
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PRIMARY MAGNETIC TRACK RENDERER
  // ═══════════════════════════════════════════════════════

  Widget _buildPrimaryMagneticTrack(List<PrimaryVideoClip> clips) {
    Duration offset = Duration.zero;

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

                  return Positioned(
                    left: startX,
                    top: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Magnetic video clip block
                        Container(
                          width: width,
                          height: _dims.trackHeight + 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blueAccent.withValues(alpha: 0.55),
                                Colors.indigo.withValues(alpha: 0.45),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.blueAccent,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 4),
                              Icon(
                                Icons.movie_outlined,
                                size: _dims.iconXS,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Clip ${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _dims.fontXS,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

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
    return Container(
      height: _dims.trackHeight,
      margin: EdgeInsets.only(top: _dims.trackSpacing),
      child: Row(
        children: [
          // Track label
          Container(
            width: _dims.trackLabelWidth,
            padding: EdgeInsets.symmetric(horizontal: _dims.paddingXS),
            child: Row(
              children: [
                Icon(icon, size: _dims.iconXS, color: color),
                SizedBox(width: _dims.paddingXS),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: _dims.fontXS, color: color),
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
                // Track background
                Container(
                  height: _dims.trackHeight,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Items
                ...items.map(
                  (item) => _buildTrackItem(
                    item: item,
                    color: color,
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
            ],
          ),
        ),
      ),
    );
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
  // DRAG HANDLERS (unchanged)
  // ═══════════════════════════════════════════════════════

  void _onItemDragStart(
    TimelineItem item,
    DragStartDetails details,
    TimelineItemType type,
  ) {
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
      return;
    }

    final newStart = _originalStartTime + timeDelta;

    if (newStart >= Duration.zero &&
        newStart + _originalDuration <= widget.totalDuration) {
      _updateItemTiming(_draggingItemId!, newStart, _originalDuration);
    }
  }

  void _onResizeStart(
    TimelineItem item,
    DragStartDetails details,
    TimelineItemType type,
    bool isLeft,
  ) {
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
        _updateItemTimingWithDuration(_draggingItemId!, newStart, newDuration);
      }
    } else {
      var newDuration = _originalDuration + timeDelta;

      if (newDuration >= const Duration(milliseconds: 200) &&
          _originalStartTime + newDuration <= widget.totalDuration) {
        _updateItemTimingWithDuration(
          _draggingItemId!,
          _originalStartTime,
          newDuration,
        );
      }
    }
  }

  void _onItemDragEnd() {
    _draggingItemId = null;
    _draggingItemType = null;
    _dragMode = _DragMode.none;
    _isMultiDrag = false;
    HapticFeedback.lightImpact();
  }

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
                  _buildCompactAddButton(
                    icon: Icons.movie_creation,
                    label: 'Stock Video',
                    color: const Color(0xFF6C63FF),
                    onTap: () {
                      Navigator.pop(context);
                      PixabayVideoPickerSheet.show(context);
                    },
                  ),
                  _buildCompactAddButton(
                    icon: Icons.audiotrack,
                    label: 'Audio',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndAddAudio(currentPosition);
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

  Future<void> _pickAndAddImage(Duration startTime) async {
    try {
      final result = await FilePicker.platform.pickFiles(
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
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
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
