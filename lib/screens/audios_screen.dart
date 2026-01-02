import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_file.dart';
import '../providers/media_provider.dart';
import '../widgets/media_item_card.dart';
import '../widgets/empty_state_widget.dart';
import '../helpers/audio_playback_helper.dart';

class AudiosScreen extends ConsumerStatefulWidget {
  const AudiosScreen({super.key});

  @override
  ConsumerState<AudiosScreen> createState() => _AudiosScreenState();
}

class _AudiosScreenState extends ConsumerState<AudiosScreen> {
  bool _isGridView = false;
  String _sortBy = 'name';

  @override
  Widget build(BuildContext context) {
    final audios = ref.watch(audiosProvider);

    return audios.when(
      data: (files) {
        if (files.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.music_note_outlined,
            title: 'No Audio Files',
            message: 'No audio files found on your device',
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
            '$count ${count == 1 ? 'track' : 'tracks'}',
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
        childAspectRatio: 1.0,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        return MediaItemCard(
          mediaFile: files[index],
          onTap: () => _openAudio(files, index),
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
          onTap: () => _openAudio(files, index),
        );
      },
    );
  }

  void _openAudio(List<MediaFile> files, int index) async {
    await ref.read(mediaProvider.notifier).addToRecent(files[index]);

    AudioPlaybackHelper.playAudio(ref, files[index], files, startIndex: index);
  }
}
