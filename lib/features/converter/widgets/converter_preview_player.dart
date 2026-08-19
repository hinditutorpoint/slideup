import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../video_player/video_player_init.dart';

/// Shared playback state so controls can live outside the player surface.
class PreviewPlayerController {
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> playing = ValueNotifier(false);

  /// Bound by [ConverterPreviewPlayer] once its internal player is ready.
  void Function()? onTogglePlay;
  void Function(Duration position)? onSeek;
  void Function()? onPause;

  void reset() {
    position.value = Duration.zero;
    duration.value = Duration.zero;
    playing.value = false;
  }

  void dispose() {
    position.dispose();
    duration.dispose();
    playing.dispose();
  }
}

/// Premium media player with glassmorphic design and enhanced UX.
class ConverterPreviewPlayer extends StatefulWidget {
  const ConverterPreviewPlayer({
    super.key,
    required this.path,
    required this.hasVideo,
    this.controller,
  });

  final String path;
  final bool hasVideo;
  final PreviewPlayerController? controller;

  @override
  State<ConverterPreviewPlayer> createState() => _ConverterPreviewPlayerState();
}

class _ConverterPreviewPlayerState extends State<ConverterPreviewPlayer>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Player? _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subs = [];

  bool _playing = false;
  bool _buffering = false;
  bool _error = false;
  String _errorMessage = '';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await VideoPlayerInit.initialize();
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

      if (!mounted) {
        await player.dispose();
        return;
      }

      _player = player;
      _controller = controller;

      final c = widget.controller;
      if (c != null) {
        c.onTogglePlay = _togglePlay;
        c.onSeek = (d) => _seekTo(d.inMilliseconds.toDouble());
        c.onPause = () => player.pause();
      }

      _subs.add(
        player.stream.playing.listen((v) {
          widget.controller?.playing.value = v;
          if (mounted) {
            setState(() => _playing = v);
          }
        }),
      );
      _subs.add(
        player.stream.position.listen((v) {
          widget.controller?.position.value = v;
        }),
      );
      _subs.add(
        player.stream.duration.listen((v) {
          widget.controller?.duration.value = v;
        }),
      );
      _subs.add(
        player.stream.buffering.listen((v) {
          if (mounted) setState(() => _buffering = v);
        }),
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

      await player.open(Media(widget.path), play: false);

      if (mounted) {
        setState(() {});
      }
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

  @override
  void dispose() {
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);

    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();

    _controller = null;
    _player?.dispose();
    _player = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.55),
              colorScheme.secondary.withValues(alpha: 0.35),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: Offset.zero,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: Colors.black,
            child: _buildSurface(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSurface(BuildContext context) {
    if (_error) {
      return _buildErrorState(context);
    }

    if (_player == null) {
      return _buildLoadingState();
    }

    final surface = _controller != null
        ? Video(controller: _controller!, controls: NoVideoControls)
        : _buildAudioVisualizer();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          surface,
          // Buffering indicator
          if (_buffering) _buildBufferingIndicator(),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Playback Error',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading media...',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioVisualizer() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: _playing ? 1.2 : 0.8),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _playing
                      ? Icons.graphic_eq_rounded
                      : Icons.music_note_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
      : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Playback controls (play/pause, seek bar, time) rendered BELOW the video,
/// detached from the player surface so nothing overlays the preview.
class PreviewPlayerControls extends StatelessWidget {
  const PreviewPlayerControls({super.key, required this.controller});

  final PreviewPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.playing,
        controller.position,
        controller.duration,
      ]),
      builder: (context, _) {
        final durationMs = controller.duration.value.inMilliseconds.toDouble();
        final positionMs = controller.position.value.inMilliseconds
            .clamp(0, controller.duration.value.inMilliseconds)
            .toDouble();
        return Row(
          children: [
            IconButton(
              onPressed: controller.onTogglePlay,
              tooltip: controller.playing.value ? 'Pause' : 'Play',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Icon(
                  controller.playing.value
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey(controller.playing.value),
                  color: colorScheme.onSurface,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _formatDuration(controller.position.value),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                    elevation: 2,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  activeTrackColor: colorScheme.primary,
                  inactiveTrackColor: colorScheme.surfaceContainerHighest,
                  thumbColor: colorScheme.primary,
                  overlayColor: colorScheme.primary.withValues(alpha: 0.25),
                ),
                child: SizedBox(
                  height: 30,
                  child: Slider(
                    value: durationMs > 0 ? positionMs.clamp(0, durationMs) : 0,
                    max: durationMs > 0 ? durationMs : 1,
                    onChanged: (ms) => controller.onSeek?.call(
                      Duration(milliseconds: ms.round()),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              _formatDuration(controller.duration.value),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
          ],
        );
      },
    );
  }
}

/// Compact trim range editor. Shows a track with two draggable flag markers
/// (start/end) directly on it; no time code or progress bar.
class ConverterTrimPanel extends StatefulWidget {
  const ConverterTrimPanel({
    super.key,
    required this.controller,
    required this.trimStart,
    required this.trimEnd,
    required this.onTrimChanged,
  });

  final PreviewPlayerController controller;
  final Duration trimStart;
  final Duration trimEnd;
  final void Function(Duration start, Duration end) onTrimChanged;

  @override
  State<ConverterTrimPanel> createState() => _ConverterTrimPanelState();
}

class _ConverterTrimPanelState extends State<ConverterTrimPanel> {
  static const double _markerSize = 24;
  static const double _trackHeight = 8;
  static const double _stackHeight = 36;
  static const double _minGapMs = 100;

  int? _dragTarget;

  bool get _hasTrim =>
      widget.trimStart > Duration.zero || widget.trimEnd > Duration.zero;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasTrim = _hasTrim;

    return ValueListenableBuilder<Duration>(
      valueListenable: widget.controller.duration,
      builder: (context, duration, _) {
        final enabled = duration > Duration.zero;
        return Row(
          children: [
            Expanded(
              child: enabled
                  ? LayoutBuilder(
                      builder: (context, constraints) => _buildTrimSlider(
                        context,
                        constraints.maxWidth,
                        duration,
                        colorScheme,
                      ),
                    )
                  : _buildDisabledStrip(colorScheme),
            ),
            if (hasTrim) ...[
              const SizedBox(width: 6),
              _buildClearButton(context),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDisabledStrip(ColorScheme colorScheme) {
    return Container(
      height: _stackHeight,
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: _trackHeight - 2,
          color: colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  Widget _buildTrimSlider(
    BuildContext context,
    double width,
    Duration duration,
    ColorScheme colorScheme,
  ) {
    final durationMs = duration.inMilliseconds.toDouble();
    final startMs = widget.trimStart.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();
    final endMs = widget.trimEnd.inMilliseconds > 0
        ? widget.trimEnd.inMilliseconds
              .clamp(0, duration.inMilliseconds)
              .toDouble()
        : durationMs;

    final usable = (width - _markerSize).clamp(0.0, double.infinity);
    if (usable <= 0) return const SizedBox(height: _stackHeight);

    final startX = _markerSize / 2 + (startMs / durationMs) * usable;
    final endX = _markerSize / 2 + (endMs / durationMs) * usable;
    final trackTop = _stackHeight / 2 - _trackHeight / 2;
    final maxLeft = (width - _markerSize).clamp(0.0, double.infinity);

    double msFromX(double dx) {
      return ((dx - _markerSize / 2) / usable * durationMs)
          .clamp(0.0, durationMs);
    }

    void setMarker(double dx, int target) {
      final ms = msFromX(dx);
      if (target == 0) {
        final maxEnd = endMs - _minGapMs;
        final clamped = ms.clamp(0.0, maxEnd);
        widget.onTrimChanged(
          Duration(milliseconds: clamped.round()),
          widget.trimEnd,
        );
      } else {
        final minStart = startMs + _minGapMs;
        final clamped = ms.clamp(minStart, durationMs);
        widget.onTrimChanged(
          widget.trimStart,
          Duration(milliseconds: clamped.round()),
        );
      }
    }

    int nearestMarker(double dx) {
      return (dx - startX).abs() <= (dx - endX).abs() ? 0 : 1;
    }

    return SizedBox(
      height: _stackHeight,
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (d) {
          setMarker(d.localPosition.dx, nearestMarker(d.localPosition.dx));
          HapticFeedback.selectionClick();
        },
        onHorizontalDragStart: (d) {
          _dragTarget = nearestMarker(d.localPosition.dx);
          HapticFeedback.selectionClick();
        },
        onHorizontalDragUpdate: (d) {
          final target = _dragTarget;
          if (target == null) return;
          setMarker(d.localPosition.dx, target);
        },
        onHorizontalDragEnd: (_) => _dragTarget = null,
        onHorizontalDragCancel: () => _dragTarget = null,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: trackTop,
              height: _trackHeight,
              child: _buildTrack(
                context,
                width,
                startX,
                endX,
                colorScheme,
              ),
            ),
            Positioned(
              left: (startX - _markerSize / 2).clamp(0.0, maxLeft),
              top: 0,
              child: _buildMarker(context, colorScheme.primary),
            ),
            Positioned(
              left: (endX - _markerSize / 2).clamp(0.0, maxLeft),
              top: 0,
              child: _buildMarker(context, colorScheme.secondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrack(
    BuildContext context,
    double width,
    double startX,
    double endX,
    ColorScheme colorScheme,
  ) {
    return Stack(
      children: [
        Container(
          width: width,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Positioned(
          left: startX,
          width: (endX - startX).clamp(0.0, width),
          top: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarker(BuildContext context, Color color) {
    return SizedBox(
      width: _markerSize,
      height: _stackHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: _markerSize,
            height: 18,
            child: CustomPaint(
              painter: _PentagonPainter(color: color),
            ),
          ),
          Container(
            width: 3,
            height: 8,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Clear trim',
      onPressed: () {
        HapticFeedback.selectionClick();
        widget.onTrimChanged(Duration.zero, Duration.zero);
      },
      icon: Icon(Icons.close_rounded, size: 18, color: colorScheme.error),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Upward-pointing pentagon (house shape) trim marker.
class _PentagonPainter extends CustomPainter {
  const _PentagonPainter({required this.color});

  final Color color;

  static const List<Offset> _pts = [
    Offset(0.50, 0.06),
    Offset(0.94, 0.40),
    Offset(0.78, 0.94),
    Offset(0.22, 0.94),
    Offset(0.06, 0.40),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < _pts.length; i++) {
      final p = Offset(_pts[i].dx * size.width, _pts[i].dy * size.height);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawShadow(
      path,
      Colors.black54,
      3,
      false,
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PentagonPainter old) => old.color != color;
}
