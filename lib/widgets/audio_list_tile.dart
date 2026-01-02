import 'package:flutter/material.dart';
import 'dart:io';
import '../models/media_file.dart';
import '../helpers/format_helper.dart';

class AudioListTile extends StatelessWidget {
  final MediaFile audioFile;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const AudioListTile({
    super.key,
    required this.audioFile,
    required this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildLeading(),
      title: Text(
        audioFile.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        audioFile.artist ?? 'Unknown Artist',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing ?? _buildTrailing(),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildLeading() {
    if (audioFile.thumbnailPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(audioFile.thumbnailPath!),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _defaultArtwork(),
        ),
      );
    }
    return _defaultArtwork();
  }

  Widget _defaultArtwork() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note, color: Colors.deepPurple),
    );
  }

  Widget _buildTrailing() {
    if (audioFile.duration != null) {
      return Text(
        FormatHelper.formatDuration(
          Duration(milliseconds: audioFile.duration!),
        ),
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      );
    }
    return const SizedBox.shrink();
  }
}
