import 'media_file.dart';

class UrlHistory {
  final String id;
  final String url;
  final String? title;
  final String? mimeType;
  final MediaType mediaType;
  final DateTime lastPlayed;
  final int playCount;
  final bool isFavorite;

  UrlHistory({
    required this.id,
    required this.url,
    this.title,
    this.mimeType,
    required this.mediaType,
    required this.lastPlayed,
    this.playCount = 1,
    this.isFavorite = false,
  });

  UrlHistory copyWith({
    String? id,
    String? url,
    String? title,
    String? mimeType,
    MediaType? mediaType,
    DateTime? lastPlayed,
    int? playCount,
    bool? isFavorite,
  }) {
    return UrlHistory(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      mimeType: mimeType ?? this.mimeType,
      mediaType: mediaType ?? this.mediaType,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      playCount: playCount ?? this.playCount,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'mimeType': mimeType,
      'mediaType': mediaType.index,
      'lastPlayed': lastPlayed.toIso8601String(),
      'playCount': playCount,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory UrlHistory.fromJson(Map<String, dynamic> json) {
    return UrlHistory(
      id: json['id'] as String,
      url: json['url'] as String,
      title: json['title'] as String?,
      mimeType: json['mimeType'] as String?,
      mediaType: MediaType.values[json['mediaType'] as int],
      lastPlayed: DateTime.parse(json['lastPlayed'] as String),
      playCount: json['playCount'] as int,
      isFavorite: json['isFavorite'] == 1,
    );
  }
}
