import 'package:flutter/material.dart';

class VideoSettings {
  final double brightness;
  final double contrast;
  final double saturation;
  final double hue;
  final bool hardwareDecoder;
  final bool pipEnabled;
  final PlaybackSpeed speed;
  final bool subtitlesEnabled;
  final Color subtitleColor;
  final double subtitleSize;

  const VideoSettings({
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.hue = 0.0,
    this.hardwareDecoder = true,
    this.pipEnabled = false,
    this.speed = PlaybackSpeed.normal,
    this.subtitlesEnabled = false,
    this.subtitleColor = Colors.white,
    this.subtitleSize = 16.0,
  });

  VideoSettings copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? hue,
    bool? hardwareDecoder,
    bool? pipEnabled,
    PlaybackSpeed? speed,
    bool? subtitlesEnabled,
    Color? subtitleColor,
    double? subtitleSize,
  }) {
    return VideoSettings(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      hue: hue ?? this.hue,
      hardwareDecoder: hardwareDecoder ?? this.hardwareDecoder,
      pipEnabled: pipEnabled ?? this.pipEnabled,
      speed: speed ?? this.speed,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      subtitleColor: subtitleColor ?? this.subtitleColor,
      subtitleSize: subtitleSize ?? this.subtitleSize,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'hue': hue,
      'hardwareDecoder': hardwareDecoder,
      'pipEnabled': pipEnabled,
      'speed': speed.value,
      'subtitlesEnabled': subtitlesEnabled,
      'subtitleColor': subtitleColor.toARGB32(),
      'subtitleSize': subtitleSize,
    };
  }

  factory VideoSettings.fromJson(Map<String, dynamic> json) {
    return VideoSettings(
      brightness: json['brightness'] ?? 0.0,
      contrast: json['contrast'] ?? 0.0,
      saturation: json['saturation'] ?? 0.0,
      hue: json['hue'] ?? 0.0,
      hardwareDecoder: json['hardwareDecoder'] ?? true,
      pipEnabled: json['pipEnabled'] ?? false,
      speed: PlaybackSpeed.fromValue(json['speed'] ?? 1.0),
      subtitlesEnabled: json['subtitlesEnabled'] ?? false,
      subtitleColor: Color(json['subtitleColor'] ?? Colors.white.toARGB32()),
      subtitleSize: json['subtitleSize'] ?? 16.0,
    );
  }
}

enum PlaybackSpeed {
  slow(0.5, '0.5x'),
  slower(0.75, '0.75x'),
  normal(1.0, '1.0x'),
  faster(1.25, '1.25x'),
  fast(1.5, '1.5x'),
  veryFast(2.0, '2.0x');

  final double value;
  final String label;

  const PlaybackSpeed(this.value, this.label);

  static PlaybackSpeed fromValue(double value) {
    return PlaybackSpeed.values.firstWhere(
      (speed) => speed.value == value,
      orElse: () => PlaybackSpeed.normal,
    );
  }
}
