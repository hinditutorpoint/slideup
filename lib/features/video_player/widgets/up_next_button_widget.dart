import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/player_media.dart';
import '../providers/video_player_provider.dart';
import '../../../services/thumbnail_service.dart';

/// YouTube-style "Up Next" button: the next item's thumbnail inside a rounded
/// pill with a 10-second circular countdown ring. Tap to skip to the next
/// video quickly. Shown only when controls are hidden (or locked) and the
/// current video is within its last lead-time seconds.
class UpNextButtonWidget extends ConsumerStatefulWidget {
  final PlayerMedia nextMedia;
  final double progress;
  final double rightOffset;
  final VoidCallback? onTap;

  const UpNextButtonWidget({
    super.key,
    required this.nextMedia,
    required this.progress,
    this.rightOffset = 16,
    this.onTap,
  });

  @override
  ConsumerState<UpNextButtonWidget> createState() => _UpNextButtonWidgetState();
}

class _UpNextButtonWidgetState extends ConsumerState<UpNextButtonWidget> {
  String? _thumbnailPath;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(UpNextButtonWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextMedia != widget.nextMedia) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final preset = widget.nextMedia.thumbnailPath;
    if (preset != null && preset.isNotEmpty) {
      if (mounted) setState(() => _thumbnailPath = preset);
      return;
    }

    // Local files usually have no precomputed thumbnail — generate one lazily
    // (mirrors how FileThumbnailWidget resolves missing thumbnails).
    final url = widget.nextMedia.url;
    if (url.startsWith('http')) return;

    if (!mounted) return;
    try {
      final path = await ThumbnailService.instance.getThumbnail(url);
      if (!mounted) return;
      setState(() {
        _thumbnailPath = path;
      });
    } catch (e) {
      debugPrint('⚠️ UpNext thumbnail generation failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.only(right: widget.rightOffset, top: 12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap ??
                () {
                  try {
                    ref.read(videoPlayerProvider.notifier).playNext();
                  } catch (e) {
                    debugPrint('⚠️ UpNext playNext error: $e');
                  }
                },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CustomPaint(
                      painter: _CountdownRingPainter(
                        progress: widget.progress.clamp(0.0, 1.0),
                        color: colorScheme.primary,
                        backgroundColor: Colors.white24,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.5),
                        child: ClipOval(child: _buildThumbnail()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Up Next',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            widget.nextMedia.title ?? 'Next video',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final path = _thumbnailPath;
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black45,
      child: const Icon(Icons.movie, color: Colors.white38, size: 16),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  const _CountdownRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;

    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = backgroundColor;
    canvas.drawCircle(center, radius, backgroundPaint);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
