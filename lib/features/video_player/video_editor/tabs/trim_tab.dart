import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TrimTab extends StatefulWidget {
  final String videoPath;
  final Duration videoDuration;
  final List<Uint8List> thumbnails;
  final double trimStartPercent;
  final double trimEndPercent;
  final Function(double start, double end) onTrimChanged;

  const TrimTab({
    super.key,
    required this.videoPath,
    required this.videoDuration,
    required this.thumbnails,
    required this.trimStartPercent,
    required this.trimEndPercent,
    required this.onTrimChanged,
  });

  @override
  State<TrimTab> createState() => _TrimTabState();
}

class _TrimTabState extends State<TrimTab> {
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;

  Duration get _trimStart => Duration(
    milliseconds:
        (widget.videoDuration.inMilliseconds * widget.trimStartPercent).toInt(),
  );
  Duration get _trimEnd => Duration(
    milliseconds: (widget.videoDuration.inMilliseconds * widget.trimEndPercent)
        .toInt(),
  );
  Duration get _trimDuration => _trimEnd - _trimStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 300;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time display
              _buildTimeDisplay(isCompact),
              SizedBox(height: isCompact ? 12 : 16),

              // Timeline
              _buildTimeline(constraints.maxWidth - (isCompact ? 24 : 32)),
              SizedBox(height: isCompact ? 16 : 24),

              // Quick trim buttons
              _buildQuickTrimSection(isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeDisplay(bool isCompact) {
    return Row(
      children: [
        Expanded(child: _buildTimeChip('Start', _trimStart, isCompact)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _formatDuration(_trimDuration),
            style: TextStyle(
              color: Colors.red,
              fontSize: isCompact ? 12 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildTimeChip('End', _trimEnd, isCompact)),
      ],
    );
  }

  Widget _buildTimeChip(String label, Duration time, bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: isCompact ? 10 : 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDuration(time),
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 13 : 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(double width) {
    return SizedBox(
      height: 70,
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          final x = details.localPosition.dx;
          final startX = width * widget.trimStartPercent;
          final endX = width * widget.trimEndPercent;

          if ((x - startX).abs() < 24) {
            setState(() => _isDraggingStart = true);
          } else if ((x - endX).abs() < 24) {
            setState(() => _isDraggingEnd = true);
          }
        },
        onHorizontalDragUpdate: (details) {
          final x = details.localPosition.dx;
          final percent = (x / width).clamp(0.0, 1.0);

          if (_isDraggingStart) {
            widget.onTrimChanged(
              percent.clamp(0.0, widget.trimEndPercent - 0.02),
              widget.trimEndPercent,
            );
          } else if (_isDraggingEnd) {
            widget.onTrimChanged(
              widget.trimStartPercent,
              percent.clamp(widget.trimStartPercent + 0.02, 1.0),
            );
          }
        },
        onHorizontalDragEnd: (_) {
          setState(() {
            _isDraggingStart = false;
            _isDraggingEnd = false;
          });
          HapticFeedback.lightImpact();
        },
        child: Stack(
          children: [
            // Thumbnails
            _buildThumbnailStrip(),

            // Dim before start
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: width * widget.trimStartPercent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(4),
                  ),
                ),
              ),
            ),

            // Dim after end
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: width * (1 - widget.trimEndPercent),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(4),
                  ),
                ),
              ),
            ),

            // Selection border
            Positioned(
              left: width * widget.trimStartPercent,
              right: width * (1 - widget.trimEndPercent),
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow, width: 2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Start handle
            Positioned(
              left: width * widget.trimStartPercent - 10,
              top: 0,
              bottom: 0,
              child: _buildHandle(true, _isDraggingStart),
            ),

            // End handle
            Positioned(
              left: width * widget.trimEndPercent - 10,
              top: 0,
              bottom: 0,
              child: _buildHandle(false, _isDraggingEnd),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    if (widget.thumbnails.isEmpty) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 50,
        child: Row(
          children: widget.thumbnails.map((thumb) {
            return Expanded(
              child: Image.memory(thumb, fit: BoxFit.cover, height: 50),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHandle(bool isStart, bool isActive) {
    return Container(
      width: 20,
      decoration: BoxDecoration(
        color: isActive ? Colors.yellow : Colors.yellow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.horizontal(
          left: isStart ? const Radius.circular(4) : Radius.zero,
          right: !isStart ? const Radius.circular(4) : Radius.zero,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.yellow.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: const Center(
        child: Icon(Icons.drag_handle, color: Colors.black87, size: 14),
      ),
    );
  }

  Widget _buildQuickTrimSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Trim',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickButton('First 15s', () => _quickTrim(0, 15), isCompact),
            _buildQuickButton('First 30s', () => _quickTrim(0, 30), isCompact),
            _buildQuickButton('First 1m', () => _quickTrim(0, 60), isCompact),
            _buildQuickButton(
              'Last 15s',
              () => _quickTrimFromEnd(15),
              isCompact,
            ),
            _buildQuickButton(
              'Last 30s',
              () => _quickTrimFromEnd(30),
              isCompact,
            ),
            _buildQuickButton('Middle', () => _quickTrimMiddle(), isCompact),
            _buildQuickButton(
              'Reset',
              () => widget.onTrimChanged(0, 1),
              isCompact,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickButton(String label, VoidCallback onTap, bool isCompact) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 12,
            vertical: isCompact ? 6 : 8,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 11 : 12,
            ),
          ),
        ),
      ),
    );
  }

  void _quickTrim(int startSec, int endSec) {
    final totalSec = widget.videoDuration.inSeconds;
    final start = (startSec / totalSec).clamp(0.0, 1.0);
    final end = (endSec / totalSec).clamp(0.0, 1.0);
    widget.onTrimChanged(start, end);
  }

  void _quickTrimFromEnd(int seconds) {
    final totalSec = widget.videoDuration.inSeconds;
    final start = ((totalSec - seconds) / totalSec).clamp(0.0, 1.0);
    widget.onTrimChanged(start, 1.0);
  }

  void _quickTrimMiddle() {
    widget.onTrimChanged(0.25, 0.75);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}
