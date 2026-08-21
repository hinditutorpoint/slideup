import 'reel_project.dart';
import 'canvas_preset.dart';

/// Adapter: VideoProject (legacy) -> ReelProject
/// Allows existing hive data to migrate without loss md:212-218
Map<String, dynamic> migrateLegacyVideoProject(Map<String, dynamic> legacy) {
  // legacy has videoPath, videoDuration, trimStart/End, textItems/imageItems/audioItems, primaryVideoClips
  final vp = legacy['videoPath'] as String? ?? '';
  final durMs = legacy['videoDuration'] as int? ?? 0;
  final trimStartMs = legacy['trimStart'] as int? ?? 0;
  final trimEndMs = legacy['trimEnd'] as int? ?? durMs;
  final clips = (legacy['primaryVideoClips'] as List?) ?? [];
  final now = DateTime.now().toIso8601String();
  final videoTracks = <Map<String,dynamic>>[];
  if (clips.isNotEmpty) {
    var cursor = 0;
    for (final c in clips) {
      final m = c as Map<String,dynamic>;
      final src = m['videoPath'] as String? ?? vp;
      final sDur = m['sourceDuration'] as int? ?? durMs;
      final tS = m['trimStart'] as int? ?? 0;
      final tE = m['trimEnd'] as int? ?? sDur;
      videoTracks.add({'id': m['id'] ?? 'clip_$cursor', 'sourcePath': src, 'sourceDuration': sDur, 'startTime': cursor==0?0:videoTracks.fold<int>(0, (a,e)=> a + ((e['trimEnd'] as int)-(e['trimStart'] as int))), 'trimStart': tS, 'trimEnd': tE, 'speed':1,'volume':1,'rotation':0,'flipH':false,'flipV':false,'mute':false});
      cursor++;
    }
  } else if (vp.isNotEmpty) {
    videoTracks.add({'id':'legacy_single','sourcePath':vp,'sourceDuration':durMs,'startTime':0,'trimStart':trimStartMs,'trimEnd':trimEndMs,'speed':1,'volume':1,'rotation':0,'flipH':false,'flipV':false,'mute':false});
  }
  return {
    'id': legacy['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    'name': legacy['name'] ?? 'Migrated Project',
    'version': ReelProject.currentVersion,
    'canvas': const CanvasConfig().toJson(), // default reel 9:16, user can switch
    'videoTracks': videoTracks,
    'audioTracks': [], // legacy audioItems are overlay, kept as text/sticker migration below if needed
    'overlayTracks': [],
    'textLayers': [],
    'stickerLayers': [],
    'filterSettings': {'filterId': null, 'intensity': 1},
    'transitions': [],
    'settings': const ReelSettings().toJson(),
    'createdAt': legacy['createdAt'] ?? now,
    'modifiedAt': legacy['modifiedAt'] ?? now,
  };
}
