import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/pdf_file.dart';

class PdfFileListItem extends StatelessWidget {
  final PdfFile file;
  final String identifier;
  final String? thumbnailUrl;
  final bool isLiked;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onLike;

  const PdfFileListItem({
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
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail
              _DocumentThumbnail(
                file: file,
                thumbnailUrl: thumbnailUrl,
                colorScheme: colorScheme,
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(width: isSmallScreen ? 8 : 10),
              // Content
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
                    // Slim Action Bar
                    _SlimActionBar(
                      isLiked: isLiked,
                      isSmallScreen: isSmallScreen,
                      colorScheme: colorScheme,
                      onDownload: onDownload,
                      onShare: onShare,
                      onLike: onLike,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              // 3-dot menu
              _MoreMenu(
                isLiked: isLiked,
                onDownload: onDownload,
                onShare: onShare,
                onLike: onLike,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentThumbnail extends StatelessWidget {
  final PdfFile file;
  final String? thumbnailUrl;
  final ColorScheme colorScheme;
  final bool isSmallScreen;

  const _DocumentThumbnail({
    required this.file,
    required this.thumbnailUrl,
    required this.colorScheme,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    final width = isSmallScreen ? 44.0 : 50.0;
    final height = isSmallScreen ? 56.0 : 64.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
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

            // Format badge - bottom
            Positioned(
              bottom: 2,
              left: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: _getFormatColor(file.extension),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  file.extension.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 7 : 8,
                    fontWeight: FontWeight.bold,
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

  Widget _buildPlaceholder() {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _getFormatIcon(file.extension),
          size: isSmallScreen ? 20 : 24,
          color: _getFormatColor(file.extension).withValues(alpha: 0.7),
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

class _TitleMeta extends StatelessWidget {
  final PdfFile file;
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
                file.displayName,
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
        // Meta row
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
  final PdfFile file;
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
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Format with color
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: _getFormatColor(
                      file.extension,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    file.extension.toUpperCase(),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: _getFormatColor(file.extension),
                    ),
                  ),
                ),
                _MicroDot(color: metaColor),
                // Size
                Icon(Icons.sd_storage, size: 10, color: metaColor),
                const SizedBox(width: 2),
                Text(
                  file.formattedSize,
                  style: TextStyle(fontSize: fontSize, color: metaColor),
                ),
              ],
            ),
          ),
        );
      },
    );
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

class _SlimActionBar extends StatelessWidget {
  final bool isLiked;
  final bool isSmallScreen;
  final ColorScheme colorScheme;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onLike;

  const _SlimActionBar({
    required this.isLiked,
    required this.isSmallScreen,
    required this.colorScheme,
    required this.onDownload,
    required this.onShare,
    required this.onLike,
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
            isLiked: isLiked,
            colorScheme: colorScheme,
            onDownload: onDownload,
            onShare: onShare,
            onLike: onLike,
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
                colorScheme: colorScheme,
              ),
            ),
            SizedBox(width: chipSpacing),
            Flexible(
              child: _SlimActionChip(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: isLiked ? 'Liked' : 'Like',
                onTap: onLike,
                isSmallScreen: isSmallScreen,
                colorScheme: colorScheme,
                iconColor: isLiked ? Colors.red : null,
                isActive: isLiked,
              ),
            ),
            SizedBox(width: chipSpacing),
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

class _IconOnlyActions extends StatelessWidget {
  final bool isLiked;
  final ColorScheme colorScheme;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onLike;

  const _IconOnlyActions({
    required this.isLiked,
    required this.colorScheme,
    required this.onDownload,
    required this.onShare,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniIconButton(
          icon: Icons.download_rounded,
          onTap: onDownload,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 8),
        _MiniIconButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          onTap: onLike,
          color: isLiked ? Colors.red : colorScheme.primary,
        ),
        const SizedBox(width: 8),
        _MiniIconButton(
          icon: Icons.share_rounded,
          onTap: onShare,
          color: colorScheme.primary,
        ),
      ],
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
  final bool isLiked;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onLike;

  const _MoreMenu({
    required this.isLiked,
    required this.onDownload,
    required this.onShare,
    required this.onLike,
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
          _menuItem('open', Icons.open_in_new, 'Open'),
          _menuItem('download', Icons.download_rounded, 'Download'),
          _menuItem(
            'like',
            isLiked ? Icons.favorite : Icons.favorite_border,
            isLiked ? 'Unlike' : 'Like',
            iconColor: isLiked ? Colors.red : null,
          ),
          _menuItem('share', Icons.share_rounded, 'Share'),
        ],
        onSelected: (value) {
          switch (value) {
            case 'download':
              onDownload();
            case 'like':
              onLike();
            case 'share':
              onShare();
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
