import 'package:equatable/equatable.dart';

class VideoItem extends Equatable {
  final String identifier;
  final String title;
  final String? description;
  final String? creator;
  final String? date;
  final String mediaType;
  final int downloads;
  final int itemSize;
  final String? format;
  final bool isSaved;
  final bool isLiked;
  final String? duration;
  final String? subject;
  final String? collection;
  final String? language;

  const VideoItem({
    required this.identifier,
    required this.title,
    this.description,
    this.creator,
    this.date,
    required this.mediaType,
    this.downloads = 0,
    this.itemSize = 0,
    this.format,
    this.isSaved = false,
    this.isLiked = false,
    this.duration,
    this.subject,
    this.collection,
    this.language,
  });

  // Thumbnail URL for Archive.org items
  String get thumbnailUrl => 'https://archive.org/services/img/$identifier';

  // Detail page URL
  String get detailsUrl => 'https://archive.org/details/$identifier';

  // Download URL
  String get downloadUrl => 'https://archive.org/download/$identifier';

  // Embed URL for video player
  String get embedUrl => 'https://archive.org/embed/$identifier';

  // Stream URL
  String get streamUrl =>
      'https://archive.org/download/$identifier/$identifier.mp4';

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

  // Formatted duration
  String get formattedDuration {
    if (duration == null || duration!.isEmpty) return '';

    try {
      // Handle different duration formats from Archive.org
      // Could be "HH:MM:SS", "MM:SS", seconds as string, etc.
      if (duration!.contains(':')) {
        return duration!;
      }

      final seconds = double.tryParse(duration!) ?? 0;
      if (seconds <= 0) return '';

      final hours = (seconds / 3600).floor();
      final minutes = ((seconds % 3600) / 60).floor();
      final secs = (seconds % 60).floor();

      if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      }
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } catch (e) {
      return duration ?? '';
    }
  }

  // Year from date
  String? get year {
    if (date == null || date!.isEmpty) return null;
    try {
      if (date!.length >= 4) {
        return date!.substring(0, 4);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      identifier: json['identifier']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      description: json['description']?.toString(),
      creator: _parseCreator(json['creator']),
      date: json['date']?.toString(),
      mediaType: json['mediatype']?.toString() ?? '',
      downloads: _parseInt(json['downloads']),
      itemSize: _parseInt(json['item_size']),
      format: _parseFormat(json['format']),
      duration: json['runtime']?.toString() ?? json['length']?.toString(),
      subject: _parseSubject(json['subject']),
      collection: _parseCollection(json['collection']),
      language: json['language']?.toString(),
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
      // Filter for video formats
      final videoFormats = format.where((f) {
        final str = f.toString().toLowerCase();
        return str.contains('mp4') ||
            str.contains('mpeg') ||
            str.contains('avi') ||
            str.contains('mkv') ||
            str.contains('webm') ||
            str.contains('mov');
      }).toList();
      if (videoFormats.isNotEmpty) {
        return videoFormats.join(', ');
      }
      return format.take(3).join(', ');
    }
    return null;
  }

  static String? _parseSubject(dynamic subject) {
    if (subject == null) return null;
    if (subject is String) return subject;
    if (subject is List && subject.isNotEmpty) {
      return subject.take(3).join(', ');
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
      'runtime': duration,
      'subject': subject,
      'collection': collection,
      'language': language,
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
    };
  }

  Map<String, dynamic> toSavedDbMap() {
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
      'duration': duration,
      'saved_at': DateTime.now().toIso8601String(),
    };
  }

  factory VideoItem.fromDbMap(Map<String, dynamic> map) {
    return VideoItem(
      identifier: map['identifier'] ?? '',
      title: map['title'] ?? 'Untitled',
      description: map['description'],
      creator: map['creator'],
      date: map['date'],
      mediaType: map['mediatype'] ?? 'movies',
      downloads: map['downloads'] ?? 0,
      itemSize: map['item_size'] ?? 0,
      duration: map['duration'],
    );
  }

  VideoItem copyWith({
    String? identifier,
    String? title,
    String? description,
    String? creator,
    String? date,
    String? mediaType,
    int? downloads,
    int? itemSize,
    String? format,
    bool? isSaved,
    bool? isLiked,
    String? duration,
    String? subject,
    String? collection,
    String? language,
  }) {
    return VideoItem(
      identifier: identifier ?? this.identifier,
      title: title ?? this.title,
      description: description ?? this.description,
      creator: creator ?? this.creator,
      date: date ?? this.date,
      mediaType: mediaType ?? this.mediaType,
      downloads: downloads ?? this.downloads,
      itemSize: itemSize ?? this.itemSize,
      format: format ?? this.format,
      isSaved: isSaved ?? this.isSaved,
      isLiked: isLiked ?? this.isLiked,
      duration: duration ?? this.duration,
      subject: subject ?? this.subject,
      collection: collection ?? this.collection,
      language: language ?? this.language,
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
    isSaved,
    isLiked,
    duration,
    subject,
    collection,
    language,
  ];
}
