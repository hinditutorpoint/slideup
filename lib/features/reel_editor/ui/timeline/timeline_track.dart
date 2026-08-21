import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/reel_project.dart';
import '../../providers/timeline_provider.dart';
import '../../providers/selection_provider.dart';
class TimelineTrack extends ConsumerWidget {
  final List<ReelVideoTrack> clips; final double pps;
  final List<ReelAudioTrack>? audioClips;
  final List<ReelTextLayer>? textLayers;
  final List<ReelOverlayTrack>? overlays;
  final List<ReelStickerLayer>? stickers;
  final List<ReelShapeLayer>? shapes;
  const TimelineTrack({super.key, required this.clips, required this.pps, this.audioClips, this.textLayers, this.overlays, this.stickers, this.shapes});
  @override Widget build(BuildContext context, WidgetRef ref){
    final sel = ref.watch(reelTimelineProvider.select((s)=>s.selectedId));
    final tl = ref.read(reelTimelineProvider.notifier);
    return LayoutBuilder(builder: (c, constraints){
      Widget lane(String label, IconData icon, Color col, List<Widget> children, bool empty) => Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(children:[Icon(icon,size:12,color:col), const SizedBox(width:4), Text(label, style: TextStyle(fontSize:10,color:col, fontWeight: FontWeight.w600)), const SizedBox(width:6), Container(height:1, width:40, color:col.withValues(alpha:0.3))]),
        const SizedBox(height:4),
        SizedBox(height:42, child: empty ? Container(alignment: Alignment.centerLeft, child: Text('Empty', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white24))) : SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: children))),
      ]);
      Widget clipBox(String id, double w, Color base, bool isSel, VoidCallback onTap, IconData ico){
        return GestureDetector(onTap: (){ tl.select(id); ref.read(selectionProvider.notifier).select(id, ReelSelectionType.clip); onTap(); }, child: Container(width:w.clamp(36, 800), height:36, margin: const EdgeInsets.only(right:4), decoration:BoxDecoration(color:isSel?base:base.withValues(alpha:0.85), border: Border.all(color:isSel?Colors.white:Colors.transparent, width: isSel?1.5:0), borderRadius:BorderRadius.circular(8), boxShadow: isSel? [BoxShadow(color: base.withValues(alpha:0.4), blurRadius:4)]: null), child: Row(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(ico,size:12,color:Colors.white), const SizedBox(width:4), Flexible(child: FittedBox(fit:BoxFit.scaleDown, child: Text(id.split('_').last, maxLines:1, style: const TextStyle(fontSize:10,color:Colors.white), overflow:TextOverflow.ellipsis))) ])));
      }
      if(clips.isEmpty && (audioClips??[]).isEmpty && (textLayers??[]).isEmpty) {
        return Container(height:48, alignment: Alignment.center, child: Text('No clips — import to start', style: Theme.of(context).textTheme.bodySmall));
      }
      return SingleChildScrollView(child: Column(children:[
        lane('VIDEO', Icons.movie, Colors.deepPurpleAccent, [for (int i=0;i<clips.length;i++) ReorderableDragStartListener(key: ValueKey(clips[i].id), index:i, child: clipBox(clips[i].id, clips[i].trimmedDuration.inMilliseconds/1000*pps, Colors.deepPurpleAccent, sel==clips[i].id, (){}, Icons.play_arrow))], clips.isEmpty),
        const SizedBox(height:6),
        lane('AUDIO', Icons.music_note, Colors.teal, [for(final a in (audioClips??[])) clipBox(a.id, (a.trimEnd-a.trimStart).inMilliseconds/1000*pps *0.6, Colors.teal, sel==a.id, (){}, Icons.graphic_eq)], (audioClips??[]).isEmpty),
        const SizedBox(height:6),
        lane('TEXT', Icons.text_fields, Colors.orange, [for(final t in (textLayers??[])) clipBox(t.id, (t.endTime-t.startTime).inMilliseconds/1000*pps *0.5, Colors.orange, sel==t.id, (){}, Icons.title)], (textLayers??[]).isEmpty),
        const SizedBox(height:6),
        lane('STICKER/SHAPE', Icons.emoji_emotions, Colors.pinkAccent, [for(final s in (stickers??[])) clipBox(s.id, (s.endTime-s.startTime).inMilliseconds/1000*pps*0.4, Colors.pinkAccent, sel==s.id, (){}, Icons.celebration), for(final sh in (shapes??[])) clipBox(sh.id, (sh.endTime-sh.startTime).inMilliseconds/1000*pps*0.4, Colors.amber, sel==sh.id, (){}, Icons.category)], (stickers??[]).isEmpty && (shapes??[]).isEmpty),
      ]));
    });
  }
}
