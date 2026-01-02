import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/archive_constants.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../providers/download_providers.dart';
import '../models/thumbnail_file.dart';
import '../models/video_file.dart';
import '../models/video_item.dart';
import '../models/video_metadata.dart';
import '../../../models/media_file.dart';
import '../../../features/video_player/video_player_launcher.dart';
import '../providers/video_metadata_provider.dart';
import '../widgets/thumbnail_grid_item.dart';
import '../widgets/thumbnail_list_item.dart';
import '../widgets/video_file_grid_item.dart';
import '../widgets/video_file_list_item.dart';

class VideoMetaScreen extends ConsumerStatefulWidget {
  final VideoItem videoItem;

  const VideoMetaScreen({super.key, required this.videoItem});

  @override
  ConsumerState<VideoMetaScreen> createState() => _VideoMetaScreenState();
}

class _VideoMetaScreenState extends ConsumerState<VideoMetaScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  void _initTabController() {
    _tabController = TabController(length: 2, vsync: this);
    _isInitialized = true;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  String get _identifier => widget.videoItem.identifier;

  @override
  Widget build(BuildContext context) {
    // Safety check
    if (!_isInitialized || _tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final metadataState = ref.watch(videoMetadataNotifierProvider(_identifier));
    final viewMode = ref.watch(metadataViewModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(context, metadataState, viewMode),
            _buildTabBarHeader(colorScheme, metadataState),
          ];
        },
        body: _buildTabBarView(metadataState, viewMode),
      ),
      floatingActionButton: _buildFAB(metadataState),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    VideoMetadataState metadataState,
    MetadataViewMode viewMode,
  ) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      floating: false,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeader(context, metadataState),
      ),
      actions: [
        IconButton(
          icon: Icon(
            viewMode == MetadataViewMode.grid
                ? Icons.view_list
                : Icons.grid_view,
          ),
          onPressed: () {
            ref
                .read(metadataViewModeProvider.notifier)
                .state = viewMode == MetadataViewMode.grid
                ? MetadataViewMode.list
                : MetadataViewMode.grid;
          },
          tooltip: viewMode == MetadataViewMode.grid
              ? 'List View'
              : 'Grid View',
        ),
        PopupMenuButton<VideoFileFilter>(
          icon: const Icon(Icons.filter_alt_outlined),
          tooltip: 'Filter files',
          onSelected: (filter) {
            ref.read(videoFileFilterProvider.notifier).state = filter;
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: VideoFileFilter.all,
              child: Text('All Files'),
            ),
            const PopupMenuItem(
              value: VideoFileFilter.original,
              child: Text('Original Only'),
            ),
            const PopupMenuItem(
              value: VideoFileFilter.derivative,
              child: Text('Derivatives Only'),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.open_in_browser),
          onPressed: () => _openInBrowser(widget.videoItem.detailsUrl),
          tooltip: 'Open in Browser',
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _shareVideo,
          tooltip: 'Share',
        ),
      ],
    );
  }

  Widget _buildTabBarHeader(ColorScheme colorScheme, VideoMetadataState state) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.video_file, size: 18),
                  const SizedBox(width: 8),
                  Text('Videos (${state.videoFilesCount})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image, size: 18),
                  const SizedBox(width: 8),
                  Text('Images (${state.thumbnailsCount})'),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.surface,
      ),
    );
  }

  Widget _buildTabBarView(VideoMetadataState state, MetadataViewMode viewMode) {
    if (state.isLoading) {
      return TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          LoadingWidget(message: 'Loading video files...'),
          LoadingWidget(message: 'Loading images...'),
        ],
      );
    }

    if (state.error != null) {
      return TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          AppErrorWidget(message: state.error!, onRetry: _refreshMetadata),
          AppErrorWidget(message: state.error!, onRetry: _refreshMetadata),
        ],
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildVideosTab(state, viewMode),
        _buildImagesTab(state, viewMode),
      ],
    );
  }

  String? _findThumbnailForFile(
    VideoFile file,
    List<ThumbnailFile> thumbnails,
  ) {
    if (thumbnails.isEmpty) {
      return widget.videoItem.thumbnailUrl;
    }

    final fileName = file.name.toLowerCase();

    // Remove extension
    final fileBaseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    // Priority 1: Exact match with frame number (e.g., video.mp4 -> video.mp4_000001.jpg)
    for (final thumb in thumbnails) {
      final thumbName = thumb.name.toLowerCase();
      if (thumbName.startsWith(fileName) ||
          thumbName.startsWith('${fileName}_')) {
        return thumb.getUrl(_identifier);
      }
    }

    // Priority 2: Base name match (e.g., video.mp4 -> video_thumb.jpg)
    for (final thumb in thumbnails) {
      final thumbName = thumb.name.toLowerCase();
      if (thumbName.contains(fileBaseName)) {
        return thumb.getUrl(_identifier);
      }
    }

    // Priority 3: Thumbnail with "thumb" in name
    final thumbFiles = thumbnails.where((t) => t.isThumbnail).toList();
    if (thumbFiles.isNotEmpty) {
      return thumbFiles.first.getUrl(_identifier);
    }

    // Priority 4: First image or main thumbnail
    return thumbnails.isNotEmpty
        ? thumbnails.first.getUrl(_identifier)
        : widget.videoItem.thumbnailUrl;
  }

  Widget? _buildFAB(VideoMetadataState state) {
    final bestFile = state.bestQualityFile;
    if (bestFile == null) return null;

    return FloatingActionButton.extended(
      onPressed: () => _playFile(bestFile),
      icon: const Icon(Icons.play_arrow),
      label: Text(
        bestFile.quality.badge.isNotEmpty
            ? 'Play ${bestFile.quality.badge}'
            : 'Play',
      ),
    );
  }

  Widget _buildHeader(BuildContext context, VideoMetadataState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metadata = state.metadata;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.8),
            colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.videoItem.thumbnailUrl,
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 120,
                        height: 90,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 120,
                        height: 90,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.movie_outlined, size: 40),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      metadata?.title ?? widget.videoItem.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_getCreator(metadata) != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _getCreator(metadata)!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _buildInfoChips(metadata),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _getCreator(VideoMetadata? metadata) {
    return metadata?.creator ?? widget.videoItem.creator;
  }

  List<Widget> _buildInfoChips(VideoMetadata? metadata) {
    final chips = <Widget>[];

    if (widget.videoItem.year != null) {
      chips.add(
        _InfoChip(icon: Icons.calendar_today, label: widget.videoItem.year!),
      );
    }

    chips.add(
      _InfoChip(
        icon: Icons.visibility,
        label:
            metadata?.formattedDownloads ?? widget.videoItem.formattedDownloads,
      ),
    );

    chips.add(
      _InfoChip(
        icon: Icons.sd_storage,
        label: metadata?.formattedItemSize ?? widget.videoItem.formattedSize,
      ),
    );

    if (metadata != null && metadata.filesCount > 0) {
      chips.add(
        _InfoChip(icon: Icons.folder, label: '${metadata.filesCount} files'),
      );
    }

    return chips;
  }

  Widget _buildVideosTab(VideoMetadataState state, MetadataViewMode viewMode) {
    final filter = ref.watch(videoFileFilterProvider);
    final files = state.getFilteredVideoFiles(filter);

    if (files.isEmpty) {
      return EmptyStateWidget(
        title: 'No Video Files',
        subtitle: filter == VideoFileFilter.all
            ? 'No playable video files found'
            : 'No ${filter.name} video files found',
        icon: Icons.video_file_outlined,
      );
    }

    return Column(
      children: [
        if (filter != VideoFileFilter.all)
          _buildFilterBanner(filter, files.length),
        Expanded(
          child: viewMode == MetadataViewMode.grid
              ? _buildVideosGrid(files, state)
              : _buildVideosList(files, state),
        ),
      ],
    );
  }

  Widget _buildFilterBanner(VideoFileFilter filter, int count) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.filter_alt,
            size: 16,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            'Showing ${filter.name} files only ($count)',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              ref.read(videoFileFilterProvider.notifier).state =
                  VideoFileFilter.all;
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosGrid(List<VideoFile> files, VideoMetadataState state) {
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);
    final padding = ResponsiveHelper.getScreenPadding(context);

    return RefreshIndicator(
      onRefresh: _refreshMetadata,
      child: GridView.builder(
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: files.length,
        itemBuilder: (context, index) =>
            _buildVideoGridItem(files[index], state),
      ),
    );
  }

  Widget _buildVideoGridItem(VideoFile file, VideoMetadataState state) {
    return VideoFileGridItem(
      file: file,
      identifier: _identifier,
      isLiked: state.isFileLiked(file.name),
      isFavorite: state.isFileFavorite(file.name),
      thumbnailUrl: _findThumbnailForFile(file, state.allThumbnails),
      onPlay: () => _playFile(file),
      onDownload: () => _downloadFile(file),
      onShare: () => _shareFile(file),
      onLike: () => _toggleFileLike(file.name),
      onFavorite: () => _toggleFileFavorite(file),
    );
  }

  Widget _buildVideosList(List<VideoFile> files, VideoMetadataState state) {
    return RefreshIndicator(
      onRefresh: _refreshMetadata,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: files.length,
        itemBuilder: (context, index) =>
            _buildVideoListItem(files[index], state),
      ),
    );
  }

  Widget _buildVideoListItem(VideoFile file, VideoMetadataState state) {
    return VideoFileListItem(
      file: file,
      identifier: _identifier,
      isLiked: state.isFileLiked(file.name),
      isFavorite: state.isFileFavorite(file.name),
      thumbnailUrl: _findThumbnailForFile(file, state.allThumbnails),
      onPlay: () => _playFile(file),
      onDownload: () => _downloadFile(file),
      onShare: () => _shareFile(file),
      onLike: () => _toggleFileLike(file.name),
      onFavorite: () => _toggleFileFavorite(file),
    );
  }

  Widget _buildImagesTab(VideoMetadataState state, MetadataViewMode viewMode) {
    final thumbnails = state.allThumbnails;

    if (thumbnails.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Images',
        subtitle: 'No images found for this item',
        icon: Icons.image_not_supported_outlined,
      );
    }

    if (viewMode == MetadataViewMode.grid) {
      return _buildImagesGrid(thumbnails, state);
    } else {
      return _buildImagesList(thumbnails, state);
    }
  }

  Widget _buildImagesGrid(
    List<ThumbnailFile> thumbnails,
    VideoMetadataState state,
  ) {
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);
    final padding = ResponsiveHelper.getScreenPadding(context);

    return RefreshIndicator(
      onRefresh: _refreshMetadata,
      child: GridView.builder(
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: thumbnails.length,
        itemBuilder: (context, index) =>
            _buildThumbnailGridItem(thumbnails[index], state),
      ),
    );
  }

  Widget _buildThumbnailGridItem(
    ThumbnailFile thumbnail,
    VideoMetadataState state,
  ) {
    return ThumbnailGridItem(
      thumbnail: thumbnail,
      identifier: _identifier,
      isLiked: state.isThumbnailLiked(thumbnail.name),
      onTap: () => _viewImage(thumbnail),
      onDownload: () => _downloadImage(thumbnail),
      onShare: () => _shareImage(thumbnail),
      onLike: () => _toggleThumbnailLike(thumbnail.name),
      onFavorite: () => _toggleFavorite(thumbnail),
    );
  }

  Widget _buildImagesList(
    List<ThumbnailFile> thumbnails,
    VideoMetadataState state,
  ) {
    return RefreshIndicator(
      onRefresh: _refreshMetadata,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: thumbnails.length,
        itemBuilder: (context, index) =>
            _buildThumbnailListItem(thumbnails[index], state),
      ),
    );
  }

  Widget _buildThumbnailListItem(
    ThumbnailFile thumbnail,
    VideoMetadataState state,
  ) {
    return ThumbnailListItem(
      thumbnail: thumbnail,
      identifier: _identifier,
      isLiked: state.isThumbnailLiked(thumbnail.name),
      isFavorite: state.isThumbnailFavorite(thumbnail.name),
      onTap: () => _viewImage(thumbnail),
      onDownload: () => _downloadImage(thumbnail),
      onShare: () => _shareImage(thumbnail),
      onLike: () => _toggleThumbnailLike(thumbnail.name),
      onFavorite: () => _toggleFavorite(thumbnail),
    );
  }

  // ========== Actions ==========

  Future<void> _refreshMetadata() async {
    await ref
        .read(videoMetadataNotifierProvider(_identifier).notifier)
        .refresh();
  }

  void _toggleFileLike(String fileName) {
    try {
      ref
          .read(videoMetadataNotifierProvider(_identifier).notifier)
          .toggleFileLike(fileName);
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  void _toggleFileFavorite(VideoFile videoFile) {
    try {
      ref
          .read(videoMetadataNotifierProvider(_identifier).notifier)
          .toggleFileFavorite(videoFile.toMap());
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  void _toggleThumbnailLike(String fileName) {
    try {
      ref
          .read(videoMetadataNotifierProvider(_identifier).notifier)
          .toggleThumbnailLike(fileName);
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  void _toggleFavorite(ThumbnailFile thumbnail) {
    try {
      ref
          .read(videoMetadataNotifierProvider(_identifier).notifier)
          .toggleThumbnailFavorite(thumbnail.toMap());
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  Future<void> _playFile(VideoFile file) async {
    try {
      debugPrint(file.getUrl(_identifier));
      final created = DateTime.now();
      final MediaFile mediaFile = MediaFile(
        id: _identifier,
        name: file.displayName,
        path: file.getUrl(_identifier),
        type: MediaType.video,
        size: file.size as int,
        dateModified: created,
      );
      VideoPlayerLauncher.openGlobal(file: mediaFile);
    } catch (e) {
      _showSnackBar('Error playing video: $e');
    }
  }

  Future<void> _downloadFile(VideoFile file) async {
    try {
      await ref
          .read(downloadsProvider.notifier)
          .startDownload(
            identifier: '${_identifier}_${file.name.hashCode}',
            title: '${widget.videoItem.title} - ${file.displayName}',
            url: file.getUrl(_identifier),
            mediaType: ArchiveConstants.mediaTypeVideo,
            thumbnailUrl: widget.videoItem.thumbnailUrl,
          );
      _showSnackBar('Download started: ${file.displayName}');
    } catch (e) {
      _showSnackBar('Failed to start download');
    }
  }

  Future<void> _shareFile(VideoFile file) async {
    try {
      final url = file.getUrl(_identifier);
      await SharePlus.instance.share(
        ShareParams(
          title: 'Share: ${file.displayName}',
          text:
              '${widget.videoItem.title}\n\n'
              'File: ${file.displayName}\n'
              'Size: ${file.formattedSize}\n\n'
              'Download: $url',
          subject: widget.videoItem.title,
        ),
      );
    } catch (e) {
      _showSnackBar('Error sharing');
    }
  }

  Future<void> _viewImage(ThumbnailFile thumbnail) async {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          imageUrl: thumbnail.getUrl(_identifier),
          title: thumbnail.displayName,
        ),
      ),
    );
  }

  Future<void> _downloadImage(ThumbnailFile thumbnail) async {
    try {
      await ref
          .read(downloadsProvider.notifier)
          .startDownload(
            identifier: '${_identifier}_${thumbnail.name.hashCode}',
            title: '${widget.videoItem.title} - ${thumbnail.displayName}',
            url: thumbnail.getUrl(_identifier),
            mediaType: 'image',
            thumbnailUrl: thumbnail.getUrl(_identifier),
          );
      _showSnackBar('Download started: ${thumbnail.displayName}');
    } catch (e) {
      _showSnackBar('Failed to start download');
    }
  }

  Future<void> _shareImage(ThumbnailFile thumbnail) async {
    try {
      final url = thumbnail.getUrl(_identifier);
      await SharePlus.instance.share(
        ShareParams(
          title: 'Share: ${thumbnail.displayName}',
          text:
              '${widget.videoItem.title}\n\n'
              'Image: ${thumbnail.displayName}\n'
              'Size: ${thumbnail.formattedSize}\n\n'
              'Download: $url',
          subject: thumbnail.displayName,
        ),
      );
    } catch (e) {
      _showSnackBar('Error sharing');
    }
  }

  Future<void> _openInBrowser(String url) async {
    try {
      /* final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } */
    } catch (e) {
      _showSnackBar('Could not open browser');
    }
  }

  Future<void> _shareVideo() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Share Archive Url',
          text:
              '${widget.videoItem.title}\n\n'
              'Watch on Archive.org: ${widget.videoItem.detailsUrl}',
          uri: Uri.parse(widget.videoItem.detailsUrl),
        ),
      );
    } catch (e) {
      _showSnackBar('Error sharing');
    }
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
}

// ========== Helper Widgets ==========

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, {required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String title;

  const _FullScreenImageViewer({required this.imageUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  title: 'Share: $title',
                  text: 'Watch on Archive.org: $imageUrl\n\n',
                  uri: Uri.parse(imageUrl),
                ),
              );
            },
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (_, __, ___) => const Center(
              child: Icon(Icons.error_outline, size: 64, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}
