import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/safe_async.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../documents/providers/pdf_providers.dart';
import '../models/video_item.dart';
import '../providers/video_providers.dart';
import '../widgets/video_grid_item.dart';
import '../widgets/video_list_item.dart';
import 'video_meta_screen.dart';

class LikedVideosScreen extends ConsumerStatefulWidget {
  const LikedVideosScreen({super.key});

  @override
  ConsumerState<LikedVideosScreen> createState() => _LikedVideosScreenState();
}

class _LikedVideosScreenState extends ConsumerState<LikedVideosScreen> {
  Future<void> _openVideo(VideoItem item) async {
    final result = await SafeAsync.run<void>(() async {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoMetaScreen(videoItem: item)),
      );
    }, operationName: 'Open Video Meta Screen');

    if (!mounted) return;

    result.when(
      success: (_) {},
      failure: (error, _) {
        _showSnackBar('Error opening video');
      },
    );
  }

  Future<void> _shareVideo(VideoItem item) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: '${item.title}\n\nWatch on Archive.org: ${item.detailsUrl}',
          subject: item.title,
        ),
      );
    } catch (e) {
      _showSnackBar('Error sharing: $e');
    }
  }

  void _saveVideo(VideoItem item) async {
    final result = await SafeAsync.run(
      () => ref.read(videoSearchProvider.notifier).toggleSave(item),
      operationName: 'Toggle Save',
    );

    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(
          savedVideosProvider,
        ); // Invalidate saved videos just in case
        _showSnackBar(
          item.isSaved ? 'Removed from saved' : 'Added to saved videos',
        );
      },
      failure: (error, _) {
        _showSnackBar('Failed to update save status');
      },
    );
  }

  void _toggleLike(VideoItem item) async {
    final result = await SafeAsync.run(
      () => ref.read(videoSearchProvider.notifier).toggleLike(item),
      operationName: 'Toggle Like',
    );

    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(likedVideosProvider); // Refresh the list
        _showSnackBar(
          item.isLiked ? 'Removed from favorites' : 'Added to favorites',
        );
      },
      failure: (error, _) {
        _showSnackBar('Failed to update favorite status');
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likedVideosAsync = ref.watch(likedVideosProvider);
    final viewMode = ref.watch(videoViewModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liked Videos'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(likedVideosProvider);
            },
          ),
          // View toggle
          IconButton(
            icon: Icon(
              viewMode == ViewMode.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
            tooltip: viewMode == ViewMode.grid ? 'List view' : 'Grid view',
            onPressed: () {
              ref.read(videoViewModeProvider.notifier).toggle();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: likedVideosAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return const EmptyStateWidget(
                title: 'No liked videos yet',
                subtitle: 'Videos you like will appear here',
                icon: Icons.favorite_border,
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(likedVideosProvider);
              },
              child: viewMode == ViewMode.grid
                  ? _buildGridView(items)
                  : _buildListView(items),
            );
          },
          loading: () => const LoadingWidget(message: 'Loading favorites...'),
          error: (error, _) => AppErrorWidget(
            message: 'Failed to load liked videos',
            onRetry: () => ref.invalidate(likedVideosProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildGridView(List<VideoItem> items) {
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);
    final padding = ResponsiveHelper.getScreenPadding(context);
    final aspectRatio = ResponsiveHelper.isMobile(context) ? 0.75 : 0.85;

    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        // Ensure isLiked is true since these are from the favorites table
        final likedItem = item;
        return VideoGridItem(
          item: likedItem,
          onTap: () => _openVideo(likedItem),
          onSave: () => _saveVideo(likedItem),
          onLike: () => _toggleLike(likedItem),
          onShare: () => _shareVideo(likedItem),
        );
      },
    );
  }

  Widget _buildListView(List<VideoItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        // Ensure isLiked is true since these are from the favorites table
        final likedItem = item;
        return VideoListItem(
          item: likedItem,
          onTap: () => _openVideo(likedItem),
          onSave: () => _saveVideo(likedItem),
          onLike: () => _toggleLike(likedItem),
          onShare: () => _shareVideo(likedItem),
        );
      },
    );
  }
}
