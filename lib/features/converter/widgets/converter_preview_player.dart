import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Compact inline media player used by the converter Preview tab.
///
/// Plays a single local file (audio or video) through `media_kit`. The widget
/// is re-created whenever the file path changes via [ValueKey] so player state
/// never leaks across files.
class ConverterPreviewPlayer extends StatefulWidget {
  const ConverterPreviewPlayer({
    super.key,
    required this.path,
    required this.title,
    required this.hasVideo,
    this.trimStart = Duration.zero,
    this.trimEnd = Duration.zero,
    this.onTrimChanged,
  });

  final String path;
  final String title;
  final bool hasVideo;

  /// Trim range to display/preview on the timeline.
  final Duration trimStart;
  final Duration trimEnd;

  /// Called when the user sets start/end points from the player.
  final void Function(Duration start, Duration end)? onTrimChanged;

  @override
  State<ConverterPreviewPlayer> createState() => _ConverterPreviewPlayerState();
}

class _ConverterPreviewPlayerState extends State<ConverterPreviewPlayer>
    with WidgetsBindingObserver {
  Player? _player;
  VideoController? _controller;

  final List<StreamSubscription<dynamic>> _subs = [];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;
  bool _error = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final player = Player(
        configuration: const PlayerConfiguration(title: 'Converter Preview'),
      );
      VideoController? controller;
      if (widget.hasVideo) {
        controller = VideoController(
          player,
          configuration: const VideoControllerConfiguration(
            enableHardwareAcceleration: true,
          ),
        );
      }
      _player = player;
      _controller = controller;

      _subs.add(
        player.stream.playing.listen(
          (v) => mounted ? setState(() => _playing = v) : null,
        ),
      );
      _subs.add(
        player.stream.position.listen(
          (v) => mounted ? setState(() => _position = v) : null,
        ),
      );
      _subs.add(
        player.stream.duration.listen(
          (v) => mounted ? setState(() => _duration = v) : null,
        ),
      );
      _subs.add(
        player.stream.buffering.listen(
          (v) => mounted ? setState(() => _buffering = v) : null,
        ),
      );
      _subs.add(
        player.stream.error.listen((e) {
          if (mounted) {
            setState(() {
              _error = true;
              _errorMessage = e;
            });
          }
        }),
      );

      await player.open(Media(widget.path), play: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player?.pause();
    }
  }

  void _togglePlay() {
    final player = _player;
    if (player == null) return;
    if (_playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  void _seekTo(double ms) {
    _player?.seek(Duration(milliseconds: ms.round()));
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final player = _player;
    final controller = _controller;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
        color: Colors.black,
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildSurface(context, player, controller),
    );
  }

  Widget _buildSurface(
    BuildContext context,
    Player? player,
    VideoController? controller,
  ) {
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (player == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // Video (or audio visual) fills the whole 16:9 surface.
    final surface = controller != null
        ? Video(controller: controller, controls: NoVideoControls)
        : Center(
            child: Icon(
              _playing ? Icons.graphic_eq : Icons.music_note,
              size: 56,
              color: Colors.white,
            ),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
          child: surface,
        ),
        // Title, progress and timecode overlaid on the top of the player.
        Positioned(top: 0, left: 0, right: 0, child: _buildTopOverlay(context)),
        // Play / pause button centered on the player.
        Center(child: _buildCenterPlayButton()),
      ],
    );
  }

  void _setTrimStart() {
    if (_duration == Duration.zero) return;
    var start = _position;
    var end = widget.trimEnd;
    // A start at/after the current end invalidates the end point.
    if (end > Duration.zero && start >= end) end = Duration.zero;
    widget.onTrimChanged?.call(start, end);
  }

  void _setTrimEnd() {
    if (_duration == Duration.zero) return;
    var end = _position;
    var start = widget.trimStart;
    // An end at/before the current start invalidates the start point.
    if (start > Duration.zero && end <= start) start = Duration.zero;
    widget.onTrimChanged?.call(start, end);
  }

  void _clearTrim() {
    widget.onTrimChanged?.call(Duration.zero, Duration.zero);
  }

  bool get _hasTrim =>
      widget.trimStart > Duration.zero || widget.trimEnd > Duration.zero;

  String get _trimLabel {
    if (!_hasTrim) return 'No trim';
    return 'Trim ${_fmt(widget.trimStart)}'
        '${widget.trimEnd > Duration.zero ? ' → ${_fmt(widget.trimEnd)}' : ' → end'}';
  }

  /// Thin timeline strip highlighting the trimmed segment.
  Widget _buildTrimStrip() {
    final totalMs = _duration.inMilliseconds;
    if (totalMs <= 0) return const SizedBox.shrink();

    final startMs = widget.trimStart.inMilliseconds.clamp(0, totalMs);
    final endMs = widget.trimEnd.inMilliseconds > 0
        ? widget.trimEnd.inMilliseconds.clamp(0, totalMs)
        : totalMs;
    final startFlex = ((startMs / totalMs) * 1000).round();
    final midFlex = (((endMs - startMs) / totalMs) * 1000).round();
    final endFlex = (((totalMs - endMs) / totalMs) * 1000).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Row(
          children: [
            Expanded(
              flex: startFlex.clamp(0, 1) > 0 ? startFlex : 1,
              child: Container(color: Colors.white24),
            ),
            Expanded(
              flex: midFlex.clamp(0, 1) > 0 ? midFlex : 1,
              child: Container(color: Colors.amber),
            ),
            Expanded(
              flex: endFlex.clamp(0, 1) > 0 ? endFlex : 1,
              child: Container(color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrimControls() {
    final style = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 11),
      foregroundColor: Colors.white70,
    );
    return Row(
      children: [
        const Icon(Icons.content_cut, size: 13, color: Colors.white70),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _trimLabel,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        TextButton(
          style: style,
          onPressed: _duration > Duration.zero ? _setTrimStart : null,
          child: const Text('Start'),
        ),
        TextButton(
          style: style,
          onPressed: _duration > Duration.zero ? _setTrimEnd : null,
          child: const Text('End'),
        ),
        if (_hasTrim)
          TextButton(
            style: style,
            onPressed: _clearTrim,
            child: const Text('✕'),
          ),
      ],
    );
  }

  Widget _buildTopOverlay(BuildContext context) {
    final durationMs = _duration.inMilliseconds.toDouble();
    final positionMs = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds)
        .toDouble();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_buffering)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              Text(
                '${_fmt(_position)} / ${_fmt(_duration)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Slider(
            value: durationMs > 0 ? positionMs.clamp(0, durationMs) : 0,
            max: durationMs > 0 ? durationMs : 1,
            activeColor: Theme.of(context).colorScheme.primary,
            inactiveColor: Colors.white24,
            onChanged: _seekTo,
          ),
          _buildTrimControls(),
          const SizedBox(height: 4),
          _buildTrimStrip(),
        ],
      ),
    );
  }

  Widget _buildCenterPlayButton() {
    return IconButton(
      tooltip: _playing ? 'Pause' : 'Play',
      iconSize: 64,
      icon: Icon(
        _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
        color: Colors.white.withValues(alpha: 0.9),
        shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
      ),
      onPressed: _togglePlay,
    );
  }
}