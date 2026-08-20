import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/archive_constants.dart';
import '../../../widgets/download_button.dart';
import '../models/video_item.dart';

class VideoListItem extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const VideoListItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onSave,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 12,
        vertical: 3,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;

              // Use compact layout for narrow screens
              if (maxWidth < 280) {
                return _CompactLayout(
                  item: item,
                  colorScheme: colorScheme,
                  onSave: onSave,
                  onLike: onLike,
                  onShare: onShare,
                );
              }

              return _StandardLayout(
                item: item,
                colorScheme: colorScheme,
                isSmallScreen: isSmallScreen,
                maxWidth: maxWidth,
                onSave: onSave,
                onLike: onLike,
                onShare: onShare,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StandardLayout extends StatelessWidget {
  final VideoItem item;
  final ColorScheme colorScheme;
  final bool isSmallScreen;
  final double maxWidth;
  final VoidCallback onSave;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const _StandardLayout({
    required this.item,
    required this.colorScheme,
    required this.isSmallScreen,
    required this.maxWidth,
    required this.onSave,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate thumbnail size based on available width
    final thumbnailWidth = isSmallScreen
        ? 100.0
        : (maxWidth < 350 ? 110.0 : 130.0);
    final thumbnailHeight = thumbnailWidth * 0.56; // 16:9 ratio

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail
        _VideoThumbnail(
          item: item,
          width: thumbnailWidth,
          height: thumbnailHeight,
          colorScheme: colorScheme,
          isSmallScreen: isSmallScreen,
        ),
        SizedBox(width: isSmallScreen ? 8 : 10),
        // Info
        Expanded(
          child: _InfoSection(
            item: item,
            colorScheme: colorScheme,
            isSmallScreen: isSmallScreen,
            onSave: onSave,
            onLike: onLike,
            onShare: onShare,
          ),
        ),
        const SizedBox(width: 4),
        // 3-dot menu
        _MoreMenu(item: item, onSave: onSave, onLike: onLike, onShare: onShare),
      ],
    );
  }
}

