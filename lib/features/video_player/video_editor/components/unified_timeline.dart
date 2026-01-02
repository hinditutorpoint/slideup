import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/video_edit_settings.dart';

// ═══════════════════════════════════════════════════════
// ✅ TIMELINE TRACK TYPE
// ═══════════════════════════════════════════════════════

enum TrackType { video, text, image, audio }

// ═══════════════════════════════════════════════════════
// ✅ TIMELINE ITEM WRAPPER
// ═══════════════════════════════════════════════════════

class TimelineItemWrapper {
  final String id;
  final TrackType trackType;
  final Duration startTime;
  final Duration endTime;
  final int layer;
  final dynamic data;
  bool isSelected;
  bool isLocked;

  TimelineItemWrapper({
    required this.id,
    required this.trackType,
    required this.startTime,
    required this.endTime,
    this.layer = 0,
    required this.data,
    this.isSelected = false,
    this.isLocked = false,
  });

  Duration get duration => endTime - startTime;

  TimelineItemWrapper copyWith({
    String? id,
    TrackType? trackType,
    Duration? startTime,
    Duration? endTime,
    int? layer,
    dynamic data,
    bool? isSelected,
    bool? isLocked,
  }) {
    return TimelineItemWrapper(
      id: id ?? this.id,
      trackType: trackType ?? this.trackType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      layer: layer ?? this.layer,
      data: data ?? this.data,
      isSelected: isSelected ?? this.isSelected,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ UNIFIED TIMELINE WIDGET
// ═══════════════════════════════════════════════════════

class UnifiedTimeline extends StatefulWidget {
  final Duration totalDuration;
  final Duration currentPosition;
  final List<TextTimelineItem> textItems;
  final List<ImageTimelineItem> imageItems;
  final List<AudioTimelineItem> audioItems;
  final List<Uint8List>? videoThumbnails;
  final Function(Duration) onPositionChanged;
  final Function(List<TextTimelineItem>) onTextItemsChanged;
  final Function(List<ImageTimelineItem>) onImageItemsChanged;
  final Function(List<AudioTimelineItem>) onAudioItemsChanged;
  final Function(TimelineItemWrapper?)? onItemSelected;
  final bool isPlaying;
  final double? trimStartPercent;
  final double? trimEndPercent;

  const UnifiedTimeline({
    super.key,
    required this.totalDuration,
    required this.currentPosition,
    required this.textItems,
    required this.imageItems,
    required this.audioItems,
    this.videoThumbnails,
    required this.onPositionChanged,
    required this.onTextItemsChanged,
    required this.onImageItemsChanged,
    required this.onAudioItemsChanged,
    this.onItemSelected,
    this.isPlaying = false,
    this.trimStartPercent,
    this.trimEndPercent,
  });

  @override
  State<UnifiedTimeline> createState() => _UnifiedTimelineState();
}

class _UnifiedTimelineState extends State<UnifiedTimeline>
    with TickerProviderStateMixin {
  // ─────────────────────────────────────────────────────
  // Constants
  // ─────────────────────────────────────────────────────
  static const double _minTrackHeight = 32.0;
  static const double _defaultTrackHeight = 40.0;
  static const double _videoTrackHeight = 50.0;
  static const double _rulerHeight = 24.0;
  static const double _minItemWidth = 16.0;
  static const double _handleWidth = 10.0;
  static const double _basePixelsPerSecond = 50.0;
  static const double _minLabelWidth = 40.0;
  static const double _maxLabelWidth = 70.0;
  static const int _minDurationMs = 200;

  // ─────────────────────────────────────────────────────
  // Controllers
  // ─────────────────────────────────────────────────────
  late final ScrollController _horizontalScrollController;
  late final ScrollController _verticalScrollController;
  late final AnimationController _selectionAnimController;
  late final Animation<double> _selectionPulse;

  // ─────────────────────────────────────────────────────
  // Scale State
  // ─────────────────────────────────────────────────────
  double _scale = 1.0;
  double _minScale = 0.3;
  double _maxScale = 4.0;
  double _baseScale = 1.0;
  Offset? _scaleStartFocalPoint;

  // ─────────────────────────────────────────────────────
  // Selection State
  // ─────────────────────────────────────────────────────
  TimelineItemWrapper? _selectedItem;
  final Set<String> _multiSelectedIds = {};

  // ─────────────────────────────────────────────────────
  // Drag State
  // ─────────────────────────────────────────────────────
  bool _isDragging = false;
  bool _isResizingStart = false;
  bool _isResizingEnd = false;
  String? _activeItemId;
  Offset _lastDragPosition = Offset.zero;
  Duration _originalStartTime = Duration.zero;
  Duration _originalEndTime = Duration.zero;

  // ─────────────────────────────────────────────────────
  // Track Visibility
  // ─────────────────────────────────────────────────────
  bool _showVideoTrack = true;
  bool _showTextTrack = true;
  bool _showImageTrack = true;
  bool _showAudioTrack = true;

  // ─────────────────────────────────────────────────────
  // Layout Cache
  // ─────────────────────────────────────────────────────
  double _availableWidth = 0;
  double _labelWidth = 50;
  bool _isCompact = false;

  // ─────────────────────────────────────────────────────
  // Debounce Timer
  // ─────────────────────────────────────────────────────
  Timer? _updateDebouncer;

  // ─────────────────────────────────────────────────────
  // Computed Properties
  // ─────────────────────────────────────────────────────
  double get _pixelsPerSecond => _basePixelsPerSecond * _scale;

  double get _timelineWidth {
    try {
      final seconds = widget.totalDuration.inMilliseconds / 1000.0;
      final width = seconds * _pixelsPerSecond;
      return math.max(width, _availableWidth);
    } catch (e) {
      return _availableWidth;
    }
  }

  double get _trackHeight => _isCompact ? _minTrackHeight : _defaultTrackHeight;

  List<TimelineItemWrapper> get _allItems {
    final items = <TimelineItemWrapper>[];

    try {
      for (final item in widget.textItems) {
        items.add(_wrapItem(item, TrackType.text));
      }
      for (final item in widget.imageItems) {
        items.add(_wrapItem(item, TrackType.image));
      }
      for (final item in widget.audioItems) {
        items.add(_wrapItem(item, TrackType.audio));
      }
    } catch (e) {
      debugPrint('❌ Error building timeline items: $e');
    }

    return items;
  }

  TimelineItemWrapper _wrapItem(dynamic item, TrackType type) {
    return TimelineItemWrapper(
      id: item.id,
      trackType: type,
      startTime: item.startTime,
      endTime: item.endTime,
      layer: item.layer ?? 0,
      data: item,
      isSelected:
          _selectedItem?.id == item.id || _multiSelectedIds.contains(item.id),
      isLocked: item.isLocked ?? false,
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ LIFECYCLE
  // ═══════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    try {
      _horizontalScrollController = ScrollController();
      _verticalScrollController = ScrollController();

      _selectionAnimController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);

      _selectionPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _selectionAnimController,
          curve: Curves.easeInOut,
        ),
      );
    } catch (e) {
      debugPrint('❌ Init controllers error: $e');
    }
  }

