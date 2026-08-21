import 'package:flutter_riverpod/legacy.dart';
import '../models/reel_project.dart';
import '../core/validation/numeric_guard.dart';

/// Timeline engine md:224-256 — multi-track, snap, zoom 0.5-5, efficient updates
class ReelTimelineState {
  final Duration currentPosition;
  final double zoomLevel; // 0.5-5
  final String? selectedId;
  final Set<String> lockedIds;
  final Set<String> hiddenIds;
  const ReelTimelineState({this.currentPosition = Duration.zero, this.zoomLevel = 1.0, this.selectedId, this.lockedIds = const {}, this.hiddenIds = const {}});
  ReelTimelineState copyWith({Duration? currentPosition, double? zoomLevel, String? selectedId, bool clearSel = false, Set<String>? lockedIds, Set<String>? hiddenIds}) =>
      ReelTimelineState(currentPosition: currentPosition ?? this.currentPosition, zoomLevel: zoomLevel ?? this.zoomLevel, selectedId: clearSel ? null : selectedId ?? this.selectedId, lockedIds: lockedIds ?? this.lockedIds, hiddenIds: hiddenIds ?? this.hiddenIds);
}

class ReelTimelineNotifier extends StateNotifier<ReelTimelineState> {
  ReelTimelineNotifier() : super(const ReelTimelineState());
  ReelProject? _project;
  void Function(ReelProject)? onProjectChanged;

  void loadProject(ReelProject p) {
    _project = p;
    state = ReelTimelineState(currentPosition: Duration.zero, zoomLevel: state.zoomLevel);
  }

  ReelProject? get project => _project;

  void setPosition(Duration pos) {
    if (!NumericGuard.isValidDuration(pos)) return;
    final max = _project?.computedDuration ?? const Duration(minutes: 10);
    if (pos > max) pos = max;
    state = state.copyWith(currentPosition: pos);
  }

  void setZoom(double z) {
    if (z.isNaN || z.isInfinite) return;
    state = state.copyWith(zoomLevel: z.clamp(0.5, 5.0));
  }

  void select(String? id) => state = state.copyWith(selectedId: id, clearSel: id == null);

  // ── Clip operations md:238-245
  void addVideoClip(ReelVideoTrack clip) {
    if (_project == null) return;
    _project = _project!.copyWith(videoTracks: [..._project!.videoTracks, clip]);
    onProjectChanged?.call(_project!);
  }

  void deleteClip(String id) {
    if (_project == null) return;
    _project = _project!.copyWith(videoTracks: _project!.videoTracks.where((e) => e.id != id).toList());
    if (state.selectedId == id) state = state.copyWith(clearSel: true);
    onProjectChanged?.call(_project!);
  }

  void duplicateClip(String id) {
    if (_project == null) return;
    final src = _project!.videoTracks.where((e) => e.id == id).firstOrNull;
    if (src == null) return;
    final dup = ReelVideoTrack(id: '${src.id}_dup_${DateTime.now().millisecondsSinceEpoch}', sourcePath: src.sourcePath, sourceDuration: src.sourceDuration, startTime: src.startTime + src.trimmedDuration, trimStart: src.trimStart, trimEnd: src.trimEnd, speed: src.speed, volume: src.volume);
    _project = _project!.copyWith(videoTracks: [..._project!.videoTracks, dup]);
    onProjectChanged?.call(_project!);
  }

