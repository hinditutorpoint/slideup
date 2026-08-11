import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_file.dart';
import '../providers/playlist_provider.dart';

class PlaylistSelectionDialog extends ConsumerWidget {
  final MediaFile mediaFile;

  const PlaylistSelectionDialog({super.key, required this.mediaFile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return AlertDialog(
      title: const Text('Add to Playlist'),
      content: SizedBox(
        width: double.maxFinite,
        child: playlistsAsync.when(
          data: (playlists) {
            if (playlists.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No playlists found. Create one first!'),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                final isAlreadyIn = playlist.mediaIds.contains(mediaFile.id);

                return ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.mediaIds.length} items'),
                  trailing: isAlreadyIn
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: isAlreadyIn
                      ? null
                      : () async {
                          await ref
                              .read(playlistsProvider.notifier)
                              .addMediaToPlaylist(playlist.id, mediaFile.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added "${mediaFile.name}" to "${playlist.name}"',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
