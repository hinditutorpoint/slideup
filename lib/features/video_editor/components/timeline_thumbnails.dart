// STUB — replaced in reel_editor P3. Kept to avoid breaking legacy imports.
import 'package:flutter/material.dart';
import '../models/video_edit_settings.dart';
class TimelineThumbnails extends StatelessWidget {
  final VideoProject project; final List<dynamic> thumbnails; final Duration trimStart; final Duration trimEnd; final void Function(Duration)? onSeek; final void Function(Duration,Duration)? onTrimChange;
  const TimelineThumbnails({super.key, required this.project, required this.thumbnails, required this.trimStart, required this.trimEnd, this.onSeek, this.onTrimChange});
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
