import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/video_file.dart';

class VideoFileListItem extends StatelessWidget {
  final VideoFile file;
  final String identifier;
  final bool isFavorite;
  final String? thumbnailUrl;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const VideoFileListItem({
    super.key,
    required this.file,
    required this.identifier,
    required this.isFavorite,
    this.thumbnailUrl,
    required this.onPlay,
    required this.onDownload,
    required this.onShare,
    required this.onFavorite,
  });

  String? get _thumbnailUrl {
    if (thumbnailUrl != null) return thumbnailUrl;
    return 'https://archive.org/services/img/$identifier';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 12,
        vertical: 2,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail
              _VideoThumbnail(
                thumbnailUrl: _thumbnailUrl,
                file: file,
                size: isSmallScreen ? 52 : 60,
                colorScheme: colorScheme,
              ),
              SizedBox(width: isSmallScreen ? 8 : 10),
              // Content - Use Expanded to prevent overflow
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title + Meta
                    _TitleMeta(
                      file: file,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                      isSmallScreen: isSmallScreen,
                    ),
                    const SizedBox(height: 6),
                    // Slim Action Bar - Fixed
                    _SlimActionBar(
                      isFavorite: isFavorite,
                      isSmallScreen: isSmallScreen,
                      colorScheme: colorScheme,
                      onDownload: onDownload,
                      onShare: onShare,
                      onFavorite: onFavorite,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              // 3-dot menu
              _MoreMenu(
                isFavorite: isFavorite,
                onDownload: onDownload,
                onShare: onShare,
                onFavorite: onFavorite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  final String? thumbnailUrl;
  final VideoFile file;
  final double size;
  final ColorScheme colorScheme;

  const _VideoThumbnail({
    required this.thumbnailUrl,
    required this.file,
    required this.size,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final width = size * 1.2;
    final height = size;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail Image
            if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildShimmer(),
                errorWidget: (context, url, error) => _buildFallback(),
                fadeInDuration: const Duration(milliseconds: 200),
              )
            else
              _buildFallback(),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),

            // Play button
            Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: size * 0.35,
                  color: Colors.white,
                ),
              ),
            ),

            // Quality badge
            Positioned(
              top: 3,
              left: 3,
              child: _QualityBadge(quality: file.quality),
            ),

            // Duration
            if (file.formattedDuration.isNotEmpty)
              Positioned(
                bottom: 3,
                right: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    file.formattedDuration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surface,
      child: Container(color: Colors.white),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: size * 0.4,
          color: colorScheme.outline,
        ),
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  final VideoQuality quality;

  const _QualityBadge({required this.quality});

