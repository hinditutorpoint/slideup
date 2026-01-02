import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mini_player_provider.dart';
import 'mini_audio_player.dart';

class AudioPlayerOverlay extends ConsumerWidget {
  final Widget child;

  const AudioPlayerOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final miniPlayerState = ref.watch(miniPlayerProvider);

    return Stack(
      children: [
        child,
        if (miniPlayerState.isVisible && !miniPlayerState.isExpanded)
          const MiniAudioPlayer(),
      ],
    );
  }
}
