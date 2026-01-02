// models/video_quality.dart
class VideoQuality {
  final String label;
  final int width;
  final int height;
  final int bitrate;
  final String url;
  final String? codec;
  final double? frameRate;
  final bool isOriginal;
  final bool isTranscoded;

  const VideoQuality({
    required this.label,
    required this.width,
    required this.height,
    required this.bitrate,
    required this.url,
    this.codec,
    this.frameRate,
    this.isOriginal = false,
    this.isTranscoded = false,
  });

  String get resolution => '${width}x$height';

  String get bitrateMbps => '${(bitrate / 1000000).toStringAsFixed(1)} Mbps';

  String get frameRateString =>
      frameRate != null ? '${frameRate!.toStringAsFixed(0)}fps' : '';

  VideoQuality copyWith({
    String? label,
    int? width,
    int? height,
    int? bitrate,
    String? url,
    String? codec,
    double? frameRate,
    bool? isOriginal,
    bool? isTranscoded,
  }) {
    return VideoQuality(
      label: label ?? this.label,
      width: width ?? this.width,
      height: height ?? this.height,
      bitrate: bitrate ?? this.bitrate,
      url: url ?? this.url,
      codec: codec ?? this.codec,
      frameRate: frameRate ?? this.frameRate,
      isOriginal: isOriginal ?? this.isOriginal,
      isTranscoded: isTranscoded ?? this.isTranscoded,
    );
  }

  factory VideoQuality.fromJson(Map<String, dynamic> json) {
    return VideoQuality(
      label: json['label'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      bitrate: json['bitrate'] as int,
      url: json['url'] as String,
      codec: json['codec'] as String?,
      frameRate: json['frameRate'] as double?,
      isOriginal: json['isOriginal'] as bool? ?? false,
      isTranscoded: json['isTranscoded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'width': width,
      'height': height,
      'bitrate': bitrate,
      'url': url,
      'codec': codec,
      'frameRate': frameRate,
      'isOriginal': isOriginal,
      'isTranscoded': isTranscoded,
    };
  }

  @override
  String toString() {
    return 'VideoQuality(label: $label, resolution: $resolution, bitrate: $bitrateMbps)';
  }
}
