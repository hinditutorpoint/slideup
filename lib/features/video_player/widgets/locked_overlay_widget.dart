import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/video_player_provider.dart';

class LockedOverlayWidget extends ConsumerStatefulWidget {
  const LockedOverlayWidget({super.key});

  @override
  ConsumerState<LockedOverlayWidget> createState() =>
      _LockedOverlayWidgetState();
}

class _LockedOverlayWidgetState extends ConsumerState<LockedOverlayWidget> {
  bool _showUnlockHint = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ═══════════════════════════════════════════════════════
        // ✅ LAYER 1: Full-screen touch absorber (blocks all gestures)
        // ═══════════════════════════════════════════════════════
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showHint, // Show hint, don't unlock
            onDoubleTap: () {}, // Absorb
            onLongPress: () {}, // Absorb
            //onPanUpdate: (_) {}, // Absorb swipes
            onScaleUpdate: (_) {}, // Absorb pinch
            child: Container(color: Colors.transparent),
          ),
        ),

        // ═══════════════════════════════════════════════════════
        // ✅ LAYER 2: Lock button (TOP RIGHT) - only this unlocks
        // ═══════════════════════════════════════════════════════
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          right: 16,
          child: GestureDetector(
            onTap: _unlockControls,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: _showUnlockHint ? 16 : 12,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: _showUnlockHint
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _showUnlockHint ? Colors.white : Colors.white38,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showUnlockHint ? Icons.lock_open : Icons.lock,
                    color: Colors.white,
                    size: 20,
                  ),
                  if (_showUnlockHint) ...[
                    const SizedBox(width: 8),
                    const Text(
                      'Tap to unlock',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showHint() {
    // When user taps anywhere except the lock button, show hint
    if (!_showUnlockHint) {
      setState(() {
        _showUnlockHint = true;
      });

      // Auto-hide after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showUnlockHint = false;
          });
        }
      });
    }
  }

  void _unlockControls() {
    try {
      ref.read(videoPlayerProvider.notifier).unlockControls();
    } catch (e) {
      debugPrint('⚠️ Unlock error: $e');
    }
  }
}
