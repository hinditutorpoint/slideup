import 'package:flutter/material.dart';
import '../models/scanned_media.dart';
import '../models/quality_variant.dart';

class MediaListSheet extends StatelessWidget {
  final List<ScannedMedia> items;

  /// Called when a media item (or a specific quality variant) is downloaded.
  final Future<void> Function(ScannedMedia media, {QualityVariant? variant})?
      onDownload;

  /// Called when a media item should be played.
  final void Function(ScannedMedia media)? onPlay;

  /// Called when a media item row is tapped (e.g. open the intercept sheet).
  final void Function(ScannedMedia media)? onOpen;

  const MediaListSheet({
    super.key,
    required this.items,
    this.onDownload,
    this.onPlay,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Found ${items.length} media items',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _buildMediaItem(context, items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaItem(BuildContext context, ScannedMedia media) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          ListTile(
            leading: _buildMediaIcon(media),
            title: Text(
              media.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  media.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (media.isHLS || media.isDASH) ...[
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(
                      media.isHLS ? 'HLS Stream' : 'DASH Stream',
                      style: const TextStyle(fontSize: 10),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
            onTap: () => onOpen?.call(media),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onPlay != null)
                  IconButton(
                    tooltip: 'Play',
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: () => onPlay!(media),
                  ),
                IconButton(
                  tooltip: 'Download',
                  icon: const Icon(Icons.download),
                  onPressed: () => _downloadMedia(context, media),
                ),
              ],
            ),
          ),
          if (media.variants != null && media.variants!.isNotEmpty)
            _buildQualityVariants(context, media),
        ],
      ),
    );
  }

  Widget _buildMediaIcon(ScannedMedia media) {
    IconData icon;
    Color color;

    if (media.isHLS) {
      icon = Icons.playlist_play;
      color = Colors.purple;
    } else if (media.isDASH) {
      icon = Icons.dashboard;
      color = Colors.indigo;
    } else if (media.mediaType == MediaType.audio) {
      icon = Icons.audiotrack;
      color = Colors.blue;
    } else {
      icon = Icons.videocam;
      color = Colors.red;
    }

    return Icon(icon, color: color, size: 32);
  }

  Widget _buildQualityVariants(BuildContext context, ScannedMedia media) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Qualities:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: media.variants!.map((variant) {
              return ActionChip(
                label: Text(variant.displayName),
                onPressed: () => _downloadVariant(context, media, variant),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadMedia(BuildContext context, ScannedMedia media) async {
    final download = onDownload;
    if (download == null) return;

    if (media.variants != null && media.variants!.isNotEmpty) {
      // Show quality selector
      final variant = await showDialog<QualityVariant>(
        context: context,
        builder: (context) => QualitySelectionDialog(variants: media.variants!),
      );

      if (variant != null) {
        download(media, variant: variant);
      }
    } else {
      download(media);
    }
  }

  void _downloadVariant(
    BuildContext context,
    ScannedMedia media,
    QualityVariant variant,
  ) {
    onDownload?.call(media, variant: variant);
  }
}

class QualitySelectionDialog extends StatelessWidget {
  final List<QualityVariant> variants;

  const QualitySelectionDialog({super.key, required this.variants});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Quality'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: variants.map((variant) {
          return ListTile(
            title: Text(variant.displayName),
            subtitle: variant.bitrate != null
                ? Text('${variant.bitrate! ~/ 1000} Kbps')
                : null,
            onTap: () => Navigator.pop(context, variant),
          );
        }).toList(),
      ),
    );
  }
}
