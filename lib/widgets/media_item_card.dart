import 'package:flutter/material.dart';
import 'dart:io';
import '../models/media_file.dart';
import '../services/thumbnail_service.dart';

class MediaItemCard extends StatelessWidget {
  final MediaFile mediaFile;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isListView;

  const MediaItemCard({
    super.key,
    required this.mediaFile,
    this.onTap,
    this.onLongPress,
    this.isListView = false,
  });

  @override
  Widget build(BuildContext context) {
    return isListView ? _buildListTile(context) : _buildGridCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(),
                  if (mediaFile.duration != null)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          mediaFile.durationFormatted,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (mediaFile.isLocked)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mediaFile.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mediaFile.sizeFormatted,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: SizedBox(
          width: 60,
          height: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildThumbnail(),
          ),
        ),
        title: Text(
          mediaFile.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(mediaFile.sizeFormatted),
            if (mediaFile.duration != null) Text(mediaFile.durationFormatted),
          ],
        ),
        trailing: mediaFile.isLocked ? const Icon(Icons.lock, size: 20) : null,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _buildThumbnail() {
    if (mediaFile.thumbnailPath != null &&
        File(mediaFile.thumbnailPath!).existsSync()) {
      return Image.file(
        File(mediaFile.thumbnailPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
      );
    }

    // For videos with a saved resume position, generate a thumbnail at that
    // frame so recent items show the last-watched position.
    if (mediaFile.type == MediaType.video &&
        mediaFile.lastPosition != null &&
        mediaFile.lastPosition! > 0 &&
        !mediaFile.path.startsWith('http')) {
      return _PositionThumbnail(
        videoPath: mediaFile.path,
        position: Duration(milliseconds: mediaFile.lastPosition!),
        fallback: _buildDefaultIcon(),
      );
    }

    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    IconData icon;
    Color color;

    switch (mediaFile.type) {
      case MediaType.video:
        icon = Icons.video_library;
        color = Colors.red;
        break;
      case MediaType.audio:
        icon = Icons.music_note;
        color = Colors.blue;
        break;
      case MediaType.document:
        icon = Icons.description;
        color = Colors.orange;
        break;
      case MediaType.image:
        icon = Icons.image;
        color = Colors.green;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Container(
      color: color.withValues(alpha: 0.1),
      child: Icon(icon, size: 40, color: color),
    );
  }
}

/// Generates a video thumbnail at a specific position (e.g. last resume frame).
class _PositionThumbnail extends StatefulWidget {
  final String videoPath;
  final Duration position;
  final Widget fallback;

  const _PositionThumbnail({
    required this.videoPath,
    required this.position,
    required this.fallback,
  });

  @override
  State<_PositionThumbnail> createState() => _PositionThumbnailState();
}

class _PositionThumbnailState extends State<_PositionThumbnail> {
  String? _thumbnailPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_PositionThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath ||
        oldWidget.position != widget.position) {
      _load();
    }
  }

  Future<void> _load() async {
    final path = await ThumbnailService.instance.generateVideoThumbnailAtTime(
      widget.videoPath,
      time: widget.position,
      width: 256,
      height: 144,
    );
    if (mounted) {
      setState(() => _thumbnailPath = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _thumbnailPath;
    if (path == null || !File(path).existsSync()) {
      return widget.fallback;
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => widget.fallback,
    );
  }
}
