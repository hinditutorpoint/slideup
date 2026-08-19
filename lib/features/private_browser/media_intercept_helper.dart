import 'dart:async';
import 'dart:io';
import 'package:extractor/extractor.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../documents/models/download_task.dart';
import '../documents/screens/unified_reader_screen.dart';
import '../iptv/providers/iptv_providers.dart';
import '../iptv/screens/iptv_player_screen.dart';
import '../iptv/services/m3u_parser.dart';
import '../video_player/video_player_launcher.dart';
import '../../helpers/audio_playback_helper.dart';
import '../../models/media_file.dart';
import '../../providers/download_providers.dart';

const kDocumentExtensions = [
  '.pdf',
  '.epub',
  '.txt',
  '.doc',
  '.docx',
  '.rtf',
  '.fb2',
  '.mobi',
];

const kAudioExtensions = [
  '.mp3',
  '.wav',
  '.flac',
  '.aac',
  '.m4a',
  '.ogg',
  '.wma',
  '.opus',
  '.aiff',
  '.ape',
  '.alac',
  '.wv',
  '.tta',
  '.ac3',
  '.dts',
  '.mka',
  '.ra',
  '.ram',
  '.oga',
  '.mogg',
  '.mid',
  '.midi',
  '.mus',
  '.psf',
  '.spc',
  '.m4b',
  '.amr',
];

const kVideoExtensions = [
  '.mp4',
  '.mkv',
  '.avi',
  '.mov',
  '.wmv',
  '.flv',
  '.3gp',
  '.webm',
  '.m4v',
  '.mpg',
  '.mpeg',
  '.ts',
  '.m3u8',
  '.mpd',
  '.f4v',
  '.vob',
  '.ogv',
  '.drc',
  '.gifv',
  '.mng',
  '.qt',
  '.yuv',
  '.rm',
  '.rmvb',
  '.asf',
  '.amv',
  '.mp2',
  '.mpe',
  '.mpv',
  '.m2v',
  '.svi',
  '.3g2',
  '.mxf',
  '.roq',
  '.nsv',
];

bool isM3uUrl(Uri uri) {
  final path = uri.path.toLowerCase();
  return path.endsWith('.m3u') ||
      path.endsWith('.m3u_plus') ||
      path.endsWith('.m3u8_plus');
}

bool isDocumentUrl(Uri uri) {
  final path = uri.path.toLowerCase();
  return kDocumentExtensions.any((ext) => path.endsWith(ext));
}

bool isAudioUrl(Uri uri) {
  final path = uri.path.toLowerCase();
  return kAudioExtensions.any((ext) => path.endsWith(ext));
}

bool isVideoUrl(Uri uri) {
  final path = uri.path.toLowerCase();
  return kVideoExtensions.any((ext) => path.endsWith(ext));
}

bool isMediaUri(Uri uri) {
  return isM3uUrl(uri) ||
      isDocumentUrl(uri) ||
      isAudioUrl(uri) ||
      isVideoUrl(uri);
}

String mediaTypeOf(Uri uri) {
  if (isM3uUrl(uri) || isVideoUrl(uri)) return 'video';
  if (isDocumentUrl(uri)) return 'document';
  if (isAudioUrl(uri)) return 'audio';
  return 'other';
}

String fileNameFromUri(Uri uri, String fallback) {
  if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty) {
    try {
      return Uri.decodeComponent(uri.pathSegments.last);
    } catch (_) {
      return uri.pathSegments.last;
    }
  }
  return fallback;
}

