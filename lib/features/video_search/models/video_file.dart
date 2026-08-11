import 'package:equatable/equatable.dart';
import 'archive_file.dart';

enum VideoQuality { low, medium, high, hd720, hd1080, uhd4k, unknown }

extension VideoQualityExtension on VideoQuality {
  String get displayName {
    switch (this) {
      case VideoQuality.low:
        return 'Low';
      case VideoQuality.medium:
        return 'SD';
      case VideoQuality.high:
        return 'HQ';
      case VideoQuality.hd720:
        return '720p';
      case VideoQuality.hd1080:
        return '1080p';
      case VideoQuality.uhd4k:
        return '4K';
      case VideoQuality.unknown:
        return '';
    }
  }

  String get badge {
    switch (this) {
      case VideoQuality.uhd4k:
        return '4K';
      case VideoQuality.hd1080:
        return 'FHD';
      case VideoQuality.hd720:
        return 'HD';
      case VideoQuality.high:
        return 'HQ';
      case VideoQuality.medium:
        return 'SD';
      case VideoQuality.low:
        return 'LQ';
      case VideoQuality.unknown:
        return '';
    }
  }

  int get sortOrder {
    switch (this) {
      case VideoQuality.uhd4k:
        return 6;
      case VideoQuality.hd1080:
        return 5;
      case VideoQuality.hd720:
        return 4;
      case VideoQuality.high:
        return 3;
      case VideoQuality.medium:
        return 2;
      case VideoQuality.low:
        return 1;
      case VideoQuality.unknown:
        return 0;
    }
  }
}

class VideoFile extends Equatable {
  final String name;
  final String source;
  final String format;
  final int? size;
  final String? mtime;
  final String? length;
  final String? width;
  final String? height;
  final String? bitrate;
  final String? original;
  final String? sha1;
  final bool isFavorite;

  const VideoFile({
    required this.name,
    required this.source,
    required this.format,
    this.size,
    this.mtime,
    this.length,
    this.width,
    this.height,
    this.bitrate,
    this.original,
    this.sha1,
    this.isFavorite = false,
  });

  /// Create from ArchiveFile
  factory VideoFile.fromArchiveFile(ArchiveFile file) {
    return VideoFile(
      name: file.name,
      source: file.source,
      format: file.format,
      size: file.size,
      mtime: file.mtime,
      length: file.length,
      width: file.width,
      height: file.height,
      bitrate: file.bitrate,
      original: file.original,
      sha1: file.sha1,
    );
  }

  /// Parse from JSON directly
  factory VideoFile.fromJson(Map<String, dynamic> json) {
    return VideoFile(
      name: json['name']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      size: _parseInt(json['size']),
      mtime: json['mtime']?.toString(),
      length: json['length']?.toString(),
      width: json['width']?.toString(),
      height: json['height']?.toString(),
      bitrate: json['bitrate']?.toString(),
      original: json['original']?.toString(),
      sha1: json['sha1']?.toString(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  /// Get download/stream URL
  String getUrl(String identifier) =>
      'https://archive.org/download/$identifier/$name';

  /// Get file extension
  String get extension {
    final lastDot = name.lastIndexOf('.');
    if (lastDot != -1 && lastDot < name.length - 1) {
      return name.substring(lastDot + 1).toUpperCase();
    }
    return format.split(' ').first.toUpperCase();
  }

  /// Check if original file
  bool get isOriginal => source.toLowerCase() == 'original';

  /// Check if derivative file
  bool get isDerivative => source.toLowerCase() == 'derivative';

  /// Get formatted size
  String get formattedSize {
    if (size == null || size! <= 0) return 'Unknown';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var fileSize = size!.toDouble();
    var suffixIndex = 0;

    while (fileSize >= 1024 && suffixIndex < suffixes.length - 1) {
      fileSize /= 1024;
      suffixIndex++;
    }

    return '${fileSize.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }

  /// Get formatted duration
  String get formattedDuration {
    if (length == null || length!.isEmpty) return '';

    try {
      final seconds = double.tryParse(length!) ?? 0;
      if (seconds <= 0) return '';

      final hours = (seconds / 3600).floor();
      final minutes = ((seconds % 3600) / 60).floor();
      final secs = (seconds % 60).floor();

      if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      }
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  /// Get resolution string
  String get resolution {
    if (width != null && height != null) {
      final w = int.tryParse(width!) ?? 0;
      final h = int.tryParse(height!) ?? 0;
      if (w > 0 && h > 0) {
        return '${w}x$h';
      }
    }
    return '';
  }

  /// Get video quality based on height
  VideoQuality get quality {
    final h = int.tryParse(height ?? '0') ?? 0;

    if (h >= 2160) return VideoQuality.uhd4k;
    if (h >= 1080) return VideoQuality.hd1080;
    if (h >= 720) return VideoQuality.hd720;
    if (h >= 480) return VideoQuality.high;
    if (h >= 360) return VideoQuality.medium;
    if (h > 0) return VideoQuality.low;

    // Estimate from file size if height not available
    if (size != null && size! > 0) {
      final sizeMB = size! / (1024 * 1024);
      // Rough estimate based on file size
      if (sizeMB > 4000) return VideoQuality.uhd4k;
      if (sizeMB > 2000) return VideoQuality.hd1080;
      if (sizeMB > 700) return VideoQuality.hd720;
      if (sizeMB > 300) return VideoQuality.high;
      if (sizeMB > 100) return VideoQuality.medium;
      if (sizeMB > 0) return VideoQuality.low;
    }

    return VideoQuality.unknown;
  }

  /// Get formatted bitrate
  String get formattedBitrate {
    if (bitrate == null || bitrate!.isEmpty) return '';

    try {
      final kbps = double.tryParse(bitrate!) ?? 0;
      if (kbps <= 0) return '';

      if (kbps >= 1000) {
        return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
      }
      return '${kbps.toStringAsFixed(0)} kbps';
    } catch (e) {
      return bitrate ?? '';
    }
  }

  /// Get display name (filename without path)
  String get displayName {
    if (name.contains('/')) {
      return name.split('/').last;
    }
    return name;
  }

  /// Copy with new values
  VideoFile copyWith({
    String? name,
    String? source,
    String? format,
    int? size,
    String? mtime,
    String? length,
    String? width,
    String? height,
    String? bitrate,
    String? original,
    String? sha1,
    bool? isFavorite,
  }) {
    return VideoFile(
      name: name ?? this.name,
      source: source ?? this.source,
      format: format ?? this.format,
      size: size ?? this.size,
      mtime: mtime ?? this.mtime,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      bitrate: bitrate ?? this.bitrate,
      original: original ?? this.original,
      sha1: sha1 ?? this.sha1,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [
    name,
    source,
    format,
    size,
    mtime,
    length,
    width,
    height,
    bitrate,
    original,
    sha1,
    isFavorite,
  ];

  factory VideoFile.fromMap(Map<String, dynamic> json) =>
      VideoFile.fromJson(json);

  Map<String, dynamic> toMap() => {
    'name': name,
    'source': source,
    'format': format,
    'size': size,
    'mtime': mtime,
    'length': length,
    'width': width,
    'height': height,
    'bitrate': bitrate,
    'original': original,
    'sha1': sha1,
    'isFavorite': isFavorite,
  };
}
