int? _parseInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

class QualityVariant {
  final String url;
  final String? quality;
  final int? width;
  final int? height;
  final int? bitrate;

  const QualityVariant({
    required this.url,
    this.quality,
    this.width,
    this.height,
    this.bitrate,
  });

  factory QualityVariant.fromMap(Map<String, dynamic> map) {
    return QualityVariant(
      url: map['url']?.toString() ?? '',
      quality: map['quality']?.toString(),
      width: _parseInt(map['width']),
      height: _parseInt(map['height']),
      bitrate: _parseInt(map['bitrate']),
    );
  }

  String get displayName {
    if (quality != null) return quality!;
    if (height != null) return '${height}p';
    if (bitrate != null) return '${bitrate! ~/ 1000}Mbps';
    return 'Unknown';
  }
}
