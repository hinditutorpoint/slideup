import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/archive_item.dart';

class PdfListItem extends StatelessWidget {
  final ArchiveItem item;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const PdfListItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Responsive sizing
    final isSmallScreen = screenWidth < 360;
    final thumbnailWidth = isSmallScreen ? 60.0 : 72.0;
    final thumbnailHeight = isSmallScreen ? 75.0 : 90.0;
    final horizontalPadding = isSmallScreen ? 8.0 : 12.0;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              _buildThumbnail(
                colorScheme,
                textTheme,
                thumbnailWidth,
                thumbnailHeight,
              ),
              SizedBox(width: isSmallScreen ? 8 : 10),
              // Info
              Expanded(
                child: _buildInfo(colorScheme, textTheme, isSmallScreen),
              ),
              // Compact Actions
              _buildActions(isSmallScreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(
    ColorScheme colorScheme,
    TextTheme textTheme,
    double width,
    double height,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
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
                  Icons.picture_as_pdf,
                  size: 24,
                  color: colorScheme.outline,
                ),
              ),
            ),
            Positioned(
              bottom: 2,
              left: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  'PDF',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isSmallScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 13 : 14,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),

        // Creator
        if (item.creator != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              item.creator!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontSize: isSmallScreen ? 11 : 12,
              ),
            ),
          ),

        // Description
        if (item.description != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              item.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: isSmallScreen ? 10 : 11,
              ),
            ),
          ),

        // Meta info - Wrapped for overflow prevention
        _buildMetaInfo(colorScheme, textTheme, isSmallScreen),
      ],
    );
  }

  Widget _buildMetaInfo(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isSmallScreen,
  ) {
    final metaStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.outline,
      fontSize: isSmallScreen ? 10 : 11,
    );
    final iconSize = isSmallScreen ? 12.0 : 13.0;

    return Wrap(
      spacing: 8,
      runSpacing: 2,
      children: [
        // Downloads
        _buildMetaItem(
          Icons.download_rounded,
          item.formattedDownloads,
          metaStyle,
          iconSize,
          colorScheme.outline,
        ),
        // Size
        _buildMetaItem(
          Icons.sd_storage_rounded,
          item.formattedSize,
          metaStyle,
          iconSize,
          colorScheme.outline,
        ),
        // Date
        if (item.date != null)
          _buildMetaItem(
            Icons.calendar_today_rounded,
            _formatDate(item.date!),
            metaStyle,
            iconSize,
            colorScheme.outline,
          ),
      ],
    );
  }

  Widget _buildMetaItem(
    IconData icon,
    String text,
    TextStyle? style,
    double iconSize,
    Color iconColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: 2),
        Flexible(
          child: Text(text, style: style, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildActions(bool isSmallScreen) {
    final iconSize = isSmallScreen ? 20.0 : 22.0;
    final buttonSize = isSmallScreen ? 32.0 : 36.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              maxWidth: buttonSize,
              maxHeight: buttonSize,
            ),
            icon: Icon(
              item.isLiked ? Icons.favorite : Icons.favorite_border,
              color: item.isLiked ? Colors.red : null,
              size: iconSize,
            ),
            onPressed: onLike,
            tooltip: item.isLiked ? 'Unlike' : 'Like',
          ),
        ),
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              maxWidth: buttonSize,
              maxHeight: buttonSize,
            ),
            icon: Icon(Icons.share, size: iconSize),
            onPressed: onShare,
            tooltip: 'Share',
          ),
        ),
      ],
    );
  }

  String _formatDate(String date) {
    final datePart = date.split('T').first;
    // Return shorter format for compact display
    final parts = datePart.split('-');
    if (parts.length == 3) {
      return '${parts[1]}/${parts[2]}/${parts[0].substring(2)}';
    }
    return datePart;
  }
}
