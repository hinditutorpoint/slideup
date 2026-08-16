import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/iptv_models.dart';
import '../providers/iptv_providers.dart';
import '../services/iptv_database_service.dart';
import '../widgets/add_playlist_sheet.dart';
import 'iptv_player_screen.dart';

/// IPTV home: lists saved playlists, add buttons, and a sample quick start.
class IptvHomeScreen extends ConsumerWidget {
  const IptvHomeScreen({super.key});

  Future<void> _openAddSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddPlaylistSheet(),
    );
  }

  Future<void> _openPlayer(BuildContext context, IptvPlaylist playlist) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final channels = await IptvDatabaseService.instance.getChannels(
        playlist.id,
      );
      if (!context.mounted) return;
      if (channels.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('This playlist has no channels.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              IptvPlayerScreen(channels: channels, playlistName: playlist.name),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to load channels: $e')),
      );
    }
  }

  Future<void> _addSample(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(iptvPlaylistsProvider.notifier)
          .addFromUrl(url: kIptvSampleUrl);
      messenger.showSnackBar(
        const SnackBar(content: Text('Sample playlist added.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to load sample: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(iptvPlaylistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IPTV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add playlist',
            onPressed: () => _openAddSheet(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add playlist'),
      ),
      body: playlists.isEmpty
          ? _EmptyState(
              onAdd: () => _openAddSheet(context),
              onSample: () => _addSample(context, ref),
            )
          : _PlaylistList(
              playlists: playlists,
              onOpen: (playlist) => _openPlayer(context, playlist),
            ),
    );
  }
}

class _PlaylistList extends ConsumerWidget {
  const _PlaylistList({required this.playlists, required this.onOpen});

  final List<IptvPlaylist> playlists;
  final ValueChanged<IptvPlaylist> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: playlists.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'My playlists',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          );
        }

        final playlist = playlists[index - 1];
        final icon = playlist.sourceType.index == 0
            ? Icons.link
            : playlist.sourceType.index == 1
            ? Icons.folder_open
            : Icons.cloud;

        return Dismissible(
          key: ValueKey('playlist-${playlist.id}'),
          direction: DismissDirection.startToEnd,
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            decoration: BoxDecoration(
              color: colorScheme.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: colorScheme.onError),
                const SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: colorScheme.onError,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            final messenger = ScaffoldMessenger.of(context);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Delete playlist?'),
                content: Text(
                  'Remove "${playlist.name}" and all its channels?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed != true) return false;
            await ref
                .read(iptvPlaylistsProvider.notifier)
                .deletePlaylist(playlist.id);
            messenger.showSnackBar(
              SnackBar(content: Text('Deleted "${playlist.name}"')),
            );
            return true;
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: ListTile(
              onTap: () => onOpen(playlist),
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(icon, color: colorScheme.onPrimaryContainer),
              ),
              title: Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${playlist.channelCount} channels · ${playlist.sourceLabel}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onOpen(playlist),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.onSample});

  final VoidCallback onAdd;
  final VoidCallback onSample;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv, size: 72, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'No playlists yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an M3U URL, a local .m3u file, or XTream credentials\nto start watching live TV.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add playlist'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSample,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Load sample playlist'),
            ),
            const SizedBox(height: 8),
            Text(
              'Public iptv-org playlist (~10,000 channels)',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
