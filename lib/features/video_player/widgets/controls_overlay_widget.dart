import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../models/video_player_state.dart';
import '../models/player_media.dart';
import '../providers/video_player_provider.dart';
import '../providers/pip_provider.dart';
import 'settings_sheet_widget.dart';
import 'playlist_sheet_widget.dart';

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
  @override
  void dispose() {
    try {
      widget.onDispose?.call();
    } catch (e) {
      debugPrint('⚠️ onDispose callback error: $e');
    }
    super.dispose();
  }

  // Keep controls visible when interacting
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
      //final playlistInfo = ref.watch(playlistInfoProvider);

      return AnimatedOpacity(
        opacity: playerState.showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !playerState.showControls,
          child: Container(
            decoration: const BoxDecoration(
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
            child: SafeArea(
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
                  ),
                ],
              ),
            ),
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _ControlIconButton(
              icon: Icons.arrow_back,
              onTap: () {
                onInteraction();
                _handleBack(ref, playerState);
              },
            ),
            Expanded(
              child: GestureDetector(
                onTap: onInteraction,
                behavior: HitTestBehavior.opaque,
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
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
            if (showPiPButton)
              _ControlIconButton(
                icon: Icons.picture_in_picture_alt,
                onTap: () {
                  onInteraction();
                  _enterPiP(ref);
                },
              ),
            _ControlIconButton(
              icon: Icons.lock_outline,
              onTap: () {
                onInteraction();
                _lockControls(ref);
              },
            ),
            _ControlIconButton(
              icon: Icons.settings,
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
            _ControlIconButton(
              icon: Icons.skip_previous,
              size: 36,
              onTap: () {
                onInteraction();
                _playPrevious(ref);
              },
            ),
            const SizedBox(width: 32),
          ],
          GestureDetector(
            onTap: () {
              onInteraction();
              _handleMainButton(ref, isCompleted);
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(color: Colors.white54, width: 2),
              ),
              child: Icon(
                _getMainIcon(isCompleted),
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          if (showReplayButton) ...[
            const SizedBox(width: 20),
            _ControlIconButton(
              icon: Icons.replay,
              size: 32,
              onTap: () {
                onInteraction();
                _replay(ref);
              },
            ),
          ],
          if (hasPlaylist) ...[
            const SizedBox(width: 32),
            _ControlIconButton(
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
      if (playerState.isPlaying) return Icons.pause;
      return Icons.play_arrow;
    } catch (e) {
      return Icons.play_arrow;
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
// ✅ BOTTOM BAR
// ═══════════════════════════════════════════════════════

class _BottomBar extends ConsumerWidget {
  final PlayerPlaylist playlist;
  final VideoPlayerState playerState;
  final VoidCallback onInteraction;

  const _BottomBar({
    required this.playlist,
    required this.playerState,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProgressBar(
              playerState: playerState,
              ref: ref,
              onInteraction: onInteraction,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  // Time
                  GestureDetector(
                    onTap: onInteraction,
                    child: Text(
                      '${_formatDuration(playerState.position)} / ${_formatDuration(playerState.duration)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),

                  const Spacer(),

                  // Speed
                  _SpeedButton(
                    speed: playerState.speed,
                    onInteraction: onInteraction,
                  ),
                  const SizedBox(width: 16),

                  // Playlist
                  if (playlist.hasMultiple) ...[
                    _ControlIconButton(
                      icon: Icons.playlist_play,
                      onTap: () {
                        onInteraction();
                        _showPlaylist(context);
                      },
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Fullscreen
                  _ControlIconButton(
                    icon: playerState.mode == PlayerMode.fullscreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    onTap: () {
                      onInteraction();
                      _toggleFullscreen(ref);
                    },
                  ),

                  // Track chips
                  const SizedBox(width: 12),
                  Flexible(
                    child: _TrackChips(
                      playerState: playerState,
                      onInteraction: onInteraction,
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
// ✅ CONTROL ICON BUTTON (No background, just icon)
// ═══════════════════════════════════════════════════════

class _ControlIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _ControlIconButton({
    required this.icon,
    required this.onTap,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ TRACK CHIPS
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

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasAudio) ...[
              _TrackChip(
                icon: Icons.audiotrack,
                label: _getAudioLabel(),
                onTap: () {
                  onInteraction();
                  _showAudioDialog(context, ref, audioTracks);
                },
              ),
              if (hasSubtitle || hasVideo) const SizedBox(width: 8),
            ],
            if (hasSubtitle) ...[
              _TrackChip(
                icon: Icons.subtitles,
                label: _getSubtitleLabel(),
                isActive: _hasActiveSubtitle(),
                onTap: () {
                  onInteraction();
                  _showSubtitleDialog(context, ref, subtitleTracks);
                },
              ),
              if (hasVideo) const SizedBox(width: 8),
            ],
            if (hasVideo)
              _TrackChip(
                icon: Icons.hd,
                label: _getVideoLabel(),
                onTap: () {
                  onInteraction();
                  _showVideoDialog(context, ref, videoTracks);
                },
              ),
          ],
        ),
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
        return t.title!.length > 6 ? t.title!.substring(0, 6) : t.title!;
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
        return t.title!.length > 6 ? t.title!.substring(0, 6) : t.title!;
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
        if (t.h! >= 1080) return '1080p';
        if (t.h! >= 720) return '720p';
        if (t.h! >= 480) return '480p';
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
        barrierColor: Colors.black26,
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
        barrierColor: Colors.black26,
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
        barrierColor: Colors.black26,
        builder: (ctx) => _TrackDialog(
          title: 'Video Quality',
          children: sorted.map((t) {
            final selected = playerState.currentVideoTrack?.id == t.id;
            String title = 'Track ${t.id}';
            if (t.h != null) {
              if (t.h! >= 2160) {
                title = '4K';
              } else if (t.h! >= 1080) {
                title = '1080p';
              } else if (t.h! >= 720) {
                title = '720p';
              } else if (t.h! >= 480) {
                title = '480p';
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
// ✅ TRACK CHIP
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
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white38),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
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
// ✅ SPEED BUTTON
// ═══════════════════════════════════════════════════════

class _SpeedButton extends ConsumerWidget {
  final double speed;
  final VoidCallback onInteraction;

  const _SpeedButton({required this.speed, required this.onInteraction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final isNormal = (speed - 1.0).abs() < 0.01;

      return GestureDetector(
        onTap: () {
          onInteraction();
          _showSpeedDialog(context, ref);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isNormal ? Colors.transparent : Colors.red,
            borderRadius: BorderRadius.circular(4),
            border: isNormal ? Border.all(color: Colors.white54) : null,
          ),
          child: Text(
            '${speed}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
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
        barrierColor: Colors.black26,
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
// ✅ SPEED DIALOG
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
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Text(
                    'Speed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ...speeds.map((s) {
              final isSelected = (currentSpeed - s).abs() < 0.01;
              return GestureDetector(
                onTap: () => onSpeedSelected(s),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? Colors.blue : Colors.white38,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        s == 1.0 ? 'Normal' : '${s}x',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
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

// ═══════════════════════════════════════════════════════
// ✅ TRACK DIALOG
// ═══════════════════════════════════════════════════════

class _TrackDialog extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _TrackDialog({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    try {
      return Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
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
// ✅ TRACK TILE
// ═══════════════════════════════════════════════════════

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
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: selected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? Colors.blue : Colors.white38,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                  ],
                ),
              ),
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
// ✅ PROGRESS BAR
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
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          activeTrackColor: Colors.red,
          inactiveTrackColor: Colors.white24,
          thumbColor: Colors.red,
          overlayColor: Colors.red.withValues(alpha: 0.2),
        ),
        child: Stack(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: SliderComponentShape.noThumb,
                activeTrackColor: Colors.white38,
                inactiveTrackColor: Colors.transparent,
              ),
              child: Slider(value: buffered, max: max, onChanged: null),
            ),
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
