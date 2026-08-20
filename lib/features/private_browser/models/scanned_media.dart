import 'quality_variant.dart';

enum MediaType {
  video,
  audio,
  hlsPlaylist, // .m3u8 master/variant playlist
  dashManifest, // .mpd manifest
  directFile, // Direct .mp4, .mkv, etc.
}

/// A single media item detected on a page
class ScannedMedia {
  final String url;
  final String title;
  final MediaType mediaType;
  final int? duration;
  final int? width;
  final int? height;
  final int? fileSize;
  final String? quality;
  final int? bitrate; // kbps
  final String? codec;
  final List<QualityVariant>? variants; // For HLS/DASH with multiple qualities

  const ScannedMedia({
    required this.url,
    required this.title,
    required this.mediaType,
    this.duration,
    this.width,
    this.height,
    this.fileSize,
    this.quality,
    this.bitrate,
    this.codec,
    this.variants,
  });

  bool get isVideo =>
      mediaType == MediaType.video ||
      mediaType == MediaType.hlsPlaylist ||
      mediaType == MediaType.dashManifest ||
      mediaType == MediaType.directFile;

  bool get isHLS => mediaType == MediaType.hlsPlaylist;
  bool get isDASH => mediaType == MediaType.dashManifest;
  bool get isStream => isHLS || isDASH;

  factory ScannedMedia.fromMap(Map<String, dynamic> map) {
    return ScannedMedia(
      url: (map['url'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      mediaType: _parseMediaType(
        map['mediaType']?.toString() ?? map['type']?.toString(),
      ),
      duration: _parseInt(map['duration']),
      width: _parseInt(map['width']),
      height: _parseInt(map['height']),
      fileSize: _parseInt(map['fileSize']),
      quality: map['quality']?.toString(),
      bitrate: _parseInt(map['bitrate']),
      codec: map['codec']?.toString(),
      variants: _parseVariants(map['variants']),
    );
  }

  static MediaType _parseMediaType(String? type) {
    switch (type?.toLowerCase()) {
      case 'hls':
      case 'hlsplaylist':
        return MediaType.hlsPlaylist;
      case 'dash':
      case 'dashmanifest':
        return MediaType.dashManifest;
      case 'video':
        return MediaType.video;
      case 'audio':
        return MediaType.audio;
      case 'file':
      case 'directfile':
        return MediaType.directFile;
      default:
        return MediaType.video;
    }
  }

  static List<QualityVariant>? _parseVariants(dynamic variants) {
    if (variants == null) return null;
    if (variants is! List) return null;

    return variants
        .whereType<Map>()
        .map((v) => QualityVariant.fromMap(v.cast<String, dynamic>()))
        .toList();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  String get displayTitle {
    final parts = <String>[];

    if (title.isNotEmpty && title != 'Unknown') {
      parts.add(title);
    }

    if (quality != null) {
      parts.add(quality!);
    } else if (height != null && height! > 0) {
      parts.add('${height}p');
    }

    if (bitrate != null && bitrate! > 0) {
      parts.add('${bitrate! ~/ 1000}Mbps');
    }

    if (codec != null) {
      parts.add(codec!.toUpperCase());
    }

    if (duration != null && duration! > 0) {
      parts.add(_formatDuration(duration!));
    }

    if (fileSize != null && fileSize! > 0) {
      parts.add(_formatSize(fileSize!));
    }

    if (isHLS) {
      parts.add('HLS');
    } else if (isDASH) {
      parts.add('DASH');
    }

    return parts.isEmpty ? _getFileName() : parts.join(' • ');
  }

  String _getFileName() {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : uri.host;
      return path.split('?').first;
    } catch (e) {
      return url;
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatSize(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  ScannedMedia copyWith({
    String? url,
    String? title,
    MediaType? mediaType,
    int? duration,
    int? width,
    int? height,
    int? fileSize,
    String? quality,
    int? bitrate,
    String? codec,
    List<QualityVariant>? variants,
  }) {
    return ScannedMedia(
      url: url ?? this.url,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSize: fileSize ?? this.fileSize,
      quality: quality ?? this.quality,
      bitrate: bitrate ?? this.bitrate,
      codec: codec ?? this.codec,
      variants: variants ?? this.variants,
    );
  }

  @override
  bool operator ==(Object other) => other is ScannedMedia && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => displayTitle;
}
