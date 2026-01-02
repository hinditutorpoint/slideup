import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_file.dart';
import '../providers/mini_player_provider.dart';
import 'mini_audio_player.dart';

class UnifiedMediaOverlay extends ConsumerWidget {
  final Widget child;

  const UnifiedMediaOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final miniPlayerState = ref.watch(miniPlayerProvider);
      final showMiniAudio =
          miniPlayerState.isVisible &&
          !miniPlayerState.isExpanded &&
          miniPlayerState.currentMedia != null &&
          miniPlayerState.currentMedia!.type == MediaType.audio;

      return Stack(
        children: [
          child,

          // Mini audio player only
          if (showMiniAudio)
            Positioned(
              bottom: miniPlayerState.position.dy.clamp(0, 300),
              left: miniPlayerState.position.dx.clamp(
                0,
                MediaQuery.of(context).size.width - 340,
              ),
              child: IgnorePointer(ignoring: false, child: MiniAudioPlayer()),
            ),
        ],
      );
    } catch (e) {
      debugPrint('⚠️ Error in UnifiedMediaOverlay: $e');
      return child;
    }
  }
}
