import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_file.dart';
import '../providers/media_provider.dart';
import '../widgets/media_item_card.dart';
import '../widgets/empty_state_widget.dart';
import '../features/video_player/video_player_launcher.dart';
import '../helpers/audio_playback_helper.dart';
import 'pdf_viewer_screen.dart';
import 'image_viewer_screen.dart';
import 'package:open_filex/open_filex.dart';

class RecentFilesScreen extends ConsumerStatefulWidget {
  const RecentFilesScreen({super.key});

  @override
  ConsumerState<RecentFilesScreen> createState() => _RecentFilesScreenState();
}

class _RecentFilesScreenState extends ConsumerState<RecentFilesScreen> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    final recentFiles = ref.watch(recentFilesProvider);

    return Scaffold(
      body: recentFiles.when(
        data: (files) {
          if (files.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.history,
              title: 'No Recent Files',
              message: 'Files you open will appear here',
            );
          }

          return Column(
            children: [
              _buildHeader(files.length),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(recentFilesProvider);
                  },
                  child: _isGridView
                      ? _buildGridView(files)
                      : _buildListView(files),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(recentFilesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '$count ${count == 1 ? 'file' : 'files'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _showClearRecentDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<MediaFile> files) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        return MediaItemCard(
          mediaFile: files[index],
          onTap: () => _openFile(files[index], files, index),
          onLongPress: () => _showFileOptions(files[index]),
        );
      },
    );
  }

  Widget _buildListView(List<MediaFile> files) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        return MediaItemCard(
          mediaFile: files[index],
          isListView: true,
          onTap: () => _openFile(files[index], files, index),
          onLongPress: () => _showFileOptions(files[index]),
        );
      },
    );
  }

  void _openFile(MediaFile file, List<MediaFile> playlist, int index) async {
    // Add to recent files
    await ref.read(mediaProvider.notifier).addToRecent(file);
    if (!mounted) return;
    switch (file.type) {
      case MediaType.video:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerLauncher.screen(
              files: playlist.where((f) => f.type == MediaType.video).toList(),
              file: file,
              index: playlist
                  .where((f) => f.type == MediaType.video)
                  .toList()
                  .indexOf(file),
            ),
          ),
        );
        break;
      case MediaType.audio:
        AudioPlaybackHelper.playAudio(
          ref,
          file,
          playlist.where((f) => f.type == MediaType.audio).toList(),
          startIndex: playlist
              .where((f) => f.type == MediaType.audio)
              .toList()
              .indexOf(file),
        );
        break;
      case MediaType.document:
        if (file.documentType == DocumentType.pdf) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFViewerScreen(
                mediaFile: file,
                playlist: playlist
                    .where((f) => f.documentType == DocumentType.pdf)
                    .toList(),
                currentIndex: playlist
                    .where((f) => f.documentType == DocumentType.pdf)
                    .toList()
                    .indexOf(file),
              ),
            ),
          );
        } else {
          // Open with external app
          await OpenFilex.open(file.path);
        }
        break;
      case MediaType.image:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageViewerScreen(
              initialImage: file,
              images: playlist.where((f) => f.type == MediaType.image).toList(),
            ),
          ),
        );
      default:
        await OpenFilex.open(file.path);
    }
  }

  void _showFileOptions(MediaFile file) {
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
              leading: const Icon(Icons.info_outline),
              title: const Text('Details'),
              onTap: () {
                Navigator.pop(context);
                _showFileDetails(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(context);
                _addToPlaylist(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove from Recent'),
              onTap: () {
                Navigator.pop(context);
                _removeFromRecent(file);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showFileDetails(MediaFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', file.name),
            _buildDetailRow('Path', file.displayPath ?? file.path),
            _buildDetailRow('Size', file.sizeFormatted),
            _buildDetailRow('Type', file.type.name.toUpperCase()),
            if (file.duration != null)
              _buildDetailRow('Duration', file.durationFormatted),
            _buildDetailRow('Modified', _formatDate(file.dateModified)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _shareFile(MediaFile file) {
    // TODO: Implement share functionality
  }

  void _addToPlaylist(MediaFile file) {
    // TODO: Show playlist selection dialog
  }

  void _removeFromRecent(MediaFile file) async {
    await ref.read(mediaProvider.notifier).removeFromRecent(file.id);
    ref.invalidate(recentFilesProvider);
  }

  void _showClearRecentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Recent Files'),
        content: const Text('Are you sure you want to clear all recent files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(mediaProvider.notifier).clearRecent();
              if (!context.mounted) return;
              Navigator.pop(context);
              ref.invalidate(recentFilesProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
