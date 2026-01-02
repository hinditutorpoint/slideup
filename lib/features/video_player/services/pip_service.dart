import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:floating/floating.dart';

enum PiPState { inactive, entering, active, exiting }

class PiPPosition {
  final double x;
  final double y;

  const PiPPosition({required this.x, required this.y});

  PiPPosition copyWith({double? x, double? y}) {
    return PiPPosition(x: x ?? this.x, y: y ?? this.y);
  }
}

class PiPSize {
  final double width;
  final double height;

  const PiPSize({required this.width, required this.height});

  static const mini = PiPSize(width: 150, height: 100);
  static const small = PiPSize(width: 200, height: 130);
  static const medium = PiPSize(width: 280, height: 180);
  static const large = PiPSize(width: 360, height: 240);

  PiPSize copyWith({double? width, double? height}) {
    return PiPSize(width: width ?? this.width, height: height ?? this.height);
  }
}

class PiPService {
  final Floating _floating = Floating();

  final _stateController = StreamController<PiPState>.broadcast();
  Stream<PiPState> get stateStream => _stateController.stream;

  PiPState _state = PiPState.inactive;
  PiPState get state => _state;

  PiPPosition _position = const PiPPosition(x: 20, y: 100);
  PiPPosition get position => _position;

  PiPSize _size = PiPSize.small;
  PiPSize get size => _size;

  bool _isDragging = false;
  bool _isResizing = false;

  bool _isDisposed = false;

  // ═══════════════════════════════════════════════════════
  // ✅ PiP AVAILABILITY
  // ═══════════════════════════════════════════════════════

  Future<bool> isPiPAvailable() async {
    try {
      return await _floating.isPipAvailable;
    } catch (e) {
      debugPrint('⚠️ PiP availability check failed: $e');
      return false;
    }
  }

  Future<bool> isPiPActive() async {
    try {
      return await _floating.isPipAvailable;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ NATIVE PiP (Android)
  // ═══════════════════════════════════════════════════════

  Future<bool> enableNativePiP({
    Rational aspectRatio = const Rational.landscape(),
    Rectangle<int>? sourceRectHint,
  }) async {
    try {
      _updateState(PiPState.entering);
      final args = ImmediatePiP(
        aspectRatio: aspectRatio,
        sourceRectHint: sourceRectHint,
      );
      final status = await _floating.enable(args);

      if (status == PiPStatus.enabled) {
        _updateState(PiPState.active);
        return true;
      } else {
        _updateState(PiPState.inactive);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to enable native PiP: $e');
      _updateState(PiPState.inactive);
      return false;
    }
  }

  Future<void> disableNativePiP() async {
    try {
      _updateState(PiPState.exiting);
      // Native PiP exits when user taps expand
      _updateState(PiPState.inactive);
    } catch (e) {
      debugPrint('⚠️ Error disabling native PiP: $e');
    }
  }

  Stream<PiPStatus> get pipStatusStream =>
      _floating.pipStatus as Stream<PiPStatus>;

  // ═══════════════════════════════════════════════════════
  // ✅ CUSTOM PiP (In-App Floating Window)
  // ═══════════════════════════════════════════════════════

  void enableCustomPiP() {
    _updateState(PiPState.active);
  }

  void disableCustomPiP() {
    _updateState(PiPState.inactive);
    _position = const PiPPosition(x: 20, y: 100);
    _size = PiPSize.small;
  }

  void toggleCustomPiP() {
    if (_state == PiPState.active) {
      disableCustomPiP();
    } else {
      enableCustomPiP();
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ POSITION & SIZE
  // ═══════════════════════════════════════════════════════

  void setPosition(PiPPosition newPosition) {
    _position = newPosition;
  }

  void updatePosition(double dx, double dy, {required Size screenSize}) {
    final newX = (_position.x + dx).clamp(0.0, screenSize.width - _size.width);
    final newY = (_position.y + dy).clamp(
      0.0,
      screenSize.height - _size.height,
    );
    _position = PiPPosition(x: newX, y: newY);
  }

  void snapToCorner(Size screenSize) {
    final centerX = _position.x + _size.width / 2;
    final centerY = _position.y + _size.height / 2;

    final padding = 16.0;

    double targetX;
    double targetY;

    // Horizontal snap
    if (centerX < screenSize.width / 2) {
      targetX = padding;
    } else {
      targetX = screenSize.width - _size.width - padding;
    }

    // Vertical snap
    if (centerY < screenSize.height / 3) {
      targetY = padding;
    } else if (centerY > screenSize.height * 2 / 3) {
      targetY = screenSize.height - _size.height - padding;
    } else {
      targetY = (screenSize.height - _size.height) / 2;
    }

    _position = PiPPosition(x: targetX, y: targetY);
  }

  void setSize(PiPSize newSize) {
    _size = newSize;
  }

  void cycleSize() {
    if (_size.width <= PiPSize.mini.width) {
      _size = PiPSize.small;
    } else if (_size.width <= PiPSize.small.width) {
      _size = PiPSize.medium;
    } else if (_size.width <= PiPSize.medium.width) {
      _size = PiPSize.large;
    } else {
      _size = PiPSize.mini;
    }
  }

  void resizeByDelta(double delta) {
    final scale = 1 + delta / 100;
    final newWidth = (_size.width * scale).clamp(
      PiPSize.mini.width,
      PiPSize.large.width,
    );
    final newHeight = newWidth * (9 / 16); // Maintain 16:9 aspect ratio
    _size = PiPSize(width: newWidth, height: newHeight);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DRAG & RESIZE STATE
  // ═══════════════════════════════════════════════════════

  void startDrag() {
    _isDragging = true;
  }

  void endDrag(Size screenSize) {
    _isDragging = false;
    snapToCorner(screenSize);
  }

  void startResize() {
    _isResizing = true;
  }

  void endResize() {
    _isResizing = false;
  }

  bool get isDragging => _isDragging;
  bool get isResizing => _isResizing;

  // ═══════════════════════════════════════════════════════
  // ✅ STATE
  // ═══════════════════════════════════════════════════════

  void _updateState(PiPState newState) {
    if (_isDisposed) return;
    _state = newState;
    _stateController.add(_state);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DISPOSE
  // ═══════════════════════════════════════════════════════

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _stateController.close();
  }
}
