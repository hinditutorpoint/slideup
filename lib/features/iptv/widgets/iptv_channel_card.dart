import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../models/iptv_models.dart';

/// A YouTube-style channel tile: thumbnail on top, name below.
class IptvChannelCard extends StatelessWidget {
  const IptvChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    required this.onToggleFavorite,
    this.grid = true,
  });

  final IptvChannel channel;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!grid) {
      return _ListTile(
        channel: channel,
        onTap: onTap,
        onToggleFavorite: onToggleFavorite,
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Thumbnail(channel: channel),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      channel.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      channel.isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: channel.isFavorite
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleFavorite,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.channel});

  final IptvChannel channel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logo = channel.logo;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: colorScheme.surfaceContainerHigh,
            child: logo != null && logo.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: logo,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _ShimmerBox(colorScheme: colorScheme),
                    errorWidget: (_, __, ___) => _FallbackIcon(
                      channel: channel,
                      colorScheme: colorScheme,
                    ),
                  )
                : _FallbackIcon(channel: channel, colorScheme: colorScheme),
          ),
          // LIVE badge, top-left.
          if (!channel.audioOnly)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (channel.audioOnly)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.headphones, size: 11, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'RADIO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Center play button.
          Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.channel, required this.colorScheme});

  final IptvChannel channel;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        channel.audioOnly ? Icons.radio : Icons.live_tv,
        size: 42,
        color: colorScheme.primary.withValues(alpha: 0.7),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surface,
      child: Container(color: colorScheme.surfaceContainerHighest),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.channel,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final IptvChannel channel;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logo = channel.logo;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: SizedBox(
          width: 64,
          height: 40,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: logo != null && logo.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: logo,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _FallbackIcon(
                      channel: channel,
                      colorScheme: colorScheme,
                    ),
                  )
                : _FallbackIcon(channel: channel, colorScheme: colorScheme),
          ),
        ),
        title: Text(
          channel.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (channel.group.isNotEmpty) ...[
              Icon(
                channel.audioOnly ? Icons.headphones : Icons.live_tv,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  channel.group,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (channel.audioOnly) ...[
              const SizedBox(width: 8),
              Text(
                'RADIO',
                style: TextStyle(
                  color: colorScheme.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            channel.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: channel.isFavorite
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
          ),
          onPressed: onToggleFavorite,
        ),
      ),
    );
  }
}