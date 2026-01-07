import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';

class TimelineThumbnails extends ConsumerStatefulWidget {
  final VideoProject project;
  final ValueChanged<Duration>? onSeek;

  const TimelineThumbnails({super.key, required this.project, this.onSeek});

  @override
  ConsumerState<TimelineThumbnails> createState() => _TimelineThumbnailsState();
}

class _TimelineThumbnailsState extends ConsumerState<TimelineThumbnails> {
  final ScrollController _scrollController = ScrollController();
  static const double thumbnailHeight = 60.0;
  static const double thumbnailWidth = 45.0;
  static const double playheadWidth = 2.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPosition = ref.watch(currentPositionProvider);
    final totalDuration = widget.project.videoDuration;

    return Container(
      height: thumbnailHeight + 20,
      color: Colors.grey[900],
      child: Stack(
        children: [
          // Thumbnails
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: GestureDetector(
              onTapDown: (details) => _handleTap(details, totalDuration),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: _buildThumbnails()),
              ),
            ),
          ),

          // Playhead
          _buildPlayhead(currentPosition, totalDuration),

          // Time overlay
          _buildTimeOverlay(currentPosition, totalDuration),
        ],
      ),
    );
  }

  List<Widget> _buildThumbnails() {
    final totalSeconds = widget.project.videoDuration.inSeconds;
    final thumbnailCount = (totalSeconds / 2)
        .ceil(); // One thumbnail every 2 seconds

    return List.generate(thumbnailCount, (index) {
      return Container(
        width: thumbnailWidth,
        height: thumbnailHeight,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            // Placeholder for actual thumbnail
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[700]!, Colors.grey[800]!],
                ),
              ),
              child: Center(
                child: Icon(Icons.image, color: Colors.grey[600], size: 20),
              ),
            ),

            // Time label
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  _formatTime(Duration(seconds: index * 2)),
                  style: const TextStyle(fontSize: 8, color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPlayhead(Duration position, Duration total) {
    final progress = total.inMilliseconds > 0
        ? position.inMilliseconds / total.inMilliseconds
        : 0.0;

    return Positioned(
      left: progress * MediaQuery.of(context).size.width,
      top: 0,
      bottom: 0,
      child: Container(
        width: playheadWidth,
        color: Colors.red,
        child: Column(
          children: [
            Container(
              width: 12,
              height: 12,
              transform: Matrix4.translationValues(-5, 6, 0),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOverlay(Duration position, Duration total) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                _formatTime(position),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                _formatTime(total),
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details, Duration totalDuration) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localX = details.localPosition.dx + _scrollController.offset;
    final totalWidth = box.size.width;
    final progress = (localX / totalWidth).clamp(0.0, 1.0);
    final newPosition = Duration(
      milliseconds: (totalDuration.inMilliseconds * progress).toInt(),
    );

    widget.onSeek?.call(newPosition);
    HapticFeedback.lightImpact();
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
