import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

import '../providers/audio_handler_provider.dart';
import '../providers/mini_player_provider.dart';
import '../models/media_file.dart';
import '../screens/full_audio_player_screen.dart';

class AudioPlayerWrapper extends ConsumerStatefulWidget {
  const AudioPlayerWrapper({super.key});

  @override
  ConsumerState<AudioPlayerWrapper> createState() => _AudioPlayerWrapperState();
}

class _AudioPlayerWrapperState extends ConsumerState<AudioPlayerWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(miniPlayerProvider.notifier).expand();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _onPop();
        }
      },
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          final mediaItem = snapshot.data;

          if (mediaItem == null) {
            return _buildNoAudioScreen(context);
          }

          final currentMediaFile = _mediaItemToMediaFile(mediaItem);

          return StreamBuilder<List<MediaItem>>(
            stream: audioHandler.queue,
            builder: (context, queueSnapshot) {
              final queueItems = queueSnapshot.data ?? [];
              final playlist = queueItems.map(_mediaItemToMediaFile).toList();

              return StreamBuilder<PlaybackState>(
                stream: audioHandler.playbackState,
                builder: (context, playbackSnapshot) {
                  final currentIndex = playbackSnapshot.data?.queueIndex ?? 0;

                  return FullAudioPlayerScreen(
                    mediaFile: currentMediaFile,
                    playlist: playlist.isNotEmpty
                        ? playlist
                        : [currentMediaFile],
                    currentIndex: currentIndex,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _onPop() {
    final audioHandler = ref.read(audioHandlerProvider);
    final hasMedia = audioHandler.mediaItem.value != null;

    if (hasMedia) {
      ref.read(miniPlayerProvider.notifier).collapse();
    } else {
      ref.read(miniPlayerProvider.notifier).hide();
    }
  }

  Widget _buildNoAudioScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Player'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _onPop();
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 24),
            Text(
              'No audio playing',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _onPop();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.home),
              label: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }

  MediaFile _mediaItemToMediaFile(MediaItem item) {
    return MediaFile(
      id: item.id,
      name: item.title,
      path: item.extras?['path'] ?? '',
      displayPath: item.extras?['displayPath'],
      type: MediaType.audio,
      documentType: null,
      size: item.extras?['size'] ?? 0,
      dateModified: DateTime.fromMillisecondsSinceEpoch(
        item.extras?['dateModified'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      dateAdded: item.extras?['dateAdded'] != null
          ? DateTime.fromMillisecondsSinceEpoch(item.extras!['dateAdded'])
          : null,
      mimeType: item.extras?['mimeType'],
      thumbnailPath: item.artUri?.path,
      duration: item.duration?.inMilliseconds,
      isLocked: item.extras?['isLocked'] ?? false,
      parentFolder: item.extras?['parentFolder'],
      artist: item.artist,
      album: item.album,
    );
  }
}