  void splitAtPlayhead() {
    if (_project == null) return;
    final pos = state.currentPosition;
    final idx = _project!.videoTracks.indexWhere((c) => pos >= c.startTime && pos < c.startTime + c.trimmedDuration);
    if (idx == -1) return;
    final clip = _project!.videoTracks[idx];
    final offsetInClip = pos - clip.startTime;
    final speed = clip.speed;
    final sourceOffset = Duration(milliseconds: (offsetInClip.inMilliseconds * speed).round());
    final splitPoint = clip.trimStart + sourceOffset;
    if (splitPoint <= clip.trimStart || splitPoint >= clip.trimEnd) return;
    final left = ReelVideoTrack(id: clip.id, sourcePath: clip.sourcePath, sourceDuration: clip.sourceDuration, startTime: clip.startTime, trimStart: clip.trimStart, trimEnd: splitPoint, speed: clip.speed, volume: clip.volume);
    final right = ReelVideoTrack(id: '${clip.id}_s${DateTime.now().millisecondsSinceEpoch}', sourcePath: clip.sourcePath, sourceDuration: clip.sourceDuration, startTime: pos, trimStart: splitPoint, trimEnd: clip.trimEnd, speed: clip.speed, volume: clip.volume);
    final list = [..._project!.videoTracks];
    list[idx] = left;
    list.insert(idx + 1, right);
    // reflow startTimes
    Duration cursor = Duration.zero;
    for (int i = 0; i < list.length; i++) {
      list[i] = ReelVideoTrack(id: list[i].id, sourcePath: list[i].sourcePath, sourceDuration: list[i].sourceDuration, startTime: cursor, trimStart: list[i].trimStart, trimEnd: list[i].trimEnd, speed: list[i].speed, volume: list[i].volume);
      cursor += list[i].trimmedDuration;
    }
    _project = _project!.copyWith(videoTracks: list);
    onProjectChanged?.call(_project!);
  }

  void reorderClips(int oldIdx, int newIdx) {
    if (_project == null) return;
    final list = [..._project!.videoTracks];
    if (oldIdx < 0 || oldIdx >= list.length || newIdx < 0 || newIdx > list.length) return;
    if (newIdx > oldIdx) newIdx--;
    final item = list.removeAt(oldIdx);
    list.insert(newIdx, item);
    // reflow
    Duration cursor = Duration.zero;
    for (int i = 0; i < list.length; i++) {
      list[i] = ReelVideoTrack(id: list[i].id, sourcePath: list[i].sourcePath, sourceDuration: list[i].sourceDuration, startTime: cursor, trimStart: list[i].trimStart, trimEnd: list[i].trimEnd, speed: list[i].speed, volume: list[i].volume);
      cursor += list[i].trimmedDuration;
    }
    _project = _project!.copyWith(videoTracks: list);
    onProjectChanged?.call(_project!);
  }

  void updateTrim(String id, Duration trimStart, Duration trimEnd){
    if(_project==null) return;
    if(!NumericGuard.isValidDuration(trimStart)||!NumericGuard.isValidDuration(trimEnd)) return;
    if(trimEnd<=trimStart) return;
    final list=[..._project!.videoTracks];
    final idx=list.indexWhere((e)=>e.id==id); if(idx==-1) return;
    final old=list[idx];
    if(trimStart<Duration.zero || trimEnd>old.sourceDuration) return;
    list[idx]=ReelVideoTrack(id:old.id, sourcePath:old.sourcePath, sourceDuration:old.sourceDuration, startTime:old.startTime, trimStart:trimStart, trimEnd:trimEnd, speed:old.speed, volume:old.volume);
    Duration cursor=Duration.zero;
    for(int i=0;i<list.length;i++){ final c=list[i]; list[i]=ReelVideoTrack(id:c.id, sourcePath:c.sourcePath, sourceDuration:c.sourceDuration, startTime:cursor, trimStart:c.trimStart, trimEnd:c.trimEnd, speed:c.speed, volume:c.volume); cursor+=list[i].trimmedDuration; }
    _project=_project!.copyWith(videoTracks:list); onProjectChanged?.call(_project!);
  }
  void updateSpeed(String id, double speed){
    if(_project==null) return; if(speed.isNaN||speed.isInfinite) return; speed=speed.clamp(0.25, 4.0);
    final list=[..._project!.videoTracks]; final idx=list.indexWhere((e)=>e.id==id); if(idx==-1) return;
    final old=list[idx]; list[idx]=ReelVideoTrack(id:old.id, sourcePath:old.sourcePath, sourceDuration:old.sourceDuration, startTime:old.startTime, trimStart:old.trimStart, trimEnd:old.trimEnd, speed:speed, volume:old.volume);
    Duration cursor=Duration.zero; for(int i=0;i<list.length;i++){ final c=list[i]; list[i]=ReelVideoTrack(id:c.id, sourcePath:c.sourcePath, sourceDuration:c.sourceDuration, startTime:cursor, trimStart:c.trimStart, trimEnd:c.trimEnd, speed:c.speed, volume:c.volume); cursor+=list[i].trimmedDuration; }
    _project=_project!.copyWith(videoTracks:list); onProjectChanged?.call(_project!);
  }
  void updateVolume(String id, double vol){
    if(_project==null) return; if(vol.isNaN||vol.isInfinite) return; vol=vol.clamp(0.0, 2.0);
    final list=[..._project!.videoTracks]; final idx=list.indexWhere((e)=>e.id==id); if(idx==-1) return;
    final old=list[idx]; list[idx]=ReelVideoTrack(id:old.id, sourcePath:old.sourcePath, sourceDuration:old.sourceDuration, startTime:old.startTime, trimStart:old.trimStart, trimEnd:old.trimEnd, speed:old.speed, volume:vol, rotation: old.rotation, flipH: old.flipH, flipV: old.flipV, mute: old.mute, filterId: old.filterId, transitionId: old.transitionId);
    _project=_project!.copyWith(videoTracks:list); onProjectChanged?.call(_project!);
  }

