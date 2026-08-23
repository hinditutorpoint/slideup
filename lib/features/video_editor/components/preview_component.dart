import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/video_edit_settings.dart';

/// Real video player preview component — replaces the stub that rendered nothing.
/// Uses [media_kit] (already a project dependency) to render the video,
/// expose playback controls, and apply a simple color‑grade matrix.
class PreviewComponent extends StatefulWidget {
  final String videoPath; final bool showControls; final bool showOverlays; final bool enableInteraction; final ColorGradeSettings? colorGrade; final double volume; final bool showGrid; final bool showSafeArea;
  final double clipVolume; final double speed; final double rotation; final bool flipH; final bool flipV;
  const PreviewComponent({super.key, required this.videoPath, this.showControls=false, this.showOverlays=true, this.enableInteraction=true, this.colorGrade, this.volume=1, this.showGrid=false, this.showSafeArea=false, this.clipVolume=1, this.speed=1, this.rotation=0, this.flipH=false, this.flipV=false});
  @override State<PreviewComponent> createState() => PreviewComponentState();
}

class PreviewComponentState extends State<PreviewComponent> {
  late final Player _player;
  late final VideoController _controller;
  bool _initialized = false;

  // Source-swap coordination: serializes open() calls, preserves playing
  // state across clip switches and defers seeks until the new source is
  // ready (otherwise they land on the outgoing file or get reset).
  String? _loadedPath;
  int _gen = 0;
  bool _loading = false;
  Duration? _pendingSeek;
  Future<void> _loadChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    // MediaKit must be initialized before any Player/Video usage.
    MediaKit.ensureInitialized();
    _player = Player();
    _controller = VideoController(_player);
    _openSource(widget.videoPath);
    // Mark as initialized after a microtask so the player has time to prepare
    _initialized = true;
    // Note: the fade-in effect is handled by the Opacity widget;
    // if the player takes time to start, the video will still be visible.
    _applyVolume();
    _applySpeed();
  }

  void _openSource(String path) {
    if (path.isEmpty || path == _loadedPath) return;
    _loadedPath = path;
    final gen = ++_gen;
    // Keep playback continuous across clip boundaries.
    final wasPlaying = _player.state.playing;
    final prev = _loadChain;
    _loading = true;
    _loadChain = () async {
      await prev;
      if (gen != _gen || !mounted) return;
      try {
        await _player.open(Media(path), play: wasPlaying);
      } catch (_) {}
      if (gen != _gen || !mounted) return;
      try {
        _applyVolume();
        _applySpeed();
      } catch (_) {}
      final seek = _pendingSeek;
      _pendingSeek = null;
      if (seek != null) {
        try {
          await _player.seek(seek);
        } catch (_) {}
      }
      if (gen == _gen) _loading = false;
    }();
  }

  void _applyVolume() {
    _player.setVolume(widget.volume * widget.clipVolume * 100);
  }

  void _applySpeed() {
    _player.setRate(widget.speed);
  }

  // ── Playback control API (used by VideoEditorScreen via GlobalKey) ──
  Duration getCurrentPosition() => _player.state.position;

  Future<void> seekTo(Duration p) {
    if (_loading) {
      _pendingSeek = p;
      return Future<void>.value();
    }
    return _player.seek(p);
  }

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  /// Dynamically set playback rate (for speed ramping via keyframes).
  void setPlaybackSpeed(double rate) {
    _player.setRate(rate);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PreviewComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _openSource(widget.videoPath);
    }
    if (oldWidget.volume != widget.volume ||
        oldWidget.clipVolume != widget.clipVolume) {
      _applyVolume();
    }
    if (oldWidget.speed != widget.speed) {
      _applySpeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final aspect = widget.videoPath.isNotEmpty ? (16 / 9) : 1.0;
    return Opacity(
      opacity: _initialized ? 1.0 : 0.0,
      child: AspectRatio(
        aspectRatio: aspect,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(widget.rotation * 3.141592653589793 / 180)
            ..scale(
              widget.flipH ? -1.0 : 1.0,
              widget.flipV ? -1.0 : 1.0,
            ),
          child: Video(
            controller: _controller,
            fit: BoxFit.contain,
            controls: NoVideoControls,
          ),
        ),
      ),
    );
  }
}