class _CompactLayout extends StatelessWidget {
  final VideoItem item;
  final ColorScheme colorScheme;
  final VoidCallback onSave;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const _CompactLayout({
    required this.item,
    required this.colorScheme,
    required this.onSave,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thumbnail + Title row
        Row(
          children: [
            _VideoThumbnail(
              item: item,
              width: 80,
              height: 45,
              colorScheme: colorScheme,
              isSmallScreen: true,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.creator != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.creator!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _MoreMenu(
              item: item,
              onSave: onSave,
              onLike: onLike,
              onShare: onShare,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Meta + Actions
        Row(
          children: [
            Expanded(
              child: _CompactMeta(item: item, colorScheme: colorScheme),
            ),
            _CompactActions(
              item: item,
              colorScheme: colorScheme,
              onSave: onSave,
              onLike: onLike,
              onShare: onShare,
            ),
          ],
        ),
      ],
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  final VideoItem item;
  final double width;
  final double height;
  final ColorScheme colorScheme;
  final bool isSmallScreen;

  const _VideoThumbnail({
    required this.item,
    required this.width,
    required this.height,
    required this.colorScheme,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
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
                  size: isSmallScreen ? 24 : 28,
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
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),

            // Play button
            Center(
              child: Container(
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: isSmallScreen ? 16 : 20,
                ),
              ),
            ),

            // Duration badge
            if (item.formattedDuration.isNotEmpty)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 3 : 4,
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
                      fontSize: isSmallScreen ? 8 : 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final VideoItem item;
  final ColorScheme colorScheme;
  final bool isSmallScreen;
  final VoidCallback onSave;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const _InfoSection({
    required this.item,
    required this.colorScheme,
    required this.isSmallScreen,
    required this.onSave,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 12 : 13,
          ),
        ),

        // Creator
        if (item.creator != null) ...[
          const SizedBox(height: 2),
          Text(
            item.creator!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontSize: isSmallScreen ? 10 : 11,
            ),
          ),
        ],

        const SizedBox(height: 4),

        // Meta row
        _MetaRow(
          item: item,
          colorScheme: colorScheme,
          isSmallScreen: isSmallScreen,
        ),

        const SizedBox(height: 6),

        // Action bar
        _SlimActionBar(
          item: item,
          isSmallScreen: isSmallScreen,
          colorScheme: colorScheme,
          onSave: onSave,
          onLike: onLike,
          onShare: onShare,
        ),
      ],
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
    final fontSize = isSmallScreen ? 9.0 : 10.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Frame size / resolution (left)
                if (item.resolution != null) ...[
                  Text(
                    item.resolution!,
                    style: TextStyle(fontSize: fontSize, color: metaColor),
                  ),
                  const SizedBox(width: 4),
                ] else ...[
                  Icon(Icons.format_color_reset, size: 10, color: Colors.grey),
                  const SizedBox(width: 4),
                ],
                // File size (center)
                _MicroDot(color: metaColor),
                const SizedBox(width: 2),
                Text(
                  item.formattedSize,
                  style: TextStyle(fontSize: fontSize, color: metaColor),
                ),
                const Spacer(),
                // Duration on right
                if (item.formattedDuration.isNotEmpty) ...[
                  _MicroDot(color: metaColor),
                  const SizedBox(width: 2),
                  Text(
                    item.formattedDuration,
                    style: TextStyle(fontSize: fontSize, color: metaColor),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompactMeta extends StatelessWidget {
  final VideoItem item;
  final ColorScheme colorScheme;

  const _CompactMeta({required this.item, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final metaColor = colorScheme.onSurface.withValues(alpha: 0.55);

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
            style: TextStyle(fontSize: 10, color: metaColor),
          ),
          if (item.year != null) ...[
            _MicroDot(color: metaColor),
            Text(item.year!, style: TextStyle(fontSize: 10, color: metaColor)),
          ],
          _MicroDot(color: metaColor),
          Text(
            item.formattedSize,
            style: TextStyle(fontSize: 10, color: metaColor),
          ),
        ],
      ),
    );
  }
}

class _SlimActionBar extends StatelessWidget {
  final VideoItem item;
  final bool isSmallScreen;
  final ColorScheme colorScheme;
  final VoidCallback onSave;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const _SlimActionBar({
    required this.item,
    required this.isSmallScreen,
    required this.colorScheme,
    required this.onSave,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final chipSpacing = isSmallScreen ? 4.0 : 6.0;
        final availableChipWidth = (maxWidth - (chipSpacing * 2)) / 3;
        final useIconsOnly = availableChipWidth < 50;

        if (useIconsOnly) {
          return _IconOnlyActions(
            item: item,
            colorScheme: colorScheme,
            onSave: onSave,
            onLike: onLike,
            onShare: onShare,
          );
        }

        return Row(
          children: [
            // Download button
            Flexible(
              child: _DownloadChip(
                item: item,
                isSmallScreen: isSmallScreen,
                colorScheme: colorScheme,
              ),
            ),
            SizedBox(width: chipSpacing),
            // Like
            Flexible(
              child: _SlimActionChip(
                icon: item.isLiked ? Icons.favorite : Icons.favorite_border,
                label: 'Like',
                onTap: onLike,
                isSmallScreen: isSmallScreen,
                colorScheme: colorScheme,
                isActive: item.isLiked,
                iconColor: Colors.red,
              ),
            ),
            SizedBox(width: chipSpacing),
            // Save
            Flexible(
              child: _SlimActionChip(
                icon: item.isSaved ? Icons.bookmark : Icons.bookmark_border,
                label: 'Save',
                onTap: onSave,
                isSmallScreen: isSmallScreen,
                colorScheme: colorScheme,
                isActive: item.isSaved,
              ),
            ),
            SizedBox(width: chipSpacing),
            // Share
            Flexible(
              child: _SlimActionChip(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: onShare,
                isSmallScreen: isSmallScreen,
                colorScheme: colorScheme,
              ),
            ),
          ],
        );
      },
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
      height: isSmallScreen ? 26 : 28,
      child: DownloadButton(
        identifier: item.identifier,
        title: item.title,
        downloadUrl: item.streamUrl,
        mediaType: ArchiveConstants.mediaTypeVideo,
        thumbnailUrl: item.thumbnailUrl,
        size: isSmallScreen ? 26 : 28,
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
      ),
    );
  }
}

class _IconOnlyActions extends StatelessWidget {
  final VideoItem item;
  final ColorScheme colorScheme;
  final VoidCallback onSave;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const _IconOnlyActions({
    required this.item,
    required this.colorScheme,
    required this.onSave,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Download button
        SizedBox(
          width: 28,
          height: 28,
          child: DownloadButton(
            identifier: item.identifier,
            title: item.title,
            downloadUrl: item.streamUrl,
            mediaType: ArchiveConstants.mediaTypeVideo,
            thumbnailUrl: item.thumbnailUrl,
            size: 28,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(width: 6),
        _MiniIconButton(
          icon: item.isLiked ? Icons.favorite : Icons.favorite_border,
          onTap: onLike,
          color: Colors.red,
        ),
        const SizedBox(width: 6),
        _MiniIconButton(
          icon: item.isSaved ? Icons.bookmark : Icons.bookmark_border,
          onTap: onSave,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 6),
        _MiniIconButton(
          icon: Icons.share_rounded,
          onTap: onShare,
          color: colorScheme.primary,
        ),
      ],
    );
  }
}

class _CompactActions extends StatelessWidget {
  final VideoItem item;
  final ColorScheme colorScheme;
  final VoidCallback onSave;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const _CompactActions({
    required this.item,
    required this.colorScheme,
    required this.onSave,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
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
        ),
        const SizedBox(width: 6),
        _MiniIconButton(
          icon: item.isLiked ? Icons.favorite : Icons.favorite_border,
          onTap: onLike,
          color: Colors.red,
        ),
        const SizedBox(width: 6),
        _MiniIconButton(
          icon: item.isSaved ? Icons.bookmark : Icons.bookmark_border,
          onTap: onSave,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 6),
        _MiniIconButton(
          icon: Icons.share_rounded,
          onTap: onShare,
          color: colorScheme.primary,
        ),
      ],
    );
  }
}

class _SlimActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSmallScreen;
  final ColorScheme colorScheme;
  final Color? iconColor;
  final bool isActive;

