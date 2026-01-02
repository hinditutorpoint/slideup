import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/media_file.dart';
import '../services/thumbnail_service.dart';

class FileThumbnailWidget extends StatefulWidget {
  final MediaFile mediaFile;
  final double size;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const FileThumbnailWidget({
    super.key,
    required this.mediaFile,
    this.size = 64,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<FileThumbnailWidget> createState() => _FileThumbnailWidgetState();
}

class _FileThumbnailWidgetState extends State<FileThumbnailWidget> {
  String? _thumbnailPath;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(FileThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaFile.path != widget.mediaFile.path) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _thumbnailPath = null;
    });

    try {
      // Check if we already have a thumbnail path
      if (widget.mediaFile.thumbnailPath != null &&
          await File(widget.mediaFile.thumbnailPath!).exists()) {
        if (mounted) {
          setState(() {
            _thumbnailPath = widget.mediaFile.thumbnailPath;
            _isLoading = false;
          });
        }
        return;
      }

      // Generate thumbnail
      final thumbnailPath = await ThumbnailService.instance.getThumbnail(
        widget.mediaFile.path,
      );

      if (mounted) {
        setState(() {
          _thumbnailPath = thumbnailPath;
          _isLoading = false;
          _hasError = thumbnailPath == null;
        });
      }
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Widget _buildDefaultIcon() {
    final extension = path.extension(widget.mediaFile.path).toLowerCase();
    IconData iconData;
    Color iconColor;

    switch (widget.mediaFile.type) {
      case MediaType.video:
        iconData = Icons.video_file;
        iconColor = Colors.red;
        break;
      case MediaType.audio:
        iconData = Icons.audio_file;
        iconColor = Colors.purple;
        break;
      case MediaType.image:
        iconData = Icons.image;
        iconColor = Colors.blue;
        break;
      case MediaType.document:
        if (extension == '.pdf') {
          iconData = Icons.picture_as_pdf;
          iconColor = Colors.red;
        } else {
          iconData = Icons.description;
          iconColor = Colors.blue;
        }
        break;
      case MediaType.text:
        iconData = Icons.text_snippet;
        iconColor = Colors.green;
        break;
      case MediaType.web:
        iconData = Icons.web;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

    return Icon(iconData, color: iconColor, size: widget.size * 0.6);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return widget.placeholder ??
          Center(
            child: SizedBox(
              width: widget.size * 0.3,
              height: widget.size * 0.3,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    }

    if (_hasError || _thumbnailPath == null) {
      return widget.errorWidget ?? Center(child: _buildDefaultIcon());
    }

    // For images, show the actual image
    if (widget.mediaFile.type == MediaType.image) {
      return Image.file(
        File(_thumbnailPath!),
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return Center(child: _buildDefaultIcon());
        },
      );
    }

    // For other types with generated thumbnails
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(
            File(_thumbnailPath!),
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) {
              return Center(child: _buildDefaultIcon());
            },
          ),
        ),
        // Add type overlay for videos and PDFs
        if (widget.mediaFile.type == MediaType.video ||
            widget.mediaFile.type == MediaType.document)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                widget.mediaFile.type == MediaType.video
                    ? Icons.play_arrow
                    : Icons.picture_as_pdf,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }
}
