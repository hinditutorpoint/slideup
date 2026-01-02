import 'dart:typed_data';
import 'package:flutter/material.dart';

class ThumbnailPreviewWidget extends StatelessWidget {
  final Uint8List? thumbnail;
  final Duration position;
  final bool isVisible;
  final double? leftPosition;

  const ThumbnailPreviewWidget({
    super.key,
    this.thumbnail,
    required this.position,
    this.isVisible = false,
    this.leftPosition,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      left: leftPosition ?? 0,
      bottom: 60,
      child: Transform.translate(
        offset: const Offset(-60, 0), // Center the preview
        child: Container(
          width: 120,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thumbnail
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                  child: thumbnail != null
                      ? Image.memory(
                          thumbnail!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              // Time
              Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(3),
                  ),
                ),
                child: Center(
                  child: Text(
                    _formatDuration(position),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
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

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
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

  String _formatDuration(Duration duration) {
    try {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);

      if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }
}

/// Timeline thumbnail strip widget
class ThumbnailTimelineWidget extends StatelessWidget {
  final List<Uint8List> thumbnails;
  final Duration totalDuration;
  final Duration currentPosition;
  final Function(Duration position)? onTap;

  const ThumbnailTimelineWidget({
    super.key,
    required this.thumbnails,
    required this.totalDuration,
    required this.currentPosition,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (thumbnails.isEmpty) {
      return const SizedBox(height: 40);
    }

    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / thumbnails.length;
          final progressPosition = totalDuration.inMilliseconds > 0
              ? (currentPosition.inMilliseconds /
                        totalDuration.inMilliseconds) *
                    constraints.maxWidth
              : 0.0;

          return Stack(
            children: [
              // Thumbnails
              Row(
                children: thumbnails.map((thumb) {
                  return SizedBox(
                    width: itemWidth,
                    child: Image.memory(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey[800]),
                    ),
                  );
                }).toList(),
              ),

              // Progress overlay
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: progressPosition,
                child: Container(color: Colors.black.withValues(alpha: 0.5)),
              ),

              // Scrubber line
              Positioned(
                left: progressPosition - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.red),
              ),

              // Tap detector
              Positioned.fill(
                child: GestureDetector(
                  onTapDown: (details) {
                    if (onTap != null && totalDuration.inMilliseconds > 0) {
                      final position =
                          (details.localPosition.dx / constraints.maxWidth) *
                          totalDuration.inMilliseconds;
                      onTap!(Duration(milliseconds: position.toInt()));
                    }
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
