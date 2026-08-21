// STUB — replaced in reel_editor P2. Kept to avoid breaking legacy imports.
import 'package:flutter/material.dart';
import '../models/video_edit_settings.dart';
class PreviewComponent extends StatefulWidget {
  final String videoPath; final bool showControls; final bool showOverlays; final bool enableInteraction; final ColorGradeSettings? colorGrade; final double volume; final bool showGrid; final bool showSafeArea;
  const PreviewComponent({super.key, required this.videoPath, this.showControls=false, this.showOverlays=true, this.enableInteraction=true, this.colorGrade, this.volume=1, this.showGrid=false, this.showSafeArea=false});
  @override State<PreviewComponent> createState() => PreviewComponentState();
}
class PreviewComponentState extends State<PreviewComponent> {
  Duration? getCurrentPosition() => Duration.zero;
  Future<void> seekTo(Duration p) async {}
  Future<void> play() async {}
  Future<void> pause() async {}
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