  const _SlimActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isSmallScreen,
    required this.colorScheme,
    this.iconColor,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? colorScheme.primary;
    final bgColor = isActive
        ? effectiveColor.withValues(alpha: 0.1)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 5 : 6,
            vertical: isSmallScreen ? 4 : 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isSmallScreen ? 12 : 13, color: effectiveColor),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 9 : 10,
                    fontWeight: FontWeight.w500,
                    color: effectiveColor,
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
          padding: const EdgeInsets.all(6),
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

class _MoreMenu extends StatelessWidget {
  final VideoItem item;
  final VoidCallback onSave;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const _MoreMenu({
    required this.item,
    required this.onSave,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        padding: EdgeInsets.zero,
        splashRadius: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          _menuItem('play', Icons.play_arrow_rounded, 'Play'),
          _menuItem('download', Icons.download_rounded, 'Download'),
          _menuItem(
            'like',
            item.isLiked ? Icons.favorite : Icons.favorite_border,
            item.isLiked ? 'Unlike' : 'Like',
            iconColor: item.isLiked ? Colors.red : null,
          ),
          _menuItem(
            'save',
            item.isSaved ? Icons.bookmark : Icons.bookmark_border,
            item.isSaved ? 'Unsave' : 'Save',
            iconColor: item.isSaved
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          _menuItem('share', Icons.share_rounded, 'Share'),
        ],
        onSelected: (value) {
          switch (value) {
            case 'save':
              onSave();
              break;
            case 'like':
              onLike();
              break;
            case 'share':
              onShare();
              break;
          }
        },
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? iconColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
