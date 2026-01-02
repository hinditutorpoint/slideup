import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tts_request.dart';
import '../services/tts_audio_player.dart';
import '../tts_controller.dart';

class FloatingAudioPlayer extends StatefulWidget {
  final String? text;
  final String? modelName;
  final VoidCallback? onClose;
  final double initialX;
  final double initialY;

  const FloatingAudioPlayer({
    super.key,
    this.text,
    this.modelName,
    this.onClose,
    this.initialX = 16,
    this.initialY = 100,
  });

  @override
  State<FloatingAudioPlayer> createState() => FloatingAudioPlayerState();
}

class FloatingAudioPlayerState extends State<FloatingAudioPlayer>
    with SingleTickerProviderStateMixin {
  late double _x;
  late double _y;
  bool _isDragging = false;
  bool _isExpanded = false;
  bool _isInCloseZone = false;
  double _playbackSpeed = 1.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription<TtsStatus>? _statusSubscription;
  TtsStatus _status = const TtsStatus();
  String? _displayText;
  String? _modelName;

  static const double _closeZoneSize = 80;
  static const double _playerSize = 56;
  static const double _expandedWidth = 300;
  static const double _expandedHeight = 160;

  @override
  void initState() {
    super.initState();
    _x = widget.initialX;
    _y = widget.initialY;
    _displayText = widget.text;
    _modelName = widget.modelName ?? TtsController.instance.currentModelName;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _statusSubscription = TtsAudioPlayer.instance.statusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);

        if (status.isPlaying && !_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        } else if (!status.isPlaying && _pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.value = 1.0;
        }
      }
    });
  }

  void updateText(String? text) {
    if (mounted) {
      setState(() => _displayText = text);
    }
  }

  void updateModelName(String? modelName) {
    if (mounted) {
      setState(() => _modelName = modelName);
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() => _isDragging = true);
    HapticFeedback.lightImpact();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    setState(() {
      _x = (_x + details.delta.dx).clamp(0, screenSize.width - _playerSize);
      _y = (_y + details.delta.dy).clamp(
        MediaQuery.of(context).padding.top,
        screenSize.height - _playerSize - bottomPadding - _closeZoneSize,
      );

      final closeZoneY = screenSize.height - _closeZoneSize - bottomPadding;
      _isInCloseZone = _y + _playerSize > closeZoneY;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);

    if (_isInCloseZone) {
      HapticFeedback.heavyImpact();
      widget.onClose?.call();
    } else {
      final screenSize = MediaQuery.of(context).size;
      final snapToLeft = _x < screenSize.width / 2;

      setState(() {
        _x = snapToLeft ? 16 : screenSize.width - _playerSize - 16;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isDragging) _buildCloseZone(),
        AnimatedPositioned(
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: _isExpanded ? 16 : _x,
          top: _y,
          child: GestureDetector(
            onPanStart: _isExpanded ? null : _onPanStart,
            onPanUpdate: _isExpanded ? null : _onPanUpdate,
            onPanEnd: _isExpanded ? null : _onPanEnd,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: _isExpanded ? _expandedWidth : _playerSize,
              height: _isExpanded ? _expandedHeight : _playerSize,
              child: _isExpanded ? _buildExpandedPlayer() : _buildMiniPlayer(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCloseZone() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPadding,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _closeZoneSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              _isInCloseZone
                  ? Colors.red.withValues(alpha: 0.8)
                  : Colors.grey.withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ),
        ),
        child: Center(
          child: AnimatedScale(
            scale: _isInCloseZone ? 1.3 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isInCloseZone ? Colors.red : Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: _isInCloseZone ? 28 : 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniPlayer() {
    final progress = _status.progress.clamp(0.0, 1.0);
    final baseColor = _isInCloseZone ? Colors.red : Colors.blue;

    return ScaleTransition(
      scale: _status.isPlaying
          ? _pulseAnimation
          : const AlwaysStoppedAnimation(1.0),
      child: SizedBox(
        width: _playerSize,
        height: _playerSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Circular progress indicator
            CustomPaint(
              size: Size(_playerSize, _playerSize),
              painter: CircularProgressPainter(
                progress: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                progressColor: Colors.white,
                strokeWidth: 3,
              ),
            ),
            // Inner circle with gradient
            Container(
              width: _playerSize - 8,
              height: _playerSize - 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [baseColor[400]!, baseColor[700]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => TtsController.instance.togglePlayPause(),
                  onDoubleTap: () => setState(() => _isExpanded = true),
                  child: Center(child: _buildPlayerIcon()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerIcon() {
    if (_status.isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }

    return Icon(
      _status.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      color: Colors.white,
      size: 28,
    );
  }

  Widget _buildExpandedPlayer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.record_voice_over,
                    color: Colors.blue,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Text to Speech',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_modelName != null)
                        Text(
                          _modelName!,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _isExpanded = false),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),

          // Text preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _displayText ?? _status.text ?? 'No text',
                style: TextStyle(color: Colors.grey[300], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: Colors.grey[700],
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _status.progress.clamp(0.0, 1.0),
                    onChanged: (value) {
                      TtsController.instance.seekToPercentage(value);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _status.positionText,
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                      Text(
                        _status.durationText,
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Rewind
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white),
                  onPressed: () {
                    final newPos =
                        _status.position - const Duration(seconds: 10);
                    TtsController.instance.seek(
                      newPos < Duration.zero ? Duration.zero : newPos,
                    );
                  },
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                ),

                // Play/Pause
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _status.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () => TtsController.instance.togglePlayPause(),
                    iconSize: 28,
                  ),
                ),

                // Forward
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white),
                  onPressed: () {
                    final newPos =
                        _status.position + const Duration(seconds: 10);
                    final duration = _status.duration;
                    TtsController.instance.seek(
                      newPos > duration ? duration : newPos,
                    );
                  },
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                ),

                // Speed
                PopupMenuButton<double>(
                  initialValue: _playbackSpeed,
                  onSelected: (speed) {
                    setState(() => _playbackSpeed = speed);
                    TtsController.instance.setSpeed(speed);
                  },
                  offset: const Offset(0, -150),
                  itemBuilder: (context) => [
                    _buildSpeedMenuItem(0.5),
                    _buildSpeedMenuItem(0.75),
                    _buildSpeedMenuItem(1.0),
                    _buildSpeedMenuItem(1.25),
                    _buildSpeedMenuItem(1.5),
                    _buildSpeedMenuItem(2.0),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_playbackSpeed}x',
                      style: TextStyle(color: Colors.grey[300], fontSize: 12),
                    ),
                  ),
                ),

                // Close
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: widget.onClose,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<double> _buildSpeedMenuItem(double speed) {
    return PopupMenuItem(
      value: speed,
      child: Row(
        children: [
          if (_playbackSpeed == speed)
            const Icon(Icons.check, size: 16, color: Colors.blue)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text('${speed}x'),
        ],
      ),
    );
  }
}

/// Custom painter for circular progress indicator
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    this.strokeWidth = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start from top
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
