import 'dart:ui';

import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════
// ✅ ENUMS
// ═══════════════════════════════════════════════════════

enum TimelineItemType { text, image, audio, video, sticker }

enum TextAlignCustom { left, center, right }

enum VideoFormat { mp4, mov, webm, avi, mkv }

enum VideoQuality { low, medium, high, ultra, original }

enum AudioFormat { mp3, aac, wav, flac, ogg }

enum MediaType { video, audio, image, clip }

enum ImageFit { contain, cover, fill, fitWidth, fitHeight }

enum TextAnimation {
  none,
  fadeIn,
  fadeOut,
  slideUp,
  slideDown,
  slideLeft,
  slideRight,
  typewriter,
  bounce,
  scale,
  rotate,
}

enum TextPositionCustom {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

enum AiImageStyle {
  realistic,
  artistic,
  anime,
  cartoon,
  sketch,
  painting,
  threeD,
  abstract,
}

enum AiImageSize { square, portrait, landscape, wide }

enum ExportStatus {
  idle,
  preparing,
  processing,
  encoding,
  saving,
  completed,
  failed,
  cancelled,
}

enum MusicCategory {
  all,
  beats,
  ambient,
  cinematic,
  classical,
  electronic,
  folk,
  hiphop,
  jazz,
  pop,
  rock,
}

enum ImageCategory {
  all,
  backgrounds,
  fashion,
  nature,
  science,
  education,
  feelings,
  health,
  people,
  places,
  animals,
  food,
  computer,
  sports,
  transportation,
  travel,
  buildings,
  business,
  music,
}

// ═══════════════════════════════════════════════════════
// ✅ UTILITY EXTENSIONS
// ═══════════════════════════════════════════════════════

extension SafeJsonParsing on Map<String, dynamic> {
  T? safeGet<T>(String key, [T? defaultValue]) {
    try {
      final value = this[key];
      if (value == null) return defaultValue;
      if (value is T) return value;

      if (T == double && value is num) return value.toDouble() as T;
      if (T == int && value is num) return value.toInt() as T;
      if (T == String && value != null) return value.toString() as T;

      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  Duration safeDuration(String key, [Duration defaultValue = Duration.zero]) {
    try {
      final ms = this[key];
      if (ms == null) return defaultValue;
      if (ms is int) return Duration(milliseconds: ms);
      if (ms is num) return Duration(milliseconds: ms.toInt());
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }
}

extension DurationClamping on Duration {
  Duration clampDuration(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}

// ═══════════════════════════════════════════════════════
// ✅ COLOR GRADE SETTINGS
// ═══════════════════════════════════════════════════════

@immutable
class ColorGradeSettings {
  final double brightness;
  final double contrast;
  final double saturation;
  final double hue;
  final double red;
  final double green;
  final double blue;
  final double temperature;
  final double tint;
  final double vibrance;
  final double highlights;
  final double shadows;
  final double whites;
  final double blacks;

  const ColorGradeSettings({
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.hue = 0.0,
    this.red = 1.0,
    this.green = 1.0,
    this.blue = 1.0,
    this.temperature = 0.0,
    this.tint = 0.0,
    this.vibrance = 0.0,
    this.highlights = 0.0,
    this.shadows = 0.0,
    this.whites = 0.0,
    this.blacks = 0.0,
  });

  factory ColorGradeSettings.clamped({
    double brightness = 0.0,
    double contrast = 1.0,
    double saturation = 1.0,
    double hue = 0.0,
    double red = 1.0,
    double green = 1.0,
    double blue = 1.0,
    double temperature = 0.0,
    double tint = 0.0,
    double vibrance = 0.0,
    double highlights = 0.0,
    double shadows = 0.0,
    double whites = 0.0,
    double blacks = 0.0,
  }) {
    return ColorGradeSettings(
      brightness: brightness.clamp(-1.0, 1.0),
      contrast: contrast.clamp(0.0, 3.0),
      saturation: saturation.clamp(0.0, 3.0),
      hue: hue.clamp(-180.0, 180.0),
      red: red.clamp(0.0, 2.0),
      green: green.clamp(0.0, 2.0),
      blue: blue.clamp(0.0, 2.0),
      temperature: temperature.clamp(-100.0, 100.0),
      tint: tint.clamp(-100.0, 100.0),
      vibrance: vibrance.clamp(-1.0, 1.0),
      highlights: highlights.clamp(-1.0, 1.0),
      shadows: shadows.clamp(-1.0, 1.0),
      whites: whites.clamp(-1.0, 1.0),
      blacks: blacks.clamp(-1.0, 1.0),
    );
  }

  ColorGradeSettings copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? hue,
    double? red,
    double? green,
    double? blue,
    double? temperature,
    double? tint,
    double? vibrance,
    double? highlights,
    double? shadows,
    double? whites,
    double? blacks,
  }) {
    return ColorGradeSettings(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      hue: hue ?? this.hue,
      red: red ?? this.red,
      green: green ?? this.green,
      blue: blue ?? this.blue,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      vibrance: vibrance ?? this.vibrance,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      whites: whites ?? this.whites,
      blacks: blacks ?? this.blacks,
    );
  }

  bool get isDefault =>
      brightness == 0.0 &&
      contrast == 1.0 &&
      saturation == 1.0 &&
      hue == 0.0 &&
      red == 1.0 &&
      green == 1.0 &&
      blue == 1.0 &&
      temperature == 0.0 &&
      tint == 0.0 &&
      vibrance == 0.0 &&
      highlights == 0.0 &&
      shadows == 0.0 &&
      whites == 0.0 &&
      blacks == 0.0;

  List<double> toColorMatrix() {
    try {
      return <double>[
        red * contrast,
        0,
        0,
        0,
        brightness * 255 * 0.5,
        0,
        green * contrast,
        0,
        0,
        brightness * 255 * 0.5,
        0,
        0,
        blue * contrast,
        0,
        brightness * 255 * 0.5,
        0,
        0,
        0,
        1,
        0,
      ];
    } catch (e) {
      return <double>[
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ];
    }
  }

  Map<String, dynamic> toJson() => {
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    'hue': hue,
    'red': red,
    'green': green,
    'blue': blue,
    'temperature': temperature,
    'tint': tint,
    'vibrance': vibrance,
    'highlights': highlights,
    'shadows': shadows,
    'whites': whites,
    'blacks': blacks,
  };

  factory ColorGradeSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ColorGradeSettings();

    try {
      return ColorGradeSettings(
        brightness: json.safeGet<double>('brightness', 0.0)!,
        contrast: json.safeGet<double>('contrast', 1.0)!,
        saturation: json.safeGet<double>('saturation', 1.0)!,
        hue: json.safeGet<double>('hue', 0.0)!,
        red: json.safeGet<double>('red', 1.0)!,
        green: json.safeGet<double>('green', 1.0)!,
        blue: json.safeGet<double>('blue', 1.0)!,
        temperature: json.safeGet<double>('temperature', 0.0)!,
        tint: json.safeGet<double>('tint', 0.0)!,
        vibrance: json.safeGet<double>('vibrance', 0.0)!,
        highlights: json.safeGet<double>('highlights', 0.0)!,
        shadows: json.safeGet<double>('shadows', 0.0)!,
        whites: json.safeGet<double>('whites', 0.0)!,
        blacks: json.safeGet<double>('blacks', 0.0)!,
      );
    } catch (e) {
      debugPrint('❌ ColorGradeSettings.fromJson error: $e');
      return const ColorGradeSettings();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ColorGradeSettings &&
        other.brightness == brightness &&
        other.contrast == contrast &&
        other.saturation == saturation &&
        other.hue == hue &&
        other.red == red &&
        other.green == green &&
        other.blue == blue &&
        other.temperature == temperature &&
        other.tint == tint &&
        other.vibrance == vibrance &&
        other.highlights == highlights &&
        other.shadows == shadows &&
        other.whites == whites &&
        other.blacks == blacks;
  }

  @override
  int get hashCode => Object.hash(
    brightness,
    contrast,
    saturation,
    hue,
    red,
    green,
    blue,
    temperature,
    tint,
    vibrance,
    highlights,
    shadows,
    whites,
    blacks,
  );

  static const ColorGradeSettings defaultSettings = ColorGradeSettings();
}

// ═══════════════════════════════════════════════════════
// ✅ CLIP MARKER
// ═══════════════════════════════════════════════════════

@immutable
class ClipMarker {
  final String id;
  final Duration startTime;
  final Duration endTime;
  final String? label;
  final ColorGradeSettings? colorGrade;

  const ClipMarker({
    required this.id,
    required this.startTime,
    required this.endTime,
    this.label,
    this.colorGrade,
  });

  Duration get duration => endTime - startTime;

  ClipMarker copyWith({
    String? id,
    Duration? startTime,
    Duration? endTime,
    String? label,
    ColorGradeSettings? colorGrade,
  }) {
    return ClipMarker(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      label: label ?? this.label,
      colorGrade: colorGrade ?? this.colorGrade,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.inMilliseconds,
    'endTime': endTime.inMilliseconds,
    'label': label,
    'colorGrade': colorGrade?.toJson(),
  };

  factory ClipMarker.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ClipMarker(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: Duration.zero,
        endTime: const Duration(seconds: 5),
      );
    }

    try {
      return ClipMarker(
        id: json.safeGet<String>(
          'id',
          DateTime.now().millisecondsSinceEpoch.toString(),
        )!,
        startTime: json.safeDuration('startTime'),
        endTime: json.safeDuration('endTime', const Duration(seconds: 5)),
        label: json.safeGet<String>('label'),
        colorGrade: json['colorGrade'] != null
            ? ColorGradeSettings.fromJson(
                json['colorGrade'] as Map<String, dynamic>?,
              )
            : null,
      );
    } catch (e) {
      debugPrint('❌ ClipMarker.fromJson error: $e');
      return ClipMarker(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: Duration.zero,
        endTime: const Duration(seconds: 5),
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClipMarker &&
        other.id == id &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.label == label &&
        other.colorGrade == colorGrade;
  }

  @override
  int get hashCode => Object.hash(id, startTime, endTime, label, colorGrade);
}

// ═══════════════════════════════════════════════════════
// ✅ EXPORT PRESET
// ═══════════════════════════════════════════════════════

@immutable
class ExportPreset {
  final String id;
  final String name;
  final String description;
  final VideoFormat format;
  final VideoQuality quality;
  final int? width;
  final int? height;
  final int? bitrate;
  final int? fps;
  final String? audioCodec;
  final int? audioBitrate;
  final bool removeAudio;

  const ExportPreset({
    required this.id,
    required this.name,
    this.description = '',
    this.format = VideoFormat.mp4,
    this.quality = VideoQuality.high,
    this.width,
    this.height,
    this.bitrate,
    this.fps,
    this.audioCodec,
    this.audioBitrate,
    this.removeAudio = false,
  });

  String get extension {
    switch (format) {
      case VideoFormat.mp4:
        return 'mp4';
      case VideoFormat.mov:
        return 'mov';
      case VideoFormat.webm:
        return 'webm';
      case VideoFormat.avi:
        return 'avi';
      case VideoFormat.mkv:
        return 'mkv';
    }
  }

  String get qualityLabel {
    if (width != null && height != null) {
      return '${width}x$height';
    }
    switch (quality) {
      case VideoQuality.low:
        return '480p';
      case VideoQuality.medium:
        return '720p';
      case VideoQuality.high:
        return '1080p';
      case VideoQuality.ultra:
        return '4K';
      case VideoQuality.original:
        return 'Original';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'format': format.index,
    'quality': quality.index,
    'width': width,
    'height': height,
    'bitrate': bitrate,
    'fps': fps,
    'audioCodec': audioCodec,
    'audioBitrate': audioBitrate,
    'removeAudio': removeAudio,
  };

  factory ExportPreset.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ExportPreset(id: 'default', name: 'Default');
    }

    try {
      return ExportPreset(
        id: json.safeGet<String>('id', 'default')!,
        name: json.safeGet<String>('name', 'Default')!,
        description: json.safeGet<String>('description', '')!,
        format: _safeEnum(VideoFormat.values, json['format'], VideoFormat.mp4),
        quality: _safeEnum(
          VideoQuality.values,
          json['quality'],
          VideoQuality.high,
        ),
        width: json.safeGet<int>('width'),
        height: json.safeGet<int>('height'),
        bitrate: json.safeGet<int>('bitrate'),
        fps: json.safeGet<int>('fps'),
        audioCodec: json.safeGet<String>('audioCodec'),
        audioBitrate: json.safeGet<int>('audioBitrate'),
        removeAudio: json.safeGet<bool>('removeAudio', false)!,
      );
    } catch (e) {
      debugPrint('❌ ExportPreset.fromJson error: $e');
      return const ExportPreset(id: 'default', name: 'Default');
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExportPreset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  static const List<ExportPreset> defaultPresets = [
    ExportPreset(
      id: 'original',
      name: 'Original',
      description: 'Keep original quality',
      quality: VideoQuality.original,
    ),
    ExportPreset(
      id: 'ultra_4k',
      name: '4K Ultra',
      description: '3840x2160, High bitrate',
      quality: VideoQuality.ultra,
      width: 3840,
      height: 2160,
      bitrate: 35000,
      fps: 60,
    ),
    ExportPreset(
      id: 'high_1080p',
      name: '1080p HD',
      description: '1920x1080, Balanced',
      quality: VideoQuality.high,
      width: 1920,
      height: 1080,
      bitrate: 8000,
      fps: 30,
    ),
    ExportPreset(
      id: 'medium_720p',
      name: '720p',
      description: '1280x720, Good quality',
      quality: VideoQuality.medium,
      width: 1280,
      height: 720,
      bitrate: 5000,
      fps: 30,
    ),
    ExportPreset(
      id: 'low_480p',
      name: '480p',
      description: '854x480, Small file',
      quality: VideoQuality.low,
      width: 854,
      height: 480,
      bitrate: 2500,
      fps: 30,
    ),
    ExportPreset(
      id: 'social_square',
      name: 'Square (1:1)',
      description: '1080x1080, Instagram',
      quality: VideoQuality.high,
      width: 1080,
      height: 1080,
      bitrate: 6000,
    ),
    ExportPreset(
      id: 'social_vertical',
      name: 'Vertical (9:16)',
      description: '1080x1920, TikTok/Reels',
      quality: VideoQuality.high,
      width: 1080,
      height: 1920,
      bitrate: 8000,
    ),
    ExportPreset(
      id: 'gif',
      name: 'GIF',
      description: 'Animated GIF',
      quality: VideoQuality.medium,
      width: 480,
      height: 270,
      fps: 15,
      removeAudio: true,
    ),
  ];
}

// ═══════════════════════════════════════════════════════
// ✅ MEDIA ITEM (For Library)
// ═══════════════════════════════════════════════════════

@immutable
class MediaItem {
  final String id;
  final String name;
  final String path;
  final MediaType type;
  final DateTime createdAt;
  final Duration? duration;
  final int? fileSize;
  final Uint8List? thumbnail;
  final Map<String, dynamic>? metadata;

  const MediaItem({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.createdAt,
    this.duration,
    this.fileSize,
    this.thumbnail,
    this.metadata,
  });

  MediaItem copyWith({
    String? id,
    String? name,
    String? path,
    MediaType? type,
    DateTime? createdAt,
    Duration? duration,
    int? fileSize,
    Uint8List? thumbnail,
    Map<String, dynamic>? metadata,
  }) {
    return MediaItem(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      thumbnail: thumbnail ?? this.thumbnail,
      metadata: metadata ?? this.metadata,
    );
  }

  String get fileSizeFormatted {
    try {
      if (fileSize == null) return '';
      if (fileSize! < 1024) return '$fileSize B';
      if (fileSize! < 1024 * 1024) {
        return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
      }
      if (fileSize! < 1024 * 1024 * 1024) {
        return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } catch (e) {
      return '';
    }
  }

  String get durationFormatted {
    try {
      if (duration == null) return '';
      final minutes = duration!.inMinutes;
      final seconds = duration!.inSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'type': type.index,
    'createdAt': createdAt.toIso8601String(),
    'duration': duration?.inMilliseconds,
    'fileSize': fileSize,
    'metadata': metadata,
  };

  factory MediaItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return MediaItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Unknown',
        path: '',
        type: MediaType.video,
        createdAt: DateTime.now(),
      );
    }

    try {
      return MediaItem(
        id: json.safeGet<String>(
          'id',
          DateTime.now().millisecondsSinceEpoch.toString(),
        )!,
        name: json.safeGet<String>('name', 'Unknown')!,
        path: json.safeGet<String>('path', '')!,
        type: _safeEnum(MediaType.values, json['type'], MediaType.video),
        createdAt: _parseDateTime(json['createdAt']),
        duration: json['duration'] != null
            ? Duration(milliseconds: json.safeGet<int>('duration', 0)!)
            : null,
        fileSize: json.safeGet<int>('fileSize'),
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      debugPrint('❌ MediaItem.fromJson error: $e');
      return MediaItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Unknown',
        path: '',
        type: MediaType.video,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════
// ✅ MERGE ITEM
// ═══════════════════════════════════════════════════════

@immutable
class MergeItem {
  final String id;
  final String path;
  final MediaType type;
  final Duration? duration;
  final Duration? trimStart;
  final Duration? trimEnd;
  final int order;
  final Uint8List? thumbnail;

  const MergeItem({
    required this.id,
    required this.path,
    required this.type,
    this.duration,
    this.trimStart,
    this.trimEnd,
    this.order = 0,
    this.thumbnail,
  });

  Duration get effectiveDuration {
    try {
      if (duration == null) return Duration.zero;
      final start = trimStart ?? Duration.zero;
      final end = trimEnd ?? duration!;
      if (end <= start) return Duration.zero;
      return end - start;
    } catch (e) {
      return Duration.zero;
    }
  }

  MergeItem copyWith({
    String? id,
    String? path,
    MediaType? type,
    Duration? duration,
    Duration? trimStart,
    Duration? trimEnd,
    int? order,
    Uint8List? thumbnail,
  }) {
    return MergeItem(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      order: order ?? this.order,
      thumbnail: thumbnail ?? this.thumbnail,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'type': type.index,
    'duration': duration?.inMilliseconds,
    'trimStart': trimStart?.inMilliseconds,
    'trimEnd': trimEnd?.inMilliseconds,
    'order': order,
  };

  factory MergeItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return MergeItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: '',
        type: MediaType.video,
      );
    }

    try {
      return MergeItem(
        id: json.safeGet<String>(
          'id',
          DateTime.now().millisecondsSinceEpoch.toString(),
        )!,
        path: json.safeGet<String>('path', '')!,
        type: _safeEnum(MediaType.values, json['type'], MediaType.video),
        duration: json['duration'] != null
            ? Duration(milliseconds: json.safeGet<int>('duration', 0)!)
            : null,
        trimStart: json['trimStart'] != null
            ? Duration(milliseconds: json.safeGet<int>('trimStart', 0)!)
            : null,
        trimEnd: json['trimEnd'] != null
            ? Duration(milliseconds: json.safeGet<int>('trimEnd', 0)!)
            : null,
        order: json.safeGet<int>('order', 0)!,
      );
    } catch (e) {
      debugPrint('❌ MergeItem.fromJson error: $e');
      return MergeItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: '',
        type: MediaType.video,
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MergeItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════
// ✅ COLOR PRESETS
// ═══════════════════════════════════════════════════════

@immutable
class ColorPreset {
  final String id;
  final String name;
  final ColorGradeSettings settings;
  final String? thumbnailPath;
  final String? iconEmoji;

  const ColorPreset({
    required this.id,
    required this.name,
    required this.settings,
    this.thumbnailPath,
    this.iconEmoji,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ColorPreset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  static const List<ColorPreset> defaultPresets = [
    ColorPreset(
      id: 'normal',
      name: 'Normal',
      settings: ColorGradeSettings(),
      iconEmoji: '⚪',
    ),
    ColorPreset(
      id: 'vivid',
      name: 'Vivid',
      settings: ColorGradeSettings(
        saturation: 1.3,
        vibrance: 0.2,
        contrast: 1.1,
      ),
      iconEmoji: '🌈',
    ),
    ColorPreset(
      id: 'warm',
      name: 'Warm',
      settings: ColorGradeSettings(temperature: 30, red: 1.1, blue: 0.9),
      iconEmoji: '🔥',
    ),
    ColorPreset(
      id: 'cool',
      name: 'Cool',
      settings: ColorGradeSettings(temperature: -30, blue: 1.1, red: 0.9),
      iconEmoji: '❄️',
    ),
    ColorPreset(
      id: 'vintage',
      name: 'Vintage',
      settings: ColorGradeSettings(
        saturation: 0.8,
        contrast: 0.9,
        brightness: 0.1,
        shadows: 0.2,
      ),
      iconEmoji: '📷',
    ),
    ColorPreset(
      id: 'bw',
      name: 'B&W',
      settings: ColorGradeSettings(saturation: 0.0, contrast: 1.2),
      iconEmoji: '⚫',
    ),
    ColorPreset(
      id: 'cinematic',
      name: 'Cinema',
      settings: ColorGradeSettings(
        contrast: 1.2,
        saturation: 0.9,
        shadows: -0.1,
        highlights: -0.1,
      ),
      iconEmoji: '🎬',
    ),
    ColorPreset(
      id: 'matte',
      name: 'Matte',
      settings: ColorGradeSettings(
        blacks: 0.15,
        contrast: 0.9,
        saturation: 0.85,
      ),
      iconEmoji: '🎨',
    ),
  ];
}

// ═══════════════════════════════════════════════════════
// ✅ VIDEO EDIT STATE
// ═══════════════════════════════════════════════════════

@immutable
class VideoEditState {
  final bool isEditing;
  final ColorGradeSettings colorGrade;
  final List<ClipMarker> clipMarkers;
  final ClipMarker? activeClip;
  final Duration? trimStart;
  final Duration? trimEnd;
  final bool isProcessing;
  final double processProgress;
  final String? processMessage;
  final List<Uint8List> extractedFrames;
  final String? extractedAudioPath;
  final List<MediaItem> libraryItems;
  final List<MergeItem> mergeQueue;
  final ExportPreset selectedPreset;

  const VideoEditState({
    this.isEditing = false,
    this.colorGrade = const ColorGradeSettings(),
    this.clipMarkers = const [],
    this.activeClip,
    this.trimStart,
    this.trimEnd,
    this.isProcessing = false,
    this.processProgress = 0.0,
    this.processMessage,
    this.extractedFrames = const [],
    this.extractedAudioPath,
    this.libraryItems = const [],
    this.mergeQueue = const [],
    this.selectedPreset = const ExportPreset(
      id: 'high_1080p',
      name: '1080p HD',
      quality: VideoQuality.high,
    ),
  });

  VideoEditState copyWith({
    bool? isEditing,
    ColorGradeSettings? colorGrade,
    List<ClipMarker>? clipMarkers,
    ClipMarker? activeClip,
    Duration? trimStart,
    Duration? trimEnd,
    bool? isProcessing,
    double? processProgress,
    String? processMessage,
    List<Uint8List>? extractedFrames,
    String? extractedAudioPath,
    List<MediaItem>? libraryItems,
    List<MergeItem>? mergeQueue,
    ExportPreset? selectedPreset,
  }) {
    return VideoEditState(
      isEditing: isEditing ?? this.isEditing,
      colorGrade: colorGrade ?? this.colorGrade,
      clipMarkers: clipMarkers ?? this.clipMarkers,
      activeClip: activeClip ?? this.activeClip,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      isProcessing: isProcessing ?? this.isProcessing,
      processProgress: processProgress ?? this.processProgress,
      processMessage: processMessage ?? this.processMessage,
      extractedFrames: extractedFrames ?? this.extractedFrames,
      extractedAudioPath: extractedAudioPath ?? this.extractedAudioPath,
      libraryItems: libraryItems ?? this.libraryItems,
      mergeQueue: mergeQueue ?? this.mergeQueue,
      selectedPreset: selectedPreset ?? this.selectedPreset,
    );
  }

  VideoEditState clearActiveClip() {
    return VideoEditState(
      isEditing: isEditing,
      colorGrade: colorGrade,
      clipMarkers: clipMarkers,
      activeClip: null,
      trimStart: trimStart,
      trimEnd: trimEnd,
      isProcessing: isProcessing,
      processProgress: processProgress,
      processMessage: processMessage,
      extractedFrames: extractedFrames,
      extractedAudioPath: extractedAudioPath,
      libraryItems: libraryItems,
      mergeQueue: mergeQueue,
      selectedPreset: selectedPreset,
    );
  }

  VideoEditState reset() {
    return const VideoEditState();
  }
}

// ═══════════════════════════════════════════════════════
// ✅ TEXT OVERLAY STYLE
// ═══════════════════════════════════════════════════════

@immutable
class TextOverlayStyle {
  final String fontFamily;
  final double fontSize;
  final int color;
  final int backgroundColor;
  final bool bold;
  final bool italic;
  final double shadowBlur;
  final int shadowColor;
  final double strokeWidth;
  final int strokeColor;
  final TextAlignCustom textAlign;
  final double letterSpacing;
  final double lineHeight;

  const TextOverlayStyle({
    this.fontFamily = 'Arial',
    this.fontSize = 48,
    this.color = 0xFFFFFFFF,
    this.backgroundColor = 0x00000000,
    this.bold = false,
    this.italic = false,
    this.shadowBlur = 0,
    this.shadowColor = 0x80000000,
    this.strokeWidth = 0,
    this.strokeColor = 0xFF000000,
    this.textAlign = TextAlignCustom.center,
    this.letterSpacing = 0,
    this.lineHeight = 1.2,
  });

  factory TextOverlayStyle.clamped({
    String fontFamily = 'Arial',
    double fontSize = 48,
    int color = 0xFFFFFFFF,
    int backgroundColor = 0x00000000,
    bool bold = false,
    bool italic = false,
    double shadowBlur = 0,
    int shadowColor = 0x80000000,
    double strokeWidth = 0,
    int strokeColor = 0xFF000000,
    TextAlignCustom textAlign = TextAlignCustom.center,
    double letterSpacing = 0,
    double lineHeight = 1.2,
  }) {
    return TextOverlayStyle(
      fontFamily: fontFamily.isNotEmpty ? fontFamily : 'Arial',
      fontSize: fontSize.clamp(8.0, 200.0),
      color: color,
      backgroundColor: backgroundColor,
      bold: bold,
      italic: italic,
      shadowBlur: shadowBlur.clamp(0.0, 50.0),
      shadowColor: shadowColor,
      strokeWidth: strokeWidth.clamp(0.0, 20.0),
      strokeColor: strokeColor,
      textAlign: textAlign,
      letterSpacing: letterSpacing.clamp(-10.0, 50.0),
      lineHeight: lineHeight.clamp(0.5, 3.0),
    );
  }

  TextOverlayStyle copyWith({
    String? fontFamily,
    double? fontSize,
    int? color,
    int? backgroundColor,
    bool? bold,
    bool? italic,
    double? shadowBlur,
    int? shadowColor,
    double? strokeWidth,
    int? strokeColor,
    TextAlignCustom? textAlign,
    double? letterSpacing,
    double? lineHeight,
  }) {
    return TextOverlayStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowColor: shadowColor ?? this.shadowColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeColor: strokeColor ?? this.strokeColor,
      textAlign: textAlign ?? this.textAlign,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }

  Map<String, dynamic> toJson() => {
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'color': color,
    'backgroundColor': backgroundColor,
    'bold': bold,
    'italic': italic,
    'shadowBlur': shadowBlur,
    'shadowColor': shadowColor,
    'strokeWidth': strokeWidth,
    'strokeColor': strokeColor,
    'textAlign': textAlign.index,
    'letterSpacing': letterSpacing,
    'lineHeight': lineHeight,
  };

  factory TextOverlayStyle.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TextOverlayStyle();

    try {
      return TextOverlayStyle(
        fontFamily: json.safeGet<String>('fontFamily', 'Arial')!,
        fontSize: json.safeGet<double>('fontSize', 48)!,
        color: json.safeGet<int>('color', 0xFFFFFFFF)!,
        backgroundColor: json.safeGet<int>('backgroundColor', 0x00000000)!,
        bold: json.safeGet<bool>('bold', false)!,
        italic: json.safeGet<bool>('italic', false)!,
        shadowBlur: json.safeGet<double>('shadowBlur', 0)!,
        shadowColor: json.safeGet<int>('shadowColor', 0x80000000)!,
        strokeWidth: json.safeGet<double>('strokeWidth', 0)!,
        strokeColor: json.safeGet<int>('strokeColor', 0xFF000000)!,
        textAlign: _safeEnum(
          TextAlignCustom.values,
          json['textAlign'],
          TextAlignCustom.center,
        ),
        letterSpacing: json.safeGet<double>('letterSpacing', 0)!,
        lineHeight: json.safeGet<double>('lineHeight', 1.2)!,
      );
    } catch (e) {
      debugPrint('❌ TextOverlayStyle.fromJson error: $e');
      return const TextOverlayStyle();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextOverlayStyle &&
        other.fontFamily == fontFamily &&
        other.fontSize == fontSize &&
        other.color == color &&
        other.backgroundColor == backgroundColor &&
        other.bold == bold &&
        other.italic == italic &&
        other.shadowBlur == shadowBlur &&
        other.shadowColor == shadowColor &&
        other.strokeWidth == strokeWidth &&
        other.strokeColor == strokeColor &&
        other.textAlign == textAlign &&
        other.letterSpacing == letterSpacing &&
        other.lineHeight == lineHeight;
  }

  @override
  int get hashCode => Object.hash(
    fontFamily,
    fontSize,
    color,
    backgroundColor,
    bold,
    italic,
    shadowBlur,
    shadowColor,
    strokeWidth,
    strokeColor,
    textAlign,
    letterSpacing,
    lineHeight,
  );
}

// ═══════════════════════════════════════════════════════
// ✅ BASE TIMELINE ITEM
// ═══════════════════════════════════════════════════════

@immutable
class TimelineItem {
  final String id;
  final TimelineItemType type;
  final Duration startTime;
  final Duration endTime;
  final int layer;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final bool isLocked;
  final bool isVisible;

  const TimelineItem({
    required this.id,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.layer = 0,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.isLocked = false,
    this.isVisible = true,
  });

  Duration get duration => endTime - startTime;

  bool isVisibleAt(Duration position) {
    return isVisible && position >= startTime && position <= endTime;
  }

  TimelineItem copyWith({
    String? id,
    TimelineItemType? type,
    Duration? startTime,
    Duration? endTime,
    int? layer,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
  }) {
    return TimelineItem(
      id: id ?? this.id,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      layer: layer ?? this.layer,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'startTime': startTime.inMilliseconds,
    'endTime': endTime.inMilliseconds,
    'layer': layer,
    'x': x,
    'y': y,
    'scale': scale,
    'rotation': rotation,
    'isLocked': isLocked,
    'isVisible': isVisible,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimelineItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════
// ✅ TEXT TIMELINE ITEM
// ═══════════════════════════════════════════════════════

@immutable
class TextTimelineItem extends TimelineItem {
  final String text;
  final TextOverlayStyle style;
  final TextAnimation animationIn;
  final TextAnimation animationOut;
  final Duration animationDuration;

  const TextTimelineItem({
    required super.id,
    required super.startTime,
    required super.endTime,
    super.layer,
    super.x = 0.5,
    super.y = 0.8,
    super.scale = 1.0,
    super.rotation = 0.0,
    super.isLocked,
    super.isVisible,
    required this.text,
    this.style = const TextOverlayStyle(),
    this.animationIn = TextAnimation.none,
    this.animationOut = TextAnimation.none,
    this.animationDuration = const Duration(milliseconds: 300),
  }) : super(type: TimelineItemType.text);

  factory TextTimelineItem.create({
    String? id,
    required String text,
    required Duration startTime,
    required Duration endTime,
    int layer = 0,
    double x = 0.5,
    double y = 0.8,
    double scale = 1.0,
    double rotation = 0.0,
    bool isLocked = false,
    bool isVisible = true,
    TextOverlayStyle style = const TextOverlayStyle(),
    TextAnimation animationIn = TextAnimation.none,
    TextAnimation animationOut = TextAnimation.none,
    Duration animationDuration = const Duration(milliseconds: 300),
  }) {
    return TextTimelineItem(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: startTime,
      endTime: endTime > startTime
          ? endTime
          : startTime + const Duration(seconds: 3),
      layer: layer,
      x: x.clamp(0.0, 1.0),
      y: y.clamp(0.0, 1.0),
      scale: scale.clamp(0.1, 5.0),
      rotation: rotation % 360,
      isLocked: isLocked,
      isVisible: isVisible,
      text: text,
      style: style,
      animationIn: animationIn,
      animationOut: animationOut,
      animationDuration: animationDuration,
    );
  }

  @override
  TextTimelineItem copyWith({
    String? id,
    TimelineItemType? type,
    Duration? startTime,
    Duration? endTime,
    int? layer,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
    String? text,
    TextOverlayStyle? style,
    TextAnimation? animationIn,
    TextAnimation? animationOut,
    Duration? animationDuration,
  }) {
    return TextTimelineItem(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      layer: layer ?? this.layer,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      text: text ?? this.text,
      style: style ?? this.style,
      animationIn: animationIn ?? this.animationIn,
      animationOut: animationOut ?? this.animationOut,
      animationDuration: animationDuration ?? this.animationDuration,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'text': text,
    'style': style.toJson(),
    'animationIn': animationIn.index,
    'animationOut': animationOut.index,
    'animationDuration': animationDuration.inMilliseconds,
  };

  factory TextTimelineItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TextTimelineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: Duration.zero,
        endTime: const Duration(seconds: 3),
        text: '',
      );
    }

    try {
      return TextTimelineItem(
        id: json.safeGet<String>(
          'id',
          DateTime.now().millisecondsSinceEpoch.toString(),
        )!,
        startTime: json.safeDuration('startTime'),
        endTime: json.safeDuration('endTime', const Duration(seconds: 3)),
        layer: json.safeGet<int>('layer', 0)!,
        x: json.safeGet<double>('x', 0.5)!,
        y: json.safeGet<double>('y', 0.8)!,
        scale: json.safeGet<double>('scale', 1.0)!,
        rotation: json.safeGet<double>('rotation', 0.0)!,
        isLocked: json.safeGet<bool>('isLocked', false)!,
        isVisible: json.safeGet<bool>('isVisible', true)!,
        text: json.safeGet<String>('text', '')!,
        style: TextOverlayStyle.fromJson(
          json['style'] as Map<String, dynamic>?,
        ),
        animationIn: _safeEnum(
          TextAnimation.values,
          json['animationIn'],
          TextAnimation.none,
        ),
        animationOut: _safeEnum(
          TextAnimation.values,
          json['animationOut'],
          TextAnimation.none,
        ),
        animationDuration: json.safeDuration(
          'animationDuration',
          const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      debugPrint('❌ TextTimelineItem.fromJson error: $e');
      return TextTimelineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: Duration.zero,
        endTime: const Duration(seconds: 3),
        text: '',
      );
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ IMAGE TIMELINE ITEM
// ═══════════════════════════════════════════════════════

@immutable
class ImageTimelineItem extends TimelineItem {
  final String imagePath;
  final String? thumbnailUrl;
  final Uint8List? imageBytes;
  final int width;
  final int height;
  final ImageFit fit;
  final double opacity;
  final int? borderColor;
  final double borderWidth;
  final double borderRadius;
  final bool isAiGenerated;
  final String? aiPrompt;
  final BlendMode? blendMode;

  const ImageTimelineItem({
    required super.id,
    required super.startTime,
    required super.endTime,
    super.layer,
    super.x = 0.5,
    super.y = 0.5,
    super.scale = 0.3,
    super.rotation = 0.0,
    super.isLocked,
    super.isVisible,
    required this.imagePath,
    this.thumbnailUrl,
    this.imageBytes,
    this.width = 1920,
    this.height = 1080,
    this.fit = ImageFit.contain,
    this.opacity = 1.0,
    this.borderColor,
    this.borderWidth = 0,
    this.borderRadius = 0,
    this.isAiGenerated = false,
    this.aiPrompt,
    this.blendMode,
  }) : super(type: TimelineItemType.image);

  double get aspectRatio {
    try {
      if (width <= 0 || height <= 0) return 1.0;
      return width / height;
    } catch (e) {
      return 1.0;
    }
  }

  bool get hasValidImage => imagePath.isNotEmpty || imageBytes != null;

  factory ImageTimelineItem.create({
    String? id,
    required String imagePath,
    required Duration startTime,
    required Duration endTime,
    int layer = 0,
    double x = 0.5,
    double y = 0.5,
    double scale = 0.3,
    double rotation = 0.0,
    bool isLocked = false,
    bool isVisible = true,
    String? thumbnailUrl,
    Uint8List? imageBytes,
    int width = 1920,
    int height = 1080,
    ImageFit fit = ImageFit.contain,
    double opacity = 1.0,
    int? borderColor,
    double borderWidth = 0,
    double borderRadius = 0,
    bool isAiGenerated = false,
    String? aiPrompt,
    BlendMode? blendMode,
  }) {
    return ImageTimelineItem(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: startTime,
      endTime: endTime > startTime
          ? endTime
          : startTime + const Duration(seconds: 3),
      layer: layer,
      x: x.clamp(0.0, 1.0),
      y: y.clamp(0.0, 1.0),
      scale: scale.clamp(0.05, 3.0),
      rotation: rotation % 360,
      isLocked: isLocked,
      isVisible: isVisible,
      imagePath: imagePath,
      thumbnailUrl: thumbnailUrl,
      imageBytes: imageBytes,
      width: width.clamp(1, 7680),
      height: height.clamp(1, 4320),
      fit: fit,
      opacity: opacity.clamp(0.0, 1.0),
      borderColor: borderColor,
      borderWidth: borderWidth.clamp(0.0, 50.0),
      borderRadius: borderRadius.clamp(0.0, 100.0),
      isAiGenerated: isAiGenerated,
      aiPrompt: aiPrompt,
      blendMode: blendMode,
    );
  }

  @override
  ImageTimelineItem copyWith({
    String? id,
    TimelineItemType? type,
    Duration? startTime,
    Duration? endTime,
    int? layer,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
    String? imagePath,
    String? thumbnailUrl,
    Uint8List? imageBytes,
    int? width,
    int? height,
    ImageFit? fit,
    double? opacity,
    int? borderColor,
    double? borderWidth,
    double? borderRadius,
    bool? isAiGenerated,
    String? aiPrompt,
    BlendMode? blendMode,
  }) {
    return ImageTimelineItem(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      layer: layer ?? this.layer,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      imagePath: imagePath ?? this.imagePath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      imageBytes: imageBytes ?? this.imageBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      fit: fit ?? this.fit,
      opacity: opacity ?? this.opacity,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      aiPrompt: aiPrompt ?? this.aiPrompt,
      blendMode: blendMode ?? this.blendMode,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'imagePath': imagePath,
    'thumbnailUrl': thumbnailUrl,
    'width': width,
    'height': height,
    'fit': fit.index,
    'opacity': opacity,
    'borderColor': borderColor,
    'borderWidth': borderWidth,
    'borderRadius': borderRadius,
    'isAiGenerated': isAiGenerated,
    'aiPrompt': aiPrompt,
    'blendMode': blendMode?.index,
  };

  factory ImageTimelineItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ImageTimelineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: Duration.zero,
        endTime: const Duration(seconds: 3),
        imagePath: '',
      );
    }

    try {
      return ImageTimelineItem(
        id: json.safeGet<String>(
          'id',
          DateTime.now().millisecondsSinceEpoch.toString(),
        )!,
        startTime: json.safeDuration('startTime'),
        endTime: json.safeDuration('endTime', const Duration(seconds: 3)),
        layer: json.safeGet<int>('layer', 0)!,
        x: json.safeGet<double>('x', 0.5)!,
        y: json.safeGet<double>('y', 0.5)!,
        scale: json.safeGet<double>('scale', 0.3)!,
        rotation: json.safeGet<double>('rotation', 0.0)!,
        isLocked: json.safeGet<bool>('isLocked', false)!,
        isVisible: json.safeGet<bool>('isVisible', true)!,
        imagePath: json.safeGet<String>('imagePath', '')!,
        thumbnailUrl: json.safeGet<String>('thumbnailUrl'),
        width: json.safeGet<int>('width', 1920)!,
        height: json.safeGet<int>('height', 1080)!,
        fit: _safeEnum(ImageFit.values, json['fit'], ImageFit.contain),
        opacity: json.safeGet<double>('opacity', 1.0)!,
        borderColor: json.safeGet<int>('borderColor'),
        borderWidth: json.safeGet<double>('borderWidth', 0)!,
        borderRadius: json.safeGet<double>('borderRadius', 0)!,
        isAiGenerated: json.safeGet<bool>('isAiGenerated', false)!,
        aiPrompt: json.safeGet<String>('aiPrompt'),
        blendMode: _safeBlendMode(json['blendMode']),
      );
    } catch (e) {
      debugPrint('❌ ImageTimelineItem.fromJson error: $e');
      return ImageTimelineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: Duration.zero,
        endTime: const Duration(seconds: 3),
        imagePath: '',
      );
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ AUDIO TIMELINE ITEM
// ═══════════════════════════════════════════════════════

@immutable
class AudioTimelineItem extends TimelineItem {
  final String audioPath;
  final String title;
  final String artist;
  final Duration audioDuration;
  final Duration trimStart;
  final Duration trimEnd;
  final double volume;
  final bool fadeIn;
  final bool fadeOut;
  final Duration fadeDuration;
  final bool isMuted;
  final Uint8List? waveformData;

  const AudioTimelineItem({
    required super.id,
    required super.startTime,
    required super.endTime,
    super.layer = -1,
    super.isLocked,
    super.isVisible,
    required this.audioPath,
    this.title = '',
    this.artist = '',
    required this.audioDuration,
    this.trimStart = Duration.zero,
    Duration? trimEnd,
    this.volume = 1.0,
    this.fadeIn = false,
    this.fadeOut = false,
    this.fadeDuration = const Duration(milliseconds: 500),
    this.isMuted = false,
    this.waveformData,
  }) : trimEnd = trimEnd ?? audioDuration,
       super(type: TimelineItemType.audio, x: 0, y: 0, scale: 1, rotation: 0);

  Duration get effectiveAudioDuration {
    try {
      if (trimEnd <= trimStart) return Duration.zero;
      return trimEnd - trimStart;
    } catch (e) {
      return Duration.zero;
    }
  }

  double get effectiveVolume => isMuted ? 0.0 : volume.clamp(0.0, 2.0);

  factory AudioTimelineItem.create({
    String? id,
    required String audioPath,
    required Duration startTime,
    required Duration endTime,
    required Duration audioDuration,
    int layer = -1,
    bool isLocked = false,
    bool isVisible = true,
    String title = '',
    String artist = '',
    Duration trimStart = Duration.zero,
    Duration? trimEnd,
    double volume = 1.0,
    bool fadeIn = false,
    bool fadeOut = false,
    Duration fadeDuration = const Duration(milliseconds: 500),
    bool isMuted = false,
    Uint8List? waveformData,
  }) {
    return AudioTimelineItem(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: startTime,
      endTime: endTime > startTime
          ? endTime
          : startTime + const Duration(seconds: 5),
      layer: layer,
      isLocked: isLocked,
      isVisible: isVisible,
      audioPath: audioPath,
      title: title,
      artist: artist,
      audioDuration: audioDuration,
      trimStart: trimStart,
      trimEnd: trimEnd ?? audioDuration,
      volume: volume.clamp(0.0, 2.0),
      fadeIn: fadeIn,
      fadeOut: fadeOut,
      fadeDuration: fadeDuration,
      isMuted: isMuted,
      waveformData: waveformData,
    );
  }

  @override
  AudioTimelineItem copyWith({
    String? id,
    TimelineItemType? type,
    Duration? startTime,
    Duration? endTime,
    int? layer,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
    String? audioPath,
    String? title,
    String? artist,
    Duration? audioDuration,
    Duration? trimStart,
    Duration? trimEnd,
    double? volume,
    bool? fadeIn,
    bool? fadeOut,
    Duration? fadeDuration,
    bool? isMuted,
    Uint8List? waveformData,
  }) {
    return AudioTimelineItem(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      layer: layer ?? this.layer,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      audioPath: audioPath ?? this.audioPath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      audioDuration: audioDuration ?? this.audioDuration,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      volume: volume ?? this.volume,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
      fadeDuration: fadeDuration ?? this.fadeDuration,
      isMuted: isMuted ?? this.isMuted,
      waveformData: waveformData ?? this.waveformData,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'audioPath': audioPath,
    'title': title,
    'artist': artist,
    'audioDuration': audioDuration.inMilliseconds,
    'trimStart': trimStart.inMilliseconds,
    'trimEnd': trimEnd.inMilliseconds,
    'volume': volume,
    'fadeIn': fadeIn,
    'fadeOut': fadeOut,
    'fadeDuration': fadeDuration.inMilliseconds,
    'isMuted': isMuted,
  };

  factory AudioTimelineItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AudioTimelineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: Duration.zero,
        endTime: const Duration(seconds: 5),
        audioPath: '',
        audioDuration: const Duration(seconds: 5),
      );
    }

    try {
      final audioDuration = json.safeDuration(
        'audioDuration',
        const Duration(seconds: 5),
      );

      return AudioTimelineItem(
        id: json.safeGet<String>(
          'id',
          DateTime.now().millisecondsSinceEpoch.toString(),
        )!,
        startTime: json.safeDuration('startTime'),
        endTime: json.safeDuration('endTime', const Duration(seconds: 5)),
        layer: json.safeGet<int>('layer', -1)!,
        isLocked: json.safeGet<bool>('isLocked', false)!,
        isVisible: json.safeGet<bool>('isVisible', true)!,
        audioPath: json.safeGet<String>('audioPath', '')!,
        title: json.safeGet<String>('title', '')!,
        artist: json.safeGet<String>('artist', '')!,
        audioDuration: audioDuration,
        trimStart: json.safeDuration('trimStart'),
        trimEnd: json.safeDuration('trimEnd', audioDuration),
        volume: json.safeGet<double>('volume', 1.0)!,
        fadeIn: json.safeGet<bool>('fadeIn', false)!,
        fadeOut: json.safeGet<bool>('fadeOut', false)!,
        fadeDuration: json.safeDuration(
          'fadeDuration',
          const Duration(milliseconds: 500),
        ),
        isMuted: json.safeGet<bool>('isMuted', false)!,
      );
    } catch (e) {
      debugPrint('❌ AudioTimelineItem.fromJson error: $e');
      return AudioTimelineItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: Duration.zero,
        endTime: const Duration(seconds: 5),
        audioPath: '',
        audioDuration: const Duration(seconds: 5),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ VIDEO AUDIO SETTINGS (Original Video Audio)
// ═══════════════════════════════════════════════════════

@immutable
class VideoAudioSettings {
  final double volume;
  final bool isMuted;
  final bool fadeIn;
  final bool fadeOut;
  final Duration fadeDuration;

  const VideoAudioSettings({
    this.volume = 1.0,
    this.isMuted = false,
    this.fadeIn = false,
    this.fadeOut = false,
    this.fadeDuration = const Duration(seconds: 2),
  });

  double get effectiveVolume => isMuted ? 0.0 : volume.clamp(0.0, 2.0);

  VideoAudioSettings copyWith({
    double? volume,
    bool? isMuted,
    bool? fadeIn,
    bool? fadeOut,
    Duration? fadeDuration,
  }) {
    return VideoAudioSettings(
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
      fadeDuration: fadeDuration ?? this.fadeDuration,
    );
  }

  Map<String, dynamic> toJson() => {
    'volume': volume,
    'isMuted': isMuted,
    'fadeIn': fadeIn,
    'fadeOut': fadeOut,
    'fadeDuration': fadeDuration.inMilliseconds,
  };

  factory VideoAudioSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VideoAudioSettings();

    try {
      return VideoAudioSettings(
        volume: json.safeGet<double>('volume', 1.0)!,
        isMuted: json.safeGet<bool>('isMuted', false)!,
        fadeIn: json.safeGet<bool>('fadeIn', false)!,
        fadeOut: json.safeGet<bool>('fadeOut', false)!,
        fadeDuration: json.safeDuration(
          'fadeDuration',
          const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('❌ VideoAudioSettings.fromJson error: $e');
      return const VideoAudioSettings();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoAudioSettings &&
        other.volume == volume &&
        other.isMuted == isMuted &&
        other.fadeIn == fadeIn &&
        other.fadeOut == fadeOut &&
        other.fadeDuration == fadeDuration;
  }

  @override
  int get hashCode =>
      Object.hash(volume, isMuted, fadeIn, fadeOut, fadeDuration);
}

// ═══════════════════════════════════════════════════════
// ✅ TEXT OVERLAY (Separate from TimelineItem)
// ═══════════════════════════════════════════════════════

@immutable
class TextOverlay {
  final String id;
  final String text;
  final TextPositionCustom position;
  final TextOverlayStyle style;
  final TextAnimation animation;
  final Duration startTime;
  final Duration endTime;
  final double x;
  final double y;

  const TextOverlay({
    required this.id,
    required this.text,
    this.position = TextPositionCustom.bottomCenter,
    this.style = const TextOverlayStyle(),
    this.animation = TextAnimation.none,
    required this.startTime,
    required this.endTime,
    this.x = 0.5,
    this.y = 0.9,
  });

  Duration get duration => endTime - startTime;

  TextOverlay copyWith({
    String? id,
    String? text,
    TextPositionCustom? position,
    TextOverlayStyle? style,
    TextAnimation? animation,
    Duration? startTime,
    Duration? endTime,
    double? x,
    double? y,
  }) {
    return TextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      position: position ?? this.position,
      style: style ?? this.style,
      animation: animation ?? this.animation,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'position': position.index,
    'style': style.toJson(),
    'animation': animation.index,
    'startTime': startTime.inMilliseconds,
    'endTime': endTime.inMilliseconds,
    'x': x,
    'y': y,
  };

  factory TextOverlay.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TextOverlay(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 5),
      );
    }

    try {
      return TextOverlay(
        id: json.safeGet<String>(
          'id',
          DateTime.now().millisecondsSinceEpoch.toString(),
        )!,
        text: json.safeGet<String>('text', '')!,
        position: _safeEnum(
          TextPositionCustom.values,
          json['position'],
          TextPositionCustom.bottomCenter,
        ),
        style: TextOverlayStyle.fromJson(
          json['style'] as Map<String, dynamic>?,
        ),
        animation: _safeEnum(
          TextAnimation.values,
          json['animation'],
          TextAnimation.none,
        ),
        startTime: json.safeDuration('startTime'),
        endTime: json.safeDuration('endTime', const Duration(seconds: 5)),
        x: json.safeGet<double>('x', 0.5)!,
        y: json.safeGet<double>('y', 0.9)!,
      );
    } catch (e) {
      debugPrint('❌ TextOverlay.fromJson error: $e');
      return TextOverlay(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 5),
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextOverlay && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════
// ✅ TEXT PRESET
// ═══════════════════════════════════════════════════════

@immutable
class TextPreset {
  final String id;
  final String name;
  final TextOverlayStyle style;
  final TextAnimation animation;
  final String? iconEmoji;

  const TextPreset({
    required this.id,
    required this.name,
    required this.style,
    this.animation = TextAnimation.none,
    this.iconEmoji,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextPreset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  static const List<TextPreset> defaultPresets = [
    TextPreset(
      id: 'simple',
      name: 'Simple',
      style: TextOverlayStyle(fontSize: 48, color: 0xFFFFFFFF),
      iconEmoji: 'Aa',
    ),
    TextPreset(
      id: 'bold_shadow',
      name: 'Bold',
      style: TextOverlayStyle(
        fontSize: 56,
        color: 0xFFFFFFFF,
        bold: true,
        shadowBlur: 4,
      ),
      iconEmoji: 'Bb',
    ),
    TextPreset(
      id: 'outline',
      name: 'Outline',
      style: TextOverlayStyle(
        fontSize: 52,
        color: 0xFFFFFFFF,
        strokeWidth: 2,
        strokeColor: 0xFF000000,
      ),
      iconEmoji: '🅾️',
    ),
    TextPreset(
      id: 'neon',
      name: 'Neon',
      style: TextOverlayStyle(
        fontSize: 48,
        color: 0xFF00FFFF,
        shadowBlur: 10,
        shadowColor: 0xFF00FFFF,
      ),
      animation: TextAnimation.fadeIn,
      iconEmoji: '💡',
    ),
    TextPreset(
      id: 'fire',
      name: 'Fire',
      style: TextOverlayStyle(
        fontSize: 52,
        color: 0xFFFF6600,
        bold: true,
        shadowBlur: 8,
        shadowColor: 0xFFFF0000,
      ),
      iconEmoji: '🔥',
    ),
    TextPreset(
      id: 'subtitle',
      name: 'Subtitle',
      style: TextOverlayStyle(
        fontSize: 36,
        color: 0xFFFFFFFF,
        backgroundColor: 0x99000000,
      ),
      iconEmoji: '💬',
    ),
    TextPreset(
      id: 'typewriter',
      name: 'Type',
      style: TextOverlayStyle(
        fontFamily: 'Courier',
        fontSize: 40,
        color: 0xFF00FF00,
      ),
      animation: TextAnimation.typewriter,
      iconEmoji: '⌨️',
    ),
    TextPreset(
      id: 'elegant',
      name: 'Elegant',
      style: TextOverlayStyle(
        fontFamily: 'Georgia',
        fontSize: 44,
        color: 0xFFFFD700,
        italic: true,
      ),
      animation: TextAnimation.fadeIn,
      iconEmoji: '✨',
    ),
  ];
}

// ═══════════════════════════════════════════════════════
// ✅ AI IMAGE GENERATION
// ═══════════════════════════════════════════════════════

@immutable
class AiImageRequest {
  final String prompt;
  final String? negativePrompt;
  final AiImageStyle style;
  final AiImageSize size;
  final int count;

  const AiImageRequest({
    required this.prompt,
    this.negativePrompt,
    this.style = AiImageStyle.realistic,
    this.size = AiImageSize.landscape,
    this.count = 1,
  });

  Map<String, int> get dimensions {
    switch (size) {
      case AiImageSize.square:
        return {'width': 1024, 'height': 1024};
      case AiImageSize.portrait:
        return {'width': 768, 'height': 1024};
      case AiImageSize.landscape:
        return {'width': 1024, 'height': 768};
      case AiImageSize.wide:
        return {'width': 1280, 'height': 720};
    }
  }

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'negativePrompt': negativePrompt,
    'style': style.index,
    'size': size.index,
    'count': count,
  };

  factory AiImageRequest.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AiImageRequest(prompt: '');
    }

    try {
      return AiImageRequest(
        prompt: json.safeGet<String>('prompt', '')!,
        negativePrompt: json.safeGet<String>('negativePrompt'),
        style: _safeEnum(
          AiImageStyle.values,
          json['style'],
          AiImageStyle.realistic,
        ),
        size: _safeEnum(
          AiImageSize.values,
          json['size'],
          AiImageSize.landscape,
        ),
        count: json.safeGet<int>('count', 1)!.clamp(1, 4),
      );
    } catch (e) {
      debugPrint('❌ AiImageRequest.fromJson error: $e');
      return const AiImageRequest(prompt: '');
    }
  }
}

@immutable
class AiGeneratedImage {
  final String id;
  final String prompt;
  final String? localPath;
  final String? url;
  final Uint8List? bytes;
  final int width;
  final int height;
  final DateTime createdAt;

  AiGeneratedImage({
    required this.id,
    required this.prompt,
    this.localPath,
    this.url,
    this.bytes,
    this.width = 1024,
    this.height = 768,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AiGeneratedImage.create({
    required String prompt,
    String? localPath,
    String? url,
    Uint8List? bytes,
    int width = 1024,
    int height = 768,
  }) {
    return AiGeneratedImage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      prompt: prompt,
      localPath: localPath,
      url: url,
      bytes: bytes,
      width: width,
      height: height,
      createdAt: DateTime.now(),
    );
  }

  double get aspectRatio {
    try {
      if (width <= 0 || height <= 0) return 1.0;
      return width / height;
    } catch (e) {
      return 1.0;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'localPath': localPath,
    'url': url,
    'width': width,
    'height': height,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AiGeneratedImage.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AiGeneratedImage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        prompt: '',
      );
    }

    try {
      return AiGeneratedImage(
        id: json.safeGet<String>(
          'id',
          DateTime.now().millisecondsSinceEpoch.toString(),
        )!,
        prompt: json.safeGet<String>('prompt', '')!,
        localPath: json.safeGet<String>('localPath'),
        url: json.safeGet<String>('url'),
        width: json.safeGet<int>('width', 1024)!,
        height: json.safeGet<int>('height', 768)!,
        createdAt: _parseDateTime(json['createdAt']),
      );
    } catch (e) {
      debugPrint('❌ AiGeneratedImage.fromJson error: $e');
      return AiGeneratedImage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        prompt: '',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiGeneratedImage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum ExportJobStatus { pending, running, completed, failed, cancelled }

// ═══════════════════════════════════════════════════════
// ✅ EXPORT PROGRESS
// ═══════════════════════════════════════════════════════

@immutable
class ExportProgress {
  final ExportStatus status;
  final double progress;
  final String message;
  final String? outputPath;
  final String? error;
  final Duration elapsed;
  final Duration? estimated;

  const ExportProgress({
    this.status = ExportStatus.idle,
    this.progress = 0.0,
    this.message = '',
    this.outputPath,
    this.error,
    this.elapsed = Duration.zero,
    this.estimated,
  });

  bool get isActive =>
      status == ExportStatus.preparing ||
      status == ExportStatus.processing ||
      status == ExportStatus.encoding ||
      status == ExportStatus.saving;

  bool get isCompleted => status == ExportStatus.completed;
  bool get isFailed => status == ExportStatus.failed;
  bool get isCancelled => status == ExportStatus.cancelled;

  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  String get etaFormatted {
    try {
      if (estimated == null) return '--:--';
      final minutes = estimated!.inMinutes;
      final seconds = estimated!.inSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  ExportProgress copyWith({
    ExportStatus? status,
    double? progress,
    String? message,
    String? outputPath,
    String? error,
    Duration? elapsed,
    Duration? estimated,
  }) {
    return ExportProgress(
      status: status ?? this.status,
      progress: (progress ?? this.progress).clamp(0.0, 1.0),
      message: message ?? this.message,
      outputPath: outputPath ?? this.outputPath,
      error: error ?? this.error,
      elapsed: elapsed ?? this.elapsed,
      estimated: estimated ?? this.estimated,
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ VIDEO PROJECT
// ═══════════════════════════════════════════════════════

@immutable
class VideoProject {
  final String id;
  final String name;
  final String videoPath;
  final Duration videoDuration;
  final Duration trimStart;
  final Duration trimEnd;
  final List<TextTimelineItem> textItems;
  final List<ImageTimelineItem> imageItems;
  final List<AudioTimelineItem> audioItems;
  final ColorGradeSettings colorGrade;
  final VideoAudioSettings videoAudioSettings;
  final ExportPreset exportPreset;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final Uint8List? thumbnail;

  VideoProject({
    required this.id,
    required this.name,
    required this.videoPath,
    required this.videoDuration,
    this.trimStart = Duration.zero,
    Duration? trimEnd,
    this.textItems = const [],
    this.imageItems = const [],
    this.audioItems = const [],
    this.colorGrade = const ColorGradeSettings(),
    this.videoAudioSettings = const VideoAudioSettings(),
    this.exportPreset = const ExportPreset(id: 'high_1080p', name: '1080p HD'),
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.thumbnail,
  }) : trimEnd = trimEnd ?? videoDuration,
       createdAt = createdAt ?? DateTime.now(),
       modifiedAt = modifiedAt ?? DateTime.now();

  Duration get effectiveDuration {
    try {
      if (trimEnd <= trimStart) return Duration.zero;
      return trimEnd - trimStart;
    } catch (e) {
      return Duration.zero;
    }
  }

  double get trimStartPercent {
    try {
      if (videoDuration.inMilliseconds <= 0) return 0.0;
      return trimStart.inMilliseconds / videoDuration.inMilliseconds;
    } catch (e) {
      return 0.0;
    }
  }

  double get trimEndPercent {
    try {
      if (videoDuration.inMilliseconds <= 0) return 1.0;
      return trimEnd.inMilliseconds / videoDuration.inMilliseconds;
    } catch (e) {
      return 1.0;
    }
  }

  List<TimelineItem> get allItems {
    try {
      return [...textItems, ...imageItems, ...audioItems]
        ..sort((a, b) => a.layer.compareTo(b.layer));
    } catch (e) {
      return [];
    }
  }

  int get totalOverlayCount =>
      textItems.length + imageItems.length + audioItems.length;

  bool get hasModifications =>
      textItems.isNotEmpty ||
      imageItems.isNotEmpty ||
      audioItems.isNotEmpty ||
      !colorGrade.isDefault ||
      trimStart > Duration.zero ||
      trimEnd < videoDuration;

  List<TimelineItem> getVisibleItemsAt(Duration position) {
    try {
      return allItems.where((item) => item.isVisibleAt(position)).toList();
    } catch (e) {
      return [];
    }
  }

  VideoProject copyWith({
    String? id,
    String? name,
    String? videoPath,
    Duration? videoDuration,
    Duration? trimStart,
    Duration? trimEnd,
    List<TextTimelineItem>? textItems,
    List<ImageTimelineItem>? imageItems,
    List<AudioTimelineItem>? audioItems,
    ColorGradeSettings? colorGrade,
    VideoAudioSettings? videoAudioSettings,
    ExportPreset? exportPreset,
    DateTime? createdAt,
    DateTime? modifiedAt,
    Uint8List? thumbnail,
  }) {
    return VideoProject(
      id: id ?? this.id,
      name: name ?? this.name,
      videoPath: videoPath ?? this.videoPath,
      videoDuration: videoDuration ?? this.videoDuration,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      textItems: textItems ?? this.textItems,
      imageItems: imageItems ?? this.imageItems,
      audioItems: audioItems ?? this.audioItems,
      colorGrade: colorGrade ?? this.colorGrade,
      videoAudioSettings: videoAudioSettings ?? this.videoAudioSettings,
      exportPreset: exportPreset ?? this.exportPreset,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      thumbnail: thumbnail ?? this.thumbnail,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'videoPath': videoPath,
    'videoDuration': videoDuration.inMilliseconds,
    'trimStart': trimStart.inMilliseconds,
    'trimEnd': trimEnd.inMilliseconds,
    'textItems': textItems.map((e) => e.toJson()).toList(),
    'imageItems': imageItems.map((e) => e.toJson()).toList(),
    'audioItems': audioItems.map((e) => e.toJson()).toList(),
    'colorGrade': colorGrade.toJson(),
    'videoAudioSettings': videoAudioSettings.toJson(),
    'exportPreset': exportPreset.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  factory VideoProject.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return VideoProject(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Untitled',
        videoPath: '',
        videoDuration: Duration.zero,
      );
    }

    try {
      final videoDuration = json.safeDuration('videoDuration');

      return VideoProject(
        id: json.safeGet<String>(
          'id',
          DateTime.now().millisecondsSinceEpoch.toString(),
        )!,
        name: json.safeGet<String>('name', 'Untitled')!,
        videoPath: json.safeGet<String>('videoPath', '')!,
        videoDuration: videoDuration,
        trimStart: json.safeDuration('trimStart'),
        trimEnd: json.safeDuration('trimEnd', videoDuration),
        textItems: _parseList<TextTimelineItem>(
          json['textItems'],
          TextTimelineItem.fromJson,
        ),
        imageItems: _parseList<ImageTimelineItem>(
          json['imageItems'],
          ImageTimelineItem.fromJson,
        ),
        audioItems: _parseList<AudioTimelineItem>(
          json['audioItems'],
          AudioTimelineItem.fromJson,
        ),
        colorGrade: ColorGradeSettings.fromJson(
          json['colorGrade'] as Map<String, dynamic>?,
        ),
        videoAudioSettings: VideoAudioSettings.fromJson(
          json['videoAudioSettings'] as Map<String, dynamic>?,
        ),
        exportPreset: ExportPreset.fromJson(
          json['exportPreset'] as Map<String, dynamic>?,
        ),
        createdAt: _parseDateTime(json['createdAt']),
        modifiedAt: _parseDateTime(json['modifiedAt']),
      );
    } catch (e) {
      debugPrint('❌ VideoProject.fromJson error: $e');
      return VideoProject(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Untitled',
        videoPath: '',
        videoDuration: Duration.zero,
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoProject && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════
// ✅ MUSIC TRACK
// ═══════════════════════════════════════════════════════

@immutable
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String? albumArt;
  final Duration duration;
  final String previewUrl;
  final String downloadUrl;
  final String? localPath;
  final MusicCategory category;
  final bool isDownloaded;
  final int downloads;
  final List<String> tags;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.albumArt,
    required this.duration,
    required this.previewUrl,
    required this.downloadUrl,
    this.localPath,
    this.category = MusicCategory.all,
    this.isDownloaded = false,
    this.downloads = 0,
    this.tags = const [],
  });

  String get durationFormatted {
    try {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }

  MusicTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? albumArt,
    Duration? duration,
    String? previewUrl,
    String? downloadUrl,
    String? localPath,
    MusicCategory? category,
    bool? isDownloaded,
    int? downloads,
    List<String>? tags,
  }) {
    return MusicTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumArt: albumArt ?? this.albumArt,
      duration: duration ?? this.duration,
      previewUrl: previewUrl ?? this.previewUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      localPath: localPath ?? this.localPath,
      category: category ?? this.category,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloads: downloads ?? this.downloads,
      tags: tags ?? this.tags,
    );
  }

  factory MusicTrack.fromPixabay(Map<String, dynamic>? json) {
    if (json == null) {
      return MusicTrack(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Unknown',
        artist: 'Unknown',
        duration: Duration.zero,
        previewUrl: '',
        downloadUrl: '',
      );
    }

    try {
      return MusicTrack(
        id:
            json['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: json.safeGet<String>('title', 'Untitled')!,
        artist: json.safeGet<String>('user', 'Unknown Artist')!,
        albumArt: json.safeGet<String>('user_image_url'),
        duration: Duration(seconds: json.safeGet<int>('duration', 0)!),
        previewUrl: json.safeGet<String>('audio', '')!,
        downloadUrl: json.safeGet<String>('audio', '')!,
        downloads: json.safeGet<int>('downloads', 0)!,
        tags: _parseTags(json['tags']),
      );
    } catch (e) {
      debugPrint('❌ MusicTrack.fromPixabay error: $e');
      return MusicTrack(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Unknown',
        artist: 'Unknown',
        duration: Duration.zero,
        previewUrl: '',
        downloadUrl: '',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'albumArt': albumArt,
    'duration': duration.inMilliseconds,
    'previewUrl': previewUrl,
    'downloadUrl': downloadUrl,
    'localPath': localPath,
    'category': category.index,
    'isDownloaded': isDownloaded,
    'downloads': downloads,
    'tags': tags,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MusicTrack && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════
// ✅ STOCK IMAGE
// ═══════════════════════════════════════════════════════

@immutable
class StockImage {
  final String id;
  final String title;
  final String photographer;
  final String thumbnailUrl;
  final String previewUrl;
  final String fullUrl;
  final String? localPath;
  final int width;
  final int height;
  final ImageCategory category;
  final bool isDownloaded;
  final int downloads;
  final int likes;
  final List<String> tags;

  const StockImage({
    required this.id,
    required this.title,
    required this.photographer,
    required this.thumbnailUrl,
    required this.previewUrl,
    required this.fullUrl,
    this.localPath,
    required this.width,
    required this.height,
    this.category = ImageCategory.all,
    this.isDownloaded = false,
    this.downloads = 0,
    this.likes = 0,
    this.tags = const [],
  });

  double get aspectRatio {
    try {
      if (width <= 0 || height <= 0) return 1.0;
      return width / height;
    } catch (e) {
      return 1.0;
    }
  }

  String get resolution => '${width}x$height';

  StockImage copyWith({
    String? id,
    String? title,
    String? photographer,
    String? thumbnailUrl,
    String? previewUrl,
    String? fullUrl,
    String? localPath,
    int? width,
    int? height,
    ImageCategory? category,
    bool? isDownloaded,
    int? downloads,
    int? likes,
    List<String>? tags,
  }) {
    return StockImage(
      id: id ?? this.id,
      title: title ?? this.title,
      photographer: photographer ?? this.photographer,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      fullUrl: fullUrl ?? this.fullUrl,
      localPath: localPath ?? this.localPath,
      width: width ?? this.width,
      height: height ?? this.height,
      category: category ?? this.category,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloads: downloads ?? this.downloads,
      likes: likes ?? this.likes,
      tags: tags ?? this.tags,
    );
  }

  factory StockImage.fromPixabay(Map<String, dynamic>? json) {
    if (json == null) {
      return const StockImage(
        id: '',
        title: 'Unknown',
        photographer: 'Unknown',
        thumbnailUrl: '',
        previewUrl: '',
        fullUrl: '',
        width: 1920,
        height: 1080,
      );
    }

    try {
      final tags = _parseTags(json['tags']);

      return StockImage(
        id:
            json['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: tags.isNotEmpty ? tags.first : 'Image',
        photographer: json.safeGet<String>('user', 'Unknown')!,
        thumbnailUrl: json.safeGet<String>('previewURL', '')!,
        previewUrl: json.safeGet<String>('webformatURL', '')!,
        fullUrl:
            json.safeGet<String>('largeImageURL') ??
            json.safeGet<String>('webformatURL', '')!,
        width: json.safeGet<int>('imageWidth', 1920)!,
        height: json.safeGet<int>('imageHeight', 1080)!,
        downloads: json.safeGet<int>('downloads', 0)!,
        likes: json.safeGet<int>('likes', 0)!,
        tags: tags,
      );
    } catch (e) {
      debugPrint('❌ StockImage.fromPixabay error: $e');
      return const StockImage(
        id: '',
        title: 'Unknown',
        photographer: 'Unknown',
        thumbnailUrl: '',
        previewUrl: '',
        fullUrl: '',
        width: 1920,
        height: 1080,
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'photographer': photographer,
    'thumbnailUrl': thumbnailUrl,
    'previewUrl': previewUrl,
    'fullUrl': fullUrl,
    'localPath': localPath,
    'width': width,
    'height': height,
    'category': category.index,
    'isDownloaded': isDownloaded,
    'downloads': downloads,
    'likes': likes,
    'tags': tags,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StockImage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════
// ✅ HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════

/// Safe enum parsing
T _safeEnum<T>(List<T> values, dynamic value, T defaultValue) {
  try {
    if (value == null) return defaultValue;
    if (value is int && value >= 0 && value < values.length) {
      return values[value];
    }
    return defaultValue;
  } catch (e) {
    return defaultValue;
  }
}

/// Safe BlendMode parsing
BlendMode? _safeBlendMode(dynamic value) {
  try {
    if (value == null) return null;
    if (value is int && value >= 0 && value < BlendMode.values.length) {
      return BlendMode.values[value];
    }
    return null;
  } catch (e) {
    return null;
  }
}

/// Safe DateTime parsing
DateTime _parseDateTime(dynamic value) {
  try {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  } catch (e) {
    return DateTime.now();
  }
}

/// Safe tags parsing
List<String> _parseTags(dynamic value) {
  try {
    if (value == null) return [];
    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  } catch (e) {
    return [];
  }
}

/// Safe list parsing with factory
List<T> _parseList<T>(
  dynamic value,
  T Function(Map<String, dynamic>?) factory,
) {
  try {
    if (value == null) return [];
    if (value is! List) return [];
    return value.map((e) => factory(e as Map<String, dynamic>?)).toList();
  } catch (e) {
    return [];
  }
}