  @override
  Widget build(BuildContext context) {
    final label = _getLabel();
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: _getColor(),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (quality) {
      case VideoQuality.uhd4k:
        return Colors.purple;
      case VideoQuality.hd1080:
        return Colors.blue;
      case VideoQuality.hd720:
        return Colors.green;
      case VideoQuality.high:
        return Colors.teal;
      case VideoQuality.medium:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getLabel() {
    switch (quality) {
      case VideoQuality.uhd4k:
        return '4K';
      case VideoQuality.hd1080:
        return 'HD';
      case VideoQuality.hd720:
        return '720';
      case VideoQuality.high:
        return 'HQ';
      case VideoQuality.medium:
        return 'MQ';
      default:
        return '';
    }
  }
}

class _TitleMeta extends StatelessWidget {
  final VideoFile file;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final bool isSmallScreen;

  const _TitleMeta({
    required this.file,
    required this.textTheme,
    required this.colorScheme,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    final metaColor = colorScheme.onSurface.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Row(
          children: [
            Expanded(
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallScreen ? 12 : 13,
                ),
              ),
            ),
            if (file.isOriginal) ...[
              const SizedBox(width: 4),
              _MicroBadge(label: 'ORIG', color: Colors.orange),
            ],
          ],
        ),
        const SizedBox(height: 2),
        // Meta - Wrap to prevent overflow
        _MetaRow(
          file: file,
          colorScheme: colorScheme,
          metaColor: metaColor,
          isSmallScreen: isSmallScreen,
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final VideoFile file;
  final ColorScheme colorScheme;
  final Color metaColor;
  final bool isSmallScreen;

  const _MetaRow({
    required this.file,
    required this.colorScheme,
    required this.metaColor,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = isSmallScreen ? 10.0 : 11.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use FittedBox to scale down if needed
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.extension.toUpperCase(),
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                _MicroDot(color: metaColor),
                Text(
                  file.formattedSize,
                  style: TextStyle(fontSize: fontSize, color: metaColor),
                ),
                if (file.formattedDuration.isNotEmpty) ...[
                  _MicroDot(color: metaColor),
                  Text(
                    file.formattedDuration,
                    style: TextStyle(fontSize: fontSize, color: metaColor),
                  ),
                ],
                if (file.resolution.isNotEmpty && !isSmallScreen) ...[
                  _MicroDot(color: metaColor),
                  Text(
                    file.resolution,
                    style: TextStyle(fontSize: fontSize - 1, color: metaColor),
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

class _SlimActionBar extends StatelessWidget {
  final bool isFavorite;
  final bool isSmallScreen;
  final ColorScheme colorScheme;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const _SlimActionBar({
    required this.isFavorite,
    required this.isSmallScreen,
    required this.colorScheme,
    required this.onDownload,
    required this.onShare,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final chipSpacing = isSmallScreen ? 4.0 : 6.0;

        // Calculate available width for each chip
        // 3 chips + 2 spaces between them
        final availableChipWidth = (maxWidth - (chipSpacing * 2)) / 3;

        // If very narrow, use icons only
        final useIconsOnly = availableChipWidth < 55;

        if (useIconsOnly) {
          return _IconOnlyActions(
            isFavorite: isFavorite,
            onDownload: onDownload,
            onShare: onShare,
            onFavorite: onFavorite,
          );
        }

        return Row(
          children: [
            Flexible(
              child: _SlimActionChip(
                icon: Icons.download_rounded,
                label: 'Save',
                onTap: onDownload,
                isSmallScreen: isSmallScreen,
              ),
            ),
            SizedBox(width: chipSpacing),
            Flexible(
              child: _SlimActionChip(
                icon: isFavorite ? Icons.star : Icons.star_border,
                label: isFavorite ? 'Favorite' : 'Favorite',
                onTap: onFavorite,
                isSmallScreen: isSmallScreen,
                iconColor: isFavorite ? Colors.red : null,
                isActive: isFavorite,
              ),
            ),
            SizedBox(width: chipSpacing),
            Flexible(
              child: _SlimActionChip(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: onShare,
                isSmallScreen: isSmallScreen,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IconOnlyActions extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const _IconOnlyActions({
    required this.isFavorite,
    required this.onDownload,
    required this.onShare,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconButton(
          icon: Icons.download_rounded,
          onTap: onDownload,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 6),
        _IconButton(
          icon: isFavorite ? Icons.star : Icons.star_border,
          onTap: onFavorite,
          color: isFavorite ? Colors.red : colorScheme.primary,
        ),
        const SizedBox(width: 8),
        _IconButton(
          icon: Icons.share_rounded,
          onTap: onShare,
          color: colorScheme.primary,
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _IconButton({
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
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _SlimActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSmallScreen;
  final Color? iconColor;
  final bool isActive;

  const _SlimActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isSmallScreen,
    this.iconColor,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              Icon(icon, size: isSmallScreen ? 12 : 14, color: effectiveColor),
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

class _MicroBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MicroBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
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
  final bool isFavorite;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const _MoreMenu({
    required this.isFavorite,
    required this.onDownload,
    required this.onShare,
    required this.onFavorite,
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
          _menuItem('download', Icons.download_rounded, 'Download'),
          _menuItem(
            'favorite',
            isFavorite ? Icons.star : Icons.star_border,
            isFavorite ? 'Favorite' : 'Favorite',
            iconColor: isFavorite ? Colors.red : null,
          ),
          _menuItem('share', Icons.share_rounded, 'Share'),
        ],
        onSelected: (value) {
          switch (value) {
            case 'download':
              onDownload();
            case 'share':
              onShare();
            case 'favorite':
              onFavorite();
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
