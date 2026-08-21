import 'dart:async';
import 'package:flutter_riverpod/legacy.dart';
import '../state/reel_editor_state.dart';

class PlaybackNotifier extends StateNotifier<PlaybackState> {
  PlaybackNotifier() : super(const PlaybackState());
  Timer? _ticker;
  Duration _duration = Duration.zero;

  void setDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    _duration = d;
  }

  void setPlaying(bool playing) {
    if (playing == state.isPlaying) return;
    state = state.copyWith(isPlaying: playing);
    if (playing) {
      _startTicker();
    } else {
      _ticker?.cancel();
    }
  }

  void seekTo(Duration pos) {
    if (pos.isNegative) pos = Duration.zero;
    if (pos > _duration) pos = _duration;
    state = state.copyWith(position: pos);
  }

  void setVolume(double v) {
    if (v.isNaN || v.isInfinite) return;
    state = state.copyWith(volume: v.clamp(0, 2));
  }

  void toggleMute() => state = state.copyWith(isMuted: !state.isMuted);

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!state.isPlaying) return;
      final next = state.position + const Duration(milliseconds: 100);
      if (next >= _duration) {
        state = state.copyWith(position: _duration, isPlaying: false);
        _ticker?.cancel();
      } else {
        state = state.copyWith(position: next);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final playbackProvider = StateNotifierProvider<PlaybackNotifier, PlaybackState>((ref) => PlaybackNotifier());
