import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../features/iptv/providers/iptv_providers.dart';
import '../features/iptv/screens/iptv_player_screen.dart';
import '../features/iptv/services/m3u_parser.dart';
import '../models/media_file.dart';
import 'audio_playback_helper.dart';

/// Opens a local .m3u/.m3u8/.m3u_plus/.m3u8_plus playlist, auto-detecting
/// whether it is a music playlist (>=60% audio-only channels) or an IPTV
/// playlist, then plays / navigates accordingly.
///
/// Returns true when the playlist was handled (or rejected with a message).
/// Returns false only when [content] is empty or has no playable entries.
Future<bool> openLocalM3uPlaylist({
  required BuildContext context,
  required WidgetRef ref,
  required File file,
  required String content,
  void Function(String message)? onSnack,
}) async {
  if (content.trim().isEmpty) {
    onSnack?.call('Playlist is empty');
    return false;
  }
  final playlistId = const Uuid().v4().replaceAll('-', '');
  final channels = M3uParser.parse(content: content, playlistId: playlistId);
  if (channels.isEmpty) {
    onSnack?.call('No playable entries found in playlist');
    return false;
  }

  final audioCount = channels.where((c) => c.audioOnly).length;
  final isMusicPlaylist =
      audioCount > 0 && audioCount / channels.length >= 0.6;

  if (isMusicPlaylist) {
    final now = DateTime.now();
    final mediaFiles = channels.map((c) {
      return MediaFile(
        id: c.id,
        name: c.name,
        path: c.url,
        displayPath: c.name,
        type: MediaType.audio,
        size: 0,
        dateModified: now,
        dateAdded: now,
        mimeType: 'audio/mpeg',
        parentFolder: file.path,
        artist: c.tvgName,
      );
    }).toList();
    AudioPlaybackHelper.playAudio(ref, mediaFiles.first, mediaFiles);
    onSnack?.call('Playing music playlist: ${path.basename(file.path)}');
  } else {
    await ref
        .read(iptvPlaylistsProvider.notifier)
        .addFromFile(path: file.path);
    if (!context.mounted) return true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IptvPlayerScreen(
          channels: channels,
          playlistName: path.basenameWithoutExtension(file.path),
        ),
      ),
    );
  }
  return true;
}