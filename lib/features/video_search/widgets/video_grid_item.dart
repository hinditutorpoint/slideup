import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/archive_constants.dart';
import '../../../widgets/download_button.dart';
import '../models/video_item.dart';

class VideoGridItem extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const VideoGridItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight = constraints.maxHeight;
            final totalWidth = constraints.maxWidth;
            final thumbnailHeight = totalHeight * 0.6;
            final infoHeight = totalHeight * 0.4;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Section
                SizedBox(
                  height: thumbnailHeight,
                  width: double.infinity,
                  child: _ThumbnailSection(
                    item: item,
                    colorScheme: colorScheme,
                    isSmallScreen: isSmallScreen,
                    onLike: onLike,
                  ),
                ),
                // Info Section
                SizedBox(
                  height: infoHeight,
                  width: totalWidth,
                  child: _InfoSection(
                    item: item,
                    colorScheme: colorScheme,
                    isSmallScreen: isSmallScreen,
                    availableWidth: totalWidth,
                    onShare: onShare,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ThumbnailSection extends StatelessWidget {
  final VideoItem item;
  final ColorScheme colorScheme;
  final bool isSmallScreen;
  final VoidCallback onLike;

  const _ThumbnailSection({
    required this.item,
    required this.colorScheme,
    required this.isSmallScreen,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail image
        CachedNetworkImage(
          imageUrl: item.thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: colorScheme.surfaceContainerHighest,
            highlightColor: colorScheme.surface,
            child: Container(color: Colors.white),
          ),
          errorWidget: (context, url, error) => Container(
            color: colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.movie_outlined,
              size: isSmallScreen ? 32 : 40,
              color: colorScheme.outline,
            ),
          ),
          fadeInDuration: const Duration(milliseconds: 200),
        ),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),

        // Play button - center
        Center(
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: isSmallScreen ? 24 : 28,
            ),
          ),
        ),

        // Like button - top right
        Positioned(
          top: 4,
          right: 4,
          child: _OverlayButton(
            icon: item.isLiked ? Icons.favorite : Icons.favorite_border,
            color: item.isLiked ? Colors.red : Colors.white,
            onTap: onLike,
            isSmallScreen: isSmallScreen,
          ),
        ),

        // Video badge - bottom left
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 4 : 5,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam,
                  color: Colors.white,
                  size: isSmallScreen ? 10 : 11,
                ),
                const SizedBox(width: 2),
                Text(
                  'VIDEO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 7 : 8,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Duration badge - bottom right
        if (item.formattedDuration.isNotEmpty)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 4 : 5,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                item.formattedDuration,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 9 : 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isSmallScreen;

  const _OverlayButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 4 : 5),
          child: Icon(icon, size: isSmallScreen ? 14 : 16, color: color),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final VideoItem item;
  final ColorScheme colorScheme;
  final bool isSmallScreen;
  final double availableWidth;
  final VoidCallback onShare;

  const _InfoSection({
    required this.item,
    required this.colorScheme,
    required this.isSmallScreen,
    required this.availableWidth,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          final showActions = availableHeight > 50;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Flexible(
                flex: 2,
                child: Text(
                  item.title,
                  maxLines: availableHeight > 70 ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 10 : 11,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Creator
              if (item.creator != null)
                Flexible(
                  flex: 1,
                  child: Text(
                    item.creator!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontSize: isSmallScreen ? 9 : 10,
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              // Meta row
              Flexible(
                flex: 1,
                child: _MetaRow(
                  item: item,
                  colorScheme: colorScheme,
                  isSmallScreen: isSmallScreen,
                ),
              ),
              if (showActions) ...[
                const SizedBox(height: 4),
                // Actions
                Flexible(
                  flex: 2,
                  child: _ActionBar(
                    item: item,
                    isSmallScreen: isSmallScreen,
                    availableWidth: constraints.maxWidth,
                    colorScheme: colorScheme,
                    onShare: onShare,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final VideoItem item;
  final ColorScheme colorScheme;
  final bool isSmallScreen;

  const _MetaRow({
    required this.item,
    required this.colorScheme,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    final metaColor = colorScheme.onSurface.withValues(alpha: 0.55);
    final fontSize = isSmallScreen ? 8.0 : 9.0;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility, size: 10, color: metaColor),
          const SizedBox(width: 2),
          Text(
            item.formattedDownloads,
            style: TextStyle(fontSize: fontSize, color: metaColor),
          ),
          if (item.year != null) ...[
            _MicroDot(color: metaColor),
            Text(
              item.year!,
              style: TextStyle(fontSize: fontSize, color: metaColor),
            ),
          ],
          _MicroDot(color: metaColor),
          Text(
            item.formattedSize,
            style: TextStyle(fontSize: fontSize, color: metaColor),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final VideoItem item;
  final bool isSmallScreen;
  final double availableWidth;
  final ColorScheme colorScheme;
  final VoidCallback onShare;

  const _ActionBar({
    required this.item,
    required this.isSmallScreen,
    required this.availableWidth,
    required this.colorScheme,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final useIconsOnly = availableWidth < 100;

    if (useIconsOnly) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _MiniDownloadButton(item: item, colorScheme: colorScheme),
          const SizedBox(width: 6),
          _MiniIconButton(
            icon: Icons.share_rounded,
            onTap: onShare,
            color: colorScheme.primary,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _DownloadChip(
            item: item,
            isSmallScreen: isSmallScreen,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _ActionChip(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: onShare,
            isSmallScreen: isSmallScreen,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }
}

class _DownloadChip extends StatelessWidget {
  final VideoItem item;
  final bool isSmallScreen;
  final ColorScheme colorScheme;

  const _DownloadChip({
    required this.item,
    required this.isSmallScreen,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isSmallScreen ? 24 : 26,
      child: DownloadButton(
        identifier: item.identifier,
        title: item.title,
        downloadUrl: item.streamUrl,
        mediaType: ArchiveConstants.mediaTypeVideo,
        thumbnailUrl: item.thumbnailUrl,
        size: isSmallScreen ? 24 : 26,
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
      ),
    );
  }
}

class _MiniDownloadButton extends StatelessWidget {
  final VideoItem item;
  final ColorScheme colorScheme;

  const _MiniDownloadButton({required this.item, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: DownloadButton(
        identifier: item.identifier,
        title: item.title,
        downloadUrl: item.streamUrl,
        mediaType: ArchiveConstants.mediaTypeVideo,
        thumbnailUrl: item.thumbnailUrl,
        size: 26,
        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSmallScreen;
  final ColorScheme colorScheme;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isSmallScreen,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 4 : 6,
            vertical: isSmallScreen ? 4 : 5,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isSmallScreen ? 11 : 12,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 9 : 10,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _MiniIconButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

class _MicroDot extends StatelessWidget {
  final Color color;

  const _MicroDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 2,
        height: 2,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
