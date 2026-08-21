import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/timeline_provider.dart';
import 'timeline_ruler.dart';
import 'timeline_track.dart';
class TimelineEditor extends ConsumerWidget {
  final Duration duration;
  const TimelineEditor({super.key, required this.duration});
  @override Widget build(BuildContext context, WidgetRef ref){
    final tlState = ref.watch(reelTimelineProvider);
    final tl = ref.read(reelTimelineProvider.notifier);
    final project = tl.project;
    final pps = 60 * tlState.zoomLevel; // 60 px/sec base
    final clips = project?.videoTracks ?? [];
    return Column(mainAxisSize:MainAxisSize.min, children:[
      // zoom controls — Wrap avoids overflow md:3
      Padding(padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), child: Row(children:[
        Expanded(child:Wrap(spacing:6, children:[ActionChip(label: const Text('−'), onPressed:()=>tl.setZoom(tlState.zoomLevel-0.25)), ActionChip(label: Text('${tlState.zoomLevel.toStringAsFixed(1)}x'), onPressed:(){}), ActionChip(label: const Text('+'), onPressed:()=>tl.setZoom(tlState.zoomLevel+0.25))])),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize:MainAxisSize.min, children:[IconButton(icon: const Icon(Icons.content_cut, size:18), tooltip:'Split at playhead', onPressed: tl.splitAtPlayhead), IconButton(icon: const Icon(Icons.copy, size:18), tooltip:'Duplicate', onPressed: tlState.selectedId==null?null:()=>tl.duplicateClip(tlState.selectedId!)), IconButton(icon: const Icon(Icons.delete_outline, size:18), tooltip:'Delete', onPressed: tlState.selectedId==null?null:()=>tl.deleteClip(tlState.selectedId!))]))) ,
      ])),
      TimelineRuler(duration: duration, pixelsPerSecond: pps, position: tlState.currentPosition),
      SizedBox(height:56, child: Stack(children:[
        TimelineTrack(clips: clips, pps: pps),
        // playhead — RepaintBoundary for isolated repaint md:6
        RepaintBoundary(child: Positioned(left: tlState.currentPosition.inMilliseconds/1000*pps -1, top:0, bottom:0, child: Container(width:2, color: Theme.of(context).colorScheme.error))),
      ])),
      // scrub — responsive Slider with snap
      Slider(value: tlState.currentPosition.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()), min:0, max:duration.inMilliseconds.toDouble().clamp(1, double.infinity), onChanged:(v){ final raw=Duration(milliseconds:v.round()); tl.setPosition(tl.snap(raw));}),
    ]);
  }
}
