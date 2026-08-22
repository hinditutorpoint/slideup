import 'dart:typed_data';
import 'package:flutter/material.dart';

class VideoThumbnailProgress extends StatelessWidget {
  final int totalThumbnails;
  final int extractedCount;
  final List<Uint8List> thumbnails;

  const VideoThumbnailProgress({
    super.key,
    required this.totalThumbnails,
    required this.extractedCount,
    required this.thumbnails,
  });

  @override
  Widget build(BuildContext context) {
    // Only show a spinner during the initial extraction phase (no thumbnails
    // yet). Once at least one frame exists, missing slots render as a neutral
    // placeholder so the UI never appears stuck in a perpetual loading state.
    final isExtracting = thumbnails.isEmpty;

    return SizedBox(
      height: 60,
      child: Row(
        children: List.generate(totalThumbnails, (index) {
          final hasThumbnail = index < thumbnails.length;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(2),
              ),
              child: hasThumbnail
                  ? Image.memory(thumbnails[index], fit: BoxFit.cover)
                  : isExtracting
                      ? Center(
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.grey[600]),
                            ),
                          ),
                        )
                      : null,
            ),
          );
        }),
      ),
    );
  }
}
