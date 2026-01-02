import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../models/media_file.dart';
import '../helpers/format_helper.dart';

class VideoPlaylistScreen extends ConsumerStatefulWidget {
  final List<MediaFile> playlist;
  final int currentIndex;
  final Function(int) onVideoSelected;

  const VideoPlaylistScreen({
    super.key,
    required this.playlist,
    required this.currentIndex,
    required this.onVideoSelected,
  });

  @override
  ConsumerState<VideoPlaylistScreen> createState() =>
      _VideoPlaylistScreenState();
}

class _VideoPlaylistScreenState extends ConsumerState<VideoPlaylistScreen> {
  bool _isGridView = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MediaFile> get _filteredPlaylist {
    if (_searchQuery.isEmpty) return widget.playlist;

    return widget.playlist.where((file) {
      return file.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredPlaylist;

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search videos...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredList.length} videos',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  'Playing ${widget.currentIndex + 1}/${widget.playlist.length}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          // List/Grid view
          Expanded(
            child: _isGridView
                ? _buildGridView(filteredList)
                : _buildListView(filteredList),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<MediaFile> videos) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 16 / 12,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        final actualIndex = widget.playlist.indexOf(video);
        final isPlaying = actualIndex == widget.currentIndex;

        return GestureDetector(
          onTap: () {
            if (isPlaying) {
              debugPrint('ℹ️ Already playing this video, closing playlist');
              Navigator.pop(context);
            } else {
              debugPrint('📋 Playlist item selected: $index - ${video.name}');
              try {
                widget.onVideoSelected(actualIndex);
                //Navigator.pop(context);
              } catch (e) {
                debugPrint('❌ Error in onVideoSelected callback: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to play video: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isPlaying
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.black54,
              borderRadius: BorderRadius.circular(8),
              border: isPlaying
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        child: video.thumbnailPath != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                child: Image.file(
                                  File(video.thumbnailPath!),
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildDefaultThumbnail();
                                  },
                                ),
                              )
                            : _buildDefaultThumbnail(),
                      ),
                      if (isPlaying)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Playing',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (video.duration != null)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              FormatHelper.formatDuration(
                                Duration(milliseconds: video.duration!),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Info
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.name,
                        style: TextStyle(
                          color: isPlaying ? Colors.blue : Colors.white,
                          fontSize: 12,
                          fontWeight: isPlaying
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FormatHelper.formatBytes(video.size),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(List<MediaFile> videos) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        final actualIndex = widget.playlist.indexOf(video);
        final isPlaying = actualIndex == widget.currentIndex;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isPlaying
                ? Colors.blue.withValues(alpha: 0.2)
                : Colors.black54,
            borderRadius: BorderRadius.circular(8),
            border: isPlaying ? Border.all(color: Colors.blue, width: 2) : null,
          ),
          child: ListTile(
            leading: Stack(
              children: [
                Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: video.thumbnailPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(video.thumbnailPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultThumbnail();
                            },
                          ),
                        )
                      : _buildDefaultThumbnail(),
                ),
                if (video.duration != null)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        FormatHelper.formatDuration(
                          Duration(milliseconds: video.duration!),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ),
                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              video.name,
              style: TextStyle(
                color: isPlaying ? Colors.blue : Colors.white,
                fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${FormatHelper.formatBytes(video.size)}${video.displayPath != null ? ' • ${video.displayPath}' : ''}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isPlaying
                ? const Icon(Icons.equalizer, color: Colors.blue)
                : const Icon(Icons.play_circle_outline, color: Colors.white54),
            onTap: () {
              if (isPlaying) {
                debugPrint('ℹ️ Already playing this video, closing playlist');
                Navigator.pop(context);
              } else {
                debugPrint('📋 Playlist item selected: $index - ${video.name}');
                try {
                  widget.onVideoSelected(actualIndex);
                  //Navigator.pop(context);
                } catch (e) {
                  debugPrint('❌ Error in onVideoSelected callback: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to play video: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildDefaultThumbnail() {
    return const Center(
      child: Icon(Icons.video_library, color: Colors.white54, size: 40),
    );
  }
}
