import 'package:equatable/equatable.dart';

/// Supported file types for filtering
enum ArchiveFileType { video, audio, image, pdf, text, metadata, other }

/// Base class for all Archive.org files
class ArchiveFile extends Equatable {
  final String name;
  final String source;
  final String format;
  final int? size;
  final String? mtime;
  final String? md5;
  final String? crc32;
  final String? sha1;

  // Video/Audio specific
  final String? length;
  final String? width;
  final String? height;
  final String? bitrate;

  // Original reference (for derivatives)
  final String? original;

  const ArchiveFile({
    required this.name,
    required this.source,
    required this.format,
    this.size,
    this.mtime,
    this.md5,
    this.crc32,
    this.sha1,
    this.length,
    this.width,
    this.height,
    this.bitrate,
    this.original,
  });

  /// Get download URL for this file
  String getDownloadUrl(String identifier) =>
      'https://archive.org/download/$identifier/$name';

  /// Check if this is an original file
  bool get isOriginal => source.toLowerCase() == 'original';

  /// Check if this is a derivative file
  bool get isDerivative => source.toLowerCase() == 'derivative';

  /// Get file extension
  String get extension {
    final lastDot = name.lastIndexOf('.');
    if (lastDot != -1 && lastDot < name.length - 1) {
      return name.substring(lastDot + 1).toLowerCase();
    }
    return '';
  }

  /// Get file extension for display (uppercase)
  String get extensionDisplay => extension.toUpperCase();

  /// Get formatted file size
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

  /// Get file type based on extension and format
  ArchiveFileType get fileType {
    final ext = extension;
    final fmt = format.toLowerCase();

    // Video
    if (_videoExtensions.contains(ext) ||
        _videoFormats.any((f) => fmt.contains(f))) {
      return ArchiveFileType.video;
    }

    // Audio
    if (_audioExtensions.contains(ext) ||
        _audioFormats.any((f) => fmt.contains(f))) {
      return ArchiveFileType.audio;
    }

    // Image
    if (_imageExtensions.contains(ext) ||
        _imageFormats.any((f) => fmt.contains(f))) {
      return ArchiveFileType.image;
    }

    // PDF
    if (ext == 'pdf' || fmt.contains('pdf')) {
      return ArchiveFileType.pdf;
    }

    // Text
    if (_textExtensions.contains(ext) ||
        _textFormats.any((f) => fmt.contains(f))) {
      return ArchiveFileType.text;
    }

    // Metadata
    if (_metadataExtensions.contains(ext) || fmt.contains('metadata')) {
      return ArchiveFileType.metadata;
    }

    return ArchiveFileType.other;
  }

  /// Parse from JSON
  factory ArchiveFile.fromJson(Map<String, dynamic> json) {
    return ArchiveFile(
      name: json['name']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      size: _parseInt(json['size']),
      mtime: json['mtime']?.toString(),
      md5: json['md5']?.toString(),
      crc32: json['crc32']?.toString(),
      sha1: json['sha1']?.toString(),
      length: json['length']?.toString(),
      width: json['width']?.toString(),
      height: json['height']?.toString(),
      bitrate: json['bitrate']?.toString(),
      original: json['original']?.toString(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  // File extension lists
  static const _videoExtensions = {
    'mp4',
    'm4v',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    '3gp',
    '3g2',
    'ts',
    'm2ts',
    'mts',
    'mpg',
    'mpeg',
    'ogv',
    'vob',
    'divx',
    'xvid',
    'asf',
    'rm',
    'rmvb',
    'f4v',
  };

  static const _audioExtensions = {
    'mp3',
    'flac',
    'ogg',
    'oga',
    'wav',
    'wma',
    'm4a',
    'aac',
    'aiff',
    'aif',
    'opus',
    'wv',
    'ape',
    'mpc',
    'shn',
    'spx',
  };

  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'tiff',
    'tif',
    'svg',
    'ico',
    'heic',
    'heif',
  };

  static const _textExtensions = {
    'txt',
    'doc',
    'docx',
    'rtf',
    'odt',
    'epub',
    'mobi',
    'azw',
    'djvu',
    'chm',
    'html',
    'htm',
    'xml',
    'json',
  };

  static const _metadataExtensions = {'xml', 'sqlite', 'torrent'};

  static const _videoFormats = [
    'mpeg4',
    'mpeg-4',
    'h.264',
    'h264',
    'avc',
    'hevc',
    'h.265',
    'h265',
    'vp8',
    'vp9',
    'av1',
    'theora',
    'divx',
    'xvid',
    'wmv',
    'flash video',
    'quicktime',
    'matroska',
    'webm',
    'ogg video',
    'cinepack',
    'video',
  ];

  static const _audioFormats = [
    'mp3',
    'flac',
    'vorbis',
    'opus',
    'aac',
    'wma',
    'pcm',
    'wave',
    'aiff',
    'audio',
    'lossless',
    'lossy',
  ];

  static const _imageFormats = [
    'jpeg',
    'png',
    'gif',
    'webp',
    'bitmap',
    'tiff',
    'thumbnail',
    'image',
    'poster',
    'cover',
    'spectrogram',
  ];

  static const _textFormats = ['text', 'djvu', 'epub', 'kindle', 'document'];

  @override
  List<Object?> get props => [
    name,
    source,
    format,
    size,
    mtime,
    md5,
    length,
    width,
    height,
    bitrate,
    original,
  ];
}
