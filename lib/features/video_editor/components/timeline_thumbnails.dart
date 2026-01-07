import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/timeline_provider.dart';

class TimelineThumbnails extends ConsumerStatefulWidget {
  final VideoProject project;
  final List<Uint8List>? thumbnails;
  final Duration? trimStart;
  final Duration? trimEnd;
  final ValueChanged<Duration>? onSeek;
  final void Function(Duration start, Duration end)? onTrimChange;

  const TimelineThumbnails({
    super.key,
    required this.project,
    this.thumbnails,
    this.trimStart,
    this.trimEnd,
    this.onSeek,
    this.onTrimChange,
  });

  @override
  ConsumerState<TimelineThumbnails> createState() => _TimelineThumbnailsState();
}

class _TimelineThumbnailsState extends ConsumerState<TimelineThumbnails> {
  final ScrollController _scrollController = ScrollController();
  bool _isDraggingLeftHandle = false;
  bool _isDraggingRightHandle = false;
  bool _isDraggingPlayhead = false;

  // Reduced sizes for compact UI
  static const double _thumbnailWidth = 40.0;
  static const double _thumbnailHeight = 36.0;
  static const double _handleWidth = 12.0;
  static const double _timeLabelsHeight = 14.0;
  static const double _thumbnailMargin = 0.5;

  Duration get _totalDuration => widget.project.videoDuration;
  Duration get _trimStart => widget.trimStart ?? widget.project.trimStart;
  Duration get _trimEnd => widget.trimEnd ?? widget.project.trimEnd;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPosition = ref.watch(timelineProvider).currentPosition;
    final zoomLevel = ref.watch(timelineProvider).zoomLevel;

    // Validate duration
    if (_totalDuration == Duration.zero) {
      return _buildEmptyState();
    }

    final thumbnailCount =
        widget.thumbnails?.length ??
        (_totalDuration.inSeconds / 2).ceil().clamp(1, 50);

    // Account for margins in total width calculation
    final thumbnailTotalWidth = _thumbnailWidth * zoomLevel;
    final thumbnailWithMargin = thumbnailTotalWidth + (_thumbnailMargin * 2);
    final totalWidth = thumbnailCount * thumbnailWithMargin;

