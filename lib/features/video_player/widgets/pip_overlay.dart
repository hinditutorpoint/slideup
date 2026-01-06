import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pip_provider.dart';
import '../providers/video_player_provider.dart';
import '../video_player_screen.dart';
import 'pip_widget.dart';
import '../../../navigation_service.dart';

class PiPOverlay extends ConsumerWidget {
  final Widget child;

  const PiPOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipState = ref.watch(pipProvider);

    return Stack(
      children: [
        child,
        if (pipState.isCustomActive)
          PiPWidget(
            onClose: () {
              ref.read(videoPlayerProvider.notifier).stop();
              ref.read(pipProvider.notifier).disablePiP();
            },
            onExpand: () {
              ref.read(pipProvider.notifier).disablePiP();

              // Navigate to full video player
              final currentPlaylist = ref
                  .read(videoPlayerProvider.notifier)
                  .currentPlaylist;
              if (currentPlaylist != null) {
                rootNavigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(
                      playlist: currentPlaylist,
                      autoPlay: true,
                    ),
                  ),
                );
              }
            },
          ),
      ],
    );
  }
}
