import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/video_edit_settings.dart';

class TimelineThumbnails extends StatelessWidget {
  final VideoProject project;
  final List<dynamic> thumbnails;
  final Duration trimStart;
  final Duration trimEnd;
  final void Function(Duration)? onSeek;
  final void Function(Duration, Duration)? onTrimChange;

  const TimelineThumbnails({
    super.key,
    required this.project,
    required this.thumbnails,
    required this.trimStart,
    required this.trimEnd,
    this.onSeek,
    this.onTrimChange,
  });

  @override
  Widget build(BuildContext context) {
    if (thumbnails.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final durationMs = project.videoDuration.inMilliseconds;
        
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (onSeek != null && durationMs > 0) {
              final ratio = (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
              final targetMs = (ratio * durationMs).round();
              onSeek!(Duration(milliseconds: targetMs));
            }
          },
          child: Container(
            width: totalWidth,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnails row
                  Row(
                    children: thumbnails.map((thumb) {
                      return Expanded(
                        child: thumb is Uint8List
                            ? Image.memory(
                                thumb,
                                fit: BoxFit.cover,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[800],
                                ),
                              )
                            : Container(color: Colors.grey[800]),
                      );
                    }).toList(),
                  ),

                  // Overlay semi-transparent background for contrast
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
