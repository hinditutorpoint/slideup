import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_file.dart';
import '../providers/media_provider.dart';
import '../widgets/media_item_card.dart';
import '../widgets/empty_state_widget.dart';
//import 'media_kit_video_player.dart';
import '../features/video_player/video_player_launcher.dart';
import '../services/settings_service.dart';

class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen> {
  late bool _isGridView;
  String _sortBy = 'name'; // name, date, size

  @override
  void initState() {
    super.initState();
    _isGridView = SettingsService.instance.isGridView;
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(videosProvider);

    return videos.when(
      data: (files) {
        if (files.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.video_library_outlined,
            title: 'No Videos',
            message: 'No video files found on your device',
          );
        }

        final sortedFiles = _sortFiles(files);

        return Column(
          children: [
            _buildHeader(sortedFiles.length),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(mediaProvider.notifier).scanMedia();
                },
                child: _isGridView
                    ? _buildGridView(sortedFiles)
                    : _buildListView(sortedFiles),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  List<MediaFile> _sortFiles(List<MediaFile> files) {
    final sorted = List<MediaFile>.from(files);
    switch (_sortBy) {
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'date':
        sorted.sort((a, b) => b.dateModified.compareTo(a.dateModified));
        break;
      case 'size':
        sorted.sort((a, b) => b.size.compareTo(a.size));
        break;
    }
    return sorted;
  }

  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '$count ${count == 1 ? 'video' : 'videos'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(value: 'date', child: Text('Sort by Date')),
              const PopupMenuItem(value: 'size', child: Text('Sort by Size')),
            ],
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
              SettingsService.instance.setIsGridView(_isGridView);
            },
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
          onTap: () => _openVideo(files, index),
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
          onTap: () => _openVideo(files, index),
        );
      },
    );
  }

  void _openVideo(List<MediaFile> files, int index) async {
    await ref.read(mediaProvider.notifier).addToRecent(files[index]);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerLauncher.screen(
          files: files,
          file: files[index],
          index: index,
        ),
      ),
    );
    /* Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaKitVideoPlayer(
          videoUrl: videoPaths[index],
          playlist: videoPaths,
          startIndex: index,
        ),
      ),
    ); */
  }
}
