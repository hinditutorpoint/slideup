import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/player_media.dart';
import '../providers/video_player_provider.dart';

class PlaylistSheetWidget extends ConsumerStatefulWidget {
  final PlayerPlaylist playlist;

  const PlaylistSheetWidget({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistSheetWidget> createState() =>
      _PlaylistSheetWidgetState();
}

class _PlaylistSheetWidgetState extends ConsumerState<PlaylistSheetWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(videoPlayerProvider);
    final currentIndex = playerState.currentIndex;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Playlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.playlist.length} videos',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Toggle view button
                  IconButton(
                    icon: Icon(
                      _isGridView ? Icons.list : Icons.grid_view,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _isGridView = !_isGridView;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search playlist...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),

            // Playlist content
            Expanded(
              child: _isGridView
                  ? _buildGridView(currentIndex)
                  : _buildListView(currentIndex),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(int currentIndex) {
    final filteredItems = _getFilteredItems();

    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final originalIndex = widget.playlist.items.indexOf(item.media);

        return _PlaylistListItem(
          media: item.media,
          index: originalIndex,
          isPlaying: originalIndex == currentIndex,
          onTap: () => _jumpToIndex(originalIndex),
        );
      },
    );
  }

  Widget _buildGridView(int currentIndex) {
    final filteredItems = _getFilteredItems();

    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 16 / 12,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final originalIndex = widget.playlist.items.indexOf(item.media);

        return _PlaylistGridItem(
          media: item.media,
          index: originalIndex,
          isPlaying: originalIndex == currentIndex,
          onTap: () => _jumpToIndex(originalIndex),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: Colors.grey[600], size: 48),
          const SizedBox(height: 16),
          Text(
            'No videos found',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  List<_FilteredItem> _getFilteredItems() {
    if (_searchQuery.isEmpty) {
      return widget.playlist.items.map((m) => _FilteredItem(media: m)).toList();
    }

    return widget.playlist.items
        .where((media) {
          final title = (media.title ?? '').toLowerCase();
          final artist = (media.artist ?? '').toLowerCase();
          return title.contains(_searchQuery) || artist.contains(_searchQuery);
        })
        .map((m) => _FilteredItem(media: m))
        .toList();
  }

  void _jumpToIndex(int index) {
    try {
      ref.read(videoPlayerProvider.notifier).jumpToIndex(index);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('⚠️ Jump to index error: $e');
    }
  }
}

class _FilteredItem {
  final PlayerMedia media;

  _FilteredItem({required this.media});
}

// ═══════════════════════════════════════════════════════
// ✅ LIST ITEM
// ═══════════════════════════════════════════════════════

class _PlaylistListItem extends StatelessWidget {
  final PlayerMedia media;
  final int index;
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlaylistListItem({
    required this.media,
    required this.index,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Stack(
        children: [
          // Thumbnail
          Container(
            width: 80,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildThumbnail(),
            ),
          ),
          // Playing indicator
          if (isPlaying)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          // Duration badge
          if (media.duration != null)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  media.durationFormatted,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        media.title ?? 'Unknown',
        style: TextStyle(
          color: isPlaying ? Colors.red : Colors.white,
          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: media.artist != null
          ? Text(
              media.artist!,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            )
          : Text(
              'Video ${index + 1}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
      trailing: isPlaying
          ? const _PlayingIndicator()
          : Text('${index + 1}', style: TextStyle(color: Colors.grey[600])),
    );
  }

  Widget _buildThumbnail() {
    if (media.thumbnailPath != null) {
      // Check if it's a file path or URL
      if (media.thumbnailPath!.startsWith('http')) {
        return Image.network(
          media.thumbnailPath!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } else {
        return Image.file(
          File(media.thumbnailPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.movie, color: Colors.white38, size: 24),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ GRID ITEM
// ═══════════════════════════════════════════════════════

class _PlaylistGridItem extends StatelessWidget {
  final PlayerMedia media;
  final int index;
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlaylistGridItem({
    required this.media,
    required this.index,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: isPlaying ? Border.all(color: Colors.red, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    child: _buildThumbnail(),
                  ),
                  // Index badge
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  // Duration badge
                  if (media.duration != null)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          media.durationFormatted,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  // Playing overlay
                  if (isPlaying)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                media.title ?? 'Unknown',
                style: TextStyle(
                  color: isPlaying ? Colors.red : Colors.white,
                  fontSize: 12,
                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (media.thumbnailPath != null) {
      if (media.thumbnailPath!.startsWith('http')) {
        return Image.network(
          media.thumbnailPath!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } else {
        return Image.file(
          File(media.thumbnailPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[700],
      child: const Icon(Icons.movie, color: Colors.white38, size: 32),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ PLAYING INDICATOR
// ═══════════════════════════════════════════════════════

class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator();

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animValue = ((_controller.value + delay) % 1.0);
            final height = 8 + animValue * 8;

            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}

class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: animation,
      builder: (context, _) => builder(context, child),
    );
  }
}
