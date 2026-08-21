import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import '../../../core/utils/download_location_helper.dart';

import '../models/video_player_state.dart';
import '../models/player_media.dart';
import '../providers/video_player_provider.dart';
import '../providers/pip_provider.dart';
import '../providers/chromecast_provider.dart';
import '../services/chromecast_service.dart';
import 'settings_sheet_widget.dart';
import 'playlist_sheet_widget.dart';
import 'chromecast_dialog_widget.dart';

class ControlsOverlayWidget extends ConsumerStatefulWidget {
  final PlayerPlaylist playlist;
  final VoidCallback? onBack;
  final VoidCallback? onDispose;
  final bool showPiPButton;

  const ControlsOverlayWidget({
    super.key,
    required this.playlist,
    this.onBack,
    this.onDispose,
    this.showPiPButton = true,
  });

  @override
  ConsumerState<ControlsOverlayWidget> createState() =>
      _ControlsOverlayWidgetState();
}

class _ControlsOverlayWidgetState extends ConsumerState<ControlsOverlayWidget> {
  final _SceneCaptureController _capture = _SceneCaptureController();

  @override
  void dispose() {
    _capture.dispose();
    try {
      widget.onDispose?.call();
    } catch (e) {
      debugPrint('⚠️ onDispose callback error: $e');
    }
    super.dispose();
  }

