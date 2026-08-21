import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/errors/reel_exceptions.dart';
import '../../core/logging/reel_logger.dart';
import '../../providers/image_provider.dart';
import '../../providers/overlay_provider.dart';
import '../../models/reel_project.dart';
import '../../providers/timeline_provider.dart';

/// Image picker for reel — local gallery | camera | Pixabay download — zero overflow md:94
class ReelImageSheet extends ConsumerStatefulWidget {
  const ReelImageSheet({super.key});
  @override ConsumerState<ReelImageSheet> createState()=> _S();
}
class _S extends ConsumerState<ReelImageSheet> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _search = TextEditingController();
  final _picker = ImagePicker();
  @override void initState(){ super.initState(); _tab=TabController(length:3, vsync:this); WidgetsBinding.instance.addPostFrameCallback((_) { ref.read(reelImageProvider.notifier).search(''); ref.read(reelImageProvider.notifier).loadDownloaded();});}
  @override void dispose(){ _tab.dispose(); _search.dispose(); super.dispose();}
  Future<bool> _ensurePermission(ImageSource src) async {
    try {
      Permission perm = src == ImageSource.camera ? Permission.camera : Permission.photos;
      var status = await perm.status;
      if (status.isGranted || status.isLimited) return true;
      status = await perm.request();
      if (status.isGranted || status.isLimited) return true;
      // Android <13 fallback: photos may map to storage
      if (src == ImageSource.gallery && status.isDenied) {
        var storage = await Permission.storage.status;
        if (storage.isGranted) return true;
        storage = await Permission.storage.request();
        if (storage.isGranted) return true;
      }
      if (status.isPermanentlyDenied || status.isDenied) {
        if (!mounted) return false;
        final open = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(src == ImageSource.camera ? 'Camera permission' : 'Photos permission'),
            content: Text(src == ImageSource.camera
                ? 'Camera access is needed to capture photos. Enable it in app settings?'
                : 'Photo library access is needed to pick images. Enable it in app settings?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Open settings')),
            ],
          ),
        );
        if (open == true) await openAppSettings();
        throw PermissionException(src == ImageSource.camera ? 'camera_denied' : 'photos_denied',
            src == ImageSource.camera ? 'Camera permission denied' : 'Photo permission denied');
      }
      return false;
    } catch (e) {
      if (e is PermissionException) rethrow;
      ReelLogger.error('perm', 'check', e, code: 'perm');
      return false;
    }
  }

  Future<void> _pick(ImageSource src) async {
    try{
      final ok = await _ensurePermission(src);
      if (!ok) return;
      final x = await _picker.pickImage(source: src, imageQuality: 92);
      if(x==null) return;
      final path = await ref.read(reelImageProvider.notifier).validateLocal(x.path);
      _addOverlay(path!);
    } on PermissionException catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));
    } catch(e){
      ReelLogger.error('pick', 'image', e, code: 'pick');
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));
    }
  }
  void _addOverlay(String path){
    final now = ref.read(reelTimelineProvider).currentPosition;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    ref.read(overlayProvider.notifier).addOverlay(ReelOverlayTrack(id: id, imagePath: path, startTime: now, endTime: now+const Duration(seconds:3)));
    if(mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image added to timeline')));
  }
  @override Widget build(BuildContext context){
    final state = ref.watch(reelImageProvider);
    return DraggableScrollableSheet(initialChildSize: 0.78, maxChildSize: 0.92, minChildSize: 0.45, expand: false, builder:(ctx, ctrl)=> SafeArea(child: Column(children:[
      TabBar(controller:_tab, tabs: const[Tab(icon: Icon(Icons.photo_library), text:'Local'), Tab(icon: Icon(Icons.camera_alt), text:'Camera'), Tab(icon: Icon(Icons.cloud_download), text:'Pixabay')]),
      Expanded(child: TabBarView(controller:_tab, children:[
        // Local — downloaded grid
        SingleChildScrollView(controller: ctrl, child: Column(children:[
          const SizedBox(height:8),
          Wrap(spacing:8, runSpacing:8, children:[
            _actionChip(Icons.photo, 'Gallery', ()=>_pick(ImageSource.gallery)),
            _actionChip(Icons.camera, 'Capture', ()=>_pick(ImageSource.camera)),
          ]),
          const Divider(),
          if(state.localDownloaded.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('No downloaded images', style: Theme.of(context).textTheme.bodySmall)),
          LayoutBuilder(builder:(c, bc){
            final w = (bc.maxWidth-24)/3;
            return Wrap(spacing:8, runSpacing:8, children:[for(final img in state.localDownloaded) GestureDetector(onTap: ()=> _addOverlay(img.localPath??img.fullUrl), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(img.localPath!), width:w, height:w, fit:BoxFit.cover, errorBuilder:(a,b,c)=>Container(width:w,height:w,color:Colors.white10, child: const Icon(Icons.broken_image)))))]);})
        ])),
        // Camera quick
        Center(child: Column(mainAxisSize:MainAxisSize.min, children:[
          const Icon(Icons.camera_alt, size:48, color: Colors.white30),
          const SizedBox(height:12),
          FilledButton.icon(onPressed: ()=>_pick(ImageSource.camera), icon: const Icon(Icons.camera), label: const Text('Open Camera')),
          const SizedBox(height:8),
          OutlinedButton.icon(onPressed: ()=>_pick(ImageSource.gallery), icon: const Icon(Icons.collections), label: const Text('Pick from Gallery')),
        ])),
        // Pixabay
        Column(children:[
          Padding(padding: const EdgeInsets.all(8), child: Row(children:[
            Expanded(child: TextField(controller:_search, decoration: const InputDecoration(hintText:'Search Pixabay...', isDense:true, border: OutlineInputBorder()), onSubmitted:(v)=>ref.read(reelImageProvider.notifier).search(v))),
            const SizedBox(width:8),
            IconButton.filled(onPressed: ()=>ref.read(reelImageProvider.notifier).search(_search.text), icon: const Icon(Icons.search)),
          ])),
          if(state.loading) const LinearProgressIndicator(),
          if(state.error!=null) Padding(padding: const EdgeInsets.all(8), child: Text(state.error!, style: const TextStyle(color:Colors.redAccent, fontSize:12))),
          Expanded(child: GridView.builder(controller: ctrl, padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3, crossAxisSpacing:8, mainAxisSpacing:8), itemCount: state.pixabay.length, itemBuilder:(c,i){
            final img = state.pixabay[i];
            return GestureDetector(onTap: () async {
              final path = await ref.read(reelImageProvider.notifier).downloadAndValidate(img);
              if(path!=null) _addOverlay(path);
            }, child: Stack(fit:StackFit.expand, children:[
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(img.thumbnailUrl, fit:BoxFit.cover, errorBuilder:(a,b,c)=>Container(color:Colors.white10))),
              Positioned(right:4,bottom:4, child: Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.download, size:12, color:Colors.white))),
            ]));
          })),
        ]),
      ])),
    ])));}
  Widget _actionChip(IconData ic, String label, VoidCallback cb)=> ActionChip(avatar: Icon(ic,size:16), label: Text(label, style: const TextStyle(fontSize:12)), onPressed: cb);
}
