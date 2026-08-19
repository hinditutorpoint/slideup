import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../video_player/video_player_init.dart';
import '../models/iptv_models.dart';

/// Professional inline IPTV player.
///
/// Renders the live stream full-bleed with YouTube/Netflix-style overlay
/// controls that auto-hide, a gradient top bar (logo + name + LIVE badge),
/// and a gradient bottom bar (play/pause, elapsed, channel up/down, list and
/// fullscreen toggles). Tapping the video toggles the controls; swiping
/// vertically switches channels. The stream re-opens when the channel changes.
class IptvPlayer extends StatefulWidget {
  const IptvPlayer({
    super.key,
    required this.channel,
    required this.onBack,
    required this.onToggleList,
    required this.onToggleFullscreen,
    this.onChannelUp,
    this.onChannelDown,
    this.qualities,
    this.currentQualityIndex = 0,
    this.onQualitySelected,
  });

  final IptvChannel channel;
  final VoidCallback onBack;
  final VoidCallback onToggleList;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onChannelUp;
  final VoidCallback? onChannelDown;

  /// Available quality labels for the current channel (e.g. ["576P", "720P"]).
  /// When null or length <= 1 the quality picker is hidden.
  final List<String>? qualities;
  final int currentQualityIndex;
  final ValueChanged<int>? onQualitySelected;

  @override
  State<IptvPlayer> createState() => _IptvPlayerState();
}

class _IptvPlayerState extends State<IptvPlayer> with WidgetsBindingObserver {
  Player? _player;
  VideoController? _controller;

  final List<StreamSubscription<dynamic>> _subs = [];

  Duration _position = Duration.zero;
  bool _playing = false;
  bool _buffering = false;
  bool _error = false;
  String _errorMessage = '';

  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleHide();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant IptvPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.url != widget.channel.url) {
      _openChannel();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_controlsVisible) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  Future<void> _initPlayer() async {
    try {
      await VideoPlayerInit.initialize();
      final player = Player(
        configuration: const PlayerConfiguration(
          title: 'IPTV',
          logLevel: MPVLogLevel.warn,
        ),
      );
      VideoController? controller;
      if (!widget.channel.audioOnly) {
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

      await _openChannel();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _openChannel() async {
    final player = _player;
    if (player == null) return;
    setState(() {
      _error = false;
      _errorMessage = '';
      _buffering = true;
    });
    try {
      await player.open(Media(widget.channel.url), play: true);
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
    _scheduleHide();
  }

  String _elapsed() {
    final h = _position.inHours;
    final m = _position.inMinutes % 60;
    final s = _position.inSeconds % 60;
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
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

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onVerticalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -300) {
                widget.onChannelUp?.call();
              } else if (v > 300) {
                widget.onChannelDown?.call();
              }
            },
            child: _buildSurface(context, player, controller),
          ),
        ),
        if (_buffering && !_error)
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: _buildTopBar(context, colorScheme),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: _buildBottomBar(context, colorScheme),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: _buildCenterControls(context, colorScheme),
            ),
          ),
        ),
      ],
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 44,
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
      return Center(
        child: Video(controller: controller, controls: NoVideoControls),
      );
    }

    // Audio-only fallback visual.
    return const Center(
      child: Icon(Icons.radio, size: 64, color: Colors.white),
    );
  }

  Widget _buildTopBar(BuildContext context, ColorScheme colorScheme) {
    final channel = widget.channel;
    final logo = channel.logo;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onBack,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 44,
                  height: 30,
                  child: (logo != null && logo.isNotEmpty)
                      ? Image.network(
                          logo,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _logoFallback(context, colorScheme),
                        )
                      : _logoFallback(context, colorScheme),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (channel.group.isNotEmpty)
                      Text(
                        channel.group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoFallback(BuildContext context, ColorScheme colorScheme) {
    return Container(
      color: colorScheme.secondaryContainer,
      child: Icon(
        widget.channel.audioOnly ? Icons.radio : Icons.live_tv,
        size: 18,
        color: colorScheme.onSecondaryContainer,
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ColorScheme colorScheme) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(left: 8, right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _elapsed(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (_buffering)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            const Spacer(),
            if (widget.qualities != null && widget.qualities!.length > 1)
              _overlayQualityButton(context),
            _overlayIconButton(
              tooltip: 'Channels',
              icon: Icons.view_list_rounded,
              onPressed: widget.onToggleList,
            ),
            _overlayIconButton(
              tooltip: 'Fullscreen',
              icon: Icons.fullscreen,
              onPressed: widget.onToggleFullscreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _centerIconButton(
            tooltip: 'Previous channel',
            icon: Icons.skip_previous,
            onPressed: widget.onChannelUp,
          ),
          const SizedBox(width: 16),
          Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: _playing ? 'Pause' : 'Play',
              iconSize: 44,
              padding: const EdgeInsets.all(8),
              icon: Icon(
                _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white,
              ),
              onPressed: _togglePlay,
            ),
          ),
          const SizedBox(width: 16),
          _centerIconButton(
            tooltip: 'Next channel',
            icon: Icons.skip_next,
            onPressed: widget.onChannelDown,
          ),
        ],
      ),
    );
  }

  Widget _centerIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        iconSize: 34,
        padding: const EdgeInsets.all(10),
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Widget _overlayIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
    );
  }

  Widget _overlayQualityButton(BuildContext context) {
    final qualities = widget.qualities!;
    final index = widget.currentQualityIndex.clamp(0, qualities.length - 1);
    return PopupMenuButton<int>(
      tooltip: 'Quality',
      offset: const Offset(0, -56),
      color: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: widget.onQualitySelected,
      itemBuilder: (context) => [
        for (var i = 0; i < qualities.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  i == index ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: i == index ? Colors.white : Colors.white54,
                ),
                const SizedBox(width: 8),
                Text(
                  qualities[i],
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: i == index
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.high_quality_outlined,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              qualities[index],
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
