import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Real-time preview audio mixer for the video editor timeline.
/// Plays background-music items (AudioTimelineItem) layered on top of the
/// video's own audio (played by the media_kit preview player). Each source is
/// kept in sync with the global playhead.
class PreviewAudioMixer {
  final Map<String, AudioPlayer> _players = {};
  final Map<String, String> _playerPaths = {};
  final Set<String> _playing = {};
  bool _syncing = false;

  /// Re-entrancy guard: [sync] runs every 50 ms from the position timer while
  /// previous invocations may still be awaiting player creation/loading.
  /// Overlapping runs would create duplicate untracked players per source
  /// (echo / silent tracks), so late ticks are simply skipped — the next
  /// timer fire applies their state.
  Future<void> sync({
    required List<PreviewMixSource> sources,
    required Duration playhead,
    required bool isPlaying,
    required double masterVolume,
    required bool muted,
  }) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _syncInternal(
        sources: sources,
        playhead: playhead,
        isPlaying: isPlaying,
        masterVolume: masterVolume,
        muted: muted,
      );
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncInternal({
    required List<PreviewMixSource> sources,
    required Duration playhead,
    required bool isPlaying,
    required double masterVolume,
    required bool muted,
  }) async {
    final ids = <String>{};

    for (final s in sources) {
      ids.add(s.id);
      final local = playhead - s.start;
      final active =
          isPlaying && local >= Duration.zero && local <= s.duration;

      if (active) {
        final player = await _ensure(s.id, s.path);
        if (player == null) continue;

        if (!_playing.contains(s.id)) {
          try {
            await player.seek(local);
            await player.play();
            _playing.add(s.id);
          } catch (e) {
            debugPrint('❌ Mixer play error: $e');
          }
        } else {
          // Re-sync if the playhead drifted (e.g. user scrubbed).
          try {
            final pos = player.position;
            if ((pos - local).abs() > const Duration(milliseconds: 400)) {
              await player.seek(local);
            }
          } catch (_) {}
        }
        final trackMuted = s.isTrackMuted;
        try {
          await player.setVolume(
              (muted || trackMuted ? 0 : masterVolume) * s.volume);
        } catch (_) {}
      } else if (_playing.contains(s.id)) {
        final player = _players[s.id];
        if (player != null) {
          try {
            await player.pause();
          } catch (_) {}
        }
        _playing.remove(s.id);
      }
    }

    // Dispose players whose source was removed or is not playing
    for (final id in _players.keys.toSet().difference(ids)) {
      try {
        await _players[id]?.dispose();
      } catch (_) {}
      _players.remove(id);
      _playerPaths.remove(id);
      _playing.remove(id);
    }
  }

  Future<AudioPlayer?> _ensure(String id, String path) async {
    var p = _players[id];
    if (p != null && _playerPaths[id] != path) {
      try {
        await p.setAudioSource(AudioSource.file(path));
        _playerPaths[id] = path;
      } catch (e) {
        debugPrint('❌ Mixer update error ($path): $e');
      }
    }
    if (p == null) {
      final created = AudioPlayer();
      // Register before awaiting so a concurrent sync can never create a
      // duplicate untracked player for the same source id.
      _players[id] = created;
      try {
        await created.setAudioSource(AudioSource.file(path));
        _playerPaths[id] = path;
      } catch (e) {
        debugPrint('⚠️ AudioTrack init skipped/failed for $path ($e)');
        if (identical(_players[id], created)) {
          _players.remove(id);
          _playerPaths.remove(id);
          _playing.remove(id);
        }
        try {
          await created.dispose();
        } catch (_) {}
        return null;
      }
      p = created;
    }
    return p;
  }

  Future<void> stopAll() async {
    for (final p in _players.values) {
      try {
        await p.pause();
      } catch (_) {}
    }
    _playing.clear();
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
    _playing.clear();
  }
}

class PreviewMixSource {
  final String id;
  final String path;
  final Duration start;
  final Duration duration;
  final double volume;
  final bool isTrackMuted;

  const PreviewMixSource({
    required this.id,
    required this.path,
    required this.start,
    required this.duration,
    required this.volume,
    this.isTrackMuted = false,
  });
}
