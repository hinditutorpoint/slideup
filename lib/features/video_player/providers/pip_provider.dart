import 'dart:async';
import 'package:flutter/widgets.dart'; // For Size
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pip_service.dart';

// ═══════════════════════════════════════════════════════
// ✅ PiP STATE
// ═══════════════════════════════════════════════════════

@immutable
class PiPStateData {
  final PiPState state;
  final PiPPosition position;
  final PiPSize size;
  final bool isDragging;
  final bool isResizing;

  const PiPStateData({
    this.state = PiPState.inactive,
    this.position = const PiPPosition(x: 20, y: 100),
    this.size = PiPSize.small,
    this.isDragging = false,
    this.isResizing = false,
  });

  PiPStateData copyWith({
    PiPState? state,
    PiPPosition? position,
    PiPSize? size,
    bool? isDragging,
    bool? isResizing,
  }) {
    return PiPStateData(
      state: state ?? this.state,
      position: position ?? this.position,
      size: size ?? this.size,
      isDragging: isDragging ?? this.isDragging,
      isResizing: isResizing ?? this.isResizing,
    );
  }

  bool get isActive => state == PiPState.active;

  // IMPORTANT for Riverpod: Override equality so widgets only rebuild when values change
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PiPStateData &&
        other.state == state &&
        other.position == position && // Ensure PiPPosition implements ==
        other.size == size &&
        other.isDragging == isDragging &&
        other.isResizing == isResizing;
  }

  @override
  int get hashCode =>
      Object.hash(state, position, size, isDragging, isResizing);
}

// ═══════════════════════════════════════════════════════
// ✅ PROVIDERS
// ═══════════════════════════════════════════════════════

// 1. Service Provider
// We keep the service alive. If the service needs disposal, handle it here.
final pipServiceProvider = Provider<PiPService>((ref) {
  final service = PiPService();
  ref.onDispose(() => service.dispose());
  return service;
});

// 2. Notifier Provider
// In Riverpod 3, we don't pass arguments to the constructor.
final pipProvider = NotifierProvider<PiPNotifier, PiPStateData>(() {
  return PiPNotifier();
});

// 3. Convenience Provider
final isPiPActiveProvider = Provider<bool>((ref) {
  return ref.watch(pipProvider.select((s) => s.isActive));
});

// ═══════════════════════════════════════════════════════
// ✅ PiP NOTIFIER
// ═══════════════════════════════════════════════════════

class PiPNotifier extends Notifier<PiPStateData> {
  // Access the service via a getter that reads from the provider
  PiPService get _service => ref.read(pipServiceProvider);

  @override
  PiPStateData build() {
    // Initialize the listener when the provider is first built
    _listenToService();

    // Return initial state
    return const PiPStateData();
  }

  void _listenToService() {
    final subscription = _service.stateStream.listen(
      (pipState) {
        // In Notifier, 'state' is a protected property we can update directly
        state = state.copyWith(
          state: pipState,
          position: _service.position,
          size: _service.size,
        );
      },
      onError: (e, stackTrace) {
        debugPrint('❌ PiP state stream error: $e');

        // Optional: Retry logic
        // Note: We use a Timer to avoid async gaps with 'mounted' checks
        // In Riverpod, checking ref.exists represents 'mounted' usually
        Future.delayed(const Duration(seconds: 2), () {
          // We don't need to manually check mounted/disposed here as much
          // because onDispose cancels the subscription.
          // However, if you want robust retry logic, you'd re-call _listenToService here.
        });
      },
    );

    // Riverpod 3: Handle cleanup using ref.onDispose
    ref.onDispose(() {
      subscription.cancel();
    });
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PiP CONTROL
  // ═══════════════════════════════════════════════════════

  Future<bool> isPiPAvailable() async {
    try {
      return await _service.isPiPAvailable();
    } catch (e) {
      debugPrint('❌ Check PiP availability error: $e');
      return false;
    }
  }

  Future<bool> enableNativePiP() async {
    try {
      return await _service.enableNativePiP();
    } catch (e) {
      debugPrint('❌ Enable native PiP error: $e');
      return false;
    }
  }

  void enableCustomPiP() {
    try {
      _service.enableCustomPiP();
      state = state.copyWith(
        state: PiPState.active,
        position: _service.position,
        size: _service.size,
      );
    } catch (e) {
      debugPrint('❌ Enable custom PiP error: $e');
    }
  }

  void disablePiP() {
    try {
      _service.disableCustomPiP();
      state = state.copyWith(state: PiPState.inactive);
    } catch (e) {
      debugPrint('❌ Disable PiP error: $e');
    }
  }

  void togglePiP() {
    if (state.isActive) {
      disablePiP();
    } else {
      enableCustomPiP();
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ POSITION & SIZE
  // ═══════════════════════════════════════════════════════

  void updatePosition(double dx, double dy, {required Size screenSize}) {
    try {
      _service.updatePosition(dx, dy, screenSize: screenSize);
      state = state.copyWith(position: _service.position);
    } catch (e) {
      debugPrint('❌ Update position error: $e');
    }
  }

  void setPosition(PiPPosition newPosition) {
    try {
      _service.setPosition(newPosition);
      state = state.copyWith(position: _service.position);
    } catch (e) {
      debugPrint('❌ Set position error: $e');
    }
  }

  void snapToCorner(Size screenSize) {
    try {
      _service.snapToCorner(screenSize);
      state = state.copyWith(position: _service.position);
    } catch (e) {
      debugPrint('❌ Snap to corner error: $e');
    }
  }

  void setSize(PiPSize newSize) {
    try {
      _service.setSize(newSize);
      state = state.copyWith(size: _service.size);
    } catch (e) {
      debugPrint('❌ Set size error: $e');
    }
  }

  void cycleSize() {
    try {
      _service.cycleSize();
      state = state.copyWith(size: _service.size);
    } catch (e) {
      debugPrint('❌ Cycle size error: $e');
    }
  }

  void resizeByDelta(double delta) {
    try {
      _service.resizeByDelta(delta);
      state = state.copyWith(size: _service.size);
    } catch (e) {
      debugPrint('❌ Resize by delta error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DRAG & RESIZE
  // ═══════════════════════════════════════════════════════

  void startDrag() {
    try {
      _service.startDrag();
      state = state.copyWith(isDragging: true);
    } catch (e) {
      debugPrint('❌ Start drag error: $e');
    }
  }

  void endDrag(Size screenSize) {
    try {
      _service.endDrag(screenSize);
      state = state.copyWith(isDragging: false, position: _service.position);
    } catch (e) {
      debugPrint('❌ End drag error: $e');
    }
  }

  void startResize() {
    try {
      _service.startResize();
      state = state.copyWith(isResizing: true);
    } catch (e) {
      debugPrint('❌ Start resize error: $e');
    }
  }

  void endResize() {
    try {
      _service.endResize();
      state = state.copyWith(isResizing: false);
    } catch (e) {
      debugPrint('❌ End resize error: $e');
    }
  }
}
