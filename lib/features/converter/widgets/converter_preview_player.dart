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
  });

  final String path;
  final String title;
  final bool hasVideo;

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

    final body = Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: _buildSurface(context, player, controller),
          ),
        ),
        _buildControls(context, colorScheme),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
        color: Colors.black,
      ),
      clipBehavior: Clip.antiAlias,
      child: body,
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

    if (controller != null) {
      return Video(controller: controller, controls: NoVideoControls);
    }

    // Audio-only: show a simple visual.
    return Center(
      child: Icon(
        _playing ? Icons.graphic_eq : Icons.music_note,
        size: 56,
        color: Colors.white,
      ),
    );
  }

  Widget _buildControls(BuildContext context, ColorScheme colorScheme) {
    final durationMs = _duration.inMilliseconds.toDouble();
    final positionMs = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds)
        .toDouble();

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: _playing ? 'Pause' : 'Play',
                icon: Icon(
                  _playing ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.white,
                ),
                onPressed: _togglePlay,
              ),
              Expanded(
                child: Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
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
            activeColor: colorScheme.primary,
            inactiveColor: Colors.white24,
            onChanged: _seekTo,
          ),
        ],
      ),
    );
  }
}