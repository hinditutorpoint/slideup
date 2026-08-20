import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/audio_playback_helper.dart';
import '../providers/audio_handler_provider.dart';
import '../providers/mini_player_provider.dart';
import '../navigation_service.dart';

class MiniAudioPlayer extends ConsumerStatefulWidget {
  const MiniAudioPlayer({super.key});

  @override
  ConsumerState<MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

class _MiniAudioPlayerState extends ConsumerState<MiniAudioPlayer>
    with SingleTickerProviderStateMixin {
  Offset _position = Offset.zero;
  bool _isDragging = false;
  bool _isOverCloseZone = false;

  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  // Mini player dimensions
  static const double playerWidth = 340;
  static const double playerHeight = 80;
  static const double closeZoneHeight = 120;
  static const double tinySize = 64;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );

    // Initialize position at bottom center after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePosition();
      _slideController.forward();
    });
  }

  void _initializePosition() {
    final screenSize = MediaQuery.of(context).size;
    final savedPosition = ref.read(miniPlayerProvider).position;

    // Default initial position
    const defaultOffset = Offset(20, 100);

    if (savedPosition == defaultOffset) {
      setState(() {
        _position = Offset(
          (screenSize.width - playerWidth) / 2, // center horizontally
          screenSize.height - playerHeight - 100, // bottom with padding
        );
      });

      ref.read(miniPlayerProvider.notifier).updatePosition(_position);
    } else {
      setState(() {
        _position = savedPosition;
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _onDismiss() async {
    await _slideController.reverse();
    if (mounted) {
      await AudioPlaybackHelper.stopAudio(ref);
    }
  }

  void _openFullPlayer() {
    final miniPlayerState = ref.read(miniPlayerProvider);
    final audioHandler = ref.read(audioHandlerProvider);
    if (miniPlayerState.currentMedia != null ||
        audioHandler.mediaItem.value != null) {
      rootNavigatorKey.currentState?.pushNamed('/audio-player');
    }
  }

  bool _isInCloseZone(Offset position, Size screenSize) {
    final closeZoneTop = screenSize.height - closeZoneHeight;
    final playerCenter = position.dy + (playerHeight / 2);
    return playerCenter > closeZoneTop;
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final screenSize = MediaQuery.of(context).size;
    final isTiny = ref.watch(miniPlayerProvider).isTiny;

    return Stack(
      children: [
        if (_isDragging) _buildCloseZone(screenSize),
        _buildMiniPlayer(audioHandler, screenSize, isTiny),
      ],
    );
  }

  Widget _buildCloseZone(Size screenSize) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: closeZoneHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              _isOverCloseZone
                  ? Colors.red.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.2),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.close,
              size: 40,
              color: _isOverCloseZone
                  ? Colors.red
                  : Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              _isOverCloseZone ? 'Release to close' : 'Drag here to close',
              style: TextStyle(
                color: _isOverCloseZone
                    ? Colors.red
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: _isOverCloseZone
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(dynamic audioHandler, Size screenSize, bool isTiny) {
    final width = isTiny ? tinySize : playerWidth;
    final height = isTiny ? tinySize : playerHeight;

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      left: _position.dx,
      top: _position.dy,
      child: SlideTransition(
        position: _slideAnimation.drive(
          Tween<Offset>(begin: const Offset(0, 2), end: Offset.zero),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTap: isTiny
              ? () => ref.read(miniPlayerProvider.notifier).restoreMini()
              : null,
          onPanStart: (_) {
            setState(() => _isDragging = true);
          },
          onPanUpdate: (details) {
            setState(() {
              final newX = (_position.dx + details.delta.dx)
                  .clamp(0, screenSize.width - width)
                  .toDouble();
              final newY = (_position.dy + details.delta.dy)
                  .clamp(0, screenSize.height - height)
                  .toDouble();

              _position = Offset(newX, newY);
              _isOverCloseZone = _isInCloseZone(_position, screenSize);
            });
          },
          onPanEnd: (details) {
            // Tiny player: long-press then fast swipe left/right reveals
            // the mini player features (restores the full mini bar).
            if (isTiny) {
              final vx = details.velocity.pixelsPerSecond.dx;
              if (vx.abs() > 200) {
                setState(() {
                  _isDragging = false;
                  _isOverCloseZone = false;
                });
                ref.read(miniPlayerProvider.notifier).restoreMini();
                return;
              }
            }
            if (_isOverCloseZone) {
              _onDismiss();
            } else {
              setState(() {
                _isDragging = false;
                _isOverCloseZone = false;

                // Snap to horizontal edges if close
                if (_position.dx < 20) {
                  _position = Offset(20, _position.dy);
                } else if (_position.dx > screenSize.width - width - 20) {
                  _position = Offset(
                    screenSize.width - width - 20,
                    _position.dy,
                  );
                }

                ref.read(miniPlayerProvider.notifier).updatePosition(_position);
              });
            }
          },
          child: AnimatedScale(
            scale: _isDragging ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedOpacity(
              opacity: _isOverCloseZone ? 0.7 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Material(
                elevation: _isDragging ? 12 : 8,
                borderRadius: BorderRadius.circular(isTiny ? 32 : 16),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isTiny ? 32 : 16),
                    gradient: LinearGradient(
                      colors: [
                        _isOverCloseZone
                            ? Colors.red.withValues(alpha: 0.8)
                            : Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.9),
                        _isOverCloseZone
                            ? Colors.red.shade700.withValues(alpha: 0.8)
                            : Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.9),
                      ],
                    ),
                    border: _isOverCloseZone
                        ? Border.all(color: Colors.red, width: 2)
                        : null,
                  ),
                  child: isTiny
                      ? _buildTinyPlayer(audioHandler)
                      : Stack(
                          children: [
                            // Progress bar
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: _buildProgressIndicator(audioHandler),
                            ),

                            // Main content
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  // Left area: tap to open full player
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: _openFullPlayer,
                                      child: Row(
                                        children: [
                                          _buildAlbumArt(audioHandler),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildTrackInfo(audioHandler),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Shrink to tiny mode
                                  IconButton(
                                    icon: const Icon(
                                      Icons.minimize_rounded,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                    tooltip: 'Tiny player',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => ref
                                        .read(miniPlayerProvider.notifier)
                                        .setTiny(true),
                                  ),
                                  const SizedBox(width: 4),
                                  // Right: playback controls
                                  _buildControls(audioHandler),
                                ],
                              ),
                            ),

                            // Drag indicator
                            Positioned(
                              top: 6,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTinyPlayer(dynamic audioHandler) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Rounded progress ring
        Padding(
          padding: const EdgeInsets.all(6),
          child: StreamBuilder<Duration>(
            stream: audioHandler.positionStream,
            builder: (context, posSnap) {
              return StreamBuilder<Duration?>(
                stream: audioHandler.durationStream,
                builder: (context, durSnap) {
                  final position = posSnap.data ?? Duration.zero;
                  final duration = durSnap.data ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;
                  return CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  );
                },
              );
            },
          ),
        ),
        // Center play/pause
        Center(
          child: StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return IconButton(
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => AudioPlaybackHelper.togglePlayPause(ref),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumArt(dynamic audioHandler) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;

        return Hero(
          tag: 'album_art_mini',
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: mediaItem?.artUri != null
                  ? Image.file(
                      File(mediaItem!.artUri!.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildDefaultArt(),
                    )
                  : _buildDefaultArt(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultArt() {
    return Container(
      color: Colors.white.withValues(alpha: 0.1),
      child: const Icon(Icons.music_note, color: Colors.white, size: 30),
    );
  }

  Widget _buildTrackInfo(dynamic audioHandler) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mediaItem?.title ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              mediaItem?.artist ?? 'Unknown Artist',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(dynamic audioHandler) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final playbackState = snapshot.data;
        final playing = playbackState?.playing ?? false;
        final processingState = playbackState?.processingState;

        final controlsEnabled =
            processingState != null &&
            processingState != AudioProcessingState.idle;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              iconSize: 24,
              onPressed: controlsEnabled ? audioHandler.skipToPrevious : null,
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  color: Theme.of(context).colorScheme.primary,
                ),
                iconSize: 24,
                padding: EdgeInsets.zero,
                onPressed: controlsEnabled
                    ? () => AudioPlaybackHelper.togglePlayPause(ref)
                    : null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              iconSize: 24,
              onPressed: controlsEnabled ? audioHandler.skipToNext : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressIndicator(dynamic audioHandler) {
    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: audioHandler.durationStream,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;

            final progress = duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0;

            return Container(
              height: 3,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
