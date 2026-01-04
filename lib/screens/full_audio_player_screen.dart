import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io';
import '../models/media_file.dart';
import '../providers/audio_handler_provider.dart';
import '../providers/mini_player_provider.dart';
import '../helpers/format_helper.dart';

class FullAudioPlayerScreen extends ConsumerStatefulWidget {
  final MediaFile mediaFile;
  final List<MediaFile> playlist;
  final int currentIndex;

  const FullAudioPlayerScreen({
    super.key,
    required this.mediaFile,
    required this.playlist,
    required this.currentIndex,
  });

  @override
  ConsumerState<FullAudioPlayerScreen> createState() =>
      _FullAudioPlayerScreenState();
}

class _FullAudioPlayerScreenState extends ConsumerState<FullAudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Listen to playback state for rotation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioHandler = ref.read(audioHandlerProvider);
      audioHandler.playbackState.listen((state) {
        if (mounted) {
          if (state.playing) {
            _rotationController.repeat();
          } else {
            _rotationController.stop();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ref.read(miniPlayerProvider.notifier).collapse();
        } else {
          ref.read(miniPlayerProvider.notifier).hide();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(child: _buildPlayerView(audioHandler)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed: _showPlaylist,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerView(dynamic audioHandler) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildAlbumArt(mediaItem),
              const SizedBox(height: 30),
              _buildTrackInfo(mediaItem),
              const SizedBox(height: 30),
              _buildProgressBar(audioHandler),
              const SizedBox(height: 30),
              _buildControls(audioHandler),
              const SizedBox(height: 30),
              _buildAdditionalControls(audioHandler),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlbumArt(MediaItem? mediaItem) {
    return RotationTransition(
      turns: _rotationController,
      child: Hero(
        tag: 'album_art_mini',
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: ClipOval(
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
      ),
    );
  }

  Widget _buildDefaultArt() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Icon(
        Icons.music_note,
        size: 140,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildTrackInfo(MediaItem? mediaItem) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          Text(
            mediaItem?.title ?? 'Unknown',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            mediaItem?.artist ?? 'Unknown Artist',
            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
          ),
          if (mediaItem?.album != null) ...[
            const SizedBox(height: 8),
            Text(
              mediaItem!.album!,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(dynamic audioHandler) {
    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: audioHandler.durationStream,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                    ),
                    child: Slider(
                      value: position.inMilliseconds.toDouble(),
                      min: 0,
                      max: duration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        audioHandler.seek(
                          Duration(milliseconds: value.toInt()),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          FormatHelper.formatDuration(position),
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        Text(
                          FormatHelper.formatDuration(duration),
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              iconSize: 48,
              onPressed: audioHandler.skipToPrevious,
            ),
            const SizedBox(width: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 40),
                color: Colors.white,
                onPressed: () {
                  if (playing) {
                    audioHandler.pause();
                  } else {
                    audioHandler.play();
                  }
                },
              ),
            ),
            const SizedBox(width: 20),
            IconButton(
              icon: const Icon(Icons.skip_next),
              iconSize: 48,
              onPressed: audioHandler.skipToNext,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdditionalControls(dynamic audioHandler) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, snapshot) {
              final repeatMode =
                  snapshot.data?.repeatMode ?? AudioServiceRepeatMode.none;

              IconData icon;
              Color? color;

              switch (repeatMode) {
                case AudioServiceRepeatMode.one:
                  icon = Icons.repeat_one;
                  color = Theme.of(context).primaryColor;
                  break;
                case AudioServiceRepeatMode.all:
                  icon = Icons.repeat;
                  color = Theme.of(context).primaryColor;
                  break;
                default:
                  icon = Icons.repeat;
                  color = Colors.grey;
              }

              return IconButton(
                icon: Icon(icon, color: color),
                onPressed: () {
                  AudioServiceRepeatMode nextMode;
                  switch (repeatMode) {
                    case AudioServiceRepeatMode.none:
                      nextMode = AudioServiceRepeatMode.all;
                      break;
                    case AudioServiceRepeatMode.all:
                      nextMode = AudioServiceRepeatMode.one;
                      break;
                    default:
                      nextMode = AudioServiceRepeatMode.none;
                  }
                  audioHandler.setRepeatMode(nextMode);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              // TODO: Add to favorites
            },
          ),
          StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, snapshot) {
              final shuffleMode =
                  snapshot.data?.shuffleMode ?? AudioServiceShuffleMode.none;

              final isShuffling = shuffleMode == AudioServiceShuffleMode.all;

              return IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color: isShuffling
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                onPressed: () {
                  audioHandler.setShuffleMode(
                    isShuffling
                        ? AudioServiceShuffleMode.none
                        : AudioServiceShuffleMode.all,
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.speed),
            onPressed: _showSpeedDialog,
          ),
        ],
      ),
    );
  }

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playback Speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSpeedOption(0.5),
            _buildSpeedOption(0.75),
            _buildSpeedOption(1.0),
            _buildSpeedOption(1.25),
            _buildSpeedOption(1.5),
            _buildSpeedOption(2.0),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedOption(double speed) {
    final audioHandler = ref.read(audioHandlerProvider);
    return ListTile(
      title: Text('${speed}x'),
      onTap: () {
        audioHandler.setSpeed(speed);
        Navigator.pop(context);
      },
    );
  }

  void _showPlaylist() {
    final audioHandler = ref.read(audioHandlerProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Now Playing',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<MediaItem>>(
                    stream: audioHandler.queue,
                    builder: (context, snapshot) {
                      final queue = snapshot.data ?? [];

                      if (queue.isEmpty) {
                        return const Center(child: Text('No songs in queue'));
                      }

                      return StreamBuilder<PlaybackState>(
                        stream: audioHandler.playbackState,
                        builder: (context, playbackSnapshot) {
                          final currentIndex =
                              playbackSnapshot.data?.queueIndex ?? 0;

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: queue.length,
                            itemBuilder: (context, index) {
                              final item = queue[index];
                              final isPlaying = index == currentIndex;

                              return ListTile(
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: isPlaying
                                        ? Theme.of(
                                            context,
                                          ).primaryColor.withValues(alpha: 0.2)
                                        : Colors.grey.withValues(alpha: 0.1),
                                  ),
                                  child: item.artUri != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.file(
                                            File(item.artUri!.path),
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Icon(
                                          Icons.music_note,
                                          color: isPlaying
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey,
                                        ),
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontWeight: isPlaying
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isPlaying
                                        ? Theme.of(context).primaryColor
                                        : null,
                                  ),
                                ),
                                subtitle: Text(item.artist ?? 'Unknown Artist'),
                                trailing: isPlaying
                                    ? Icon(
                                        Icons.equalizer,
                                        color: Theme.of(context).primaryColor,
                                      )
                                    : null,
                                onTap: () {
                                  audioHandler.skipToQueueItem(index);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Share implementation
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Song Details'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show details
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Sleep Timer'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Sleep timer
              },
            ),
            ListTile(
              leading: const Icon(Icons.equalizer),
              title: const Text('Equalizer'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Equalizer
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
