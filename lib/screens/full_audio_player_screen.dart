import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:equalizer_flutter/equalizer_flutter.dart';
import 'dart:io';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import '../models/media_file.dart';
import '../models/audio_data.dart';
import '../providers/audio_handler_provider.dart';
import '../providers/favorites_provider.dart';
import '../helpers/format_helper.dart';
import '../services/database_service.dart';
import '../widgets/lyrics_view_widget.dart';

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
  Timer? _sleepTimer;
  bool _isFavorite = false;
  String? _currentMediaId;
  bool _showLyrics = false;
  String? _trackInfoPath;
  Future<AudioData?>? _trackInfoFuture;

  @override
  void initState() {
    super.initState();
    _currentMediaId = widget.mediaFile.id;
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Listen to playback state for rotation & active media changes
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

      audioHandler.mediaItem.listen((item) {
        if (mounted && item != null) {
          _loadFavoriteStatus(item.id);
        }
      });

      // Load favorite status
      _loadFavoriteStatus(widget.mediaFile.id);
    });
  }

  Future<void> _loadFavoriteStatus([String? mediaId]) async {
    final id = mediaId ?? _currentMediaId ?? widget.mediaFile.id;
    _currentMediaId = id;
    try {
      final isFav = await DatabaseService.instance.isMediaFileFavorite(id);
      if (mounted) {
        setState(() => _isFavorite = isFav);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final id = _currentMediaId ?? widget.mediaFile.id;
    try {
      final newFav = await DatabaseService.instance.toggleFavoriteMediaFile(
        id,
        widget.mediaFile,
      );
      if (mounted) {
        setState(() => _isFavorite = newFav);
        ref.invalidate(allFavoritesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newFav ? 'Added to favorites' : 'Removed from favorites',
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update favorite'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);

    return Scaffold(
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
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 32),
            tooltip: 'Minimize',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _showLyrics ? Icons.lyrics : Icons.lyrics_outlined,
              color: _showLyrics ? Theme.of(context).primaryColor : null,
            ),
            tooltip: _showLyrics ? 'Show Album Art' : 'Show Lyrics',
            onPressed: () {
              setState(() {
                _showLyrics = !_showLyrics;
              });
            },
          ),
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
        final currentTitle = mediaItem?.title ?? widget.mediaFile.name;
        final currentArtist = mediaItem?.artist ?? widget.mediaFile.artist;
        final currentDuration = mediaItem?.duration ??
            (widget.mediaFile.duration != null
                ? Duration(milliseconds: widget.mediaFile.duration!)
                : null);

        // Use LayoutBuilder so lyrics panel fits correctly on all screen sizes
        return LayoutBuilder(
          builder: (context, constraints) {
            // Lyrics panel height = screen height minus fixed controls area
            // Approximate: appbar ~72, trackInfo ~80, progress ~70,
            // controls ~90, additionalControls ~60, padding ~80
            final lyricsPanelHeight =
                (constraints.maxHeight - 454).clamp(220.0, 400.0);

            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // ── Album Art  OR  Lyrics Panel ─────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: _showLyrics
                        ? SizedBox(
                            key: const ValueKey('lyrics'),
                            height: lyricsPanelHeight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: LyricsViewWidget(
                                songTitle: currentTitle,
                                artist: currentArtist,
                                duration: currentDuration,
                                onClose: () =>
                                    setState(() => _showLyrics = false),
                              ),
                            ),
                          )
                        : SizedBox(
                            key: const ValueKey('albumArt'),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildAlbumArt(mediaItem),
                                const SizedBox(height: 10),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor:
                                        Theme.of(context).primaryColor,
                                  ),
                                  onPressed: () =>
                                      setState(() => _showLyrics = true),
                                  icon: const Icon(
                                    Icons.lyrics_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Show Lyrics'),
                                ),
                              ],
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),
                  _buildTrackInfo(mediaItem),
                  const SizedBox(height: 24),
                  _buildProgressBar(audioHandler),
                  const SizedBox(height: 24),
                  _buildControls(audioHandler),
                  const SizedBox(height: 24),
                  _buildAdditionalControls(audioHandler),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
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
    final path = mediaItem?.extras?['path'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: FutureBuilder<AudioData?>(
        future: _audioDataForPath(path),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final title = data?.title ?? mediaItem?.title ?? 'Unknown';
          final artist =
              data?.artist ?? mediaItem?.artist ?? 'Unknown Artist';
          final album = data?.album ?? mediaItem?.album;

          return Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                artist,
                style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (album != null) ...[
                const SizedBox(height: 8),
                Text(
                  album,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<AudioData?> _audioDataForPath(String? path) {
    if (path == null || path.isEmpty) {
      return Future<AudioData?>.value(null);
    }
    if (_trackInfoPath != path || _trackInfoFuture == null) {
      _trackInfoPath = path;
      _trackInfoFuture = AudioData.load(path);
    }
    return _trackInfoFuture!;
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
                tooltip: switch (repeatMode) {
                  AudioServiceRepeatMode.none => 'Repeat: Off',
                  AudioServiceRepeatMode.all => 'Repeat: All',
                  AudioServiceRepeatMode.one => 'Repeat: One',
                  _ => 'Repeat: Off',
                },
                onPressed: () {
                  AudioServiceRepeatMode nextMode;
                  String msg;
                  switch (repeatMode) {
                    case AudioServiceRepeatMode.none:
                      nextMode = AudioServiceRepeatMode.all;
                      msg = 'Repeat: All';
                      break;
                    case AudioServiceRepeatMode.all:
                      nextMode = AudioServiceRepeatMode.one;
                      msg = 'Repeat: One';
                      break;
                    default:
                      nextMode = AudioServiceRepeatMode.none;
                      msg = 'Repeat: Off';
                  }
                  audioHandler.setRepeatMode(nextMode);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      duration: const Duration(milliseconds: 900),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
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
                tooltip: isShuffling ? 'Shuffle: On' : 'Shuffle: Off',
                onPressed: () {
                  final nextMode = isShuffling
                      ? AudioServiceShuffleMode.none
                      : AudioServiceShuffleMode.all;
                  audioHandler.setShuffleMode(nextMode);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        nextMode == AudioServiceShuffleMode.all
                            ? 'Shuffle: On'
                            : 'Shuffle: Off',
                      ),
                      duration: const Duration(milliseconds: 900),
                      behavior: SnackBarBehavior.floating,
                    ),
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
              onTap: () async {
                Navigator.pop(context);
                final audioHandler = ref.read(audioHandlerProvider);
                final mediaItem = audioHandler.mediaItem.value;
                if (mediaItem != null) {
                  final path = mediaItem.extras?['path'] as String?;
                  if (path != null) {
                    try {
                      // ignore: deprecated_member_use
                      await Share.shareXFiles([
                        XFile(path),
                      ], text: 'Check out this song: ${mediaItem.title}');
                    } catch (e) {
                      debugPrint('Error sharing file: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to share file: $e')),
                        );
                      }
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('File path not found for sharing'),
                        ),
                      );
                    }
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.lyrics),
              title: const Text('Lyrics'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _showLyrics = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Song Details'),
              onTap: () {
                Navigator.pop(context);
                _showSongDetails();
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Sleep Timer'),
              onTap: () {
                Navigator.pop(context);
                _showSleepTimerDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.equalizer),
              title: const Text('Equalizer'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final audioHandler = ref.read(audioHandlerProvider);
                  final sessionId = audioHandler.player.androidAudioSessionId;
                  if (sessionId != null) {
                    EqualizerFlutter.setAudioSessionId(sessionId);
                  }
                  EqualizerFlutter.open(sessionId ?? 0);
                } catch (e) {
                  debugPrint('Error opening equalizer: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Equalizer not supported on this device'),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSongDetails() {
    final audioHandler = ref.read(audioHandlerProvider);
    final mediaItem = audioHandler.mediaItem.value;

    if (mediaItem == null) return;

    final path = mediaItem.extras?['path'] as String?;
    final future = path == null || path.isEmpty
        ? Future<AudioData?>.value(null)
        : AudioData.load(path);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
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
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'Song Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<AudioData?>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: _buildAudioDetailRows(
                      snapshot.data,
                      mediaItem,
                      path,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAudioDetailRows(
    AudioData? data,
    MediaItem item,
    String? path,
  ) {
    final rows = <Widget>[];

    void add(String label, String? value) {
      if (value != null && value.isNotEmpty) {
        rows.add(_buildDetailRow(label, value));
      }
    }

    add('Title', data?.title ?? item.title);
    add('Album', data?.album ?? item.album);
    add('Artist', data?.artist ?? item.artist);
    add('Album Artist', data?.albumArtist);
    add('Author', data?.author);
    add('Writer', data?.writer);
    add('Composer', data?.composer);
    add('Genre', data?.genre ?? item.genre);
    add('Year', data?.year?.toString());
    add('Date', data?.date);
    add('Track Number', data?.trackNumber?.toString());
    add('Disc Number', data?.discNumber?.toString());
    if (data?.compilation == true) {
      add('Compilation', 'Yes');
    }
    add('Duration', data?.durationFormatted);
    add('Bitrate', data?.bitrateKbps);
    add('Quality', data?.quality);
    add('MIME Type', data?.mimeType);
    final rawSize = item.extras?['size'];
    add(
      'Size',
      data?.fileSizeMB ??
          (rawSize is num ? FormatHelper.formatBytes(rawSize.toInt()) : null),
    );
    add('Bytes', data?.fileSizeBytes?.toString());
    if (data?.hasArtwork == true) {
      add('Artwork', 'Embedded');
    }
    add('Path', path);

    return rows;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sleep Timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimerOption('5 Minutes', const Duration(minutes: 5)),
            _buildTimerOption('15 Minutes', const Duration(minutes: 15)),
            _buildTimerOption('30 Minutes', const Duration(minutes: 30)),
            _buildTimerOption('1 Hour', const Duration(hours: 1)),
            if (_sleepTimer != null && _sleepTimer!.isActive) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.timer_off, color: Colors.red),
                title: const Text(
                  'Cancel Timer',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  _sleepTimer?.cancel();
                  _sleepTimer = null;
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sleep timer cancelled')),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimerOption(String label, Duration duration) {
    return ListTile(
      leading: const Icon(Icons.timer),
      title: Text(label),
      onTap: () {
        _startSleepTimer(duration);
        Navigator.pop(context);
      },
    );
  }

  void _startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(duration, () {
      if (mounted) {
        final audioHandler = ref.read(audioHandlerProvider);
        audioHandler.stop();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sleep timer set for ${duration.inMinutes} minutes'),
        ),
      );
    }
  }
}
