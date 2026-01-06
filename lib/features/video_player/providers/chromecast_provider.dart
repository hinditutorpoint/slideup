import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/chromecast_service.dart';

// ═══════════════════════════════════════════════════════
// ✅ CHROMECAST PROVIDERS
// ═══════════════════════════════════════════════════════

final chromecastServiceProvider = Provider<ChromecastService>((ref) {
  final service = ChromecastService();

  ref.onDispose(() {
    debugPrint('🧹 Disposing ChromecastService...');
    service.dispose();
  });

  return service;
});

final chromecastStateProvider = StreamProvider<CastState>((ref) {
  final service = ref.watch(chromecastServiceProvider);
  return service.stateStream;
});

final chromecastDevicesProvider = StreamProvider<List<ChromecastDevice>>((ref) {
  final service = ref.watch(chromecastServiceProvider);
  return service.devicesStream;
});

final chromecastConnectedDeviceProvider = Provider<ChromecastDevice?>((ref) {
  final service = ref.watch(chromecastServiceProvider);
  return service.connectedDevice;
});

final isCastingProvider = Provider<bool>((ref) {
  final state = ref.watch(chromecastStateProvider).asData?.value;
  return state == CastState.connected;
});