/// Shows the Play/Read | Download | Cancel interception bottom sheet for a
/// media/document URL. Used by the private browser and the downloads screen.
Future<void> showMediaActionSheet(
  BuildContext context,
  WidgetRef ref,
  Uri uri, {
  String? customTitle,
  VoidCallback? onOpenDownloads,
}) async {
  if (!context.mounted) return;
  final urlStr = uri.toString();

  final String category;
  final IconData icon;
  final Color color;
  final String defaultTitle;
  final String mediaType;

  if (isM3uUrl(uri)) {
    category = 'IPTV Playlist';
    icon = Icons.live_tv_rounded;
    color = Colors.purple;
    defaultTitle = 'IPTV Playlist';
    mediaType = 'video';
  } else if (isDocumentUrl(uri)) {
    category = 'Document';
    icon = Icons.menu_book_rounded;
    color = Colors.indigo;
    defaultTitle = 'Document';
    mediaType = 'document';
  } else if (isAudioUrl(uri)) {
    category = 'Audio File';
    icon = Icons.audiotrack_rounded;
    color = Colors.deepOrange;
    defaultTitle = 'Audio File';
    mediaType = 'audio';
  } else if (isVideoUrl(uri)) {
    category = 'Video';
    icon = Icons.videocam_rounded;
    color = Colors.teal;
    defaultTitle = 'Video File';
    mediaType = 'video';
  } else {
    category = 'Download File';
    icon = Icons.download_rounded;
    color = Colors.blueGrey;
    defaultTitle = 'File';
    mediaType = 'other';
  }

  final fileName = customTitle?.isNotEmpty == true
      ? customTitle!
      : fileNameFromUri(uri, defaultTitle);

  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        uri.host.isNotEmpty ? uri.host : urlStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            // Action Buttons: Play/Read | Download
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: color.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      isDocumentUrl(uri)
                          ? Icons.visibility_rounded
                          : Icons.play_arrow_rounded,
                      color: color,
                    ),
                    label: Text(
                      isDocumentUrl(uri) ? 'Read' : 'Play',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      openMedia(context, ref, uri, fileName);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                    label: const Text(
                      'Download',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      startBrowserDownload(
                        context,
                        ref,
                        url: urlStr,
                        title: fileName,
                        mediaType: mediaType,
                        onOpenDownloads: onOpenDownloads,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!kIsWeb && Platform.isAndroid) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: Colors.blueGrey.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  Icons.movie_filter_rounded,
                  color: Colors.blueGrey[300],
                ),
                label: Text(
                  'Extract Media (yt-dlp)',
                  style: TextStyle(
                    color: Colors.blueGrey[300],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _startYtDlpExtraction(context, ref, uri, fileName);
                },
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Starts downloading the media/document URL in background with notifications.
Future<void> startBrowserDownload(
  BuildContext context,
  WidgetRef ref, {
  required String url,
  required String title,
  required String mediaType,
  VoidCallback? onOpenDownloads,
}) async {
  try {
    final notifier = ref.read(downloadsProvider.notifier);
    final id = const Uuid().v4();
    final task = await notifier.startDownload(
      identifier: id,
      title: title,
      url: url,
      mediaType: mediaType,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          task != null
              ? 'Download started: $title'
              : 'Failed to start download (check permissions)',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: onOpenDownloads != null
            ? SnackBarAction(
                label: 'View',
                textColor: Colors.tealAccent,
                onPressed: onOpenDownloads,
              )
            : null,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      _snack(context, 'Error starting download: $e');
    }
  }
}

/// Directly opens or plays the media/document in its respective player/reader.
Future<void> openMedia(
  BuildContext context,
  WidgetRef ref,
  Uri uri,
  String fileName,
) async {
  final urlStr = uri.toString();
  if (isM3uUrl(uri)) {
    await _openM3uPlaylist(context, ref, urlStr, fileName);
  } else if (isDocumentUrl(uri)) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            UnifiedReaderScreen(documentUrl: urlStr, title: fileName),
      ),
    );
    _snack(context, 'Opening $fileName in reader');
  } else if (isAudioUrl(uri)) {
    final mediaFile = MediaFile(
      id: urlStr,
      name: fileName,
      path: urlStr,
      displayPath: urlStr,
      type: MediaType.audio,
      size: 0,
      dateModified: DateTime.now(),
      dateAdded: DateTime.now(),
    );
    AudioPlaybackHelper.playAudio(ref, mediaFile, [mediaFile]);
    _snack(context, 'Playing $fileName in audio player');
  } else {
    VideoPlayerLauncher.smart(source: urlStr, context: context);
  }
}

Future<void> _openM3uPlaylist(
  BuildContext context,
  WidgetRef ref,
  String url,
  String name,
) async {
  _snack(context, 'Loading playlist: $name...');
  try {
    final datasource = ref.read(iptvDatasourceProvider);
    final content = await datasource.fetchM3uUrl(url);
    final playlistId = const Uuid().v4().replaceAll('-', '');
    final channels = M3uParser.parse(
      content: content,
      playlistId: playlistId,
    );

    if (!context.mounted) return;
    if (channels.isNotEmpty) {
      final audioCount = channels.where((c) => c.audioOnly).length;
      final isMusicPlaylist =
          audioCount > 0 && audioCount / channels.length >= 0.6;

      if (isMusicPlaylist) {
        final mediaFiles = channels.map((c) {
          final now = DateTime.now();
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
            parentFolder: url,
            artist: c.tvgName,
          );
        }).toList();

        AudioPlaybackHelper.playAudio(ref, mediaFiles.first, mediaFiles);
        _snack(context, 'Playing music playlist: $name');
        return;
      }

      unawaited(
        ref
            .read(iptvPlaylistsProvider.notifier)
            .addFromUrl(url: url, name: name),
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IptvPlayerScreen(
            channels: channels,
            playlistName: name,
            startIndex: 0,
          ),
        ),
      );
    } else {
      VideoPlayerLauncher.smart(source: url, context: context);
    }
  } catch (e) {
    if (context.mounted) {
      _snack(context, 'Opening stream in video player...');
      VideoPlayerLauncher.smart(source: url, context: context);
    }
  }
}

