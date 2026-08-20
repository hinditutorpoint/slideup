import 'package:flutter/foundation.dart';
import '../../../../models/media_file.dart';

/// Internal media representation for the player
@immutable
class PlayerMedia {
  final String id;
  final String url;
  final String? title;
  final String? thumbnailPath;
  final Duration? duration;
  final String? artist;
  final String? album;
  final Map<String, dynamic>? metadata;
  final int? width;
  final int? height;
  final int? lastPosition;

  const PlayerMedia({
    required this.id,
    required this.url,
    this.title,
    this.thumbnailPath,
    this.duration,
    this.artist,
    this.album,
    this.metadata,
    this.width,
    this.height,
    this.lastPosition,
  });

  /// Create from MediaFile
  factory PlayerMedia.fromMediaFile(MediaFile file) {
    return PlayerMedia(
      id: file.id,
      url: file.path,
      title: file.name,
      thumbnailPath: file.thumbnailPath,
      duration: file.duration != null
          ? Duration(milliseconds: file.duration!)
          : null,
      artist: file.artist,
      album: file.album,
      width: file.width,
      height: file.height,
      lastPosition: file.lastPosition,
      metadata: {
        'size': file.size,
        'mimeType': file.mimeType,
        'dateModified': file.dateModified.toIso8601String(),
        'parentFolder': file.parentFolder,
      },
    );
  }

  /// Create from URL string
  factory PlayerMedia.fromUrl(String url, {String? title, String? id}) {
    return PlayerMedia(
      id: id ?? url.hashCode.toString(),
      url: url,
      title: title ?? _extractTitleFromUrl(url),
    );
  }

  /// Convert list of MediaFiles to PlayerMedia list
  static List<PlayerMedia> fromMediaFileList(List<MediaFile> files) {
    return files.map((file) => PlayerMedia.fromMediaFile(file)).toList();
  }

  /// Convert list of URLs to PlayerMedia list
  static List<PlayerMedia> fromUrlList(
    List<String> urls, {
    List<String>? titles,
  }) {
    return urls.asMap().entries.map((entry) {
      final index = entry.key;
      final url = entry.value;
      final title = titles != null && index < titles.length
          ? titles[index]
          : null;
      return PlayerMedia.fromUrl(url, title: title);
    }).toList();
  }

  /// Extract title from URL
  static String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final fileName = pathSegments.last;
        // Remove extension
        final dotIndex = fileName.lastIndexOf('.');
        if (dotIndex > 0) {
          return fileName.substring(0, dotIndex);
        }
        return fileName;
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return 'Unknown';
  }

  PlayerMedia copyWith({
    String? id,
    String? url,
    String? title,
    String? thumbnailPath,
    Duration? duration,
    String? artist,
    String? album,
    Map<String, dynamic>? metadata,
    int? width,
    int? height,
    int? lastPosition,
  }) {
    return PlayerMedia(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      metadata: metadata ?? this.metadata,
      width: width ?? this.width,
      height: height ?? this.height,
      lastPosition: lastPosition ?? this.lastPosition,
    );
  }

  /// Resolution text like "1920x1080" when width & height are known.
  String? get resolutionText {
    if (width == null || height == null) return null;
    return '${width}x$height';
  }

  /// File size in bytes when available (stored in metadata for MediaFiles).
  int? get fileSize => metadata?['size'] as int?;

  /// Human-readable file size, e.g. "25.4 MB".
  String? get fileSizeText {
    final size = fileSize;
    if (size == null || size <= 0) return null;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Last played date stored in metadata as an ISO string, if any.
  DateTime? get lastPlayedAt {
    final raw = metadata?['lastPlayed'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Get formatted duration
  String get durationFormatted {
    if (duration == null) return '';

    final hours = duration!.inHours;
    final minutes = duration!.inMinutes.remainder(60);
    final seconds = duration!.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerMedia && other.id == id && other.url == url;
  }

  @override
  int get hashCode => id.hashCode ^ url.hashCode;

  @override
  String toString() {
    return 'PlayerMedia(id: $id, title: $title, url: $url)';
  }
}

/// Playlist data class
@immutable
class PlayerPlaylist {
  final List<PlayerMedia> items;
  final int currentIndex;
  final String? title;

  const PlayerPlaylist({
    required this.items,
    this.currentIndex = 0,
    this.title,
  });

  /// Create from list of MediaFiles
  factory PlayerPlaylist.fromMediaFiles(
    List<MediaFile> files, {
    int startIndex = 0,
    String? title,
  }) {
    return PlayerPlaylist(
      items: PlayerMedia.fromMediaFileList(files),
      currentIndex: startIndex.clamp(0, files.length - 1),
      title: title,
    );
  }

  /// Create from single MediaFile
  factory PlayerPlaylist.single(MediaFile file) {
    return PlayerPlaylist(
      items: [PlayerMedia.fromMediaFile(file)],
      currentIndex: 0,
    );
  }

  /// Create from URLs
  factory PlayerPlaylist.fromUrls(
    List<String> urls, {
    List<String>? titles,
    int startIndex = 0,
    String? playlistTitle,
  }) {
    return PlayerPlaylist(
      items: PlayerMedia.fromUrlList(urls, titles: titles),
      currentIndex: startIndex.clamp(0, urls.length - 1),
      title: playlistTitle,
    );
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get length => items.length;
  bool get hasMultiple => items.length > 1;

  PlayerMedia? get currentMedia {
    if (items.isEmpty || currentIndex < 0 || currentIndex >= items.length) {
      return null;
    }
    return items[currentIndex];
  }

  bool get canPlayNext => currentIndex < items.length - 1;
  bool get canPlayPrevious => currentIndex > 0;

  PlayerPlaylist copyWith({
    List<PlayerMedia>? items,
    int? currentIndex,
    String? title,
  }) {
    return PlayerPlaylist(
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      title: title ?? this.title,
    );
  }

  /// Get list of URLs
  List<String> get urls => items.map((m) => m.url).toList();

  /// Get list of titles
  List<String> get titles => items.map((m) => m.title ?? 'Unknown').toList();

  /// Get list of IDs
  List<String> get ids => items.map((m) => m.id).toList();
}
