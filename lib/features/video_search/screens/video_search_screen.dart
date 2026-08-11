import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/utils/responsive_helper.dart';
import '../../../../core/utils/safe_async.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../providers/download_providers.dart';
import '../../../screens/downloads_screen.dart';
import '../../documents/providers/pdf_providers.dart';
import '../models/video_item.dart';
import '../providers/video_providers.dart';
import '../widgets/video_active_filter_chips.dart';
import '../widgets/video_filter_sheet.dart';
import '../widgets/video_grid_item.dart';
import '../widgets/video_list_item.dart';
import '../widgets/video_search_bar.dart';

import 'liked_videos_screen.dart';
import 'saved_videos_screen.dart';
import 'video_meta_screen.dart';

class VideoSearchScreen extends ConsumerStatefulWidget {
  const VideoSearchScreen({super.key});

  @override
  ConsumerState<VideoSearchScreen> createState() => _VideoSearchScreenState();
}

class _VideoSearchScreenState extends ConsumerState<VideoSearchScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(videoSearchProvider.notifier).loadMore();
    }
  }

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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const VideoFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(videoSearchProvider);
    final viewMode = ref.watch(videoViewModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Search'),
        actions: [
          // Refresh button (kept outside as requested)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(videoSearchProvider.notifier).refresh();
            },
          ),

          // More actions menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More actions',
            onSelected: (value) {
              switch (value) {
                case 'filters':
                  _showFilterSheet();
                  break;
                case 'view_mode':
                  ref.read(videoViewModeProvider.notifier).toggle();
                  break;
                case 'liked':
                  _showLikedVideos(context);
                  break;
                case 'saved':
                  _showSavedVideos(context);
                  break;
                case 'downloads':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              // Filters
              PopupMenuItem(
                value: 'filters',
                child: Row(
                  children: [
                    Badge(
                      isLabelVisible: searchState.filter.hasActiveFilters,
                      label: Text('${searchState.filter.activeFilterCount}'),
                      child: Icon(
                        searchState.filter.hasActiveFilters
                            ? Icons.filter_list
                            : Icons.filter_list_outlined,
                        color: searchState.filter.hasActiveFilters
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Filters'),
                  ],
                ),
              ),

              // View toggle
              PopupMenuItem(
                value: 'view_mode',
                child: Row(
                  children: [
                    Icon(
                      viewMode == ViewMode.grid
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                    ),
                    const SizedBox(width: 12),
                    Text(viewMode == ViewMode.grid ? 'List view' : 'Grid view'),
                  ],
                ),
              ),

              // Favorites
              const PopupMenuItem(
                value: 'liked',
                child: Row(
                  children: [
                    Icon(Icons.favorite),
                    SizedBox(width: 12),
                    Text('Liked Videos'),
                  ],
                ),
              ),

              // Saved
              const PopupMenuItem(
                value: 'saved',
                child: Row(
                  children: [
                    Icon(Icons.bookmark),
                    SizedBox(width: 12),
                    Text('Saved Videos'),
                  ],
                ),
              ),

              // Downloads
              PopupMenuItem(
                value: 'downloads',
                child: Consumer(
                  builder: (context, ref, child) {
                    final downloadsState = ref.watch(downloadsProvider);
                    final activeCount = downloadsState.activeDownloads.length;

                    return Row(
                      children: [
                        Badge(
                          isLabelVisible: activeCount > 0,
                          label: Text('$activeCount'),
                          child: const Icon(Icons.download),
                        ),
                        const SizedBox(width: 12),
                        const Text('Downloads'),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const VideoSearchBar(),
            const VideoActiveFilterChips(),

            // Results count
            if (searchState.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      '${_formatNumber(searchState.totalResults)} videos found',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    if (searchState.filter.hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Filtered',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Content
            Expanded(child: _buildContent(searchState, viewMode)),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildContent(VideoSearchState state, ViewMode viewMode) {
    if (state.isLoading) {
      return const LoadingWidget(message: 'Searching videos...');
    }

    if (state.error != null && state.items.isEmpty) {
      return AppErrorWidget(
        message: state.error!,
        onRetry: () => ref.read(videoSearchProvider.notifier).refresh(),
      );
    }

    if (state.query.isEmpty) {
      return const EmptyStateWidget(
        title: 'Search for Videos',
        subtitle: 'Enter a keyword to search Archive.org videos',
        icon: Icons.video_library_outlined,
      );
    }

    if (state.items.isEmpty) {
      return EmptyStateWidget(
        title: 'No videos found',
        subtitle: 'Try searching with different keywords for "${state.query}"',
        icon: Icons.search_off,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(videoSearchProvider.notifier).refresh(),
      child: viewMode == ViewMode.grid
          ? _buildGridView(state)
          : _buildListView(state),
    );
  }

  Widget _buildGridView(VideoSearchState state) {
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);
    final padding = ResponsiveHelper.getScreenPadding(context);

    // Video items need different aspect ratio (16:9 + info)
    final aspectRatio = ResponsiveHelper.isMobile(context) ? 0.75 : 0.85;

    return GridView.builder(
      controller: _scrollController,
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final item = state.items[index];
        return VideoGridItem(
          item: item,
          onTap: () => _openVideo(item),
          onSave: () => _saveVideo(item),
          onLike: () => _toggleLike(item),
          onShare: () => _shareVideo(item),
        );
      },
    );
  }

  Widget _buildListView(VideoSearchState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final item = state.items[index];
        return VideoListItem(
          item: item,
          onTap: () => _openVideo(item),
          onSave: () => _saveVideo(item),
          onLike: () => _toggleLike(item),
          onShare: () => _shareVideo(item),
        );
      },
    );
  }

  void _showLikedVideos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LikedVideosScreen()),
    );
  }

  void _showSavedVideos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SavedVideosScreen()),
    );
  }
}
