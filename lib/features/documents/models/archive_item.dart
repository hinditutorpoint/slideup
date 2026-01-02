import 'package:equatable/equatable.dart';

class ArchiveItem extends Equatable {
  final String identifier;
  final String title;
  final String? description;
  final String? creator;
  final String? date;
  final String mediaType;
  final int downloads;
  final int itemSize;
  final String? format;
  final bool isLiked;

  const ArchiveItem({
    required this.identifier,
    required this.title,
    this.description,
    this.creator,
    this.date,
    required this.mediaType,
    this.downloads = 0,
    this.itemSize = 0,
    this.format,
    this.isLiked = false,
  });

  // Thumbnail URL for Archive.org items
  String get thumbnailUrl => 'https://archive.org/services/img/$identifier';

  // Detail page URL
  String get detailsUrl => 'https://archive.org/details/$identifier';

  // Download URL
  String get downloadUrl => 'https://archive.org/download/$identifier/$title';

  // Formatted size
  String get formattedSize {
    if (itemSize <= 0) return 'Unknown';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = itemSize.toDouble();
    var suffixIndex = 0;

    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }

  // Formatted downloads
  String get formattedDownloads {
    if (downloads <= 0) return '0';

    if (downloads >= 1000000) {
      return '${(downloads / 1000000).toStringAsFixed(1)}M';
    } else if (downloads >= 1000) {
      return '${(downloads / 1000).toStringAsFixed(1)}K';
    }
    return downloads.toString();
  }

  factory ArchiveItem.fromJson(Map<String, dynamic> json) {
    return ArchiveItem(
      identifier: json['identifier']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      description: json['description']?.toString(),
      creator: _parseCreator(json['creator']),
      date: json['date']?.toString(),
      mediaType: json['mediatype']?.toString() ?? '',
      downloads: _parseInt(json['downloads']),
      itemSize: _parseInt(json['item_size']),
      format: _parseFormat(json['format']),
    );
  }

  static String? _parseCreator(dynamic creator) {
    if (creator == null) return null;
    if (creator is String) return creator;
    if (creator is List && creator.isNotEmpty) {
      return creator.first.toString();
    }
    return null;
  }

  static String? _parseFormat(dynamic format) {
    if (format == null) return null;
    if (format is String) return format;
    if (format is List && format.isNotEmpty) {
      return format.join(', ');
    }
    return null;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'title': title,
      'description': description,
      'creator': creator,
      'date': date,
      'mediatype': mediaType,
      'downloads': downloads,
      'item_size': itemSize,
      'format': format,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'identifier': identifier,
      'title': title,
      'description': description,
      'creator': creator,
      'date': date,
      'mediatype': mediaType,
      'downloads': downloads,
      'item_size': itemSize,
      'thumbnail_url': thumbnailUrl,
      'format': format,
      'liked_at': DateTime.now().toIso8601String(),
    };
  }

  factory ArchiveItem.fromDbMap(Map<String, dynamic> map) {
    return ArchiveItem(
      identifier: map['identifier'] ?? '',
      title: map['title'] ?? 'Untitled',
      description: map['description'],
      creator: map['creator'],
      date: map['date'],
      mediaType: map['mediatype'] ?? '',
      downloads: map['downloads'] ?? 0,
      itemSize: map['item_size'] ?? 0,
      format: map['format'],
      isLiked: true,
    );
  }

  ArchiveItem copyWith({
    String? identifier,
    String? title,
    String? description,
    String? creator,
    String? date,
    String? mediaType,
    int? downloads,
    int? itemSize,
    String? format,
    bool? isLiked,
  }) {
    return ArchiveItem(
      identifier: identifier ?? this.identifier,
      title: title ?? this.title,
      description: description ?? this.description,
      creator: creator ?? this.creator,
      date: date ?? this.date,
      mediaType: mediaType ?? this.mediaType,
      downloads: downloads ?? this.downloads,
      itemSize: itemSize ?? this.itemSize,
      format: format ?? this.format,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  @override
  List<Object?> get props => [
    identifier,
    title,
    description,
    creator,
    date,
    mediaType,
    downloads,
    itemSize,
    format,
    isLiked,
  ];
}
