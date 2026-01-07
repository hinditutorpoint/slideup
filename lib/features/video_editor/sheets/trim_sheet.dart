import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

// ═══════════════════════════════════════════════════════
// ✅ TRIM SHEET (YouCut Style)
// ═══════════════════════════════════════════════════════

class TrimSheet extends ConsumerStatefulWidget {
  const TrimSheet({super.key});

  @override
  ConsumerState<TrimSheet> createState() => _TrimSheetState();
}

class _TrimSheetState extends ConsumerState<TrimSheet> {
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(currentProjectProvider);

    if (project == null) {
      return Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Color(0xFF2D2D2D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(
          child: Text(
            'No video loaded',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final thumbnails = ref.watch(thumbnailsProvider);
    final videoDuration = project.videoDuration;
    final trimStart = project.trimStart;
    final trimEnd = project.trimEnd;
    final trimDuration = trimEnd - trimStart;

    final trimStartPercent = videoDuration.inMilliseconds > 0
        ? trimStart.inMilliseconds / videoDuration.inMilliseconds
        : 0.0;
    final trimEndPercent = videoDuration.inMilliseconds > 0
        ? trimEnd.inMilliseconds / videoDuration.inMilliseconds
        : 1.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trim Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time display chips
                  _buildTimeDisplay(trimStart, trimEnd, trimDuration),

                  const SizedBox(height: 24),

                  // Timeline with thumbnails
                  _buildTimeline(
                    context,
                    videoDuration,
                    trimStartPercent,
                    trimEndPercent,
                    thumbnails,
                  ),

                  const SizedBox(height: 32),

                  // Quick trim section
                  _buildQuickTrimSection(videoDuration),

                  const SizedBox(height: 24),

                  // Precise controls
                  _buildPreciseControls(trimStart, trimEnd, videoDuration),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Apply button
          _buildApplyButton(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TIME DISPLAY
  // ═══════════════════════════════════════════════════════

  Widget _buildTimeDisplay(
    Duration trimStart,
    Duration trimEnd,
    Duration trimDuration,
  ) {
    return Row(
      children: [
        // Start time
        Expanded(
          child: _buildTimeChip(
            'Start',
            trimStart,
            const Color(0xFF4CAF50),
            Icons.arrow_forward,
          ),
        ),

        const SizedBox(width: 12),

        // Duration
        Expanded(
          child: _buildTimeChip(
            'Duration',
            trimDuration,
            const Color(0xFFFF6B6B),
            Icons.timer_outlined,
          ),
        ),

        const SizedBox(width: 12),

        // End time
        Expanded(
          child: _buildTimeChip(
            'End',
            trimEnd,
            const Color(0xFFF44336),
            Icons.stop,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeChip(
    String label,
    Duration time,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDuration(time),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TIMELINE WITH THUMBNAILS
  // ═══════════════════════════════════════════════════════

  Widget _buildTimeline(
    BuildContext context,
    Duration videoDuration,
    double startPercent,
    double endPercent,
    List<Uint8List> thumbnails,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Drag handles to trim',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            return SizedBox(
              height: 80,
              child: GestureDetector(
                onHorizontalDragStart: (details) {
                  final x = details.localPosition.dx;
                  final startX = width * startPercent;
                  final endX = width * endPercent;

                  if ((x - startX).abs() < 30) {
                    setState(() => _isDraggingStart = true);
                  } else if ((x - endX).abs() < 30) {
                    setState(() => _isDraggingEnd = true);
                  }
                },
                onHorizontalDragUpdate: (details) {
                  final x = details.localPosition.dx;
                  final percent = (x / width).clamp(0.0, 1.0);

                  if (_isDraggingStart) {
                    final newStart = Duration(
                      milliseconds: (videoDuration.inMilliseconds * percent)
                          .toInt(),
                    );
                    _updateTrimStart(newStart);
                  } else if (_isDraggingEnd) {
                    final newEnd = Duration(
                      milliseconds: (videoDuration.inMilliseconds * percent)
                          .toInt(),
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
                    // Thumbnail strip
                    _buildThumbnailStrip(thumbnails),

                    // Dim overlay before start
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: width * startPercent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    // Dim overlay after end
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: width * (1 - endPercent),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(8),
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
                          border: Border.all(
                            color: const Color(0xFFFF6B6B),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    // Start handle
                    Positioned(
                      left: width * startPercent - 14,
                      top: 0,
                      bottom: 0,
                      child: _buildHandle(true, _isDraggingStart),
                    ),

                    // End handle
                    Positioned(
                      left: width * endPercent - 14,
                      top: 0,
                      bottom: 0,
                      child: _buildHandle(false, _isDraggingEnd),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildThumbnailStrip(List<Uint8List> thumbnails) {
    if (thumbnails.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 80,
        child: Row(
          children: thumbnails.map((thumb) {
            return Expanded(
              child: Image.memory(thumb, fit: BoxFit.cover, height: 80),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHandle(bool isStart, bool isActive) {
    return Container(
      width: 28,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFF6B6B) : Colors.white,
        borderRadius: BorderRadius.horizontal(
          left: isStart ? const Radius.circular(6) : Radius.zero,
          right: !isStart ? const Radius.circular(6) : Radius.zero,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drag_handle,
            color: isActive ? Colors.white : Colors.black87,
            size: 20,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ QUICK TRIM SECTION
  // ═══════════════════════════════════════════════════════

  Widget _buildQuickTrimSection(Duration videoDuration) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Trim',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildQuickButton(
              'First 15s',
              Icons.looks_one,
              () => _quickTrim(
                Duration.zero,
                const Duration(seconds: 15),
                videoDuration,
              ),
            ),
            _buildQuickButton(
              'First 30s',
              Icons.looks_two,
              () => _quickTrim(
                Duration.zero,
                const Duration(seconds: 30),
                videoDuration,
              ),
            ),
            _buildQuickButton(
              'First 1m',
              Icons.looks_3,
              () => _quickTrim(
                Duration.zero,
                const Duration(minutes: 1),
                videoDuration,
              ),
            ),
            _buildQuickButton(
              'Last 15s',
              Icons.last_page,
              () => _quickTrim(
                videoDuration - const Duration(seconds: 15),
                videoDuration,
                videoDuration,
              ),
            ),
            _buildQuickButton(
              'Last 30s',
              Icons.skip_previous,
              () => _quickTrim(
                videoDuration - const Duration(seconds: 30),
                videoDuration,
                videoDuration,
              ),
            ),
            _buildQuickButton(
              'Middle',
              Icons.crop_16_9,
              () => _quickTrimMiddle(videoDuration),
            ),
            _buildQuickButton(
              'Reset',
              Icons.refresh,
              () => _resetTrim(videoDuration),
              color: const Color(0xFFFF9800),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    Color color = const Color(0xFF2196F3),
  }) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PRECISE CONTROLS (Frame-by-Frame)
  // ═══════════════════════════════════════════════════════

  Widget _buildPreciseControls(
    Duration trimStart,
    Duration trimEnd,
    Duration videoDuration,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Precise Control',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFrameControl(
                'Start',
                trimStart,
                const Color(0xFF4CAF50),
                () => _adjustStartByFrames(-1),
                () => _adjustStartByFrames(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFrameControl(
                'End',
                trimEnd,
                const Color(0xFFF44336),
                () => _adjustEndByFrames(-1),
                () => _adjustEndByFrames(1),
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
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  onPrevious();
                  HapticFeedback.lightImpact();
                },
                icon: Icon(Icons.remove_circle_outline, size: 24, color: color),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              Expanded(
                child: Text(
                  _formatDuration(time),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: () {
                  onNext();
                  HapticFeedback.lightImpact();
                },
                icon: Icon(Icons.add_circle_outline, size: 24, color: color),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ APPLY BUTTON
  // ═══════════════════════════════════════════════════════

  Widget _buildApplyButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trim applied'),
                  backgroundColor: Color(0xFF4CAF50),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Apply Trim',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTIONS (From trim_tab.dart)
  // ═══════════════════════════════════════════════════════

  void _updateTrimStart(Duration newStart) {
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    if (newStart >= Duration.zero && newStart < project.trimEnd) {
      ref.read(projectProvider.notifier).updateTrim(newStart, project.trimEnd);
    }
  }

  void _updateTrimEnd(Duration newEnd) {
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    if (newEnd > project.trimStart && newEnd <= project.videoDuration) {
      ref.read(projectProvider.notifier).updateTrim(project.trimStart, newEnd);
    }
  }

  void _quickTrim(Duration start, Duration end, Duration videoDuration) {
    final clampedStart = start.clamp(
      Duration.zero,
      videoDuration - const Duration(seconds: 1),
    );
    final clampedEnd = end.clamp(
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

    const frameDuration = Duration(milliseconds: 33); // ~30fps
    final newStart = project.trimStart + (frameDuration * frames);
    _updateTrimStart(newStart);
  }

  void _adjustEndByFrames(int frames) {
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    const frameDuration = Duration(milliseconds: 33); // ~30fps
    final newEnd = project.trimEnd + (frameDuration * frames);
    _updateTrimEnd(newEnd);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (h > 0) {
      return '$h:$m:$s';
    }
    return '$m:$s';
  }
}

// ═══════════════════════════════════════════════════════
// ✅ EXTENSION HELPER
// ═══════════════════════════════════════════════════════

extension DurationExtension on Duration {
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}
