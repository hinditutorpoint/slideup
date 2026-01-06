import 'package:flutter/material.dart';

import '../models/video_player_state.dart';

/// Gesture zone detection - works with horizontal seeking
class PlayerGestureDetector extends StatefulWidget {
  final VoidCallback? onTap;
  final Function(GestureZone zone)? onDoubleTap;
  final Function(GestureZone zone)? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final Function(double delta, bool isLeftSide)? onVerticalDrag;

  // ✅ Changed callbacks for horizontal seek
  final VoidCallback? onHorizontalDragStart;
  final Function(double delta)? onHorizontalDragUpdate;
  final VoidCallback? onHorizontalDragEnd;

  final bool enabled;

  const PlayerGestureDetector({
    super.key,
    this.onTap,
    this.onDoubleTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onVerticalDrag,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
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

  // Long press
  bool _isLongPressing = false;
  GestureZone? _longPressZone;

  // Constants
  static const _doubleTapTimeout = Duration(milliseconds: 300);
  static const _dragThreshold = 10.0;
  static const _verticalDragThreshold = 0.5;

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

      // ✅ Use onPanStart/Update/End for better control
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onPanCancel: _handlePanCancel,

      child: const SizedBox.expand(),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAP HANDLING
  // ═══════════════════════════════════════════════════════

  void _handleTapDown(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  void _handleTapUp(TapUpDetails details) {
    if (_tapPosition == null) return;

    final now = DateTime.now();
    final position = details.globalPosition;

    try {
      if (_lastTapTime != null &&
          now.difference(_lastTapTime!) < _doubleTapTimeout &&
          _isNearPosition(position, _tapPosition!)) {
        _tapCount++;

        if (_tapCount >= 2) {
          final zone = _getZoneFromPosition(context, position);
          widget.onDoubleTap?.call(zone);
          _resetTapState();
          return;
        }
      } else {
        _tapCount = 1;
      }

      _lastTapTime = now;
      _tapPosition = position;

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
  // LONG PRESS HANDLING
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
  // PAN/DRAG HANDLING
  // ═══════════════════════════════════════════════════════

  void _handlePanStart(DragStartDetails details) {
    _dragStartPosition = details.globalPosition;
    _isDragging = false;
    _isVerticalDrag = false;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragStartPosition == null) return;

    try {
      final currentPosition = details.globalPosition;
      final totalDelta = currentPosition - _dragStartPosition!;

      if (!_isDragging) {
        if (totalDelta.distance > _dragThreshold) {
          _isDragging = true;
          _isVerticalDrag =
              totalDelta.dy.abs() >
              totalDelta.dx.abs() * _verticalDragThreshold;

          // ✅ Notify start of horizontal drag
          if (!_isVerticalDrag) {
            widget.onHorizontalDragStart?.call();
          }
        } else {
          return;
        }
      }

      if (_isVerticalDrag) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isLeftSide = _dragStartPosition!.dx < screenWidth / 2;
        widget.onVerticalDrag?.call(details.delta.dy, isLeftSide);
      } else {
        // ✅ Horizontal drag - pass raw delta
        widget.onHorizontalDragUpdate?.call(details.delta.dx);
      }
    } catch (e) {
      debugPrint('⚠️ Pan update error: $e');
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    try {
      if (_isDragging && !_isVerticalDrag) {
        widget.onHorizontalDragEnd?.call();
      }
    } catch (e) {
      debugPrint('⚠️ Pan end error: $e');
    } finally {
      _dragStartPosition = null;
      _isDragging = false;
      _isVerticalDrag = false;
    }
  }

  void _handlePanCancel() {
    if (_isDragging && !_isVerticalDrag) {
      widget.onHorizontalDragEnd?.call();
    }

    _dragStartPosition = null;
    _isDragging = false;
    _isVerticalDrag = false;
  }

  // ═══════════════════════════════════════════════════════
  // ZONE DETECTION
  // ═══════════════════════════════════════════════════════

  GestureZone _getZoneFromPosition(BuildContext context, Offset position) {
    try {
      final size = MediaQuery.of(context).size;
      final x = position.dx;
      final y = position.dy;

      final thirdWidth = size.width / 3;
      final thirdHeight = size.height / 3;

      int col;
      if (x < thirdWidth) {
        col = 0;
      } else if (x < thirdWidth * 2) {
        col = 1;
      } else {
        col = 2;
      }

      int row;
      if (y < thirdHeight) {
        row = 0;
      } else if (y < thirdHeight * 2) {
        row = 1;
      } else {
        row = 2;
      }

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
