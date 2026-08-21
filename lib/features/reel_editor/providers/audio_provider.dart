import 'package:flutter_riverpod/legacy.dart';
import '../core/validation/numeric_guard.dart';
import '../models/reel_project.dart';

class AudioNotifier extends StateNotifier<ReelProject?> {
  AudioNotifier() : super(null);
  void Function(ReelProject)? onChanged;
  void load(ReelProject p) => state = p;
  void addAudio(ReelAudioTrack t) {
    if (state == null) return;
    state = state!.copyWith(audioTracks: [...state!.audioTracks, t]);
    onChanged?.call(state!);
  }
  void updateVolume(String id, double v) {
    if (state == null) return;
    v = NumericGuard.sanitizeVolume(v);
    final list = [...state!.audioTracks];
    final i = list.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final old = list[i];
    list[i] = ReelAudioTrack(id: old.id, sourcePath: old.sourcePath, startTime: old.startTime, trimStart: old.trimStart, trimEnd: old.trimEnd, volume: v, mute: old.mute, fadeIn: old.fadeIn, fadeOut: old.fadeOut);
    state = state!.copyWith(audioTracks: list);
    onChanged?.call(state!);
  }
  void remove(String id) {
    if (state == null) return;
    state = state!.copyWith(audioTracks: state!.audioTracks.where((e) => e.id != id).toList());
    onChanged?.call(state!);
  }
}
final audioProvider = StateNotifierProvider<AudioNotifier, ReelProject?>((_) => AudioNotifier());
