import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/pdf_file.dart';

class PdfFileGridItem extends StatelessWidget {
  final PdfFile file;
  final String identifier;
  final String? thumbnailUrl;
  final bool isLiked;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onLike;

  const PdfFileGridItem({
    super.key,
    required this.file,
    required this.identifier,
    this.thumbnailUrl,
    required this.isLiked,
    required this.onOpen,
    required this.onDownload,
    required this.onShare,
    required this.onLike,
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
        onTap: onOpen,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight = constraints.maxHeight;
            final totalWidth = constraints.maxWidth;
            final thumbnailHeight = totalHeight * 0.58;
            final infoHeight = totalHeight * 0.42;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Section
                SizedBox(
                  height: thumbnailHeight,
                  width: double.infinity,
                  child: _ThumbnailSection(
                    file: file,
                    thumbnailUrl: thumbnailUrl,
                    isLiked: isLiked,
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
                    file: file,
                    colorScheme: colorScheme,
                    isSmallScreen: isSmallScreen,
                    availableWidth: totalWidth,
                    onDownload: onDownload,
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
  final PdfFile file;
  final String? thumbnailUrl;
  final bool isLiked;
  final ColorScheme colorScheme;
  final bool isSmallScreen;
  final VoidCallback onLike;

  const _ThumbnailSection({
    required this.file,
    required this.thumbnailUrl,
    required this.isLiked,
    required this.colorScheme,
    required this.isSmallScreen,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail or Placeholder
        if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: thumbnailUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildShimmer(),
            errorWidget: (context, url, error) => _buildPlaceholder(),
            fadeInDuration: const Duration(milliseconds: 200),
          )
        else
          _buildPlaceholder(),

        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 40,
          child: Container(
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
        ),

        // Format badge - top left
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 4 : 5,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: _getFormatColor(file.extension),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              file.extension.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 8 : 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Like button - top right
        Positioned(
          top: 4,
          right: 4,
          child: _LikeButton(
            isLiked: isLiked,
            onTap: onLike,
            isSmallScreen: isSmallScreen,
          ),
        ),

        // Original badge - bottom left
        if (file.isOriginal)
          Positioned(
            bottom: 4,
            left: 4,
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
                'ORIG',
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

  Widget _buildPlaceholder() {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _getFormatIcon(file.extension),
          size: isSmallScreen ? 32 : 40,
          color: _getFormatColor(file.extension).withValues(alpha: 0.6),
        ),
      ),
    );
  }

  IconData _getFormatIcon(String ext) {
    switch (ext.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'EPUB':
        return Icons.book;
      case 'TXT':
        return Icons.description;
      case 'DJVU':
        return Icons.auto_stories;
      case 'MOBI':
        return Icons.phone_android;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFormatColor(String ext) {
    switch (ext.toUpperCase()) {
      case 'PDF':
        return Colors.red;
      case 'EPUB':
        return Colors.green;
      case 'TXT':
        return Colors.blue;
      case 'DJVU':
        return Colors.purple;
      case 'MOBI':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _LikeButton extends StatelessWidget {
  final bool isLiked;
  final VoidCallback onTap;
  final bool isSmallScreen;

  const _LikeButton({
    required this.isLiked,
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
          child: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            size: isSmallScreen ? 14 : 16,
            color: isLiked ? Colors.red : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final PdfFile file;
  final ColorScheme colorScheme;
  final bool isSmallScreen;
  final double availableWidth;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  const _InfoSection({
    required this.file,
    required this.colorScheme,
    required this.isSmallScreen,
    required this.availableWidth,
    required this.onDownload,
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
          final showActions = availableHeight > 45;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Flexible(
                flex: 2,
                child: Text(
                  file.displayName,
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
              // Meta info
              Flexible(
                flex: 1,
                child: _MetaInfo(
                  file: file,
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
                    isSmallScreen: isSmallScreen,
                    availableWidth: constraints.maxWidth,
                    colorScheme: colorScheme,
                    onDownload: onDownload,
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

class _MetaInfo extends StatelessWidget {
  final PdfFile file;
  final ColorScheme colorScheme;
  final bool isSmallScreen;

  const _MetaInfo({
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
          Icon(Icons.sd_storage, size: 10, color: metaColor),
          const SizedBox(width: 2),
          Text(
            file.formattedSize,
            style: TextStyle(fontSize: fontSize, color: metaColor),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool isSmallScreen;
  final double availableWidth;
  final ColorScheme colorScheme;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  const _ActionBar({
    required this.isSmallScreen,
    required this.availableWidth,
    required this.colorScheme,
    required this.onDownload,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final useIconsOnly = availableWidth < 100;

    if (useIconsOnly) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _MiniIconButton(
            icon: Icons.download_rounded,
            onTap: onDownload,
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

    return Row(
      children: [
        Expanded(
          child: _ActionChip(
            icon: Icons.download_rounded,
            label: 'Save',
            onTap: onDownload,
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