/// Android-only: resolves the media URL via yt-dlp (youtubedl-android) and
/// downloads the resolved file through the extractor plugin, then registers
/// the finished file into the downloads manager.
Future<void> _startYtDlpExtraction(
  BuildContext context,
  WidgetRef ref,
  Uri uri,
  String fileName,
) async {
  final urlStr = uri.toString();
  _snack(context, 'Resolving media with yt-dlp...');

  try {
    final yd = YoutubeDLFlutter.instance;
    final init = await yd.initialize(enableFFmpeg: true, enableAria2c: true);
    if (!context.mounted) return;
    if (!init.success) {
      _snack(context, 'Extractor init failed: ${init.errorMessage}');
      return;
    }

    final info = await yd.getVideoInfo(urlStr);
    if (!context.mounted) return;
    final title = (info.title?.isNotEmpty == true) ? info.title! : fileName;

    const choices = <({String label, String format, bool audioOnly})>[
      (label: 'Best Quality', format: 'bestvideo+bestaudio/best', audioOnly: false),
      (label: '1080p', format: 'bestvideo[height<=1080]+bestaudio/best[height<=1080]', audioOnly: false),
      (label: '720p', format: 'bestvideo[height<=720]+bestaudio/best[height<=720]', audioOnly: false),
      (label: '480p', format: 'bestvideo[height<=480]+bestaudio/best[height<=480]', audioOnly: false),
      (label: 'Audio Only (MP3)', format: 'bestaudio/best', audioOnly: true),
    ];

    final chosen = await showModalBottomSheet<
        ({String label, String format, bool audioOnly})>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E222B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Select quality',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            for (final c in choices)
              ListTile(
                leading: Icon(
                  c.audioOnly
                      ? Icons.audiotrack_rounded
                      : Icons.high_quality_rounded,
                  color: Colors.teal,
                ),
                title: Text(c.label),
                onTap: () => Navigator.of(sheetContext).pop(c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    if (!context.mounted) return;

    final dir = await getExternalStorageDirectory();
    if (!context.mounted) return;
    if (dir == null) {
      _snack(context, 'Storage not available');
      return;
    }
    final downloadPath = '${dir.path}/Download';
    await Directory(downloadPath).create(recursive: true);

    final processId = 'extract_${DateTime.now().millisecondsSinceEpoch}';
    final progress = ValueNotifier<String>('Starting download...');

    final progressSub = yd.onProgress.listen((p) {
      if (p.processId != processId) return;
      progress.value =
          'Downloading... ${p.progress.toStringAsFixed(0)}% (ETA ${p.eta.inSeconds}s)';
    });
    final stateSub = yd.onStateChanged.listen((s) {
      if (s.processId == processId) {
        progress.value = 'State: ${s.state}';
      }
    });
    final errorSub = yd.onError.listen((e) {
      if (e.processId == processId) {
        progress.value = 'Error: ${e.error}';
      }
    });

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValueListenableBuilder<String>(
        valueListenable: progress,
        builder: (_, value, __) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Extracting Media'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              const LinearProgressIndicator(color: Colors.teal),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => yd.cancelDownload(processId),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Cancel Extraction'),
            ),
          ],
        ),
      ),
    );

    final result = await yd.download(
      DownloadRequest(
        url: urlStr,
        outputPath: downloadPath,
        outputTemplate: '%(title)s.%(ext)s',
        format: chosen.format,
        noPlaylist: true,
        extractAudio: chosen.audioOnly,
        audioFormat: chosen.audioOnly ? 'mp3' : null,
        audioQuality: chosen.audioOnly ? 0 : null,
        embedThumbnail: true,
        embedMetadata: true,
        processId: processId,
      ),
    );

    await progressSub.cancel();
    await stateSub.cancel();
    await errorSub.cancel();
    progress.dispose();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final outPath = result.outputPath;
    if (result.status == OperationStatus.cancelled) {
      _snack(context, 'Extraction cancelled');
    } else if (result.status == OperationStatus.success && outPath != null) {
      final file = File(outPath);
      final size = file.existsSync() ? await file.length() : 0;
      final task = DownloadTask(
        id: const Uuid().v4(),
        identifier: urlStr,
        title: title,
        url: urlStr,
        fileName: outPath.split(Platform.pathSeparator).last,
        filePath: outPath,
        totalBytes: size,
        downloadedBytes: size,
        status: DownloadStatus.completed,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
        mediaType: chosen.audioOnly ? 'audio' : 'video',
      );
      await ref.read(downloadsProvider.notifier).updateTask(task);
      if (!context.mounted) return;
      _snack(context, 'Extracted: ${task.fileName}');
    } else {
      _snack(context, 'Extraction failed: ${result.errorMessage}');
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _snack(context, 'Extraction error: $e');
    }
  }
}

void _snack(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}