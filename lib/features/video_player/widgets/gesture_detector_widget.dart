import 'package:flutter/material.dart';

import '../models/video_player_state.dart';

/// Gesture zone detection for 3x3 grid
class PlayerGestureDetector extends StatefulWidget {
  final VoidCallback? onTap;
  final Function(GestureZone zone)? onDoubleTap;
  final Function(GestureZone zone)? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final Function(double delta, bool isLeftSide)? onVerticalDrag;
  final Function(double delta)? onHorizontalDrag;
  final Function(double scale)? onScale;
  final bool enabled;

  const PlayerGestureDetector({
    super.key,
    this.onTap,
    this.onDoubleTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onVerticalDrag,
    this.onHorizontalDrag,
    this.onScale,
    this.enabled = true,
  });

  @override
  State<PlayerGestureDetector> createState() => _PlayerGestureDetectorState();
}

class _PlayerGestureDetectorState extends State<PlayerGestureDetector> {
  // Tap detection
  Offset? _tapPosition;
  DateTime? _lastTapTime;
  int _tapCount = 0;

  // Drag detection
  Offset? _dragStartPosition;
  bool _isDragging = false;
  bool _isVerticalDrag = false;
  double _accumulatedDelta = 0;

  // Long press
  bool _isLongPressing = false;
  GestureZone? _longPressZone;

  // Constants
  static const _doubleTapTimeout = Duration(milliseconds: 300);
  static const _dragThreshold = 10.0;
  static const _verticalDragThreshold =
      0.5; // Ratio to determine drag direction

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.expand();
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPressStart: _handleLongPressStart,
      onLongPressEnd: _handleLongPressEnd,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onScaleUpdate: widget.onScale != null ? _handleScaleUpdate : null,
      child: const SizedBox.expand(),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TAP HANDLING
  // ═══════════════════════════════════════════════════════

