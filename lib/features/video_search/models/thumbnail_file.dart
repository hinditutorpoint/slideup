import 'package:equatable/equatable.dart';
import 'archive_file.dart';

class ThumbnailFile extends Equatable {
  final String name;
  final String source;
  final String format;
  final int? size;
  final String? mtime;
  final String? width;
  final String? height;
  final bool isFavorite;

  const ThumbnailFile({
    required this.name,
    required this.source,
    required this.format,
    this.size,
    this.mtime,
    this.width,
    this.height,
    this.isFavorite = false,
  });

  /// Create from ArchiveFile
  factory ThumbnailFile.fromArchiveFile(ArchiveFile file) {
    return ThumbnailFile(
      name: file.name,
      source: file.source,
      format: file.format,
      size: file.size,
      mtime: file.mtime,
      width: file.width,
      height: file.height,
    );
  }

  /// Parse from JSON directly
  factory ThumbnailFile.fromJson(Map<String, dynamic> json) {
    return ThumbnailFile(
      name: json['name']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      size: _parseInt(json['size']),
      mtime: json['mtime']?.toString(),
      width: json['width']?.toString(),
      height: json['height']?.toString(),
    );
  }

  factory ThumbnailFile.fromMap(Map<String, dynamic> map) =>
      ThumbnailFile.fromJson(map);

  Map<String, dynamic> toJson() => {
    'name': name,
    'source': source,
    'format': format,
    'size': size,
    'mtime': mtime,
    'width': width,
    'height': height,
    'isFavorite': isFavorite,
  };

  Map<String, dynamic> toMap() => toJson();

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  /// Get image URL
  String getUrl(String identifier) =>
      'https://archive.org/download/$identifier/$name';

  /// Get file extension
  String get extension {
    final lastDot = name.lastIndexOf('.');
    if (lastDot != -1 && lastDot < name.length - 1) {
      return name.substring(lastDot + 1).toUpperCase();
    }
    return 'IMG';
  }

  /// Get formatted size
  String get formattedSize {
    if (size == null || size! <= 0) return 'Unknown';

    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var fileSize = size!.toDouble();
    var suffixIndex = 0;

    while (fileSize >= 1024 && suffixIndex < suffixes.length - 1) {
      fileSize /= 1024;
      suffixIndex++;
    }

    return '${fileSize.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
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

  /// Get display name
  String get displayName {
    String result = name;

    // Remove path prefix
    if (result.contains('/')) {
      result = result.split('/').last;
    }

    // Remove extension
    final lastDot = result.lastIndexOf('.');
    if (lastDot > 0) {
      result = result.substring(0, lastDot);
    }

    // Replace underscores and hyphens with spaces
    result = result.replaceAll(RegExp(r'[_-]'), ' ');

    // Capitalize first letter
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }

    return result.isEmpty ? 'Image' : result;
  }

  /// Check if this is a thumbnail (vs other images)
  bool get isThumbnail {
    final lowerName = name.toLowerCase();
    final lowerFormat = format.toLowerCase();

    return lowerName.contains('thumb') ||
        lowerName.contains('_000') ||
        lowerFormat.contains('thumbnail') ||
        lowerFormat.contains('spectrogram');
  }

  /// Copy with new values
  ThumbnailFile copyWith({
    String? name,
    String? source,
    String? format,
    int? size,
    String? mtime,
    String? width,
    String? height,
    bool? isFavorite,
  }) {
    return ThumbnailFile(
      name: name ?? this.name,
      source: source ?? this.source,
      format: format ?? this.format,
      size: size ?? this.size,
      mtime: mtime ?? this.mtime,
      width: width ?? this.width,
      height: height ?? this.height,
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
    width,
    height,
    isFavorite,
  ];
}
