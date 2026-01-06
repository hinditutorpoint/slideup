import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pip_service.dart';

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

  // Helpers
  bool get isCustomActive => state == PiPState.customActive;
  bool get isNativeActive => state == PiPState.nativeActive;
  bool get isActive => isCustomActive; // UI uses this for foreground overlay
}

// ─── PROVIDERS ──────────────────────────────────────────────

final pipServiceProvider = Provider<PiPService>((ref) {
  final service = PiPService();
  ref.onDispose(() => service.dispose());
  return service;
});

final pipProvider = NotifierProvider<PiPNotifier, PiPStateData>(() {
  return PiPNotifier();
});

// ─── NOTIFIER ───────────────────────────────────────────────

class PiPNotifier extends Notifier<PiPStateData> {
  PiPService get _service => ref.read(pipServiceProvider);

  @override
  PiPStateData build() {
    // Listen to service updates (driven by SimplePip callbacks)
    final sub = _service.stateStream.listen((newState) {
      state = state.copyWith(
        state: newState,
        position: _service.position,
        size: _service.size,
      );
    });
    ref.onDispose(() => sub.cancel());

    return const PiPStateData();
  }

  // ─── NATIVE CONTROLS ───

  Future<void> updateAutoPiP({required bool isPlaying}) async {
    // Don't enable auto-pip if custom pip is running
    if (state.isCustomActive) {
      await _service.disableAutoNativePiP();
      return;
    }

    if (isPlaying) {
      // Default 16:9
      await _service.enableAutoNativePiP(aspectX: 16, aspectY: 9);
    } else {
      await _service.disableAutoNativePiP();
    }
  }

  // ─── CUSTOM CONTROLS ───

  void enableCustomPiP() {
    _service.enableCustomPiP();
    state = state.copyWith(state: PiPState.customActive);
  }

  void disablePiP() {
    _service.disableCustomPiP();
    _service.disableAutoNativePiP(); // Ensure native is off too
    state = state.copyWith(state: PiPState.inactive);
  }

  // ─── INTERACTION (For Custom PiP) ───

  void setPosition(PiPPosition p) {
    _service.setPosition(p);
    state = state.copyWith(position: _service.position);
  }

  void setSize(PiPSize s) {
    _service.setSize(s);
    state = state.copyWith(size: _service.size);
  }

  void resizeByDelta(double delta) {
    _service.resizeByDelta(delta);
    state = state.copyWith(size: _service.size);
  }

  void startDrag() {
    state = state.copyWith(isDragging: true);
  }

  void endDrag(Size screenSize) {
    _service.snapToCorner(screenSize);
    state = state.copyWith(isDragging: false, position: _service.position);
  }

  void startResize() => state = state.copyWith(isResizing: true);
  void endResize() => state = state.copyWith(isResizing: false);

  void cycleSize() {
    _service.cycleSize();
    state = state.copyWith(size: _service.size);
  }

  void snapToCorner(Size screenSize) {
    _service.snapToCorner(screenSize);
    state = state.copyWith(position: _service.position);
  }
}
