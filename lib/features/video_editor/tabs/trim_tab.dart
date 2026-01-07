import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';

// ═══════════════════════════════════════════════════════
// ✅ TRIM TAB - Provider-Based (No Required Props!)
// ═══════════════════════════════════════════════════════

class TrimTab extends ConsumerStatefulWidget {
  const TrimTab({super.key});

  @override
  ConsumerState<TrimTab> createState() => _TrimTabState();
}

class _TrimTabState extends ConsumerState<TrimTab> {
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;

  @override
  Widget build(BuildContext context) {
    // Get all data from providers
    final project = ref.watch(currentProjectProvider);
    final thumbnails = ref.watch(thumbnailsProvider);

    // Handle null project
    if (project == null) {
      return const Center(
        child: Text('No video loaded', style: TextStyle(color: Colors.white54)),
      );
    }

    final videoDuration = project.videoDuration;
    final trimStart = project.trimStart;
    final trimEnd = project.trimEnd;
    final trimDuration = trimEnd - trimStart;

    // Calculate percentages
    final trimStartPercent = videoDuration.inMilliseconds > 0
        ? trimStart.inMilliseconds / videoDuration.inMilliseconds
        : 0.0;
    final trimEndPercent = videoDuration.inMilliseconds > 0
        ? trimEnd.inMilliseconds / videoDuration.inMilliseconds
        : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 300;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time display
              _buildTimeDisplay(trimStart, trimEnd, trimDuration, isCompact),
              SizedBox(height: isCompact ? 12 : 16),

              // Timeline
              _buildTimeline(
                constraints.maxWidth - (isCompact ? 24 : 32),
                videoDuration,
                trimStartPercent,
                trimEndPercent,
                thumbnails,
              ),
              SizedBox(height: isCompact ? 16 : 24),

              // Quick trim buttons
              _buildQuickTrimSection(videoDuration, isCompact),

              SizedBox(height: isCompact ? 16 : 24),

              // Advanced controls
              _buildAdvancedControls(
                trimStart,
                trimEnd,
                videoDuration,
                isCompact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeDisplay(
    Duration trimStart,
    Duration trimEnd,
    Duration trimDuration,
    bool isCompact,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildTimeChip('Start', trimStart, Colors.green, isCompact),
        ),
        const SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: isCompact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                'Duration',
                style: TextStyle(
                  color: Colors.blue.withValues(alpha: 0.7),
                  fontSize: isCompact ? 10 : 11,
                ),
              ),
              Text(
                _formatDuration(trimDuration),
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: isCompact ? 12 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildTimeChip('End', trimEnd, Colors.red, isCompact)),
      ],
    );
  }

  Widget _buildTimeChip(
    String label,
    Duration time,
    Color color,
    bool isCompact,
  ) {
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
              color: color.withValues(alpha: 0.7),
              fontSize: isCompact ? 10 : 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDuration(time),
            style: TextStyle(
              color: color,
              fontSize: isCompact ? 13 : 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    double width,
    Duration videoDuration,
    double startPercent,
    double endPercent,
    List<Uint8List> thumbnails,
  ) {
    return SizedBox(
      height: 70,
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          final x = details.localPosition.dx;
          final startX = width * startPercent;
          final endX = width * endPercent;

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
            final newStart = Duration(
              milliseconds: (videoDuration.inMilliseconds * percent).toInt(),
            );
            _updateTrimStart(newStart);
          } else if (_isDraggingEnd) {
            final newEnd = Duration(
              milliseconds: (videoDuration.inMilliseconds * percent).toInt(),
            );
            _updateTrimEnd(newEnd);
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
            _buildThumbnailStrip(thumbnails),

            // Dim before start
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: width * startPercent,
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
              width: width * (1 - endPercent),
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
              left: width * startPercent,
              right: width * (1 - endPercent),
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
              left: width * startPercent - 10,
              top: 0,
              bottom: 0,
              child: _buildHandle(true, _isDraggingStart),
            ),

            // End handle
            Positioned(
              left: width * endPercent - 10,
              top: 0,
              bottom: 0,
              child: _buildHandle(false, _isDraggingEnd),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip(List<Uint8List> thumbnails) {
    if (thumbnails.isEmpty) {
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
          children: thumbnails.map((thumb) {
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

  Widget _buildQuickTrimSection(Duration videoDuration, bool isCompact) {
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
            _buildQuickButton(
              'First 15s',
              () => _quickTrim(
                Duration.zero,
                const Duration(seconds: 15),
                videoDuration,
              ),
              isCompact,
            ),
            _buildQuickButton(
              'First 30s',
              () => _quickTrim(
                Duration.zero,
                const Duration(seconds: 30),
                videoDuration,
              ),
              isCompact,
            ),
            _buildQuickButton(
              'First 1m',
              () => _quickTrim(
                Duration.zero,
                const Duration(minutes: 1),
                videoDuration,
              ),
              isCompact,
            ),
            _buildQuickButton(
              'Last 15s',
              () => _quickTrim(
                videoDuration - const Duration(seconds: 15),
                videoDuration,
                videoDuration,
              ),
              isCompact,
            ),
            _buildQuickButton(
              'Last 30s',
              () => _quickTrim(
                videoDuration - const Duration(seconds: 30),
                videoDuration,
                videoDuration,
              ),
              isCompact,
            ),
            _buildQuickButton(
              'Middle',
              () => _quickTrimMiddle(videoDuration),
              isCompact,
            ),
            _buildQuickButton(
              'Reset',
              () => _resetTrim(videoDuration),
              isCompact,
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickButton(
    String label,
    VoidCallback onTap,
    bool isCompact, {
    Color color = Colors.blue,
  }) {
    return Material(
      color: color.withValues(alpha: 0.2),
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
              color: color,
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedControls(
    Duration trimStart,
    Duration trimEnd,
    Duration videoDuration,
    bool isCompact,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Precise Control',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),

        // Frame-by-frame controls
        Row(
          children: [
            Expanded(
              child: _buildFrameControl(
                'Start',
                trimStart,
                Colors.green,
                () => _adjustStartByFrames(-1),
                () => _adjustStartByFrames(1),
                isCompact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFrameControl(
                'End',
                trimEnd,
                Colors.red,
                () => _adjustEndByFrames(-1),
                () => _adjustEndByFrames(1),
                isCompact,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFrameControl(
    String label,
    Duration time,
    Color color,
    VoidCallback onPrevious,
    VoidCallback onNext,
    bool isCompact,
  ) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: Icon(Icons.skip_previous, size: isCompact ? 18 : 20),
                color: color,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Text(
                _formatDuration(time),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 11 : 12,
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: Icon(Icons.skip_next, size: isCompact ? 18 : 20),
                color: color,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTIONS - Using Providers
  // ═══════════════════════════════════════════════════════

  void _updateTrimStart(Duration newStart) {
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    // Ensure valid range
    if (newStart >= Duration.zero && newStart < project.trimEnd) {
      ref.read(projectProvider.notifier).updateTrim(newStart, project.trimEnd);
    }
  }

  void _updateTrimEnd(Duration newEnd) {
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    // Ensure valid range
    if (newEnd > project.trimStart && newEnd <= project.videoDuration) {
      ref.read(projectProvider.notifier).updateTrim(project.trimStart, newEnd);
    }
  }

  void _quickTrim(Duration start, Duration end, Duration videoDuration) {
    // Clamp to valid range
    final clampedStart = start.clampDuration(
      Duration.zero,
      videoDuration - const Duration(seconds: 1),
    );
    final clampedEnd = end.clampDuration(
      clampedStart + const Duration(seconds: 1),
      videoDuration,
    );

    ref.read(projectProvider.notifier).updateTrim(clampedStart, clampedEnd);
  }

  void _quickTrimMiddle(Duration videoDuration) {
    final quarter = videoDuration.inMilliseconds ~/ 4;
    ref
        .read(projectProvider.notifier)
        .updateTrim(
          Duration(milliseconds: quarter),
          Duration(milliseconds: quarter * 3),
        );
  }

  void _resetTrim(Duration videoDuration) {
    ref.read(projectProvider.notifier).updateTrim(Duration.zero, videoDuration);
  }

  void _adjustStartByFrames(int frames) {
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    // Assume 30fps
    const frameDuration = Duration(milliseconds: 33);
    final newStart = project.trimStart + (frameDuration * frames);
    _updateTrimStart(newStart);
  }

  void _adjustEndByFrames(int frames) {
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    // Assume 30fps
    const frameDuration = Duration(milliseconds: 33);
    final newEnd = project.trimEnd + (frameDuration * frames);
    _updateTrimEnd(newEnd);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}
