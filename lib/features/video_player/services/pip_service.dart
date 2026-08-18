import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/aspect_ratio.dart' as sar;

enum PiPState {
  inactive,
  customActive, // Foreground (In-App)
  nativeActive, // Background (System)
}

// ─── Custom PiP Models ──────────────────────────────────────

class PiPPosition {
  final double x;
  final double y;
  const PiPPosition({required this.x, required this.y});

  PiPPosition copyWith({double? x, double? y}) =>
      PiPPosition(x: x ?? this.x, y: y ?? this.y);
}

class PiPSize {
  final double width;
  final double height;
  const PiPSize({required this.width, required this.height});

  static const mini = PiPSize(width: 150, height: 84); // ✅ Adjusted
  static const small = PiPSize(width: 200, height: 112);
  static const medium = PiPSize(width: 280, height: 158);
  static const large = PiPSize(width: 360, height: 202);

  PiPSize copyWith({double? width, double? height}) =>
      PiPSize(width: width ?? this.width, height: height ?? this.height);
}

// ─── Service Implementation ─────────────────────────────────

class PiPService {
  static final PiPService _instance = PiPService._internal();
  factory PiPService() => _instance;

  late final SimplePip _simplePip;
  final _stateController = StreamController<PiPState>.broadcast();
  Stream<PiPState> get stateStream => _stateController.stream;

  /// Emits PiP action names ("play_pause" | "previous" | "next") tapped on
  /// the native Android PiP menu (registered as RemoteActions in Kotlin).
  final _pipActionController = StreamController<String>.broadcast();
  Stream<String> get pipActionStream => _pipActionController.stream;

  // Custom PiP State
  PiPState _state = PiPState.inactive;
  bool _wasCustomActive = false;
  PiPPosition _position = const PiPPosition(x: 20, y: 100);
  PiPSize _size = PiPSize.small;

  PiPService._internal() {
    // Forward native PiP menu actions (tapped in the OS PiP window) to Dart.
    const MethodChannel('com.slideup.mediaplayer/background_video')
        .setMethodCallHandler((call) async {
      if (call.method == 'pipAction') {
        final action = call.arguments as String?;
        if (action != null && !_pipActionController.isClosed) {
          _pipActionController.add(action);
        }
      }
      return null;
    });

    // ✅ Initialize SimplePip with Callbacks
    _simplePip = SimplePip(
      onPipEntered: () {
        debugPrint("📺 Native PiP Entered");
        if (_state == PiPState.customActive) {
          _wasCustomActive = true;
        }
        _updateState(PiPState.nativeActive);
      },
      onPipExited: () {
        debugPrint("📺 Native PiP Exited");
        if (_state == PiPState.nativeActive) {
          if (_wasCustomActive) {
            _updateState(PiPState.customActive);
          } else {
            _updateState(PiPState.inactive);
          }
          _wasCustomActive = false;
        }
      },
    );
  }

  // Getters
  PiPState get state => _state;
  PiPPosition get position => _position;
  PiPSize get size => _size;

  // ═══════════════════════════════════════════════════════
  // ✅ NATIVE PiP (Matching your Source Code)
  // ═══════════════════════════════════════════════════════

  Future<bool> isNativeApiAvailable() async {
    try {
      // Using the static getter from your code
      return await SimplePip.isPipAvailable;
    } catch (_) {
      return false;
    }
  }

  /// ✅ AUTO-ENTER (Android 12+ via simple_pip, Android 8-11 via native channel)
  Future<void> enableAutoNativePiP({int aspectX = 16, int aspectY = 9}) async {
    // Android 12+ path: simple_pip handles autoEnter natively.
    // setAutoPipMode THROWS on Android < 12 (plugin returns
    // "NotImplemented / System Version less than Android S found"), so it is
    // gated by isAutoPipAvailable AND isolated in its own try/catch so it can
    // never block the Android 8–11 fallback below.
    try {
      if (await SimplePip.isPipAvailable && await SimplePip.isAutoPipAvailable) {
        sar.AspectRatio aspectRatio = (aspectX, aspectY);
        await _simplePip.setAutoPipMode(
          aspectRatio: aspectRatio,
          seamlessResize: false,
          autoEnter: true,
        );
      }
    } catch (e) {
      debugPrint('❌ Auto-PiP (Android 12+) Error: $e');
    }
    // Android 8–11: tell our Kotlin onUserLeaveHint to enter PiP on Home press.
    // MUST run unconditionally — it is what makes Home-press PiP work pre-12.
    await _setNativeAutoEnter(true);
  }