    return Container(
      height: _thumbnailHeight + _timeLabelsHeight + 2,
      color: Colors.grey[900],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final contentWidth = totalWidth.clamp(screenWidth, double.infinity);

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Scrollable content
              GestureDetector(
                onTapDown: (details) =>
                    _handleTap(details, contentWidth, screenWidth),
                onHorizontalDragStart: (details) =>
                    _handleDragStart(details, contentWidth, currentPosition),
                onHorizontalDragUpdate: (details) =>
                    _handleDragUpdate(details, contentWidth),
                onHorizontalDragEnd: (_) => _handleDragEnd(),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: contentWidth,
                    height: _thumbnailHeight + _timeLabelsHeight + 2,
                    child: Column(
                      children: [
                        // Time labels
                        SizedBox(
                          height: _timeLabelsHeight,
                          child: _buildTimeRuler(contentWidth),
                        ),

                        // Thumbnails with trim overlay
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              // Thumbnails - Use SizedBox to constrain
                              SizedBox(
                                width: contentWidth,
                                child: _buildThumbnailsRow(
                                  thumbnailCount,
                                  zoomLevel,
                                  contentWidth,
                                ),
                              ),

                              // Trim overlay
                              _buildTrimOverlay(contentWidth),

                              // Trim handles
                              _buildTrimHandles(contentWidth),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Playhead (fixed to screen, not scrollable)
              _buildPlayhead(currentPosition, contentWidth, screenWidth),

              // Current time badge
              _buildCurrentTimeBadge(currentPosition, screenWidth),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: _thumbnailHeight + _timeLabelsHeight + 2,
      color: Colors.grey[900],
      child: const Center(
        child: Text(
          'No video loaded',
          style: TextStyle(color: Colors.grey, fontSize: 10),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TIME RULER
  // ═══════════════════════════════════════════════════════

  Widget _buildTimeRuler(double totalWidth) {
    if (_totalDuration == Duration.zero) return const SizedBox.shrink();

    return CustomPaint(
      size: Size(totalWidth, _timeLabelsHeight),
      painter: _TimeRulerPainter(
        totalDuration: _totalDuration,
        totalWidth: totalWidth,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // THUMBNAILS - FIXED OVERFLOW
  // ═══════════════════════════════════════════════════════

  Widget _buildThumbnailsRow(int count, double zoomLevel, double maxWidth) {
    final thumbWidth = _thumbnailWidth * zoomLevel;

    // Use ListView.builder instead of Row to prevent overflow
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) {
        final hasThumbnail =
            widget.thumbnails != null && index < widget.thumbnails!.length;

        return Container(
          width: thumbWidth,
          height: _thumbnailHeight,
          margin: EdgeInsets.symmetric(horizontal: _thumbnailMargin),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: hasThumbnail
                ? Image.memory(
                    widget.thumbnails![index],
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) =>
                        _buildPlaceholderThumbnail(index),
                  )
                : _buildPlaceholderThumbnail(index),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderThumbnail(int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[700]!, Colors.grey[800]!],
        ),
      ),
      child: Center(
        child: Icon(Icons.movie_outlined, color: Colors.grey[600], size: 12),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TRIM OVERLAY
  // ═══════════════════════════════════════════════════════

  Widget _buildTrimOverlay(double totalWidth) {
    if (_totalDuration == Duration.zero) return const SizedBox.shrink();

    final trimStartX = _durationToX(_trimStart, totalWidth);
    final trimEndX = _durationToX(_trimEnd, totalWidth);

    return Stack(
      children: [
        // Left darkened area
        if (trimStartX > 0)
          Positioned(
            left: 0,
            top: 0,
            width: trimStartX.clamp(0, totalWidth),
            bottom: 0,
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

        // Right darkened area
        if (trimEndX < totalWidth)
          Positioned(
            left: trimEndX.clamp(0, totalWidth),
            top: 0,
            right: 0,
            bottom: 0,
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
      ],
    );
  }

  Widget _buildTrimHandles(double totalWidth) {
    if (_totalDuration == Duration.zero) return const SizedBox.shrink();

    final trimStartX = _durationToX(
      _trimStart,
      totalWidth,
    ).clamp(0.0, totalWidth - _handleWidth);
    final trimEndX = _durationToX(
      _trimEnd,
      totalWidth,
    ).clamp(_handleWidth, totalWidth);
    final trimWidth = (trimEndX - trimStartX).clamp(0.0, totalWidth);

    return Stack(
      children: [
        // Top border
        Positioned(
          left: trimStartX,
          top: 0,
          width: trimWidth,
          height: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(1),
              ),
            ),
          ),
        ),

        // Bottom border
        Positioned(
          left: trimStartX,
          bottom: 0,
          width: trimWidth,
          height: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(1),
              ),
            ),
          ),
        ),

        // Left handle
        Positioned(
          left: (trimStartX - _handleWidth / 2).clamp(
            0,
            totalWidth - _handleWidth,
          ),
          top: 0,
          bottom: 0,
          child: GestureDetector(
            onHorizontalDragStart: (_) {
              setState(() => _isDraggingLeftHandle = true);
              HapticFeedback.lightImpact();
            },
            onHorizontalDragUpdate: (details) =>
                _handleLeftTrimDrag(details, totalWidth),
            onHorizontalDragEnd: (_) {
              setState(() => _isDraggingLeftHandle = false);
              HapticFeedback.lightImpact();
            },
            child: _buildHandle(isLeft: true, isActive: _isDraggingLeftHandle),
          ),
        ),

        // Right handle
        Positioned(
          left: (trimEndX - _handleWidth / 2).clamp(
            0,
            totalWidth - _handleWidth,
          ),
          top: 0,
          bottom: 0,
          child: GestureDetector(
            onHorizontalDragStart: (_) {
              setState(() => _isDraggingRightHandle = true);
              HapticFeedback.lightImpact();
            },
            onHorizontalDragUpdate: (details) =>
                _handleRightTrimDrag(details, totalWidth),
            onHorizontalDragEnd: (_) {
              setState(() => _isDraggingRightHandle = false);
              HapticFeedback.lightImpact();
            },
            child: _buildHandle(
              isLeft: false,
              isActive: _isDraggingRightHandle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHandle({required bool isLeft, required bool isActive}) {
    return Container(
      width: _handleWidth,
      decoration: BoxDecoration(
        color: isActive ? Colors.amber : Colors.amber.withValues(alpha: 0.9),
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(3) : Radius.zero,
          right: isLeft ? Radius.zero : const Radius.circular(3),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Container(
          width: 2,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // PLAYHEAD
  // ═══════════════════════════════════════════════════════

  Widget _buildPlayhead(
    Duration position,
    double totalWidth,
    double screenWidth,
  ) {
    if (_totalDuration == Duration.zero) return const SizedBox.shrink();

    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final playheadX = _durationToX(position, totalWidth) - scrollOffset;

    // Hide if out of view
    if (playheadX < -10 || playheadX > screenWidth + 10) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: playheadX.clamp(0.0, screenWidth - 2),
      top: _timeLabelsHeight,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragStart: (_) =>
            setState(() => _isDraggingPlayhead = true),
        onHorizontalDragUpdate: (details) =>
            _handlePlayheadDrag(details, totalWidth),
        onHorizontalDragEnd: (_) => setState(() => _isDraggingPlayhead = false),
        child: Container(
          width: 1.5,
          color: Colors.redAccent,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                transform: Matrix4.translationValues(-4.25, -1, 0),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: _isDraggingPlayhead
                      ? [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // CURRENT TIME BADGE - COMPACT
  // ═══════════════════════════════════════════════════════

  Widget _buildCurrentTimeBadge(Duration position, double screenWidth) {
    return Positioned(
      left: 3,
      top: 0,
      child: Container(
        constraints: BoxConstraints(maxWidth: screenWidth / 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          _formatTime(position),
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // GESTURE HANDLERS
  // ═══════════════════════════════════════════════════════

  void _handleTap(
    TapDownDetails details,
    double totalWidth,
    double screenWidth,
  ) {
    if (_totalDuration == Duration.zero) return;

    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final tapX = (details.localPosition.dx + scrollOffset).clamp(
      0.0,
      totalWidth,
    );
    final position = _xToDuration(tapX, totalWidth);

    final clampedPosition = Duration(
      milliseconds: position.inMilliseconds.clamp(
        _trimStart.inMilliseconds,
        _trimEnd.inMilliseconds,
      ),
    );

    widget.onSeek?.call(clampedPosition);
    HapticFeedback.lightImpact();
  }

  void _handleDragStart(
    DragStartDetails details,
    double totalWidth,
    Duration currentPosition,
  ) {
    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final tapX = details.localPosition.dx + scrollOffset;
    final playheadX = _durationToX(currentPosition, totalWidth);

    if ((tapX - playheadX).abs() < 20) {
      setState(() => _isDraggingPlayhead = true);
    }
  }

  void _handleDragUpdate(DragUpdateDetails details, double totalWidth) {
    if (_isDraggingPlayhead) {
      _handlePlayheadDrag(details, totalWidth);
    }
  }

  void _handleDragEnd() {
    setState(() {
      _isDraggingPlayhead = false;
      _isDraggingLeftHandle = false;
      _isDraggingRightHandle = false;
    });
  }

  void _handlePlayheadDrag(DragUpdateDetails details, double totalWidth) {
    if (_totalDuration == Duration.zero) return;

    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final newX = (details.localPosition.dx + scrollOffset).clamp(
      0.0,
      totalWidth,
    );
    final position = _xToDuration(newX, totalWidth);

    final clampedPosition = Duration(
      milliseconds: position.inMilliseconds.clamp(
        _trimStart.inMilliseconds,
        _trimEnd.inMilliseconds,
      ),
    );

    widget.onSeek?.call(clampedPosition);
  }

  void _handleLeftTrimDrag(DragUpdateDetails details, double totalWidth) {
    if (_totalDuration == Duration.zero) return;

    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final newX = (details.localPosition.dx + scrollOffset).clamp(
      0.0,
      totalWidth,
    );
    var newTrimStart = _xToDuration(newX, totalWidth);

    // Minimum 1 second between handles
    newTrimStart = Duration(
      milliseconds: newTrimStart.inMilliseconds.clamp(
        0,
        (_trimEnd.inMilliseconds - 1000).clamp(
          0,
          _totalDuration.inMilliseconds,
        ),
      ),
    );

    widget.onTrimChange?.call(newTrimStart, _trimEnd);
  }

  void _handleRightTrimDrag(DragUpdateDetails details, double totalWidth) {
    if (_totalDuration == Duration.zero) return;

    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final newX = (details.localPosition.dx + scrollOffset).clamp(
      0.0,
      totalWidth,
    );
    var newTrimEnd = _xToDuration(newX, totalWidth);

    // Minimum 1 second between handles
    newTrimEnd = Duration(
      milliseconds: newTrimEnd.inMilliseconds.clamp(
        (_trimStart.inMilliseconds + 1000).clamp(
          0,
          _totalDuration.inMilliseconds,
        ),
        _totalDuration.inMilliseconds,
      ),
    );

    widget.onTrimChange?.call(_trimStart, newTrimEnd);
  }

  // ═══════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════

  double _durationToX(Duration duration, double totalWidth) {
    if (_totalDuration.inMilliseconds == 0) return 0;
    final ratio = duration.inMilliseconds / _totalDuration.inMilliseconds;
    return (ratio * totalWidth).clamp(0.0, totalWidth);
  }

  Duration _xToDuration(double x, double totalWidth) {
    if (totalWidth <= 0) return Duration.zero;
    final progress = (x / totalWidth).clamp(0.0, 1.0);
    return Duration(
      milliseconds: (progress * _totalDuration.inMilliseconds).toInt(),
    );
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// ═══════════════════════════════════════════════════════
// TIME RULER PAINTER
// ═══════════════════════════════════════════════════════

class _TimeRulerPainter extends CustomPainter {
  final Duration totalDuration;
  final double totalWidth;

  _TimeRulerPainter({required this.totalDuration, required this.totalWidth});

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDuration == Duration.zero || totalWidth <= 0 || size.width <= 0) {
      return;
    }

    final paint = Paint()..strokeWidth = 0.5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final totalSeconds = totalDuration.inSeconds;
    if (totalSeconds <= 0) return;

    final pixelsPerSecond = totalWidth / totalSeconds;

    // Determine interval based on zoom level
    int interval;
    if (pixelsPerSecond < 10) {
      interval = 30;
    } else if (pixelsPerSecond < 20) {
      interval = 15;
    } else if (pixelsPerSecond < 40) {
      interval = 10;
    } else if (pixelsPerSecond < 80) {
      interval = 5;
    } else {
      interval = 1;
    }

    for (int i = 0; i <= totalSeconds; i += interval) {
      final x = (i / totalSeconds) * totalWidth;
      if (x > size.width) break;
      if (x < 0) continue;

      // Draw tick
      paint.color = Colors.white.withValues(alpha: 0.3);
      canvas.drawLine(
        Offset(x, size.height - 3),
        Offset(x, size.height),
        paint,
      );

      // Draw time label
      final time = _formatSeconds(i);
      textPainter.text = TextSpan(
        text: time,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 8,
        ),
      );
      textPainter.layout(maxWidth: 40);

      // Don't draw if it would overflow
      final textX = x - textPainter.width / 2;
      if (textX >= 0 && textX + textPainter.width <= size.width) {
        textPainter.paint(canvas, Offset(textX, 0));
      }
    }
  }

  String _formatSeconds(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) {
    return oldDelegate.totalDuration != totalDuration ||
        oldDelegate.totalWidth != totalWidth;
  }
}
