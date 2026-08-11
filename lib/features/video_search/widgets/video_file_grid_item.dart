import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/video_file.dart';

class VideoFileGridItem extends StatelessWidget {
  final VideoFile file;
  final String identifier;
  final bool isFavorite;
  final String? thumbnailUrl;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const VideoFileGridItem({
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onPlay,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight = constraints.maxHeight;
            final thumbnailHeight = totalHeight * 0.58;
            final infoHeight = totalHeight * 0.42;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Section
                SizedBox(
                  height: thumbnailHeight,
                  width: double.infinity,
                  child: _VideoThumbnail(
                    thumbnailUrl: _thumbnailUrl,
                    file: file,
                    isFavorite: isFavorite,
                    colorScheme: colorScheme,
                    isSmallScreen: isSmallScreen,
                    onDownload: onDownload,
                    onShare: onShare,
                    onFavorite: onFavorite,
                  ),
                ),
                // Info Section
                SizedBox(
                  height: infoHeight,
                  child: _InfoSection(
                    file: file,
                    isFavorite: isFavorite,
                    colorScheme: colorScheme,
                    isSmallScreen: isSmallScreen,
                    onDownload: onDownload,
                    onShare: onShare,
                    onFavorite: onFavorite,
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

class _VideoThumbnail extends StatelessWidget {
  final String? thumbnailUrl;
  final VideoFile file;
  final bool isFavorite;
  final ColorScheme colorScheme;
  final bool isSmallScreen;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const _VideoThumbnail({
    required this.thumbnailUrl,
    required this.file,
    required this.isFavorite,
    required this.colorScheme,
    required this.isSmallScreen,
    required this.onDownload,
    required this.onShare,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                Colors.black.withValues(alpha: 0.0),
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.5),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Play button - center
        Center(
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
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

        // Quality badge - top left
        Positioned(
          top: 6,
          left: 6,
          child: _QualityBadge(
            quality: file.quality,
            isSmallScreen: isSmallScreen,
          ),
        ),

        Positioned(
          top: 4,
          right: 4,
          child: _FavoriteButton(
            isFavorite: isFavorite,
            onTap: onFavorite,
            isSmallScreen: isSmallScreen,
          ),
        ),

        // Duration badge - bottom right
        if (file.formattedDuration.isNotEmpty)
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 4 : 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                file.formattedDuration,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 9 : 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

        // Original badge - bottom left
        if (file.isOriginal)
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 4 : 5,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'ORIGINAL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 7 : 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
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
          size: isSmallScreen ? 36 : 44,
          color: colorScheme.outline,
        ),
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  final VideoQuality quality;
  final bool isSmallScreen;

  const _QualityBadge({required this.quality, required this.isSmallScreen});

  @override
  Widget build(BuildContext context) {
    final label = _getLabel();
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 5 : 6,
        vertical: isSmallScreen ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: _getColor(),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: isSmallScreen ? 9 : 10,
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
        return '1080p';
      case VideoQuality.hd720:
        return '720p';
      case VideoQuality.high:
        return 'HQ';
      case VideoQuality.medium:
        return 'MQ';
      case VideoQuality.low:
        return 'LQ';
      case VideoQuality.unknown:
        return '';
    }
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  final bool isSmallScreen;

  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 5 : 6),
          child: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            size: isSmallScreen ? 16 : 18,
            color: isFavorite ? Colors.red : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final VideoFile file;
  final bool isFavorite;
  final ColorScheme colorScheme;
  final bool isSmallScreen;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const _InfoSection({
    required this.file,
    required this.isFavorite,
    required this.colorScheme,
    required this.isSmallScreen,
    required this.onDownload,
    required this.onShare,
    required this.onFavorite,
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
                child: Text(
                  file.name,
                  maxLines: availableHeight > 80 ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // Meta row
              _MetaRow(
                file: file,
                colorScheme: colorScheme,
                isSmallScreen: isSmallScreen,
              ),
              if (showActions) ...[
                const SizedBox(height: 6),
                // Action bar
                _SlimActionBar(
                  isSmallScreen: isSmallScreen,
                  onDownload: onDownload,
                  onShare: onShare,
                  onFavorite: onFavorite,
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
  final VideoFile file;
  final ColorScheme colorScheme;
  final bool isSmallScreen;

  const _MetaRow({
    required this.file,
    required this.colorScheme,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    final metaColor = colorScheme.onSurface.withValues(alpha: 0.55);
    final fontSize = isSmallScreen ? 9.0 : 10.0;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Format chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              file.extension.toUpperCase(),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Size
          Icon(Icons.sd_storage, size: 10, color: metaColor),
          const SizedBox(width: 2),
          Text(
            file.formattedSize,
            style: TextStyle(fontSize: fontSize, color: metaColor),
          ),
          // Resolution (if available)
          if (file.resolution.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              file.resolution,
              style: TextStyle(fontSize: fontSize, color: metaColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlimActionBar extends StatelessWidget {
  final bool isSmallScreen;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const _SlimActionBar({
    required this.isSmallScreen,
    required this.onDownload,
    required this.onShare,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionChip(
            icon: Icons.download_rounded,
            label: 'Download',
            onTap: onDownload,
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ActionChip(
            icon: Icons.star,
            label: 'Favorite',
            onTap: onFavorite,
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ActionChip(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: onShare,
            isSmallScreen: isSmallScreen,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSmallScreen;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                size: isSmallScreen ? 12 : 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 9 : 10,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
