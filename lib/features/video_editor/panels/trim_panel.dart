import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';

// ═══════════════════════════════════════════════════════
// ✅ TRIM PANEL - Compact Panel Version
// ═══════════════════════════════════════════════════════

class TrimPanel extends ConsumerStatefulWidget {
  final bool isExpanded;

  const TrimPanel({super.key, this.isExpanded = false});

  @override
  ConsumerState<TrimPanel> createState() => _TrimPanelState();
}

class _TrimPanelState extends ConsumerState<TrimPanel> {
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(currentProjectProvider);
    if (project == null) return const SizedBox.shrink();

    final videoDuration = project.videoDuration;
    final trimStart = project.trimStart;
    final trimEnd = project.trimEnd;
    final trimDuration = trimEnd - trimStart;

    // Calculate percentages for sliders
    final trimStartPercent = videoDuration.inMilliseconds > 0
        ? trimStart.inMilliseconds / videoDuration.inMilliseconds
        : 0.0;
    final trimEndPercent = videoDuration.inMilliseconds > 0
        ? trimEnd.inMilliseconds / videoDuration.inMilliseconds
        : 1.0;

    return Container(
      constraints: BoxConstraints(maxHeight: widget.isExpanded ? 400 : 200),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(project),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time display
                  _buildTimeDisplay(trimStart, trimEnd, trimDuration),
                  const SizedBox(height: 12),

                  // Mini timeline
                  _buildMiniTimeline(
                    videoDuration,
                    trimStartPercent,
                    trimEndPercent,
                  ),
                  const SizedBox(height: 16),

                  // Range sliders
                  _buildRangeSliders(videoDuration, trimStart, trimEnd),
                  const SizedBox(height: 12),

                  // Quick actions
                  _buildQuickActions(videoDuration),

                  if (_showAdvanced) ...[
                    const SizedBox(height: 16),
                    _buildAdvancedControls(trimStart, trimEnd, videoDuration),
                  ],
                ],
              ),
            ),
          ),

          // Action buttons
          _buildActionButtons(trimStart, trimEnd, videoDuration),
        ],
      ),
    );
  }

  Widget _buildHeader(VideoProject project) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.content_cut, size: 20, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Trim Video',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Original: ${_formatDuration(project.videoDuration)}',
                  style: TextStyle(
                    color: Colors.blue.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Advanced toggle
          TextButton(
            onPressed: () {
              setState(() => _showAdvanced = !_showAdvanced);
            },
            child: Text(
              _showAdvanced ? 'Simple' : 'Advanced',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay(
    Duration trimStart,
    Duration trimEnd,
    Duration trimDuration,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildTimeCard(
            'Start',
            _formatDuration(trimStart),
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTimeCard(
            'Duration',
            _formatDuration(trimDuration),
            Colors.blue,
            isHighlighted: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTimeCard('End', _formatDuration(trimEnd), Colors.red),
        ),
      ],
    );
  }

  Widget _buildTimeCard(
    String label,
    String value,
    Color color, {
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlighted
              ? color.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: isHighlighted ? color : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTimeline(
    Duration videoDuration,
    double startPercent,
    double endPercent,
  ) {
    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          return GestureDetector(
            onHorizontalDragStart: (details) {
              final x = details.localPosition.dx;
              final startX = width * startPercent;
              final endX = width * endPercent;

              if ((x - startX).abs() < 20) {
                setState(() => _isDraggingStart = true);
              } else if ((x - endX).abs() < 20) {
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
                final currentEnd = ref.read(currentProjectProvider)!.trimEnd;
                if (newStart < currentEnd) {
                  ref
                      .read(projectProvider.notifier)
                      .updateTrim(newStart, currentEnd);
                }
              } else if (_isDraggingEnd) {
                final currentStart = ref
                    .read(currentProjectProvider)!
                    .trimStart;
                final newEnd = Duration(
                  milliseconds: (videoDuration.inMilliseconds * percent)
                      .toInt(),
                );
                if (newEnd > currentStart) {
                  ref
                      .read(projectProvider.notifier)
                      .updateTrim(currentStart, newEnd);
                }
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
                // Background
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                // Selected region
                Positioned(
                  left: width * startPercent,
                  right: width * (1 - endPercent),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.3),
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Start handle
                Positioned(
                  left: width * startPercent - 8,
                  top: 0,
                  bottom: 0,
                  child: _buildHandle(
                    isStart: true,
                    isActive: _isDraggingStart,
                  ),
                ),

                // End handle
                Positioned(
                  left: width * endPercent - 8,
                  top: 0,
                  bottom: 0,
                  child: _buildHandle(isStart: false, isActive: _isDraggingEnd),
                ),

                // Time markers
                ..._buildTimeMarkers(width, videoDuration),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandle({required bool isStart, required bool isActive}) {
    return Container(
      width: 16,
      decoration: BoxDecoration(
        color: isActive ? Colors.blue : Colors.blue.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(2),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Container(
          width: 2,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimeMarkers(double width, Duration duration) {
    final markers = <Widget>[];
    const markerCount = 5;

    for (int i = 0; i <= markerCount; i++) {
      final x = (width / markerCount) * i;
      final time = Duration(
        milliseconds: ((duration.inMilliseconds / markerCount) * i).toInt(),
      );

      markers.add(
        Positioned(
          left: x - 1,
          top: 0,
          height: 6,
          child: Container(
            width: 1,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
      );

      markers.add(
        Positioned(
          left: x - 10,
          bottom: -16,
          child: Text(
            _formatDurationShort(time),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 8,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildRangeSliders(
    Duration videoDuration,
    Duration trimStart,
    Duration trimEnd,
  ) {
    final maxMs = videoDuration.inMilliseconds.toDouble();
    if (maxMs <= 0) return const SizedBox.shrink();

    final startMs = trimStart.inMilliseconds.toDouble();
    final endMs = trimEnd.inMilliseconds.toDouble();

    return Column(
      children: [
        // Start time slider
        _buildSlider(
          label: 'Start Time',
          value: startMs,
          min: 0,
          max: endMs - 1000, // At least 1 second duration
          color: Colors.green,
          onChanged: (value) {
            ref
                .read(projectProvider.notifier)
                .updateTrim(Duration(milliseconds: value.toInt()), trimEnd);
          },
        ),
        const SizedBox(height: 8),

        // End time slider
        _buildSlider(
          label: 'End Time',
          value: endMs,
          min: startMs + 1000, // At least 1 second duration
          max: maxMs,
          color: Colors.red,
          onChanged: (value) {
            ref
                .read(projectProvider.notifier)
                .updateTrim(trimStart, Duration(milliseconds: value.toInt()));
          },
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            Text(
              _formatDuration(Duration(milliseconds: value.toInt())),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.1),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(Duration videoDuration) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildQuickButton(
          'First 15s',
          () => _applyQuickTrim(Duration.zero, const Duration(seconds: 15)),
        ),
        _buildQuickButton(
          'Last 15s',
          () => _applyQuickTrim(
            videoDuration - const Duration(seconds: 15),
            videoDuration,
          ),
        ),
        _buildQuickButton(
          'Middle 50%',
          () => _applyQuickTrim(
            Duration(milliseconds: videoDuration.inMilliseconds ~/ 4),
            Duration(milliseconds: videoDuration.inMilliseconds * 3 ~/ 4),
          ),
        ),
        _buildQuickButton(
          'Reset',
          () => ref
              .read(projectProvider.notifier)
              .updateTrim(Duration.zero, videoDuration),
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildQuickButton(
    String label,
    VoidCallback onTap, {
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Precise Time Input',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTimeInput(
                label: 'Start',
                time: trimStart,
                onChanged: (newTime) {
                  if (newTime < trimEnd) {
                    ref
                        .read(projectProvider.notifier)
                        .updateTrim(newTime, trimEnd);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimeInput(
                label: 'End',
                time: trimEnd,
                onChanged: (newTime) {
                  if (newTime > trimStart && newTime <= videoDuration) {
                    ref
                        .read(projectProvider.notifier)
                        .updateTrim(trimStart, newTime);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Frame-by-frame controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Frame Control',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            Row(
              children: [
                _buildFrameButton(
                  Icons.skip_previous,
                  () => _adjustByFrames(trimStart, -1, true),
                ),
                const SizedBox(width: 4),
                Text(
                  'Start',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 4),
                _buildFrameButton(
                  Icons.skip_next,
                  () => _adjustByFrames(trimStart, 1, true),
                ),
                const SizedBox(width: 16),
                _buildFrameButton(
                  Icons.skip_previous,
                  () => _adjustByFrames(trimEnd, -1, false),
                ),
                const SizedBox(width: 4),
                Text(
                  'End',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 4),
                _buildFrameButton(
                  Icons.skip_next,
                  () => _adjustByFrames(trimEnd, 1, false),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeInput({
    required String label,
    required Duration time,
    required Function(Duration) onChanged,
  }) {
    final controller = TextEditingController(text: _formatDuration(time));

    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onSubmitted: (value) {
        final parsed = _parseDuration(value);
        if (parsed != null) {
          onChanged(parsed);
        }
      },
    );
  }

  Widget _buildFrameButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    Duration trimStart,
    Duration trimEnd,
    Duration videoDuration,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Preview button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _previewTrim(),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Preview', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Apply button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: trimStart == Duration.zero && trimEnd == videoDuration
                  ? null
                  : () => _applyTrim(),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Apply Trim', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTIONS
  // ═══════════════════════════════════════════════════════

  void _applyQuickTrim(Duration start, Duration end) {
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    // Clamp to valid range
    final clampedStart = start.clampDuration(
      Duration.zero,
      project.videoDuration - const Duration(seconds: 1),
    );
    final clampedEnd = end.clampDuration(
      clampedStart + const Duration(seconds: 1),
      project.videoDuration,
    );

    ref.read(projectProvider.notifier).updateTrim(clampedStart, clampedEnd);
  }

  void _adjustByFrames(Duration current, int frames, bool isStart) {
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    // Assume 30fps
    const frameDuration = Duration(milliseconds: 33);
    final adjustment = frameDuration * frames;
    final newTime = current + adjustment;

    if (isStart) {
      if (newTime >= Duration.zero && newTime < project.trimEnd) {
        ref.read(projectProvider.notifier).updateTrim(newTime, project.trimEnd);
      }
    } else {
      if (newTime > project.trimStart && newTime <= project.videoDuration) {
        ref
            .read(projectProvider.notifier)
            .updateTrim(project.trimStart, newTime);
      }
    }
  }

  void _previewTrim() {
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    // Seek to trim start
    ref.read(timelineProvider.notifier).setCurrentPosition(project.trimStart);
    ref.read(videoEditorProvider.notifier).setPreviewPlaying(true);

    // Auto-pause at trim end
    Future.delayed(project.trimEnd - project.trimStart, () {
      if (mounted) {
        ref.read(videoEditorProvider.notifier).setPreviewPlaying(false);
      }
    });
  }

  void _applyTrim() {
    // Save project with trim applied
    ref.read(projectProvider.notifier).saveProject();
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trim applied'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final ms = (d.inMilliseconds.remainder(1000) ~/ 10);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}.'
          '${ms.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${ms.toString().padLeft(2, '0')}';
  }

  String _formatDurationShort(Duration d) {
    if (d.inMinutes >= 60) {
      return '${d.inHours}h';
    } else if (d.inSeconds >= 60) {
      return '${d.inMinutes}m';
    }
    return '${d.inSeconds}s';
  }

  Duration? _parseDuration(String input) {
    try {
      final parts = input.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final ms = secondsParts.length > 1
            ? int.parse(secondsParts[1].padRight(3, '0'))
            : 0;
        return Duration(minutes: minutes, seconds: seconds, milliseconds: ms);
      } else if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secondsParts = parts[2].split('.');
        final seconds = int.parse(secondsParts[0]);
        final ms = secondsParts.length > 1
            ? int.parse(secondsParts[1].padRight(3, '0'))
            : 0;
        return Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          milliseconds: ms,
        );
      }
    } catch (e) {
      debugPrint('Failed to parse duration: $input');
    }
    return null;
  }
}
