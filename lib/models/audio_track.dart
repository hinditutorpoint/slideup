// models/audio_track.dart
class AudioTrack {
  final int id;
  final String language;
  final String label;
  final int channels;
  final String? codec;
  final int? bitrate;
  final bool isDefault;

  const AudioTrack({
    required this.id,
    required this.language,
    required this.label,
    required this.channels,
    this.codec,
    this.bitrate,
    this.isDefault = false,
  });

  // ✅ Create from JSON (for native communication)
  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      id: json['id'] as int,
      language: json['language'] as String? ?? 'Unknown',
      label: json['label'] as String? ?? 'Track ${json['id']}',
      channels: json['channels'] as int? ?? 2,
      codec: json['codec'] as String?,
      bitrate: json['bitrate'] as int?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'language': language,
      'label': label,
      'channels': channels,
      'codec': codec,
      'bitrate': bitrate,
      'isDefault': isDefault,
    };
  }

  @override
  String toString() {
    return 'AudioTrack(id: $id, language: $language, label: $label)';
  }
}
