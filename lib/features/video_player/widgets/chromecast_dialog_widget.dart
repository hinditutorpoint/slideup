import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/chromecast_service.dart';
import '../providers/chromecast_provider.dart';
import '../providers/video_player_provider.dart';

class ChromecastDialogWidget extends ConsumerStatefulWidget {
  const ChromecastDialogWidget({super.key});

  @override
  ConsumerState<ChromecastDialogWidget> createState() =>
      _ChromecastDialogWidgetState();
}

class _ChromecastDialogWidgetState
    extends ConsumerState<ChromecastDialogWidget> {
  @override
  void initState() {
    super.initState();
    // Start discovery when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(chromecastServiceProvider).startDiscovery();
      } catch (e) {
        debugPrint('❌ Start discovery error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final castState = ref.watch(chromecastStateProvider).asData?.value;
    final devicesAsync = ref.watch(chromecastDevicesProvider);
    final connectedDevice = ref.watch(chromecastConnectedDeviceProvider);
    final service = ref.read(chromecastServiceProvider);

    return Dialog(
      backgroundColor: const Color(0xE6212121),
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.cast,
                    color: Colors.lightBlueAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Cast to Device',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          color: Colors.white54,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Connected Device (if any)
            if (connectedDevice != null) ...[
              _ConnectedDeviceTile(
                device: connectedDevice,
                onDisconnect: () async {
                  try {
                    await service.disconnect();
                  } catch (e) {
                    debugPrint('❌ Disconnect error: $e');
                  }
                },
              ),
              const Divider(color: Colors.white12, height: 1),
            ],

            // Available Devices
            Flexible(
              child: devicesAsync.when(
                data: (devices) {
                  if (devices.isEmpty) {
                    return _EmptyDevicesList(
                      isScanning: service.isScanning,
                      onRefresh: () {
                        try {
                          service.startDiscovery();
                        } catch (e) {
                          debugPrint('❌ Refresh error: $e');
                        }
                      },
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (service.isScanning)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.lightBlueAccent,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Scanning for devices...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...devices.map(
                          (device) => _DeviceTile(
                            device: device,
                            isConnecting: castState == CastState.connecting,
                            onTap: () async {
                              try {
                                final success = await service.connect(device);
                                if (success && context.mounted) {
                                  // Load current media to chromecast
                                  final playerState = ref.read(
                                    videoPlayerProvider,
                                  );
                                  final currentMedia = ref.read(
                                    currentMediaProvider,
                                  );

                                  await service.loadMedia(
                                    url: playerState.currentUrl,
                                    title:
                                        currentMedia?.title ??
                                        playerState.currentTitle,
                                    startPosition: playerState.position,
                                  );

                                  // Optionally pause local playback
                                  await ref
                                      .read(videoPlayerProvider.notifier)
                                      .pause();
                                }
                              } catch (e) {
                                debugPrint('❌ Connect error: $e');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.lightBlueAccent,
                      ),
                    ),
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: $error',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ CONNECTED DEVICE TILE
// ═══════════════════════════════════════════════════════

class _ConnectedDeviceTile extends StatelessWidget {
  final ChromecastDevice device;
  final VoidCallback onDisconnect;

  const _ConnectedDeviceTile({
    required this.device,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.lightBlueAccent.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(
            Icons.cast_connected,
            color: Colors.lightBlueAccent,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Connected to',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  device.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (device.modelName != null)
                  Text(
                    device.modelName!,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDisconnect,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.close, color: Colors.grey[400], size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ DEVICE TILE
// ═══════════════════════════════════════════════════════

class _DeviceTile extends StatelessWidget {
  final ChromecastDevice device;
  final bool isConnecting;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.device,
    required this.isConnecting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isConnecting ? null : onTap,
        splashColor: Colors.white12,
        highlightColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.tv, color: Colors.grey[400], size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (device.modelName != null)
                      Text(
                        device.modelName!,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (isConnecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.lightBlueAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ EMPTY DEVICES LIST
// ═══════════════════════════════════════════════════════

class _EmptyDevicesList extends StatelessWidget {
  final bool isScanning;
  final VoidCallback onRefresh;

  const _EmptyDevicesList({required this.isScanning, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isScanning ? Icons.search : Icons.devices_other,
              color: Colors.grey[600],
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              isScanning ? 'Searching for devices...' : 'No devices found',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isScanning
                  ? 'Make sure your device is on the same network'
                  : 'Tap refresh to search again',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (!isScanning) ...[
              const SizedBox(height: 24),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.lightBlueAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          color: Colors.lightBlueAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Refresh',
                          style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