  void _handleTapDown(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  void _handleTapUp(TapUpDetails details) {
    if (_tapPosition == null) return;

    final now = DateTime.now();
    final position = details.globalPosition;

    try {
      // Check for double tap
      if (_lastTapTime != null &&
          now.difference(_lastTapTime!) < _doubleTapTimeout &&
          _isNearPosition(position, _tapPosition!)) {
        _tapCount++;

        if (_tapCount >= 2) {
          // Double tap detected
          final zone = _getZoneFromPosition(context, position);
          widget.onDoubleTap?.call(zone);
          _resetTapState();
          return;
        }
      } else {
        // Reset tap count for new tap sequence
        _tapCount = 1;
      }

      _lastTapTime = now;
      _tapPosition = position;

      // Schedule single tap callback
      Future.delayed(_doubleTapTimeout, () {
        if (_tapCount == 1 && mounted) {
          widget.onTap?.call();
          _resetTapState();
        }
      });
    } catch (e) {
      debugPrint('⚠️ Tap handling error: $e');
      _resetTapState();
    }
  }

  void _handleTapCancel() {
    _resetTapState();
  }

  void _resetTapState() {
    _tapCount = 0;
    _tapPosition = null;
  }

  bool _isNearPosition(Offset a, Offset b, {double threshold = 50}) {
    return (a - b).distance < threshold;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ LONG PRESS HANDLING
  // ═══════════════════════════════════════════════════════

  void _handleLongPressStart(LongPressStartDetails details) {
    try {
      _isLongPressing = true;
      _longPressZone = _getZoneFromPosition(context, details.globalPosition);
      widget.onLongPressStart?.call(_longPressZone!);
    } catch (e) {
      debugPrint('⚠️ Long press start error: $e');
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    try {
      if (_isLongPressing) {
        widget.onLongPressEnd?.call();
      }
    } catch (e) {
      debugPrint('⚠️ Long press end error: $e');
    } finally {
      _isLongPressing = false;
      _longPressZone = null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PAN/DRAG HANDLING
  // ═══════════════════════════════════════════════════════

  void _handlePanStart(DragStartDetails details) {
    _dragStartPosition = details.globalPosition;
    _isDragging = false;
    _isVerticalDrag = false;
    _accumulatedDelta = 0;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragStartPosition == null) return;

    try {
      final currentPosition = details.globalPosition;
      final totalDelta = currentPosition - _dragStartPosition!;

      // Determine drag direction if not yet determined
      if (!_isDragging) {
        if (totalDelta.distance > _dragThreshold) {
          _isDragging = true;
          _isVerticalDrag =
              totalDelta.dy.abs() >
              totalDelta.dx.abs() * _verticalDragThreshold;
        } else {
          return;
        }
      }

      if (_isVerticalDrag) {
        // Vertical drag - brightness/volume
        final screenWidth = MediaQuery.of(context).size.width;
        final isLeftSide = _dragStartPosition!.dx < screenWidth / 2;
        widget.onVerticalDrag?.call(details.delta.dy, isLeftSide);
      } else {
        // Horizontal drag - seek
        _accumulatedDelta += details.delta.dx;
      }
    } catch (e) {
      debugPrint('⚠️ Pan update error: $e');
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    try {
      if (_isDragging && !_isVerticalDrag && _accumulatedDelta.abs() > 20) {
        widget.onHorizontalDrag?.call(_accumulatedDelta);
      }
    } catch (e) {
      debugPrint('⚠️ Pan end error: $e');
    } finally {
      _dragStartPosition = null;
      _isDragging = false;
      _isVerticalDrag = false;
      _accumulatedDelta = 0;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SCALE HANDLING
  // ═══════════════════════════════════════════════════════

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    try {
      if (details.scale != 1.0) {
        widget.onScale?.call(details.scale);
      }
    } catch (e) {
      debugPrint('⚠️ Scale update error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ZONE DETECTION
  // ═══════════════════════════════════════════════════════

  GestureZone _getZoneFromPosition(BuildContext context, Offset position) {
    try {
      final size = MediaQuery.of(context).size;
      final x = position.dx;
      final y = position.dy;

      // Calculate zone boundaries
      final thirdWidth = size.width / 3;
      final thirdHeight = size.height / 3;

      // Determine column (0, 1, 2)
      int col;
      if (x < thirdWidth) {
        col = 0;
      } else if (x < thirdWidth * 2) {
        col = 1;
      } else {
        col = 2;
      }

      // Determine row (0, 1, 2)
      int row;
      if (y < thirdHeight) {
        row = 0;
      } else if (y < thirdHeight * 2) {
        row = 1;
      } else {
        row = 2;
      }

      // Map to GestureZone
      const zones = [
        [GestureZone.topLeft, GestureZone.topCenter, GestureZone.topRight],
        [GestureZone.centerLeft, GestureZone.center, GestureZone.centerRight],
        [
          GestureZone.bottomLeft,
          GestureZone.bottomCenter,
          GestureZone.bottomRight,
        ],
      ];

      return zones[row][col];
    } catch (e) {
      debugPrint('⚠️ Zone detection error: $e');
      return GestureZone.center;
    }
  }
}

/// Visual debug overlay for gesture zones (for development)
class GestureZoneDebugOverlay extends StatelessWidget {
  final bool show;

  const GestureZoneDebugOverlay({super.key, this.show = false});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return IgnorePointer(
      child: GridView.count(
        crossAxisCount: 3,
        childAspectRatio:
            MediaQuery.of(context).size.width /
            MediaQuery.of(context).size.height *
            3,
        children: [
          _buildZoneLabel('⏮️\nPrevious'),
          _buildZoneLabel('⏯️\nPlay/Pause'),
          _buildZoneLabel('⏭️\nNext'),
          _buildZoneLabel('⏪\n-10s'),
          _buildZoneLabel('⏯️\nPlay/Pause'),
          _buildZoneLabel('⏩\n+10s'),
          _buildZoneLabel('⏮️\nPrevious'),
          _buildZoneLabel('⏯️\nPlay/Pause'),
          _buildZoneLabel('⏭️\nNext'),
        ],
      ),
    );
  }

  Widget _buildZoneLabel(String label) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
    );
  }
}
