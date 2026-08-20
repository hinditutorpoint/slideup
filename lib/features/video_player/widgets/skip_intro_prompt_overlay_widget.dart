import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_player_state.dart';
import '../providers/video_player_provider.dart';

/// In-player "Skip the intro?" prompt.
///
/// Rendered as a translucent centered dialog while the player controls are
/// visible, or as a compact top-left banner (below the status bar) when the
/// controls are hidden. Exactly two actions: Skip | Cancel.
class SkipIntroPromptOverlay extends ConsumerWidget {
  final VideoPlayerState playerState;

  const SkipIntroPromptOverlay({super.key, required this.playerState});

  String _formatPosition(Duration? position) {
    final p = position ?? Duration.zero;
    final h = p.inHours;
    final m = p.inMinutes.remainder(60);
    final s = p.inSeconds.remainder(60);
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:$ss';
    }
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final positionText = _formatPosition(playerState.skipIntroPosition);

    final skipButton = FilledButton.icon(
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: theme.colorScheme.primary,
      ),
      icon: const Icon(Icons.fast_forward_rounded, size: 18),
      label: const Text('Skip'),
      onPressed: () =>
          ref.read(videoPlayerProvider.notifier).skipIntroFromPrompt(),
    );
    final cancelButton = TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
      child: const Text('Cancel'),
      onPressed: () =>
          ref.read(videoPlayerProvider.notifier).cancelSkipIntroPrompt(),
    );

    if (playerState.showControls) {
      // Centered translucent dialog.
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fast_forward_rounded, color: Colors.white70, size: 28),
              const SizedBox(height: 8),
              Text(
                'Skip the intro?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Jump past the intro to $positionText',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [cancelButton, const SizedBox(width: 8), skipButton],
              ),
            ],
          ),
        ),
      );
    }

    // Top-left banner (controls hidden), below the status bar.
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          margin: const EdgeInsets.only(left: 12, top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fast_forward_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Skip the intro to $positionText?',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 8),
              skipButton,
              const SizedBox(width: 4),
              cancelButton,
            ],
          ),
        ),
      ),
    );
  }
}