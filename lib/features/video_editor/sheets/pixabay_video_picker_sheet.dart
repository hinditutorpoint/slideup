import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/video_edit_settings.dart';
import '../providers/timeline_provider.dart';
import '../services/pixabay_api_service.dart';
import 'package:slideup/features/video_player/video_player_launcher.dart';

// ═══════════════════════════════════════════════════════
// ✅ PIXABAY STOCK VIDEO PICKER & PREVIEW SHEET
// ═══════════════════════════════════════════════════════

class PixabayVideoPickerSheet extends ConsumerStatefulWidget {
  const PixabayVideoPickerSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PixabayVideoPickerSheet(),
    );
  }

  @override
  ConsumerState<PixabayVideoPickerSheet> createState() =>
      _PixabayVideoPickerSheetState();
}

class _PixabayVideoPickerSheetState
    extends ConsumerState<PixabayVideoPickerSheet> {
  final PixabayApiService _apiService = PixabayApiService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<StockVideo> _videos = [];
  bool _isLoading = false;
  String _query = '';
  int _page = 1;

  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadingIds = {};

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await _apiService.fetchVideos(
        query: _query,
        page: _page,
      );

      if (mounted) {
        setState(() {
          _videos = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _query = value;
          _page = 1;
        });
        _loadVideos();
      }
    });
  }

  Future<void> _insertVideoToTimeline(StockVideo video) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      setState(() {
        _downloadingIds.add(video.id);
        _downloadProgress[video.id] = 0.05;
      });

      final downloaded = await _apiService.downloadVideoAsset(
        video,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress[video.id] = progress;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _downloadingIds.remove(video.id);
        _downloadProgress.remove(video.id);
      });

      if (downloaded != null && downloaded.localPath != null) {
        // Insert onto primary magnetic timeline
        ref.read(timelineProvider.notifier).addPrimaryClip(
              PrimaryVideoClip(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                videoPath: downloaded.localPath!,
                sourceDuration: downloaded.duration,
              ),
            );

        HapticFeedback.heavyImpact();
        navigator.pop(); // Close sheet

        messenger.showSnackBar(
          SnackBar(
            content: Text('Inserted "${video.title}" to Magnetic Timeline'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF6C63FF),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to download video asset'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(video.id);
          _downloadProgress.remove(video.id);
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error downloading video: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showVideoPreviewModal(StockVideo video) {
    final isDownloading = _downloadingIds.contains(video.id);
    final progress = _downloadProgress[video.id] ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Thumbnail / Preview Header (Direct URL Streaming)
            GestureDetector(
              onTap: () {
                if (video.videoUrl.isNotEmpty) {
                  VideoPlayerLauncher.open(context, url: video.videoUrl);
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.black45,
                          child: const Icon(Icons.movie,
                              size: 48, color: Colors.white54),
                        ),
                      ),
                    ),
                  ),
                  // Direct Stream Play Button Overlay
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${video.width}x${video.height}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${video.duration.inSeconds}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Video Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Artist: ${video.author}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  if (video.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: video.tags
                          .take(4)
                          .map(
                            (tag) => Chip(
                              label: Text('#$tag',
                                  style: const TextStyle(fontSize: 9)),
                              backgroundColor: Colors.white10,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              if (video.videoUrl.isNotEmpty) {
                VideoPlayerLauncher.open(context, url: video.videoUrl);
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
            ),
            icon: const Icon(Icons.play_circle_outline, size: 16),
            label: const Text('Stream Preview'),
          ),
          ElevatedButton.icon(
            onPressed: isDownloading
                ? null
                : () {
                    Navigator.pop(context); // Close modal
                    _insertVideoToTimeline(video);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: isDownloading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_for_offline),
            label: Text(
              isDownloading
                  ? 'Downloading ${(progress * 100).toInt()}%'
                  : 'Download & Insert',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Sheet Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.movie_creation_outlined,
                    color: Color(0xFF6C63FF)),
                const SizedBox(width: 8),
                const Text(
                  'Pixabay Stock Videos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search 4K/HD stock videos (e.g. nature, ocean, city)...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                prefixIcon:
                    const Icon(Icons.search, size: 18, color: Colors.grey),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Video Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _videos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_library_outlined,
                                color: Colors.grey[600], size: 48),
                            const SizedBox(height: 12),
                            Text('No videos found',
                                style: TextStyle(color: Colors.grey[400])),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          final video = _videos[index];
                          final isDownloading =
                              _downloadingIds.contains(video.id);
                          final progress = _downloadProgress[video.id] ?? 0.0;

                          return GestureDetector(
                            onTap: () => _showVideoPreviewModal(video),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Thumbnail
                                  CachedNetworkImage(
                                    imageUrl: video.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.black45,
                                      child: const Icon(Icons.movie,
                                          color: Colors.white38),
                                    ),
                                  ),

                                  // Play Overlay Badge
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),

                                  // Duration Badge
                                  Positioned(
                                    bottom: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${video.duration.inSeconds}s',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Title Badge
                                  Positioned(
                                    bottom: 6,
                                    left: 6,
                                    right: 40,
                                    child: Text(
                                      video.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 3,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Downloading Progress Indicator
                                  if (isDownloading)
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.8),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(
                                              value: progress > 0
                                                  ? progress
                                                  : null,
                                              color: const Color(0xFF6C63FF),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${(progress * 100).toInt()}%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
