import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/timeline_provider.dart';

// ═══════════════════════════════════════════════════════
// ✅ TRANSITION SHEET (Hybrid Magnetic Timeline)
// ═══════════════════════════════════════════════════════

/// Bottom sheet for selecting the inter-clip transition between two primary
/// clips on the magnetic timeline. Displays all [TransitionType] presets with
/// emoji icons, labels, and a duration slider.
class TransitionSheet extends ConsumerStatefulWidget {
  /// The index in [TimelineState.primaryVideoClips] for the LEFT clip.
  /// The transition is the outgoing transition of clip at [clipIndex].
  final int clipIndex;
  final ClipTransition current;

  const TransitionSheet({
    super.key,
    required this.clipIndex,
    required this.current,
  });

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required int clipIndex,
    required ClipTransition current,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransitionSheet(clipIndex: clipIndex, current: current),
    );
  }

  @override
  ConsumerState<TransitionSheet> createState() => _TransitionSheetState();
}

class _TransitionSheetState extends ConsumerState<TransitionSheet> {
  late TransitionType _selectedType;
  late double _durationMs;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.current.type;
    _durationMs = widget.current.duration.inMilliseconds.toDouble().clamp(
      200,
      2000,
    );
  }

  void _apply() {
    try {
      ref.read(timelineProvider.notifier).setClipTransition(
        widget.clipIndex,
        ClipTransition(
          type: _selectedType,
          duration: Duration(milliseconds: _durationMs.toInt()),
        ),
      );
    } catch (e) {
      debugPrint('❌ TransitionSheet._apply error: $e');
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            '⚡ Clip Transition',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select transition between clips',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Transition grid
          SizedBox(
            height: 220,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: TransitionType.values.length,
              itemBuilder: (_, idx) {
                final t = TransitionType.values[idx];
                final isSelected = t == _selectedType;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          t.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Duration slider (only visible when transition is not "none")
          AnimatedCrossFade(
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Duration',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(_durationMs / 1000).toStringAsFixed(1)}s',
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF6C63FF),
                    inactiveTrackColor: Colors.white12,
                    thumbColor: const Color(0xFF6C63FF),
                    overlayColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _durationMs,
                    min: 200,
                    max: 2000,
                    divisions: 18,
                    onChanged: (v) => setState(() => _durationMs = v),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _selectedType != TransitionType.none
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),

          const SizedBox(height: 8),

          // Apply button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _selectedType == TransitionType.none
                    ? 'Set as Cut (No Transition)'
                    : 'Apply ${_selectedType.label}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
