import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/video_player_state.dart';
import '../providers/video_player_provider.dart';

/// Native Android PiP Widget
/// This widget is shown when the app enters native PiP mode
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

          // PiP Controls Overlay
          _buildPiPControls(context, ref, playerState),
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

  Widget _buildPiPControls(
    BuildContext context,
    WidgetRef ref,
    VideoPlayerState playerState,
  ) {
    // Get screen size to determine available space
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 300; // Compact mode for small PiP

    return SafeArea(
      child: Column(
        children: [
          // Top bar with expand button
          _buildTopBar(context, ref),

          const Spacer(),

          // Center controls (play/pause + navigation)
          _buildCenterControls(ref, playerState, isCompact),

          const SizedBox(height: 12),

          // Progress bar at bottom
          _buildProgressBar(playerState),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Expand/Restore button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleExpand(context, ref),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_full,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(
    WidgetRef ref,
    VideoPlayerState playerState,
    bool isCompact,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button (if available and not compact)
          if (playerState.canPlayPrevious && !isCompact) ...[
            _PiPButton(
              icon: Icons.skip_previous_rounded,
              size: 32,
              onTap: () => _handlePrevious(ref),
            ),
            const SizedBox(width: 24),
          ],

          // Play/Pause button
          _PiPButton(
            icon: playerState.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            size: 48,
            onTap: () => _handlePlayPause(ref),
          ),

          // Next button (if available and not compact)
          if (playerState.canPlayNext && !isCompact) ...[
            const SizedBox(width: 24),
            _PiPButton(
              icon: Icons.skip_next_rounded,
              size: 32,
              onTap: () => _handleNext(ref),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(VideoPlayerState playerState) {
    final progress = playerState.progress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withValues(alpha: 0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
          minHeight: 4,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HANDLERS
  // ═══════════════════════════════════════════════════════

  void _handlePlayPause(WidgetRef ref) {
    try {
      ref.read(videoPlayerProvider.notifier).playOrPause();
    } catch (e) {
      debugPrint('⚠️ PiP play/pause error: $e');
    }
  }

  void _handlePrevious(WidgetRef ref) {
    try {
      ref.read(videoPlayerProvider.notifier).playPrevious();
    } catch (e) {
      debugPrint('⚠️ PiP previous error: $e');
    }
  }

  void _handleNext(WidgetRef ref) {
    try {
      ref.read(videoPlayerProvider.notifier).playNext();
    } catch (e) {
      debugPrint('⚠️ PiP next error: $e');
    }
  }

  void _handleExpand(BuildContext context, WidgetRef ref) {
    try {
      // Exit PiP mode - will restore to full app
      ref.read(videoPlayerProvider.notifier).exitPiPMode();
      // The floating package will handle bringing back the full UI
    } catch (e) {
      debugPrint('⚠️ PiP expand error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ PIP BUTTON WIDGET
// ═══════════════════════════════════════════════════════

class _PiPButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _PiPButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Container(
          padding: EdgeInsets.all(size * 0.25),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}
