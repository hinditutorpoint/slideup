import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/thumbnail_file.dart';

class ThumbnailListItem extends StatelessWidget {
  final ThumbnailFile thumbnail;
  final String identifier;
  final bool isLiked;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onLike;
  final VoidCallback onFavorite;

  const ThumbnailListItem({
    super.key,
    required this.thumbnail,
    required this.identifier,
    required this.isLiked,
    required this.isFavorite,
    required this.onTap,
    required this.onDownload,
    required this.onShare,
    required this.onLike,
    required this.onFavorite,
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail
              _ThumbnailImage(
                thumbnail: thumbnail,
                identifier: identifier,
                colorScheme: colorScheme,
                size: isSmallScreen ? 48 : 56,
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
                      thumbnail: thumbnail,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                      isSmallScreen: isSmallScreen,
                    ),
                    const SizedBox(height: 6),
                    // Slim Action Bar
                    _SlimActionBar(
                      isLiked: isLiked,
                      isFavorite: thumbnail.isFavorite,
                      isSmallScreen: isSmallScreen,
                      colorScheme: colorScheme,
                      onDownload: onDownload,
                      onShare: onShare,
                      onLike: onLike,
                      onFavorite: onFavorite,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              // 3-dot menu
              _MoreMenu(
                isFavorite: isFavorite,
                isLiked: isLiked,
                onDownload: onDownload,
                onShare: onShare,
                onLike: onLike,
                onFavorite: onFavorite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  final ThumbnailFile thumbnail;
  final String identifier;
  final ColorScheme colorScheme;
  final double size;

  const _ThumbnailImage({
    required this.thumbnail,
    required this.identifier,
    required this.colorScheme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: thumbnail.getUrl(identifier),
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: colorScheme.surfaceContainerHighest,
                highlightColor: colorScheme.surface,
                child: Container(color: Colors.white),
              ),
              errorWidget: (context, url, error) => Container(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_not_supported,
                  size: size * 0.4,
                  color: colorScheme.outline,
                ),
              ),
              fadeInDuration: const Duration(milliseconds: 200),
            ),
            // Format badge
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  thumbnail.extension.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
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
}

class _TitleMeta extends StatelessWidget {
  final ThumbnailFile thumbnail;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final bool isSmallScreen;

  const _TitleMeta({
    required this.thumbnail,
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
        Text(
          thumbnail.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 12 : 13,
          ),
        ),
        const SizedBox(height: 2),
        // Meta row
        _MetaRow(
          thumbnail: thumbnail,
          colorScheme: colorScheme,
          metaColor: metaColor,
          isSmallScreen: isSmallScreen,
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final ThumbnailFile thumbnail;
  final ColorScheme colorScheme;
  final Color metaColor;
  final bool isSmallScreen;

  const _MetaRow({
    required this.thumbnail,
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
                if (thumbnail.resolution.isNotEmpty) ...[
                  Icon(Icons.aspect_ratio, size: 10, color: metaColor),
                  const SizedBox(width: 2),
                  Text(
                    thumbnail.resolution,
                    style: TextStyle(fontSize: fontSize, color: metaColor),
                  ),
                  _MicroDot(color: metaColor),
                ],
                Icon(Icons.sd_storage, size: 10, color: metaColor),
                const SizedBox(width: 2),
                Text(
                  thumbnail.formattedSize,
                  style: TextStyle(fontSize: fontSize, color: metaColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlimActionBar extends StatelessWidget {
  final bool isLiked;
  final bool isFavorite;
  final bool isSmallScreen;
  final ColorScheme colorScheme;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onLike;
  final VoidCallback onFavorite;

  const _SlimActionBar({
    required this.isLiked,
    required this.isFavorite,
    required this.isSmallScreen,
    required this.colorScheme,
    required this.onDownload,
    required this.onShare,
    required this.onLike,
    required this.onFavorite,
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
            isFavorite: isFavorite,
            colorScheme: colorScheme,
            onDownload: onDownload,
            onShare: onShare,
            onLike: onLike,
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
                icon: isFavorite ? Icons.star : Icons.star_border,
                label: isFavorite ? 'Liked' : 'Like',
                onTap: onLike,
                isSmallScreen: isSmallScreen,
                colorScheme: colorScheme,
                iconColor: isFavorite
                    ? const Color.fromARGB(255, 173, 17, 6)
                    : null,
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
  final bool isFavorite;
  final ColorScheme colorScheme;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onLike;
  final VoidCallback onFavorite;

  const _IconOnlyActions({
    required this.isLiked,
    required this.isFavorite,
    required this.colorScheme,
    required this.onDownload,
    required this.onShare,
    required this.onLike,
    required this.onFavorite,
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
          icon: isFavorite ? Icons.star : Icons.star_border,
          onTap: onFavorite,
          color: isFavorite ? Colors.red : colorScheme.primary,
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
  final bool isFavorite;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onLike;
  final VoidCallback onFavorite;

  const _MoreMenu({
    required this.isLiked,
    required this.isFavorite,
    required this.onDownload,
    required this.onShare,
    required this.onLike,
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
            'like',
            isLiked ? Icons.favorite : Icons.favorite_border,
            isLiked ? 'Unlike' : 'Like',
            iconColor: isLiked ? Colors.red : null,
          ),
          _menuItem(
            'favorite',
            isFavorite ? Icons.star : Icons.star_border,
            isFavorite ? 'Favorite' : 'Favorite',
            iconColor: isFavorite
                ? const Color.fromARGB(255, 181, 17, 5)
                : null,
          ),
          _menuItem('share', Icons.share_rounded, 'Share'),
        ],
        onSelected: (value) {
          switch (value) {
            case 'download':
              onDownload();
            case 'like':
              onLike();
            case 'favorite':
              onFavorite();
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