  void updateRotation(String id, double rotation){
    if(_project==null) return; if(rotation.isNaN||rotation.isInfinite) return;
    final list=[..._project!.videoTracks]; final idx=list.indexWhere((e)=>e.id==id); if(idx==-1) return;
    final old=list[idx]; list[idx]=ReelVideoTrack(id:old.id, sourcePath:old.sourcePath, sourceDuration:old.sourceDuration, startTime:old.startTime, trimStart:old.trimStart, trimEnd:old.trimEnd, speed:old.speed, volume:old.volume, rotation: rotation % 360, flipH: old.flipH, flipV: old.flipV, mute: old.mute, filterId: old.filterId, transitionId: old.transitionId);
    _project=_project!.copyWith(videoTracks:list); onProjectChanged?.call(_project!);
  }

  void updateFlip(String id, {bool? flipH, bool? flipV}){
    if(_project==null) return;
    final list=[..._project!.videoTracks]; final idx=list.indexWhere((e)=>e.id==id); if(idx==-1) return;
    final old=list[idx]; list[idx]=ReelVideoTrack(id:old.id, sourcePath:old.sourcePath, sourceDuration:old.sourceDuration, startTime:old.startTime, trimStart:old.trimStart, trimEnd:old.trimEnd, speed:old.speed, volume:old.volume, rotation: old.rotation, flipH: flipH ?? old.flipH, flipV: flipV ?? old.flipV, mute: old.mute, filterId: old.filterId, transitionId: old.transitionId);
    _project=_project!.copyWith(videoTracks:list); onProjectChanged?.call(_project!);
  }

  void updateMute(String id, bool mute){
    if(_project==null) return;
    final list=[..._project!.videoTracks]; final idx=list.indexWhere((e)=>e.id==id); if(idx==-1) return;
    final old=list[idx]; list[idx]=ReelVideoTrack(id:old.id, sourcePath:old.sourcePath, sourceDuration:old.sourceDuration, startTime:old.startTime, trimStart:old.trimStart, trimEnd:old.trimEnd, speed:old.speed, volume:old.volume, rotation: old.rotation, flipH: old.flipH, flipV: old.flipV, mute: mute, filterId: old.filterId, transitionId: old.transitionId);
    _project=_project!.copyWith(videoTracks:list); onProjectChanged?.call(_project!);
  }

  Duration snap(Duration pos, {Duration threshold = const Duration(milliseconds: 150)}) {
    if (_project == null) return pos;
    // snap to clip boundaries and playhead
    final candidates = <Duration>[Duration.zero, _project!.computedDuration];
    for (final c in _project!.videoTracks) {
      candidates.add(c.startTime);
      candidates.add(c.startTime + c.trimmedDuration);
    }
    for (final cand in candidates) {
      if ((pos - cand).inMilliseconds.abs() <= threshold.inMilliseconds) return cand;
    }
    return pos;
  }
}

final reelTimelineProvider = StateNotifierProvider<ReelTimelineNotifier, ReelTimelineState>((ref) => ReelTimelineNotifier());