  void _keepControlsVisible() {
    try {
      ref.read(videoPlayerProvider.notifier).showControls();
    } catch (e) {
      debugPrint('⚠️ Keep controls visible error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final playerState = ref.watch(videoPlayerProvider);
      final title = playerState.currentTitle.isNotEmpty
          ? playerState.currentTitle
          : widget.playlist.currentMedia?.title ?? 'Loading...';
      final currentTitle = title;

      return Stack(
        fit: StackFit.expand,
        children: [
          // Scene capture indicator — stays visible even when controls hide
          _SceneCaptureOverlay(
            playerState: playerState,
            capture: _capture,
          ),
          AnimatedOpacity(
            opacity: playerState.showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !playerState.showControls,
              child: Stack(
            fit: StackFit.expand,
            children: [
              // Non-interactive gradient background so gestures (double-tap
              // seek, drags) pass through to the gesture detector below.
              Positioned.fill(
                child: IgnorePointer(
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black54,
                        ],
                        stops: [0.0, 0.2, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      title: currentTitle,
                      playlist: widget.playlist,
                      onBack: widget.onBack,
                      showPiPButton: widget.showPiPButton,
                      onInteraction: _keepControlsVisible,
                    ),
                    const Spacer(),
                    _CenterPlayButton(
                      playerState: playerState,
                      hasPlaylist: widget.playlist.hasMultiple,
                      onInteraction: _keepControlsVisible,
                    ),
                    const Spacer(),
                    _BottomBar(
                      playlist: widget.playlist,
                      playerState: playerState,
                      onInteraction: _keepControlsVisible,
                      capture: _capture,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
        ],
      );
    } catch (e) {
      debugPrint('❌ ControlsOverlayWidget build error: $e');
      return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ TOP BAR
// ═══════════════════════════════════════════════════════

class _TopBar extends ConsumerWidget {
  final String title;
  final PlayerPlaylist playlist;
  final VoidCallback? onBack;
  final bool showPiPButton;
  final VoidCallback onInteraction;

  const _TopBar({
    required this.title,
    required this.playlist,
    this.onBack,
    this.showPiPButton = true,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final playerState = ref.watch(videoPlayerProvider);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            _ControlButton(
              icon: Icons.arrow_back,
              size: 24,
              onTap: () {
                onInteraction();
                _handleBack(ref, playerState);
              },
            ),
            Expanded(
              child: GestureDetector(
                onTap: onInteraction,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (playlist.hasMultiple)
                        Text(
                          '${playerState.currentIndex + 1} of ${playlist.length}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (showPiPButton)
              _ControlButton(
                icon: Icons.picture_in_picture_alt,
                size: 24,
                onTap: () {
                  onInteraction();
                  _enterPiP(ref);
                },
              ),
            _ControlButton(
              icon: Icons.lock_outline,
              size: 24,
              onTap: () {
                onInteraction();
                _lockControls(ref);
              },
            ),
            _ControlButton(
              icon: Icons.settings,
              size: 24,
              onTap: () {
                onInteraction();
                _showSettings(context);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ _TopBar build error: $e');
      return const SizedBox.shrink();
    }
  }

  void _handleBack(WidgetRef ref, VideoPlayerState playerState) {
    try {
      if (playerState.mode == PlayerMode.fullscreen) {
        ref.read(videoPlayerProvider.notifier).exitFullscreen();
      } else {
        onBack?.call();
      }
    } catch (e) {
      debugPrint('⚠️ Back button error: $e');
    }
  }

  Future<void> _enterPiP(WidgetRef ref) async {
    try {
      final pipNotifier = ref.read(pipProvider.notifier);
      pipNotifier.enableCustomPiP();
      ref.read(videoPlayerProvider.notifier).enterPiPMode();
    } catch (e) {
      debugPrint('⚠️ Enter PiP error: $e');
    }
  }

  void _lockControls(WidgetRef ref) {
    try {
      ref.read(videoPlayerProvider.notifier).lockControls();
    } catch (e) {
      debugPrint('⚠️ Lock button error: $e');
    }
  }

  void _showSettings(BuildContext context) {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => const SettingsSheetWidget(),
      );
    } catch (e) {
      debugPrint('⚠️ Show settings error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ CENTER PLAY BUTTON
// ═══════════════════════════════════════════════════════

class _CenterPlayButton extends ConsumerWidget {
  final VideoPlayerState playerState;
  final bool hasPlaylist;
  final VoidCallback onInteraction;

  const _CenterPlayButton({
    required this.playerState,
    required this.hasPlaylist,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final isCompleted = playerState.isCompleted;
      final showReplayButton = isCompleted && !hasPlaylist;

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPlaylist) ...[
            _CenterControlButton(
              icon: Icons.skip_previous,
              size: 36,
              onTap: () {
                onInteraction();
                _playPrevious(ref);
              },
            ),
            const SizedBox(width: 40),
          ],
          _PlayPauseButton(
            icon: _getMainIcon(isCompleted),
            showLoading: !isCompleted &&
                (playerState.isBuffering || playerState.isLoading),
            onTap: () {
              onInteraction();
              _handleMainButton(ref, isCompleted);
            },
          ),
          if (showReplayButton) ...[
            const SizedBox(width: 24),
            _CenterControlButton(
              icon: Icons.replay,
              size: 32,
              onTap: () {
                onInteraction();
                _replay(ref);
              },
            ),
          ],
          if (hasPlaylist) ...[
            const SizedBox(width: 40),
            _CenterControlButton(
              icon: Icons.skip_next,
              size: 36,
              onTap: () {
                onInteraction();
                _playNext(ref);
              },
            ),
          ],
        ],
      );
    } catch (e) {
      debugPrint('❌ _CenterPlayButton build error: $e');
      return const SizedBox.shrink();
    }
  }

  IconData _getMainIcon(bool isCompleted) {
    try {
      if (isCompleted && hasPlaylist) return Icons.replay;
      if (playerState.isPlaying) return Icons.pause_rounded;
      return Icons.play_arrow_rounded;
    } catch (e) {
      return Icons.play_arrow_rounded;
    }
  }

  void _handleMainButton(WidgetRef ref, bool isCompleted) {
    try {
      if (isCompleted) {
        _replay(ref);
      } else {
        ref.read(videoPlayerProvider.notifier).playOrPause();
      }
    } catch (e) {
      debugPrint('⚠️ Main button error: $e');
    }
  }

  void _replay(WidgetRef ref) {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      notifier.seek(Duration.zero);
      notifier.play();
    } catch (e) {
      debugPrint('⚠️ Replay error: $e');
    }
  }

  void _playPrevious(WidgetRef ref) {
    try {
      ref.read(videoPlayerProvider.notifier).playPrevious();
    } catch (e) {
      debugPrint('⚠️ Play previous error: $e');
    }
  }

  void _playNext(WidgetRef ref) {
    try {
      ref.read(videoPlayerProvider.notifier).playNext();
    } catch (e) {
      debugPrint('⚠️ Play next error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ PLAY/PAUSE BUTTON (Large center button)
// ═══════════════════════════════════════════════════════

class _PlayPauseButton extends StatelessWidget {
  final IconData icon;
  final bool showLoading;
  final VoidCallback onTap;

  const _PlayPauseButton({
    required this.icon,
    this.showLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.3),
          ),
          child: showLoading
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                )
              : Icon(icon, color: Colors.white, size: 48),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ CENTER CONTROL BUTTON (Skip buttons)
// ═══════════════════════════════════════════════════════

class _CenterControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _CenterControlButton({
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
        borderRadius: BorderRadius.circular(24),
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ BOTTOM BAR - FIXED OVERFLOW + PROFESSIONAL DESIGN
// ═══════════════════════════════════════════════════════

class _BottomBar extends ConsumerWidget {
  final PlayerPlaylist playlist;
  final VideoPlayerState playerState;
  final VoidCallback onInteraction;
  final _SceneCaptureController capture;

  const _BottomBar({
    required this.playlist,
    required this.playerState,
    required this.onInteraction,
    required this.capture,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar with time labels on left/right
            Row(
              children: [
                // Current position (left)
                Text(
                  _formatDuration(playerState.position),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                // Slider
                Expanded(
                  child: _ProgressBar(
                    playerState: playerState,
                    ref: ref,
                    onInteraction: onInteraction,
                  ),
                ),
                const SizedBox(width: 8),
                // Duration (right)
                Text(
                  _formatDuration(playerState.duration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Controls row
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  // Scrollable controls
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Screenshot
                                _ScreenshotButton(
                                  onInteraction: onInteraction,
                                ),

                                // Scene Capture (arm → cut → cancel)
                                _SceneCaptureButton(
                                  capture: capture,
                                  onInteraction: onInteraction,
                                ),

                                // Loop
                                _LoopButton(
                                  onInteraction: onInteraction,
                                ),

                                // Speed
                                _SpeedButton(
                                  speed: playerState.speed,
                                  onInteraction: onInteraction,
                                ),

                                // Video Fit
                                _VideoFitButton(
                                  videoFit: playerState.videoFit,
                                  onInteraction: onInteraction,
                                ),

                                // Flip
                                _FlipButton(
                                  isFlippedH: playerState.isFlippedHorizontally,
                                  isFlippedV: playerState.isFlippedVertically,
                                  onInteraction: onInteraction,
                                ),

                                // Mute
                                _MuteButton(
                                  isMuted: playerState.isMuted,
                                  volume: playerState.volume,
                                  onInteraction: onInteraction,
                                ),

                                _ChromecastButton(onInteraction: onInteraction),

                                // Playlist
                                if (playlist.hasMultiple)
                                  _ControlButton(
                                    icon: Icons.playlist_play,
                                    size: 24,
                                    onTap: () {
                                      onInteraction();
                                      _showPlaylist(context);
                                    },
                                  ),

                                // Fullscreen
                                _ControlButton(
                                  icon:
                                      playerState.mode == PlayerMode.fullscreen
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                  size: 24,
                                  onTap: () {
                                    onInteraction();
                                    _toggleFullscreen(ref);
                                  },
                                ),

                                // Track chips
                                _TrackChips(
                                  playerState: playerState,
                                  onInteraction: onInteraction,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ _BottomBar build error: $e');
      return const SizedBox.shrink();
    }
  }

  void _toggleFullscreen(WidgetRef ref) {
    try {
      ref.read(videoPlayerProvider.notifier).toggleFullscreen();
    } catch (e) {
      debugPrint('⚠️ Fullscreen toggle error: $e');
    }
  }

  void _showPlaylist(BuildContext context) {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => PlaylistSheetWidget(playlist: playlist),
      );
    } catch (e) {
      debugPrint('⚠️ Show playlist error: $e');
    }
  }

  String _formatDuration(Duration d) {
    try {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      final s = d.inSeconds.remainder(60);
      if (h > 0) {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ LOOP BUTTON - Toggle Playlist Loop
// ═══════════════════════════════════════════════════════

class _LoopButton extends ConsumerWidget {
  final VoidCallback onInteraction;

  const _LoopButton({required this.onInteraction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return const SizedBox.shrink();

      final isLooping = notifier.settings.loopPlaylist;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onInteraction();
            notifier.toggleLoopPlaylist();
          },
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.repeat,
              color: isLooping ? Colors.white : Colors.white38,
              size: 24,
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ SCREENSHOT BUTTON - Capture & Save to Download Path
// ═══════════════════════════════════════════════════════

class _ScreenshotButton extends ConsumerWidget {
  final VoidCallback onInteraction;

  const _ScreenshotButton({required this.onInteraction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onInteraction();
            _captureScreenshot(context, ref);
          },
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.camera_alt, color: Colors.white, size: 24),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Future<void> _captureScreenshot(BuildContext context, WidgetRef ref) async {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      final Uint8List? imageBytes = await notifier.takeScreenshot();
      if (imageBytes == null || imageBytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to capture screenshot'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final downloadDir = await DownloadLocationHelper.configuredDirectory();
      if (downloadDir == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No download path set. Please set one in Settings.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final screenshotsDir = Directory('${downloadDir.path}/screenshots');
      if (!await screenshotsDir.exists()) {
        await screenshotsDir.create(recursive: true);
      }

      final now = DateTime.now();
      final fileName = 'slideup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.png';
      final file = File('${screenshotsDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Screenshot saved to ${file.path}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Screenshot error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ SCENE CAPTURE — arm → cut → cancel (icon-only, tiny)
// ═══════════════════════════════════════════════════════

enum _CapturePhase { off, armed, cutting, done }

/// Shared state between the controls-row toggle and the frame overlay.
class _SceneCaptureController extends ChangeNotifier {
  _CapturePhase phase = _CapturePhase.off;
  double progress = 0;

  VoidCallback? onToggleRequested;

  void requestToggle() => onToggleRequested?.call();

  void setPhase(_CapturePhase value) {
    phase = value;
    if (value != _CapturePhase.cutting) progress = 0;
    notifyListeners();
  }

  void setProgress(double value) {
    final v = value.clamp(0.0, 1.0);
    if ((v - progress).abs() < 0.005) return;
    progress = v;
    notifyListeners();
  }
}

/// Icon-only toggle living in the controls row.
/// Disabled while a capture process is running; re-enabled when done.
class _SceneCaptureButton extends StatelessWidget {
  final _SceneCaptureController capture;
  final VoidCallback onInteraction;

  const _SceneCaptureButton({
    required this.capture,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: capture,
      builder: (context, _) {
        final phase = capture.phase;
        final busy = phase != _CapturePhase.off;
        final cutting = phase == _CapturePhase.cutting;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            highlightColor: Colors.white10,
            onTap: busy
                ? null
                : () {
                    onInteraction();
                    capture.requestToggle();
                  },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: cutting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.redAccent),
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            phase == _CapturePhase.armed
                                ? Icons.fiber_manual_record
                                : Icons.content_cut,
                            key: ValueKey(phase),
                            color: phase == _CapturePhase.armed
                                ? Colors.redAccent
                                : Colors.white,
                            size: 24,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Always-visible pill at the top-right of the video frame.
/// Lives outside the fading controls so state is never hidden.
class _SceneCaptureOverlay extends StatefulWidget {
  final VideoPlayerState playerState;
  final _SceneCaptureController capture;

  const _SceneCaptureOverlay({
    required this.playerState,
    required this.capture,
  });

  @override
  State<_SceneCaptureOverlay> createState() => _SceneCaptureOverlayState();
}

class _SceneCaptureOverlayState extends State<_SceneCaptureOverlay>
    with SingleTickerProviderStateMixin {
  static const _doneFlash = Duration(milliseconds: 900);

  AnimationController? _pulse;
  Duration _startPos = Duration.zero;
  String? _armedUrl;
  FFmpegSession? _session;
  bool _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
    widget.capture.onToggleRequested = _handleToggle;
  }

  @override
  void didUpdateWidget(covariant _SceneCaptureOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playerState.currentUrl != oldWidget.playerState.currentUrl &&
        widget.capture.phase != _CapturePhase.off) {
      _reset(cancelCut: true);
    }
  }

  @override
  void dispose() {
    widget.capture.onToggleRequested = null;
    _pulse?.dispose();
    final s = _session;
    if (s != null) {
      try {
        FFmpegKit.cancel(s.getSessionId());
      } catch (_) {}
    }
    super.dispose();
  }

  void _handleToggle() {
    final phase = widget.capture.phase;
    if (phase == _CapturePhase.off) {
      _arm();
    } else if (phase == _CapturePhase.armed) {
      _beginCut();
    }
  }

  void _arm() {
    _armedUrl = widget.playerState.currentUrl;
    _startPos = widget.playerState.position;
    HapticFeedback.selectionClick();
    widget.capture.setPhase(_CapturePhase.armed);
  }

  Future<void> _beginCut() async {
    final url = _armedUrl ?? widget.playerState.currentUrl;
    final endPos = widget.playerState.position;
    HapticFeedback.mediumImpact();

    if (endPos - _startPos < const Duration(milliseconds: 300)) {
      widget.capture.setPhase(_CapturePhase.off);
      _showSnack('Clip too short');
      return;
    }

    final downloadDir = await DownloadLocationHelper.configuredDirectory();
    if (downloadDir == null) {
      widget.capture.setPhase(_CapturePhase.off);
      _showSnack('No download path set');
      return;
    }

    final clipsDir = Directory('${downloadDir.path}/clips');
    if (!await clipsDir.exists()) {
      await clipsDir.create(recursive: true);
    }

    final now = DateTime.now();
    final ts =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final outputPath = '${clipsDir.path}/clip_$ts.mp4';

    final startStr = _fmtDur(_startPos);
    final dur = endPos - _startPos;
    final durStr = _fmtDur(dur);

    final bool isLocal = !url.startsWith('http');
    final String command = isLocal
        ? '-y -ss $startStr -i "$url" -t $durStr -c copy -avoid_negative_ts make_zero "$outputPath"'
        : '-y -ss $startStr -i "$url" -t $durStr -c:v libx264 -c:a aac -movflags +faststart "$outputPath"';

    _cancelRequested = false;
    widget.capture.setPhase(_CapturePhase.cutting);

    try {
      final session = await FFmpegKit.executeAsync(
        command,
        (s) => _onComplete(s, outputPath),
        null,
        (Statistics stats) {
          final t = stats.getTime();
          if (t > 0) widget.capture.setProgress(t / dur.inMilliseconds);
        },
      );
      _session = session;
    } catch (e) {
      debugPrint('❌ Scene capture error: $e');
      widget.capture.setPhase(_CapturePhase.off);
      _showSnack('Capture error');
    }
  }

  Future<void> _onComplete(FFmpegSession session, String outputPath) async {
    _session = null;
    if (!mounted) return;

    final rc = await session.getReturnCode();
    final success = rc != null && rc.isValueSuccess();

    if (!success) {
      try {
        final f = File(outputPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    if (_cancelRequested || !success) {
      if (!_cancelRequested) _showSnack('Failed to capture clip');
      widget.capture.setPhase(_CapturePhase.off);
      return;
    }

    widget.capture.setProgress(1);
    widget.capture.setPhase(_CapturePhase.done);
    _showSnack('Clip saved');
    await Future.delayed(_doneFlash);
    if (mounted && widget.capture.phase == _CapturePhase.done) {
      widget.capture.setPhase(_CapturePhase.off);
    }
  }

  Future<void> _cancel() async {
    if (widget.capture.phase != _CapturePhase.cutting) return;
    _cancelRequested = true;
    HapticFeedback.selectionClick();
    try {
      final s = _session;
      if (s != null) await FFmpegKit.cancel(s.getSessionId());
    } catch (_) {}
  }

  void _reset({required bool cancelCut}) {
    if (cancelCut && widget.capture.phase == _CapturePhase.cutting) {
      _cancelRequested = true;
      final s = _session;
      if (s != null) {
        try {
          FFmpegKit.cancel(s.getSessionId());
        } catch (_) {}
      }
    }
    _armedUrl = null;
    widget.capture.setPhase(_CapturePhase.off);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final ms = d.inMilliseconds.remainder(1000);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        // Sits below the top bar while controls are visible, then glides up
        // to the video frame's top-right corner when controls hide.
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(
            top: widget.playerState.showControls ? 58 : 8,
            right: 10,
          ),
          child: ListenableBuilder(
            listenable: widget.capture,
            builder: (context, _) {
              final phase = widget.capture.phase;
              final visible = phase != _CapturePhase.off;
              return IgnorePointer(
                ignoring: !visible,
                child: AnimatedScale(
                  scale: visible ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: visible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child:
                                  ScaleTransition(scale: anim, child: child),
                            ),
                            child: _buildCluster(phase),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCluster(_CapturePhase phase) {
    switch (phase) {
      case _CapturePhase.armed:
        return Row(
          key: const ValueKey('armed'),
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing red recording dot
            ListenableBuilder(
              listenable: _pulse!,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_pulse!.value);
                return Container(
                  width: 9.0 + 3.0 * t,
                  height: 9.0 + 3.0 * t,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.55 + 0.45 * t),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.4 * t),
                        blurRadius: 6 + 4 * t,
                        spreadRadius: t,
                      ),
                    ],
                  ),
                );
              },
            ),
            _tinyButton(Icons.stop, Colors.white, _beginCut),
          ],
        );
      case _CapturePhase.cutting:
        return Row(
          key: const ValueKey('cutting'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(5),
              child: ListenableBuilder(
                listenable: widget.capture,
                builder: (context, _) => SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: widget.capture.progress > 0
                        ? widget.capture.progress
                        : null,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.redAccent),
                  ),
                ),
              ),
            ),
            _tinyButton(Icons.close, Colors.white70, _cancel),
          ],
        );
      case _CapturePhase.done:
        return const Padding(
          key: ValueKey('done'),
          padding: EdgeInsets.all(5),
          child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
        );
      case _CapturePhase.off:
        return const SizedBox(key: ValueKey('off'), width: 0, height: 0);
    }
  }

  Widget _tinyButton(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 15),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ CONTROL BUTTON - Professional with Ripple
// ═══════════════════════════════════════════════════════

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: size),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ SPEED BUTTON - Professional Design
// ═══════════════════════════════════════════════════════

class _SpeedButton extends ConsumerWidget {
  final double speed;
  final VoidCallback onInteraction;

  const _SpeedButton({required this.speed, required this.onInteraction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final isNormal = (speed - 1.0).abs() < 0.01;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onInteraction();
            _showSpeedDialog(context, ref);
          },
          borderRadius: BorderRadius.circular(4),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Text(
              '${speed}x',
              style: TextStyle(
                color: isNormal ? Colors.white : Colors.amber,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  void _showSpeedDialog(BuildContext context, WidgetRef ref) {
    try {
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => _SpeedDialog(
          currentSpeed: speed,
          onSpeedSelected: (s) {
            Navigator.of(ctx).pop();
            try {
              ref.read(videoPlayerProvider.notifier).setSpeed(s);
            } catch (e) {
              debugPrint('⚠️ Set speed error: $e');
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Show speed dialog error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ VIDEO FIT BUTTON - Professional Design
// ═══════════════════════════════════════════════════════

class _VideoFitButton extends ConsumerWidget {
  final VideoFit videoFit;
  final VoidCallback onInteraction;

  const _VideoFitButton({required this.videoFit, required this.onInteraction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final icon = _getFitIcon();
      final isDefault = videoFit == VideoFit.contain;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onInteraction();
            ref.read(videoPlayerProvider.notifier).cycleVideoFit();
          },
          onLongPress: () {
            onInteraction();
            _showFitDialog(context, ref);
          },
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: isDefault ? Colors.white : Colors.lightBlueAccent,
              size: 24,
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  IconData _getFitIcon() {
    switch (videoFit) {
      case VideoFit.contain:
        return Icons.fit_screen_outlined;
      case VideoFit.cover:
        return Icons.crop_free;
      case VideoFit.fill:
        return Icons.aspect_ratio;
      case VideoFit.fitWidth:
        return Icons.width_full;
      case VideoFit.fitHeight:
        return Icons.height;
    }
  }

  void _showFitDialog(BuildContext context, WidgetRef ref) {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);

      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => _FitDialog(
          currentFit: videoFit,
          onFitSelected: (fit) {
            Navigator.of(ctx).pop();
            try {
              notifier.setVideoFit(fit);
            } catch (e) {
              debugPrint('⚠️ Set fit error: $e');
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Show fit dialog error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ FLIP BUTTON - Professional Design
// ═══════════════════════════════════════════════════════

class _FlipButton extends ConsumerWidget {
  final bool isFlippedH;
  final bool isFlippedV;
  final VoidCallback onInteraction;

  const _FlipButton({
    required this.isFlippedH,
    required this.isFlippedV,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final hasFlip = isFlippedH || isFlippedV;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onInteraction();
            _showFlipDialog(context, ref);
          },
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.flip_outlined,
              color: hasFlip ? Colors.orangeAccent : Colors.white,
              size: 24,
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  void _showFlipDialog(BuildContext context, WidgetRef ref) {
    try {
      final hasFlip = isFlippedH || isFlippedV;
      final notifier = ref.read(videoPlayerProvider.notifier);

      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => _FlipDialog(
          isFlippedH: isFlippedH,
          isFlippedV: isFlippedV,
          hasFlip: hasFlip,
          onFlipHorizontal: () {
            try {
              notifier.toggleFlipHorizontal();
            } catch (e) {
              debugPrint('⚠️ Flip horizontal error: $e');
            }
          },
          onFlipVertical: () {
            try {
              notifier.toggleFlipVertical();
            } catch (e) {
              debugPrint('⚠️ Flip vertical error: $e');
            }
          },
          onReset: () {
            try {
              notifier.resetFlip();
              Navigator.of(ctx).pop();
            } catch (e) {
              debugPrint('⚠️ Reset flip error: $e');
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Show flip dialog error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ MUTE BUTTON - Professional Design
// ═══════════════════════════════════════════════════════

class _MuteButton extends ConsumerWidget {
  final bool isMuted;
  final double volume;
  final VoidCallback onInteraction;

  const _MuteButton({
    required this.isMuted,
    required this.volume,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final icon = _getMuteIcon();

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onInteraction();
            ref.read(videoPlayerProvider.notifier).toggleMute();
          },
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: isMuted ? Colors.redAccent : Colors.white,
              size: 24,
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  IconData _getMuteIcon() {
    if (isMuted || volume == 0) {
      return Icons.volume_off_outlined;
    } else if (volume < 0.5) {
      return Icons.volume_down_outlined;
    } else {
      return Icons.volume_up_outlined;
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ TRACK CHIPS - Professional Design
// ═══════════════════════════════════════════════════════

class _TrackChips extends ConsumerWidget {
  final VideoPlayerState playerState;
  final VoidCallback onInteraction;

  const _TrackChips({required this.playerState, required this.onInteraction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final audioTracks = playerState.audioTracks
          .where((t) => t.id != 'auto' && t.id != 'no')
          .toList();
      final subtitleTracks = playerState.subtitleTracks
          .where((t) => t.id != 'auto' && t.id != 'no')
          .toList();
      final videoTracks = playerState.videoTracks
          .where((t) => t.id != 'auto' && t.id != 'no')
          .toList();

      final hasAudio = audioTracks.length > 1;
      final hasSubtitle = subtitleTracks.isNotEmpty;
      final hasVideo = videoTracks.length > 1;

      if (!hasAudio && !hasSubtitle && !hasVideo) {
        return const SizedBox.shrink();
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasAudio)
            _TrackChip(
              icon: Icons.audiotrack_outlined,
              label: _getAudioLabel(),
              onTap: () {
                onInteraction();
                _showAudioDialog(context, ref, audioTracks);
              },
            ),
          if (hasSubtitle)
            _TrackChip(
              icon: Icons.subtitles_outlined,
              label: _getSubtitleLabel(),
              isActive: _hasActiveSubtitle(),
              onTap: () {
                onInteraction();
                _showSubtitleDialog(context, ref, subtitleTracks);
              },
            ),
          if (hasVideo)
            _TrackChip(
              icon: Icons.hd_outlined,
              label: _getVideoLabel(),
              onTap: () {
                onInteraction();
                _showVideoDialog(context, ref, videoTracks);
              },
            ),
        ],
      );
    } catch (e) {
      debugPrint('❌ _TrackChips build error: $e');
      return const SizedBox.shrink();
    }
  }

  String _getAudioLabel() {
    try {
      final t = playerState.currentAudioTrack;
      if (t == null) return 'Audio';
      if (t.title != null && t.title!.isNotEmpty) {
        return t.title!.length > 5 ? '${t.title!.substring(0, 5)}…' : t.title!;
      }
      if (t.language != null) return t.language!.toUpperCase();
      return 'Audio';
    } catch (e) {
      return 'Audio';
    }
  }

  String _getSubtitleLabel() {
    try {
      final t = playerState.currentSubtitleTrack;
      if (t == null || t.id == 'no') return 'CC';
      if (t.title != null && t.title!.isNotEmpty) {
        return t.title!.length > 5 ? '${t.title!.substring(0, 5)}…' : t.title!;
      }
      if (t.language != null) return t.language!.toUpperCase();
      return 'CC';
    } catch (e) {
      return 'CC';
    }
  }

  String _getVideoLabel() {
    try {
      final t = playerState.currentVideoTrack;
      if (t == null) return 'Auto';
      if (t.h != null) {
        if (t.h! >= 2160) return '4K';
        if (t.h! >= 1080) return 'FHD';
        if (t.h! >= 720) return 'HD';
        if (t.h! >= 480) return 'SD';
        return '${t.h}p';
      }
      return 'Auto';
    } catch (e) {
      return 'Auto';
    }
  }

  bool _hasActiveSubtitle() {
    try {
      final t = playerState.currentSubtitleTrack;
      return t != null && t.id != 'no';
    } catch (e) {
      return false;
    }
  }

  void _showAudioDialog(
    BuildContext context,
    WidgetRef ref,
    List<AudioTrack> tracks,
  ) {
    try {
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => _TrackDialog(
          title: 'Audio Track',
          children: tracks.map((t) {
            final selected = playerState.currentAudioTrack?.id == t.id;
            return _TrackTile(
              title: t.title ?? t.language ?? 'Track ${t.id}',
              subtitle: t.language,
              selected: selected,
              onTap: () {
                Navigator.of(ctx).pop();
                _setAudioTrack(ref, t);
              },
            );
          }).toList(),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Show audio dialog error: $e');
    }
  }

  void _showSubtitleDialog(
    BuildContext context,
    WidgetRef ref,
    List<SubtitleTrack> tracks,
  ) {
    try {
      final currentId = playerState.currentSubtitleTrack?.id;
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => _TrackDialog(
          title: 'Subtitles',
          children: [
            _TrackTile(
              title: 'Off',
              selected: currentId == null || currentId == 'no',
              onTap: () {
                Navigator.of(ctx).pop();
                _disableSubtitles(ref);
              },
            ),
            ...tracks.map(
              (t) => _TrackTile(
                title: t.title ?? t.language ?? 'Track ${t.id}',
                subtitle: t.language,
                selected: currentId == t.id,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setSubtitleTrack(ref, t);
                },
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Show subtitle dialog error: $e');
    }
  }

  void _showVideoDialog(
    BuildContext context,
    WidgetRef ref,
    List<VideoTrack> tracks,
  ) {
    try {
      final sorted = List<VideoTrack>.from(tracks)
        ..sort((a, b) => (b.h ?? 0).compareTo(a.h ?? 0));
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => _TrackDialog(
          title: 'Video Quality',
          children: sorted.map((t) {
            final selected = playerState.currentVideoTrack?.id == t.id;
            String title = 'Track ${t.id}';
            if (t.h != null) {
              if (t.h! >= 2160) {
                title = '4K Ultra HD';
              } else if (t.h! >= 1080) {
                title = '1080p Full HD';
              } else if (t.h! >= 720) {
                title = '720p HD';
              } else if (t.h! >= 480) {
                title = '480p SD';
              } else {
                title = '${t.h}p';
              }
            }
            return _TrackTile(
              title: title,
              subtitle: t.w != null && t.h != null ? '${t.w}×${t.h}' : null,
              selected: selected,
              onTap: () {
                Navigator.of(ctx).pop();
                _setVideoTrack(ref, t);
              },
            );
          }).toList(),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Show video dialog error: $e');
    }
  }

  Future<void> _setAudioTrack(WidgetRef ref, AudioTrack track) async {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      final wasPlaying = playerState.isPlaying;
      final pos = playerState.position;
      await notifier.setAudioTrack(track);
      await Future.delayed(const Duration(milliseconds: 50));
      await notifier.seek(pos);
      if (wasPlaying) await notifier.play();
    } catch (e) {
      debugPrint('⚠️ Set audio track error: $e');
    }
  }

  Future<void> _setSubtitleTrack(WidgetRef ref, SubtitleTrack track) async {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      final wasPlaying = playerState.isPlaying;
      final pos = playerState.position;
      await notifier.setSubtitleTrack(track);
      await Future.delayed(const Duration(milliseconds: 50));
      await notifier.seek(pos);
      if (wasPlaying) await notifier.play();
    } catch (e) {
      debugPrint('⚠️ Set subtitle track error: $e');
    }
  }

  Future<void> _disableSubtitles(WidgetRef ref) async {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      final wasPlaying = playerState.isPlaying;
      final pos = playerState.position;
      await notifier.disableSubtitles();
      await Future.delayed(const Duration(milliseconds: 50));
      await notifier.seek(pos);
      if (wasPlaying) await notifier.play();
    } catch (e) {
      debugPrint('⚠️ Disable subtitles error: $e');
    }
  }

  Future<void> _setVideoTrack(WidgetRef ref, VideoTrack track) async {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      final wasPlaying = playerState.isPlaying;
      final pos = playerState.position;
      await notifier.setVideoTrack(track);
      await Future.delayed(const Duration(milliseconds: 50));
      await notifier.seek(pos);
      if (wasPlaying) await notifier.play();
    } catch (e) {
      debugPrint('⚠️ Set video track error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ TRACK CHIP - Professional Design
// ═══════════════════════════════════════════════════════

class _TrackChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TrackChip({
    required this.icon,
    required this.label,
    this.isActive = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ PROGRESS BAR - Professional Design
// ═══════════════════════════════════════════════════════

class _ProgressBar extends StatefulWidget {
  final VideoPlayerState playerState;
  final WidgetRef ref;
  final VoidCallback onInteraction;

  const _ProgressBar({
    required this.playerState,
    required this.ref,
    required this.onInteraction,
  });

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  bool _dragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    try {
      final pos = widget.playerState.position;
      final dur = widget.playerState.duration;
      final buf = widget.playerState.bufferedPosition;

      final max = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
      final current = _dragging
          ? _dragValue
          : pos.inMilliseconds.toDouble().clamp(0.0, max);
      final buffered = buf.inMilliseconds.toDouble().clamp(0.0, max);

      return SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: _dragging ? 8 : 6,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: Colors.red,
          inactiveTrackColor: Colors.white24,
          thumbColor: Colors.red,
          overlayColor: Colors.red.withValues(alpha: 0.2),
        ),
        child: Stack(
          children: [
            // Buffered progress
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: SliderComponentShape.noThumb,
                activeTrackColor: Colors.white38,
                inactiveTrackColor: Colors.transparent,
              ),
              child: Slider(value: buffered, max: max, onChanged: null),
            ),
            // Main slider
            Slider(
              value: current,
              max: max,
              onChangeStart: (v) {
                widget.onInteraction();
                setState(() {
                  _dragging = true;
                  _dragValue = v;
                });
              },
              onChanged: (v) {
                widget.onInteraction();
                setState(() => _dragValue = v);
              },
              onChangeEnd: (v) {
                try {
                  widget.ref
                      .read(videoPlayerProvider.notifier)
                      .seek(Duration(milliseconds: v.toInt()));
                } catch (e) {
                  debugPrint('⚠️ Seek error: $e');
                }
                setState(() => _dragging = false);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ _ProgressBar build error: $e');
      return const SizedBox(height: 20);
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ DIALOGS - Professional Design
// ═══════════════════════════════════════════════════════

class _SpeedDialog extends StatelessWidget {
  final double currentSpeed;
  final void Function(double) onSpeedSelected;

  const _SpeedDialog({
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  static const List<double> speeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  @override
  Widget build(BuildContext context) {
    try {
      return Dialog(
        backgroundColor: const Color(0xE6212121),
        insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(title: 'Playback Speed'),
            ...speeds.map((s) {
              final isSelected = (currentSpeed - s).abs() < 0.01;
              return _DialogOption(
                title: s == 1.0 ? 'Normal' : '${s}x',
                selected: isSelected,
                onTap: () => onSpeedSelected(s),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}

class _FitDialog extends StatelessWidget {
  final VideoFit currentFit;
  final void Function(VideoFit) onFitSelected;

  const _FitDialog({required this.currentFit, required this.onFitSelected});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xE6212121),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(title: 'Video Fit'),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...VideoFit.values.map((fit) {
                      final isSelected = currentFit == fit;
                      return _DialogOption(
                        title: _getFitName(fit),
                        selected: isSelected,
                        onTap: () => onFitSelected(fit),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _getFitName(VideoFit fit) {
    switch (fit) {
      case VideoFit.contain:
        return 'Contain';
      case VideoFit.cover:
        return 'Cover';
      case VideoFit.fill:
        return 'Fill';
      case VideoFit.fitWidth:
        return 'Fit Width';
      case VideoFit.fitHeight:
        return 'Fit Height';
    }
  }
}

class _FlipDialog extends StatelessWidget {
  final bool isFlippedH;
  final bool isFlippedV;
  final bool hasFlip;
  final VoidCallback onFlipHorizontal;
  final VoidCallback onFlipVertical;
  final VoidCallback onReset;

  const _FlipDialog({
    required this.isFlippedH,
    required this.isFlippedV,
    required this.hasFlip,
    required this.onFlipHorizontal,
    required this.onFlipVertical,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xE6212121),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(title: 'Flip Video'),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DialogOption(
                      title: 'Flip Horizontal',
                      selected: isFlippedH,
                      icon: Icons.flip,
                      onTap: onFlipHorizontal,
                    ),
                    _DialogOption(
                      title: 'Flip Vertical',
                      selected: isFlippedV,
                      icon: Icons.flip,
                      iconRotation: 1.5708,
                      onTap: onFlipVertical,
                    ),
                    if (hasFlip)
                      _DialogOption(
                        title: 'Reset',
                        selected: false,
                        icon: Icons.refresh,
                        onTap: onReset,
                      ),
                  ],
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

class _TrackDialog extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _TrackDialog({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    try {
      return Dialog(
        backgroundColor: const Color(0xE6212121),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(title: title),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ DIALOG COMPONENTS
// ═══════════════════════════════════════════════════════

class _DialogHeader extends StatelessWidget {
  final String title;

  const _DialogHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
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
                    child: Icon(Icons.close, color: Colors.white54, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
      ],
    );
  }
}

class _DialogOption extends StatelessWidget {
  final String title;
  final bool selected;
  final IconData? icon;
  final double iconRotation;
  final VoidCallback onTap;

  const _DialogOption({
    required this.title,
    required this.selected,
    this.icon,
    this.iconRotation = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white12,
        highlightColor: Colors.white10,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Colors.lightBlueAccent : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 14),
              if (icon != null) ...[
                Transform.rotate(
                  angle: iconRotation,
                  child: Icon(icon, color: Colors.white70, size: 20),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
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

class _TrackTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TrackTile({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white12,
          highlightColor: Colors.white10,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? Colors.lightBlueAccent : Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}

class _ChromecastButton extends ConsumerWidget {
  final VoidCallback onInteraction;

  const _ChromecastButton({required this.onInteraction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final castState = ref.watch(chromecastStateProvider).asData?.value;
      final isCasting = castState == CastState.connected;
      final isConnecting = castState == CastState.connecting;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onInteraction();
            _showChromecastDialog(context, ref);
          },
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Stack(
              children: [
                Icon(
                  isCasting ? Icons.cast_connected : Icons.cast,
                  color: isCasting
                      ? Colors.lightBlueAccent
                      : (isConnecting ? Colors.amber : Colors.white),
                  size: 24,
                ),
                if (isConnecting)
                  Positioned.fill(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.amber.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  void _showChromecastDialog(BuildContext context, WidgetRef ref) {
    try {
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => const ChromecastDialogWidget(),
      );
    } catch (e) {
      debugPrint('⚠️ Show chromecast dialog error: $e');
    }
  }
}