  @override
  void didUpdateWidget(UnifiedTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    try {
      if (oldWidget.totalDuration != widget.totalDuration) {
        _calculateOptimalScale();
      }

      // Auto-scroll to follow playhead
      if (widget.isPlaying && !_isDragging) {
        _scrollToPlayhead();
      }
    } catch (e) {
      debugPrint('❌ didUpdateWidget error: $e');
    }
  }

  void _calculateOptimalScale() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final contentWidth = _availableWidth - _labelWidth;
        if (contentWidth <= 0) return;

        final totalSeconds = widget.totalDuration.inMilliseconds / 1000.0;
        if (totalSeconds <= 0) return;

        final optimalScale =
            contentWidth / (totalSeconds * _basePixelsPerSecond);

        setState(() {
          _minScale = (optimalScale * 0.5).clamp(0.1, 1.0);
          _scale = optimalScale.clamp(_minScale, _maxScale);
        });
      } catch (e) {
        debugPrint('❌ Calculate optimal scale error: $e');
      }
    });
  }

  void _scrollToPlayhead() {
    try {
      if (!_horizontalScrollController.hasClients) return;

      final totalMs = widget.totalDuration.inMilliseconds.toDouble();
      if (totalMs <= 0) return;

      final playheadX =
          (widget.currentPosition.inMilliseconds / totalMs) * _timelineWidth;
      final viewportWidth =
          _horizontalScrollController.position.viewportDimension;
      final currentScroll = _horizontalScrollController.offset;

      // Only scroll if playhead is outside visible area
      if (playheadX < currentScroll ||
          playheadX > currentScroll + viewportWidth - 50) {
        _horizontalScrollController.animateTo(
          (playheadX - viewportWidth / 2).clamp(
            0.0,
            _horizontalScrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      // Ignore scroll errors
    }
  }

  @override
  void dispose() {
    _updateDebouncer?.cancel();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _selectionAnimController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        try {
          // Update layout cache
          _availableWidth = constraints.maxWidth;
          _isCompact = constraints.maxHeight < 180;
          _labelWidth = _isCompact
              ? _minLabelWidth
              : math.min(_maxLabelWidth, constraints.maxWidth * 0.12);

          return Container(
            constraints: BoxConstraints(
              minHeight: 100,
              maxHeight: constraints.maxHeight,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Toolbar
                _buildToolbar(),

                // Timeline content
                Expanded(child: _buildTimelineContent(constraints)),
              ],
            ),
          );
        } catch (e) {
          debugPrint('❌ Build error: $e');
          return _buildErrorWidget();
        }
      },
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            SizedBox(height: 8),
            Text('Timeline Error', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TOOLBAR
  // ═══════════════════════════════════════════════════════

  Widget _buildToolbar() {
    return Container(
      height: _isCompact ? 32 : 40,
      padding: EdgeInsets.symmetric(horizontal: _isCompact ? 4 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Track toggles
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TrackToggle(
                    icon: Icons.movie_outlined,
                    isActive: _showVideoTrack,
                    color: Colors.blue,
                    onTap: () =>
                        setState(() => _showVideoTrack = !_showVideoTrack),
                    isCompact: _isCompact,
                  ),
                  _TrackToggle(
                    icon: Icons.text_fields,
                    isActive: _showTextTrack,
                    color: Colors.orange,
                    onTap: () =>
                        setState(() => _showTextTrack = !_showTextTrack),
                    isCompact: _isCompact,
                  ),
                  _TrackToggle(
                    icon: Icons.image_outlined,
                    isActive: _showImageTrack,
                    color: Colors.green,
                    onTap: () =>
                        setState(() => _showImageTrack = !_showImageTrack),
                    isCompact: _isCompact,
                  ),
                  _TrackToggle(
                    icon: Icons.music_note_outlined,
                    isActive: _showAudioTrack,
                    color: Colors.purple,
                    onTap: () =>
                        setState(() => _showAudioTrack = !_showAudioTrack),
                    isCompact: _isCompact,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Zoom controls
          _buildZoomControls(),

          // Selection info
          if (_hasSelection) ...[
            const SizedBox(width: 8),
            _buildSelectionInfo(),
          ],
        ],
      ),
    );
  }

  bool get _hasSelection =>
      _selectedItem != null || _multiSelectedIds.isNotEmpty;

  Widget _buildZoomControls() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isCompact ? 2 : 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(
            icon: Icons.remove,
            onTap: () => _adjustScale(-0.25),
            isCompact: _isCompact,
          ),
          Container(
            constraints: BoxConstraints(minWidth: _isCompact ? 32 : 40),
            alignment: Alignment.center,
            child: Text(
              '${(_scale * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white60,
                fontSize: _isCompact ? 9 : 10,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _ZoomButton(
            icon: Icons.add,
            onTap: () => _adjustScale(0.25),
            isCompact: _isCompact,
          ),
        ],
      ),
    );
  }

  void _adjustScale(double delta) {
    setState(() {
      _scale = (_scale + delta).clamp(_minScale, _maxScale);
    });
    HapticFeedback.selectionClick();
  }

  Widget _buildSelectionInfo() {
    final count = _multiSelectedIds.isNotEmpty
        ? _multiSelectedIds.length
        : (_selectedItem != null ? 1 : 0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isCompact ? 6 : 8,
        vertical: _isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.cyan.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: _isCompact ? 10 : 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _clearSelection,
            child: Icon(
              Icons.close,
              size: _isCompact ? 12 : 14,
              color: Colors.cyan,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TIMELINE CONTENT
  // ═══════════════════════════════════════════════════════

  Widget _buildTimelineContent(BoxConstraints constraints) {
    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: Row(
        children: [
          // Track labels
          SizedBox(width: _labelWidth, child: _buildTrackLabels()),

          // Divider
          Container(width: 1, color: Colors.grey.withValues(alpha: 0.2)),

          // Scrollable timeline
          Expanded(child: _buildScrollableTimeline()),
        ],
      ),
    );
  }

  Widget _buildTrackLabels() {
    return Container(
      color: const Color(0xFF202020),
      child: Column(
        children: [
          // Ruler space
          SizedBox(height: _rulerHeight),

          // Track labels
          Expanded(
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showVideoTrack)
                    _TrackLabel(
                      label: 'Video',
                      icon: Icons.movie_outlined,
                      color: Colors.blue,
                      height: _videoTrackHeight,
                      isCompact: _isCompact,
                    ),
                  if (_showTextTrack)
                    _TrackLabel(
                      label: 'Text',
                      icon: Icons.text_fields,
                      color: Colors.orange,
                      height: _trackHeight,
                      isCompact: _isCompact,
                    ),
                  if (_showImageTrack)
                    _TrackLabel(
                      label: 'Image',
                      icon: Icons.image_outlined,
                      color: Colors.green,
                      height: _trackHeight,
                      isCompact: _isCompact,
                    ),
                  if (_showAudioTrack)
                    _TrackLabel(
                      label: 'Audio',
                      icon: Icons.music_note_outlined,
                      color: Colors.purple,
                      height: _trackHeight,
                      isCompact: _isCompact,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableTimeline() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Sync vertical scroll if needed
        return false;
      },
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        physics: _isDragging || _isResizingStart || _isResizingEnd
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        child: GestureDetector(
          onTapUp: _onTimelineTap,
          behavior: HitTestBehavior.translucent,
          child: SizedBox(
            width: math.max(_timelineWidth, 100),
            child: RepaintBoundary(
              child: Stack(
                children: [
                  // Background and tracks
                  Column(
                    children: [
                      // Time ruler
                      RepaintBoundary(child: _buildTimeRuler()),

                      // Tracks
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_showVideoTrack) _buildVideoTrack(),
                              if (_showTextTrack) _buildTrack(TrackType.text),
                              if (_showImageTrack) _buildTrack(TrackType.image),
                              if (_showAudioTrack) _buildTrack(TrackType.audio),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Playhead (on top)
                  _buildPlayhead(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TIME RULER
  // ═══════════════════════════════════════════════════════

  Widget _buildTimeRuler() {
    return Container(
      height: _rulerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: CustomPaint(
        size: Size(_timelineWidth, _rulerHeight),
        painter: _TimeRulerPainter(
          totalDuration: widget.totalDuration,
          pixelsPerSecond: _pixelsPerSecond,
          trimStartPercent: widget.trimStartPercent,
          trimEndPercent: widget.trimEndPercent,
          isCompact: _isCompact,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VIDEO TRACK
  // ═══════════════════════════════════════════════════════

  Widget _buildVideoTrack() {
    return Container(
      height: _videoTrackHeight,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: Stack(
        children: [
          // Thumbnails
          if (widget.videoThumbnails != null &&
              widget.videoThumbnails!.isNotEmpty)
            _buildVideoThumbnails()
          else
            Center(
              child: Icon(
                Icons.movie_outlined,
                color: Colors.blue.withValues(alpha: 0.2),
                size: 20,
              ),
            ),

          // Trim overlay
          if (widget.trimStartPercent != null || widget.trimEndPercent != null)
            _buildTrimOverlay(),
        ],
      ),
    );
  }

  Widget _buildVideoThumbnails() {
    try {
      final thumbnails = widget.videoThumbnails!;
      final thumbWidth = _timelineWidth / thumbnails.length;

      return Row(
        children: thumbnails.asMap().entries.map((entry) {
          return SizedBox(
            width: thumbWidth.clamp(1, _timelineWidth),
            height: _videoTrackHeight,
            child: Image.memory(
              entry.value,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[850]),
            ),
          );
        }).toList(),
      );
    } catch (e) {
      return Container(color: Colors.grey[850]);
    }
  }

  Widget _buildTrimOverlay() {
    try {
      final startPercent = widget.trimStartPercent ?? 0.0;
      final endPercent = widget.trimEndPercent ?? 1.0;

      return Stack(
        children: [
          // Before trim start
          if (startPercent > 0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _timelineWidth * startPercent,
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: CustomPaint(painter: _DiagonalLinesPainter()),
              ),
            ),

          // After trim end
          if (endPercent < 1)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: _timelineWidth * (1 - endPercent),
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: CustomPaint(painter: _DiagonalLinesPainter()),
              ),
            ),

          // Trim handles
          Positioned(
            left: _timelineWidth * startPercent - 2,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: Colors.yellow),
          ),
          Positioned(
            left: _timelineWidth * endPercent - 2,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: Colors.yellow),
          ),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GENERIC TRACK
  // ═══════════════════════════════════════════════════════

  Widget _buildTrack(TrackType type) {
    final items = _allItems.where((i) => i.trackType == type).toList();
    final color = _getTrackColor(type);

    return Container(
      height: _trackHeight,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Empty state
          if (items.isEmpty)
            Center(
              child: Icon(
                _getTrackIcon(type),
                color: color.withValues(alpha: 0.15),
                size: 16,
              ),
            ),

          // Items
          ...items.map((item) => _buildTimelineItem(item)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(TimelineItemWrapper item) {
    try {
      final totalMs = widget.totalDuration.inMilliseconds.toDouble();
      if (totalMs <= 0) return const SizedBox.shrink();

      final startX = (item.startTime.inMilliseconds / totalMs) * _timelineWidth;
      final endX = (item.endTime.inMilliseconds / totalMs) * _timelineWidth;
      final itemWidth = math.max(endX - startX, _minItemWidth);

      final isActive = _activeItemId == item.id;
      final color = _getTrackColor(item.trackType);

      return AnimatedPositioned(
        duration: isActive ? Duration.zero : const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        left: startX.clamp(0.0, _timelineWidth - _minItemWidth),
        top: 2,
        width: itemWidth.clamp(_minItemWidth, _timelineWidth),
        height: _trackHeight - 4,
        child: _TimelineItemWidget(
          item: item,
          color: color,
          isCompact: _isCompact,
          handleWidth: _handleWidth,
          selectionAnimation: _selectionPulse,
          onTap: () => _onItemTap(item),
          onLongPress: () => _onItemLongPress(item),
          onDragStart: (details) => _onItemDragStart(item, details),
          onDragUpdate: (details) => _onItemDragUpdate(item, details),
          onDragEnd: () => _onItemDragEnd(),
          onResizeStartStart: () => _onResizeStartBegin(item),
          onResizeStartUpdate: (details) => _onResizeStartUpdate(item, details),
          onResizeEndStart: () => _onResizeEndBegin(item),
          onResizeEndUpdate: (details) => _onResizeEndUpdate(item, details),
          onResizeEnd: () => _onResizeComplete(),
        ),
      );
    } catch (e) {
      debugPrint('❌ Build timeline item error: $e');
      return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYHEAD
  // ═══════════════════════════════════════════════════════

  Widget _buildPlayhead() {
    try {
      final totalMs = widget.totalDuration.inMilliseconds.toDouble();
      if (totalMs <= 0) return const SizedBox.shrink();

      final position =
          (widget.currentPosition.inMilliseconds / totalMs) * _timelineWidth;

      return Positioned(
        left: position.clamp(0.0, _timelineWidth - 1),
        top: 0,
        bottom: 0,
        child: IgnorePointer(
          child: SizedBox(
            width: 2,
            child: Column(
              children: [
                // Head
                Container(
                  width: 14,
                  height: 14,
                  transform: Matrix4.translationValues(-6, 0, 0),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                // Line
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GESTURE HANDLERS
  // ═══════════════════════════════════════════════════════

  void _onScaleStart(ScaleStartDetails details) {
    try {
      if (details.pointerCount >= 2) {
        _baseScale = _scale;
        _scaleStartFocalPoint = details.localFocalPoint;
      }
    } catch (e) {
      debugPrint('❌ Scale start error: $e');
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    try {
      if (details.pointerCount >= 2 && _scaleStartFocalPoint != null) {
        setState(() {
          _scale = (_baseScale * details.scale).clamp(_minScale, _maxScale);
        });
      }
    } catch (e) {
      debugPrint('❌ Scale update error: $e');
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _scaleStartFocalPoint = null;
  }

  void _onTimelineTap(TapUpDetails details) {
    try {
      final scrollOffset = _horizontalScrollController.hasClients
          ? _horizontalScrollController.offset
          : 0.0;
      final x = details.localPosition.dx + scrollOffset;
      final percent = (x / _timelineWidth).clamp(0.0, 1.0);
      final position = Duration(
        milliseconds: (percent * widget.totalDuration.inMilliseconds).toInt(),
      );
      widget.onPositionChanged(position);
      _clearSelection();
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('❌ Timeline tap error: $e');
    }
  }

  // ─────────────────────────────────────────────────────
  // Item Selection
  // ─────────────────────────────────────────────────────

  void _onItemTap(TimelineItemWrapper item) {
    try {
      HapticFeedback.selectionClick();
      setState(() {
        if (_multiSelectedIds.contains(item.id)) {
          _multiSelectedIds.remove(item.id);
          if (_multiSelectedIds.isEmpty) {
            _selectedItem = null;
          }
        } else {
          _selectedItem = item;
          _multiSelectedIds.clear();
        }
      });
      widget.onItemSelected?.call(_selectedItem);
    } catch (e) {
      debugPrint('❌ Item tap error: $e');
    }
  }

  void _onItemLongPress(TimelineItemWrapper item) {
    try {
      HapticFeedback.mediumImpact();
      setState(() {
        _multiSelectedIds.add(item.id);
        if (_selectedItem != null && _selectedItem!.id != item.id) {
          _multiSelectedIds.add(_selectedItem!.id);
        }
        _selectedItem = null;
      });
    } catch (e) {
      debugPrint('❌ Item long press error: $e');
    }
  }

  // ─────────────────────────────────────────────────────
  // Item Drag
  // ─────────────────────────────────────────────────────

  void _onItemDragStart(TimelineItemWrapper item, DragStartDetails details) {
    if (item.isLocked) return;

    try {
      setState(() {
        _isDragging = true;
        _activeItemId = item.id;
        _lastDragPosition = details.localPosition;
        _originalStartTime = item.startTime;
        _originalEndTime = item.endTime;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('❌ Drag start error: $e');
    }
  }

  void _onItemDragUpdate(TimelineItemWrapper item, DragUpdateDetails details) {
    if (!_isDragging || _activeItemId != item.id || item.isLocked) return;

    try {
      final deltaX = details.localPosition.dx - _lastDragPosition.dx;
      final deltaMs =
          (deltaX / _timelineWidth) * widget.totalDuration.inMilliseconds;

      final duration = _originalEndTime - _originalStartTime;
      var newStartMs = item.startTime.inMilliseconds + deltaMs.toInt();

      // Clamp to valid range
      newStartMs = newStartMs.clamp(
        0,
        widget.totalDuration.inMilliseconds - duration.inMilliseconds,
      );

      final newStart = Duration(milliseconds: newStartMs);
      final newEnd = newStart + duration;

      _debouncedUpdate(() {
        _updateItemTiming(item, newStart, newEnd);
      });

      _lastDragPosition = details.localPosition;
    } catch (e) {
      debugPrint('❌ Drag update error: $e');
    }
  }

  void _onItemDragEnd() {
    setState(() {
      _isDragging = false;
      _activeItemId = null;
    });
    HapticFeedback.lightImpact();
  }

  // ─────────────────────────────────────────────────────
  // Resize Handlers
  // ─────────────────────────────────────────────────────

  void _onResizeStartBegin(TimelineItemWrapper item) {
    if (item.isLocked) return;

    setState(() {
      _isResizingStart = true;
      _activeItemId = item.id;
      _originalStartTime = item.startTime;
      _originalEndTime = item.endTime;
    });
    HapticFeedback.lightImpact();
  }

  void _onResizeStartUpdate(
    TimelineItemWrapper item,
    DragUpdateDetails details,
  ) {
    if (!_isResizingStart || _activeItemId != item.id || item.isLocked) return;

    try {
      final deltaMs =
          (details.delta.dx / _timelineWidth) *
          widget.totalDuration.inMilliseconds;

      var newStartMs = item.startTime.inMilliseconds + deltaMs.toInt();

      // Ensure minimum duration
      final maxStartMs = item.endTime.inMilliseconds - _minDurationMs;
      newStartMs = newStartMs.clamp(0, maxStartMs);

      _debouncedUpdate(() {
        _updateItemTiming(
          item,
          Duration(milliseconds: newStartMs),
          item.endTime,
        );
      });
    } catch (e) {
      debugPrint('❌ Resize start update error: $e');
    }
  }

  void _onResizeEndBegin(TimelineItemWrapper item) {
    if (item.isLocked) return;

    setState(() {
      _isResizingEnd = true;
      _activeItemId = item.id;
      _originalStartTime = item.startTime;
      _originalEndTime = item.endTime;
    });
    HapticFeedback.lightImpact();
  }

  void _onResizeEndUpdate(TimelineItemWrapper item, DragUpdateDetails details) {
    if (!_isResizingEnd || _activeItemId != item.id || item.isLocked) return;

    try {
      final deltaMs =
          (details.delta.dx / _timelineWidth) *
          widget.totalDuration.inMilliseconds;

      var newEndMs = item.endTime.inMilliseconds + deltaMs.toInt();

      // Ensure minimum duration
      final minEndMs = item.startTime.inMilliseconds + _minDurationMs;
      newEndMs = newEndMs.clamp(minEndMs, widget.totalDuration.inMilliseconds);

      _debouncedUpdate(() {
        _updateItemTiming(
          item,
          item.startTime,
          Duration(milliseconds: newEndMs),
        );
      });
    } catch (e) {
      debugPrint('❌ Resize end update error: $e');
    }
  }

  void _onResizeComplete() {
    setState(() {
      _isResizingStart = false;
      _isResizingEnd = false;
      _activeItemId = null;
    });
    HapticFeedback.lightImpact();
  }

  // ─────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────

  void _debouncedUpdate(VoidCallback callback) {
    _updateDebouncer?.cancel();
    _updateDebouncer = Timer(const Duration(milliseconds: 8), callback);
  }

  void _updateItemTiming(
    TimelineItemWrapper item,
    Duration newStart,
    Duration newEnd,
  ) {
    try {
      switch (item.trackType) {
        case TrackType.text:
          final textItem = item.data as TextTimelineItem;
          final updated = textItem.copyWith(
            startTime: newStart,
            endTime: newEnd,
          );
          final newList = widget.textItems
              .map((t) => t.id == item.id ? updated : t)
              .toList();
          widget.onTextItemsChanged(newList);
          break;

        case TrackType.image:
          final imageItem = item.data as ImageTimelineItem;
          final updated = imageItem.copyWith(
            startTime: newStart,
            endTime: newEnd,
          );
          final newList = widget.imageItems
              .map((i) => i.id == item.id ? updated : i)
              .toList();
          widget.onImageItemsChanged(newList);
          break;

        case TrackType.audio:
          final audioItem = item.data as AudioTimelineItem;
          final updated = audioItem.copyWith(
            startTime: newStart,
            endTime: newEnd,
          );
          final newList = widget.audioItems
              .map((a) => a.id == item.id ? updated : a)
              .toList();
          widget.onAudioItemsChanged(newList);
          break;

        default:
          break;
      }
    } catch (e) {
      debugPrint('❌ Update item timing error: $e');
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedItem = null;
      _multiSelectedIds.clear();
    });
    widget.onItemSelected?.call(null);
  }

  Color _getTrackColor(TrackType type) {
    switch (type) {
      case TrackType.video:
        return Colors.blue;
      case TrackType.text:
        return Colors.orange;
      case TrackType.image:
        return Colors.green;
      case TrackType.audio:
        return Colors.purple;
    }
  }

  IconData _getTrackIcon(TrackType type) {
    switch (type) {
      case TrackType.video:
        return Icons.movie_outlined;
      case TrackType.text:
        return Icons.text_fields;
      case TrackType.image:
        return Icons.image_outlined;
      case TrackType.audio:
        return Icons.music_note_outlined;
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ HELPER WIDGETS
// ═══════════════════════════════════════════════════════

class _TrackToggle extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  final bool isCompact;

  const _TrackToggle({
    required this.icon,
    required this.isActive,
    required this.color,
    required this.onTap,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.only(right: isCompact ? 2 : 4),
        padding: EdgeInsets.all(isCompact ? 3 : 5),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: isCompact ? 12 : 14,
          color: isActive ? color : Colors.grey,
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isCompact;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 3 : 5),
        child: Icon(icon, size: isCompact ? 12 : 14, color: Colors.white60),
      ),
    );
  }
}

class _TrackLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double height;
  final bool isCompact;

  const _TrackLabel({
    required this.label,
    required this.icon,
    required this.color,
    required this.height,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: isCompact ? 12 : 14, color: color),
          if (!isCompact) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 8),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineItemWidget extends StatelessWidget {
  final TimelineItemWrapper item;
  final Color color;
  final bool isCompact;
  final double handleWidth;
  final Animation<double> selectionAnimation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Function(DragStartDetails) onDragStart;
  final Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onResizeStartStart;
  final Function(DragUpdateDetails) onResizeStartUpdate;
  final VoidCallback onResizeEndStart;
  final Function(DragUpdateDetails) onResizeEndUpdate;
  final VoidCallback onResizeEnd;

  const _TimelineItemWidget({
    required this.item,
    required this.color,
    required this.isCompact,
    required this.handleWidth,
    required this.selectionAnimation,
    required this.onTap,
    required this.onLongPress,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onResizeStartStart,
    required this.onResizeStartUpdate,
    required this.onResizeEndStart,
    required this.onResizeEndUpdate,
    required this.onResizeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: selectionAnimation,
      builder: (context, child) {
        final glowOpacity = item.isSelected
            ? selectionAnimation.value * 0.3
            : 0.0;

        return GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          onPanStart: item.isLocked ? null : onDragStart,
          onPanUpdate: item.isLocked ? null : onDragUpdate,
          onPanEnd: item.isLocked ? null : (_) => onDragEnd(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: color.withValues(alpha: item.isSelected ? 0.5 : 0.35),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: item.isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : color.withValues(alpha: 0.6),
                width: item.isSelected ? 1.5 : 1,
              ),
              boxShadow: item.isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3 + glowOpacity),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // Content
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: item.isSelected ? handleWidth + 2 : 4,
                    ),
                    child: _buildContent(),
                  ),
                ),

                // Resize handles
                if (item.isSelected && !item.isLocked) ...[
                  _buildResizeHandle(isStart: true),
                  _buildResizeHandle(isStart: false),
                ],

                // Lock indicator
                if (item.isLocked)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Icon(
                      Icons.lock,
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    try {
      switch (item.trackType) {
        case TrackType.text:
          final textItem = item.data as TextTimelineItem;
          return Center(
            child: Text(
              textItem.text.isNotEmpty ? textItem.text : 'Text',
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 9 : 10,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );

        case TrackType.image:
          return Row(
            children: [
              Icon(Icons.image, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Image',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 9 : 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

        case TrackType.audio:
          final audioItem = item.data as AudioTimelineItem;
          return Row(
            children: [
              Icon(
                audioItem.isMuted ? Icons.volume_off : Icons.music_note,
                size: 12,
                color: Colors.white70,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  audioItem.title.isNotEmpty ? audioItem.title : 'Audio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 9 : 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

        default:
          return const SizedBox.shrink();
      }
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildResizeHandle({required bool isStart}) {
    return Positioned(
      left: isStart ? 0 : null,
      right: isStart ? null : 0,
      top: 0,
      bottom: 0,
      width: handleWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => isStart ? onResizeStartStart() : onResizeEndStart(),
        onPanUpdate: (d) =>
            isStart ? onResizeStartUpdate(d) : onResizeEndUpdate(d),
        onPanEnd: (_) => onResizeEnd(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.horizontal(
              left: isStart ? const Radius.circular(4) : Radius.zero,
              right: isStart ? Radius.zero : const Radius.circular(4),
            ),
          ),
          child: Center(
            child: Container(
              width: 2,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ ANIMATED BUILDER (Local Definition)
// ═══════════════════════════════════════════════════════

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

// ═══════════════════════════════════════════════════════
// ✅ TIME RULER PAINTER
// ═══════════════════════════════════════════════════════

class _TimeRulerPainter extends CustomPainter {
  final Duration totalDuration;
  final double pixelsPerSecond;
  final double? trimStartPercent;
  final double? trimEndPercent;
  final bool isCompact;

  _TimeRulerPainter({
    required this.totalDuration,
    required this.pixelsPerSecond,
    this.trimStartPercent,
    this.trimEndPercent,
    required this.isCompact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final tickPaint = Paint()
        ..color = Colors.grey[600]!
        ..strokeWidth = 1;

      final minorTickPaint = Paint()
        ..color = Colors.grey[700]!
        ..strokeWidth = 0.5;

      final textStyle = TextStyle(
        color: Colors.grey[500],
        fontSize: isCompact ? 8 : 9,
      );

      final totalSeconds = totalDuration.inSeconds.toDouble();
      if (totalSeconds <= 0) return;

      final interval = _calculateInterval(pixelsPerSecond);
      final minorInterval = interval / 5;

      // Draw ticks
      for (double t = 0; t <= totalSeconds; t += minorInterval) {
        final x = t * pixelsPerSecond;
        if (x > size.width) break;

        final isMajor = (t % interval).abs() < 0.01;

        if (isMajor) {
          // Major tick
          canvas.drawLine(
            Offset(x, size.height - 8),
            Offset(x, size.height),
            tickPaint,
          );

          // Label
          final minutes = t ~/ 60;
          final seconds = (t % 60).toInt();
          final label =
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

          final textSpan = TextSpan(text: label, style: textStyle);
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();

          // Don't draw if it would overflow
          if (x + textPainter.width / 2 < size.width) {
            textPainter.paint(canvas, Offset(x - textPainter.width / 2, 2));
          }
        } else {
          // Minor tick
          canvas.drawLine(
            Offset(x, size.height - 4),
            Offset(x, size.height),
            minorTickPaint,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Time ruler paint error: $e');
    }
  }

  double _calculateInterval(double pps) {
    if (pps > 100) return 1;
    if (pps > 50) return 5;
    if (pps > 25) return 10;
    if (pps > 10) return 30;
    return 60;
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) {
    return oldDelegate.totalDuration != totalDuration ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond ||
        oldDelegate.trimStartPercent != trimStartPercent ||
        oldDelegate.trimEndPercent != trimEndPercent ||
        oldDelegate.isCompact != isCompact;
  }
}

// ═══════════════════════════════════════════════════════
// ✅ DIAGONAL LINES PAINTER (for trim overlay)
// ═══════════════════════════════════════════════════════

class _DiagonalLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    try {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..strokeWidth = 1;

      const spacing = 8.0;
      final diagonal = size.width + size.height;

      for (double i = -size.height; i < diagonal; i += spacing) {
        canvas.drawLine(
          Offset(i, 0),
          Offset(i + size.height, size.height),
          paint,
        );
      }
    } catch (e) {
      // Ignore paint errors
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
