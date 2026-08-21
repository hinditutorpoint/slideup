import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/video_player_state.dart';
import '../providers/video_player_provider.dart';

/// Native Android PiP Widget
/// This widget is shown when the app enters native PiP mode.
///
/// It renders ONLY the video on an opaque black background plus a slim
/// position bar — no buttons. All playback controls (play/pause, previous,
/// next, zoom, close) are provided by the system PiP menu itself and are
/// wired through [PiPService.pipActionStream] → [VideoPlayerScreen].
///
/// The video player screen stops rendering its own surface while native PiP
/// is active (see [VideoPlayerScreen]), so there is exactly ONE [Video]
/// widget attached to the shared media_kit controller at any time.
class NativePiPWidget extends ConsumerWidget {
  const NativePiPWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(videoPlayerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player
          Center(child: _buildVideo(ref)),

          // Slim position indicator (not a button)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildProgressBar(playerState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideo(WidgetRef ref) {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);

      return Video(
        controller: notifier.videoController,
        controls: NoVideoControls,
        fit: BoxFit.contain,
        // Keep playing through the Home -> PiP transition. The default (true)
        // pauses the player as soon as the app enters the background lifecycle,
        // which freezes the PiP frame; a later play() often appears to "not
        // work" on older devices while the app is backgrounded.
        pauseUponEnteringBackgroundMode: false,
      );
    } catch (e) {
      debugPrint('⚠️ Native PiP video build error: $e');
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.red, size: 48),
        ),
      );
    }
  }

  Widget _buildProgressBar(VideoPlayerState playerState) {
    final progress = playerState.progress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withValues(alpha: 0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
          minHeight: 3,
        ),
      ),
    );
  }
}
