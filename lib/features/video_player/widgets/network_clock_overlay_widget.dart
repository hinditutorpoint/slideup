import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ═══════════════════════════════════════════════════════
// ✅ NETWORK SPEED / DATA + DIGITAL CLOCK OVERLAY
// Shows when controls are HIDDEN
// ═══════════════════════════════════════════════════════

class NetworkClockOverlayWidget extends StatefulWidget {
  final bool visible;

  const NetworkClockOverlayWidget({super.key, required this.visible});

  @override
  State<NetworkClockOverlayWidget> createState() =>
      _NetworkClockOverlayWidgetState();
}

class _NetworkClockOverlayWidgetState extends State<NetworkClockOverlayWidget> {
  Timer? _timer;
  String _currentTime = '';
  String _networkSpeed = '0 KB/s';
  String _totalConsumed = '0 KB';

  int _lastRxBytes = 0;
  int _totalBytes = 0;
  bool _isFirstRead = true;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _initNetworkTracking();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTime();
      _updateNetworkStats();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (!mounted) return;
    setState(() {
      _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());
    });
  }

  Future<int> _getTotalRxBytes() async {
    try {
      if (Platform.isAndroid) {
        // Read from /proc/net/dev on Android
        final file = File('/proc/net/dev');
        if (await file.exists()) {
          final lines = await file.readAsLines();
          int totalBytes = 0;
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            // Skip header lines and loopback
            if (trimmed.startsWith('Inter-') ||
                trimmed.startsWith('face') ||
                trimmed.startsWith('lo:')) {
              continue;
            }
            final colonIndex = trimmed.indexOf(':');
            if (colonIndex == -1) continue;
            final iface = trimmed.substring(0, colonIndex).trim();
            final rest = trimmed.substring(colonIndex + 1).trim();
            if (iface.isEmpty || rest.isEmpty) continue;
            // Skip virtual/tunnel interfaces (wlan/rmnet/eth/ccmni/etc. pass)
            if (iface.startsWith('lo') ||
                iface.startsWith('tun') ||
                iface.startsWith('ip6') ||
                iface.startsWith('dummy') ||
                iface.startsWith('ifb') ||
                iface.startsWith('sit') ||
                iface.startsWith('gre') ||
                iface.startsWith('veth')) {
              continue;
            }
            final parts = rest.split(RegExp(r'\s+'));
            if (parts.isEmpty) continue;
            final rxBytes = int.tryParse(parts[0]);
            if (rxBytes != null && rxBytes > 0) {
              totalBytes += rxBytes;
            }
          }
          return totalBytes;
        }
      }
      return 0;
    } catch (e) {
      debugPrint('⚠️ Network stats read error: $e');
      return 0;
    }
  }

  Future<void> _initNetworkTracking() async {
    _lastRxBytes = await _getTotalRxBytes();
    _isFirstRead = false;
  }

  Future<void> _updateNetworkStats() async {
    if (!mounted || _isFirstRead) return;

    try {
      final currentRxBytes = await _getTotalRxBytes();
      final bytesPerSecond = currentRxBytes - _lastRxBytes;

      if (bytesPerSecond > 0) {
        _totalBytes += bytesPerSecond;
      }

      _lastRxBytes = currentRxBytes;

      setState(() {
        _networkSpeed = _formatSpeed(bytesPerSecond > 0 ? bytesPerSecond : 0);
        _totalConsumed = _formatBytes(_totalBytes);
      });
    } catch (e) {
      debugPrint('⚠️ Network stats update error: $e');
    }
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 KB/s';
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Left: Network Speed + Total Data ──
                _InfoChip(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_downward_rounded,
                          color: Colors.greenAccent,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _networkSpeed,
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black87),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.data_usage_rounded,
                          color: Colors.white70,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _totalConsumed,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black87),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // ── Top Right: Digital Clock ──
                _InfoChip(
                  children: [
                    Text(
                      _currentTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                        shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ INFO CHIP — Subtle pill-shaped background
// ═══════════════════════════════════════════════════════

class _InfoChip extends StatelessWidget {
  final List<Widget> children;

  const _InfoChip({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
