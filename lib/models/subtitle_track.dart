// models/subtitle_track.dart
class SubtitleTrack {
  final int id;
  final String language;
  final String label;
  final bool isTranscribed;
  final bool isTranslated;
  final String? filePath;
  final String? format; // srt, vtt, ass, etc.
  final bool isEmbedded;
  final bool isExternal;

  const SubtitleTrack({
    required this.id,
    required this.language,
    required this.label,
    this.isTranscribed = false,
    this.isTranslated = false,
    this.filePath,
    this.format,
    this.isEmbedded = false,
    this.isExternal = false,
  });

  SubtitleTrack copyWith({
    int? id,
    String? language,
    String? label,
    bool? isTranscribed,
    bool? isTranslated,
    String? filePath,
    String? format,
    bool? isEmbedded,
    bool? isExternal,
  }) {
    return SubtitleTrack(
      id: id ?? this.id,
      language: language ?? this.language,
      label: label ?? this.label,
      isTranscribed: isTranscribed ?? this.isTranscribed,
      isTranslated: isTranslated ?? this.isTranslated,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      isEmbedded: isEmbedded ?? this.isEmbedded,
      isExternal: isExternal ?? this.isExternal,
    );
  }

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    return SubtitleTrack(
      id: json['id'] as int,
      language: json['language'] as String,
      label: json['label'] as String,
      isTranscribed: json['isTranscribed'] as bool? ?? false,
      isTranslated: json['isTranslated'] as bool? ?? false,
      filePath: json['filePath'] as String?,
      format: json['format'] as String?,
      isEmbedded: json['isEmbedded'] as bool? ?? false,
      isExternal: json['isExternal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'language': language,
      'label': label,
      'isTranscribed': isTranscribed,
      'isTranslated': isTranslated,
      'filePath': filePath,
      'format': format,
      'isEmbedded': isEmbedded,
      'isExternal': isExternal,
    };
  }
}