  /// ✅ DISABLE AUTO-ENTER
  Future<void> disableAutoNativePiP() async {
    try {
      if (await SimplePip.isAutoPipAvailable) {
        await _simplePip.setAutoPipMode(autoEnter: false);
      }
    } catch (e) {
      debugPrint('❌ Disable Auto-PiP (Android 12+) Error: $e');
    }
    await _setNativeAutoEnter(false);
  }

  /// Notifies the Kotlin [MainActivity] whether to auto-enter PiP
  /// when the user presses Home (Android 8–11 fallback path).
  Future<void> _setNativeAutoEnter(bool enabled) async {
    try {
      await const MethodChannel('com.slideup.mediaplayer/background_video')
          .invokeMethod<void>('setPiPAutoEnter', {'enabled': enabled});
    } catch (e) {
      debugPrint('⚠️ setPiPAutoEnter channel error: $e');
    }
  }

  /// ✅ MANUAL ENTER (Fallback)
  Future<void> enterNativePipNow({int aspectX = 16, int aspectY = 9}) async {
    try {
      sar.AspectRatio aspectRatio = (aspectX, aspectY);
      await _simplePip.enterPipMode(
        aspectRatio: aspectRatio,
        autoEnter: false, // Manual entry doesn't need autoEnter flag usually
      );
    } catch (e) {
      debugPrint('❌ Manual Enter PiP Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CUSTOM PiP (Foreground)
  // ═══════════════════════════════════════════════════════

  void enableCustomPiP() {
    _updateState(PiPState.customActive);
    enableAutoNativePiP(); // Keep native auto-enter active on home press
  }

  void disableCustomPiP() {
    _wasCustomActive = false;
    _updateState(PiPState.inactive);
    _position = const PiPPosition(x: 20, y: 100);
    _size = PiPSize.small;
  }

  // Position Logic
  void setPosition(PiPPosition p) => _position = p;
  void setSize(PiPSize s) => _size = s;

  void updatePosition(double dx, double dy, {required Size screenSize}) {
    final newX = (_position.x + dx).clamp(0.0, screenSize.width - _size.width);
    final newY = (_position.y + dy).clamp(
      0.0,
      screenSize.height - _size.height,
    );
    _position = PiPPosition(x: newX, y: newY);
  }

  void snapToCorner(Size screenSize) {
    // Simple corner snap logic
    final centerX = _position.x + _size.width / 2;
    final targetX = centerX < screenSize.width / 2
        ? 16.0
        : screenSize.width - _size.width - 16.0;

    final centerY = _position.y + _size.height / 2;
    double targetY;

    if (centerY < screenSize.height / 3) {
      targetY = 16.0;
    } else if (centerY > screenSize.height * 2 / 3) {
      targetY = screenSize.height - _size.height - 16.0;
    } else {
      targetY = _position.y;
    }

    _position = PiPPosition(x: targetX, y: targetY);
  }

  void cycleSize() {
    if (_size.width < 250) {
      _size = PiPSize.medium;
    } else {
      _size = PiPSize.small;
    }
  }

  void resizeByDelta(double delta) {
    final scale = 1 + delta / 100;
    final newWidth = (_size.width * scale).clamp(150.0, 360.0);
    final newHeight = newWidth * (9 / 16);

    // Ensure minimum height doesn't cause overflow
    final constrainedHeight = newHeight.clamp(84.0, 360.0 * (9 / 16));
    final constrainedWidth = constrainedHeight * (16 / 9);

    _size = PiPSize(width: constrainedWidth, height: constrainedHeight);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ STATE UPDATES
  // ═══════════════════════════════════════════════════════

  void _updateState(PiPState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void dispose() {
    _stateController.close();
    _pipActionController.close();
  }
}
