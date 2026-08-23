import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/video_edit_settings.dart';
import '../providers/timeline_provider.dart';
import '../providers/video_editor_provider.dart';

/// A single picture-in-picture video layer that owns its own player and
/// stays synced to the master playhead / play state / volume.
class VideoLayerContent extends ConsumerStatefulWidget {
  final VideoOverlayTimelineItem item;
  const VideoLayerContent({super.key, required this.item});

  @override
  ConsumerState<VideoLayerContent> createState() => _VideoLayerContentState();
}

class _VideoLayerContentState extends ConsumerState<VideoLayerContent> {
  late final Player _player;
  late final VideoController _controller;
  bool _opened = false;

  /// Re-entrancy guard: [_sync] is triggered from a post-frame callback on
  /// every rebuild while earlier runs may still be awaiting seek/pause/play.
  /// Overlapping runs fight each other (pause vs play, duplicated seeks).
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    _player = Player();
    _controller = VideoController(_player);
    _open();
  }

  Future<void> _open() async {
    try {
      await _player.open(Media(_normalize(widget.item.videoPath)), play: false);
      if (mounted) setState(() => _opened = true);
    } catch (_) {}
  }

  String _normalize(String p) =>
      p.startsWith('file://') ? p.substring(7) : p;

  @override
  void dispose() {
    try {
      _player.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tl = ref.watch(timelineProvider);
    final editor = ref.watch(videoEditorProvider);
    final item = widget.item;

    final inRange =
        tl.currentPosition >= item.startTime && tl.currentPosition < item.endTime;
    final shouldPlay = tl.isPlaying && inRange && !tl.hiddenItems.contains(item.id);

    final rawLocal = tl.currentPosition - item.startTime;
    final localPos = rawLocal < Duration.zero ? Duration.zero : rawLocal;

    final masterVol = editor.isMuted ? 0.0 : editor.volume.clamp(0.0, 1.0);
    final targetVolume = masterVol * item.volume.clamp(0.0, 1.0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sync(shouldPlay, localPos, targetVolume);
      }
    });


    return !_opened
        ? Container(
            color: Colors.black,
            child: item.thumbnail != null
                ? Image.memory(item.thumbnail!, fit: BoxFit.contain)
                : null,
          )
        : Video(
            controller: _controller,
            fit: BoxFit.contain,
            controls: NoVideoControls,
          );
  }

  Future<void> _sync(bool shouldPlay, Duration localPos, double volume) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _player.setVolume((volume * 100).clamp(0.0, 100.0));

      if (!shouldPlay) {
        if (_player.state.playing) await _player.pause();
        return;
      }

      final cur = _player.state.position;
      final drift = (cur - localPos).inMilliseconds.abs();
      if (drift > 500) {
        await _player.seek(localPos);
      }
      if (!_player.state.playing) await _player.play();
    } catch (_) {
    } finally {
      _syncing = false;
    }
  }
}
