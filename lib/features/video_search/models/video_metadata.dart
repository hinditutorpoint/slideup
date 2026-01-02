import 'package:equatable/equatable.dart';
import 'archive_file.dart';
import 'video_file.dart';
import 'thumbnail_file.dart';

class VideoMetadata extends Equatable {
  final String identifier;
  final String title;
  final String? description;
  final String? creator;
  final String? date;
  final String? collection;
  final String? subject;
  final String? licenseUrl;
  final String? mediaType;
  final int? downloads;
  final int? itemSize;
  final int filesCount;
  final String? server;
  final String? dir;
  final List<VideoFile> videoFiles;
  final List<ThumbnailFile> thumbnails;
  final List<ArchiveFile> allFiles;

  const VideoMetadata({
    required this.identifier,
    required this.title,
    this.description,
    this.creator,
    this.date,
    this.collection,
    this.subject,
    this.licenseUrl,
    this.mediaType,
    this.downloads,
    this.itemSize,
    this.filesCount = 0,
    this.server,
    this.dir,
    this.videoFiles = const [],
    this.thumbnails = const [],
    this.allFiles = const [],
  });

  /// Detail page URL
  String get detailsUrl => 'https://archive.org/details/$identifier';

  /// Download base URL
  String get downloadBaseUrl => 'https://archive.org/download/$identifier';

  /// Embed URL
  String get embedUrl => 'https://archive.org/embed/$identifier';

  /// Formatted item size
  String get formattedItemSize {
    if (itemSize == null || itemSize! <= 0) return 'Unknown';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = itemSize!.toDouble();
    var suffixIndex = 0;

    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }

  /// Formatted downloads count
  String get formattedDownloads {
    if (downloads == null || downloads! <= 0) return '0';

    if (downloads! >= 1000000) {
      return '${(downloads! / 1000000).toStringAsFixed(1)}M';
    } else if (downloads! >= 1000) {
      return '${(downloads! / 1000).toStringAsFixed(1)}K';
    }
    return downloads.toString();
  }

  /// Parse from API response
  factory VideoMetadata.fromJson(Map<String, dynamic> json) {
    // Parse metadata section
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};

    // Parse files array
    final filesJson = json['files'] as List<dynamic>? ?? [];

    // Parse all files first
    final allFiles = <ArchiveFile>[];
    final videoFiles = <VideoFile>[];
    final thumbnails = <ThumbnailFile>[];

    for (final fileJson in filesJson) {
      if (fileJson is! Map<String, dynamic>) continue;

      final file = ArchiveFile.fromJson(fileJson);

      // Skip metadata files
      if (_shouldSkipFile(file.name)) continue;

      allFiles.add(file);

      // Categorize file
      switch (file.fileType) {
        case ArchiveFileType.video:
          videoFiles.add(VideoFile.fromArchiveFile(file));
          break;
        case ArchiveFileType.image:
          thumbnails.add(ThumbnailFile.fromArchiveFile(file));
          break;
        default:
          break;
      }
    }

    // Sort video files by quality (best first)
    videoFiles.sort((a, b) {
      final qualityCompare = b.quality.sortOrder.compareTo(a.quality.sortOrder);
      if (qualityCompare != 0) return qualityCompare;
      // If same quality, sort by size (larger first)
      return (b.size ?? 0).compareTo(a.size ?? 0);
    });

    // Sort thumbnails by name
    thumbnails.sort((a, b) => a.name.compareTo(b.name));

    return VideoMetadata(
      identifier:
          _parseString(metadata['identifier']) ??
          _parseString(json['metadata']?['identifier']) ??
          '',
      title: _parseString(metadata['title']) ?? 'Untitled',
      description: _parseString(metadata['description']),
      creator: _parseCreator(metadata['creator']),
      date: _parseString(metadata['date']),
      collection: _parseCollection(metadata['collection']),
      subject: _parseSubject(metadata['subject']),
      licenseUrl: _parseString(metadata['licenseurl']),
      mediaType: _parseString(metadata['mediatype']),
      downloads: _parseInt(json['item']?['downloads']),
      itemSize: _parseInt(json['item_size']),
      filesCount: _parseInt(json['files_count']) ?? filesJson.length,
      server: _parseString(json['server']) ?? _parseString(json['d1']),
      dir: _parseString(json['dir']),
      videoFiles: videoFiles,
      thumbnails: thumbnails,
      allFiles: allFiles,
    );
  }

  /// Check if file should be skipped (metadata, torrents, etc.)
  static bool _shouldSkipFile(String name) {
    final lowerName = name.toLowerCase();
    return lowerName.endsWith('_meta.xml') ||
        lowerName.endsWith('_meta.sqlite') ||
        lowerName.endsWith('_files.xml') ||
        lowerName.endsWith('_archive.torrent') ||
        lowerName.endsWith('.torrent') ||
        lowerName.endsWith('_reviews.xml') ||
        lowerName == '__ia_thumb.jpg';
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isNotEmpty ? value : null;
    if (value is List && value.isNotEmpty) return value.first.toString();
    return value.toString();
  }

  static String? _parseCreator(dynamic creator) {
    if (creator == null) return null;
    if (creator is String) return creator;
    if (creator is List && creator.isNotEmpty) {
      return creator.map((e) => e.toString()).join(', ');
    }
    return null;
  }

  static String? _parseCollection(dynamic collection) {
    if (collection == null) return null;
    if (collection is String) return collection;
    if (collection is List && collection.isNotEmpty) {
      return collection.first.toString();
    }
    return null;
  }

  static String? _parseSubject(dynamic subject) {
    if (subject == null) return null;
    if (subject is String) return subject;
    if (subject is List && subject.isNotEmpty) {
      return subject.take(5).map((e) => e.toString()).join(', ');
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  /// Copy with new values
  VideoMetadata copyWith({
    String? identifier,
    String? title,
    String? description,
    String? creator,
    String? date,
    String? collection,
    String? subject,
    String? licenseUrl,
    String? mediaType,
    int? downloads,
    int? itemSize,
    int? filesCount,
    String? server,
    String? dir,
    List<VideoFile>? videoFiles,
    List<ThumbnailFile>? thumbnails,
    List<ArchiveFile>? allFiles,
  }) {
    return VideoMetadata(
      identifier: identifier ?? this.identifier,
      title: title ?? this.title,
      description: description ?? this.description,
      creator: creator ?? this.creator,
      date: date ?? this.date,
      collection: collection ?? this.collection,
      subject: subject ?? this.subject,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      mediaType: mediaType ?? this.mediaType,
      downloads: downloads ?? this.downloads,
      itemSize: itemSize ?? this.itemSize,
      filesCount: filesCount ?? this.filesCount,
      server: server ?? this.server,
      dir: dir ?? this.dir,
      videoFiles: videoFiles ?? this.videoFiles,
      thumbnails: thumbnails ?? this.thumbnails,
      allFiles: allFiles ?? this.allFiles,
    );
  }

  @override
  List<Object?> get props => [
    identifier,
    title,
    description,
    creator,
    date,
    collection,
    subject,
    licenseUrl,
    mediaType,
    downloads,
    itemSize,
    filesCount,
    server,
    dir,
    videoFiles,
    thumbnails,
    allFiles,
  ];
}
