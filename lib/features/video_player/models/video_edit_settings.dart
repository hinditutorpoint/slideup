import 'package:flutter/foundation.dart';

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

  factory ColorGradeSettings.fromJson(Map<String, dynamic> json) {
    return ColorGradeSettings(
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1.0,
      hue: (json['hue'] as num?)?.toDouble() ?? 0.0,
      red: (json['red'] as num?)?.toDouble() ?? 1.0,
      green: (json['green'] as num?)?.toDouble() ?? 1.0,
      blue: (json['blue'] as num?)?.toDouble() ?? 1.0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      tint: (json['tint'] as num?)?.toDouble() ?? 0.0,
      vibrance: (json['vibrance'] as num?)?.toDouble() ?? 0.0,
      highlights: (json['highlights'] as num?)?.toDouble() ?? 0.0,
      shadows: (json['shadows'] as num?)?.toDouble() ?? 0.0,
      whites: (json['whites'] as num?)?.toDouble() ?? 0.0,
      blacks: (json['blacks'] as num?)?.toDouble() ?? 0.0,
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

  static const ColorGradeSettings defaultSettings = ColorGradeSettings();
}

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

  factory ClipMarker.fromJson(Map<String, dynamic> json) {
    return ClipMarker(
      id: json['id'] as String,
      startTime: Duration(milliseconds: json['startTime'] as int),
      endTime: Duration(milliseconds: json['endTime'] as int),
      label: json['label'] as String?,
      colorGrade: json['colorGrade'] != null
          ? ColorGradeSettings.fromJson(
              json['colorGrade'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

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
    );
  }
}

class ColorPreset {
  final String id;
  final String name;
  final ColorGradeSettings settings;
  final String? thumbnailPath;

  const ColorPreset({
    required this.id,
    required this.name,
    required this.settings,
    this.thumbnailPath,
  });

  static const List<ColorPreset> defaultPresets = [
    ColorPreset(id: 'normal', name: 'Normal', settings: ColorGradeSettings()),
    ColorPreset(
      id: 'vivid',
      name: 'Vivid',
      settings: ColorGradeSettings(
        saturation: 1.3,
        vibrance: 0.2,
        contrast: 1.1,
      ),
    ),
    ColorPreset(
      id: 'warm',
      name: 'Warm',
      settings: ColorGradeSettings(temperature: 30, red: 1.1, blue: 0.9),
    ),
    ColorPreset(
      id: 'cool',
      name: 'Cool',
      settings: ColorGradeSettings(temperature: -30, blue: 1.1, red: 0.9),
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
    ),
    ColorPreset(
      id: 'bw',
      name: 'B&W',
      settings: ColorGradeSettings(saturation: 0.0, contrast: 1.2),
    ),
    ColorPreset(
      id: 'cinematic',
      name: 'Cinematic',
      settings: ColorGradeSettings(
        contrast: 1.2,
        saturation: 0.9,
        shadows: -0.1,
        highlights: -0.1,
      ),
    ),
    ColorPreset(
      id: 'matte',
      name: 'Matte',
      settings: ColorGradeSettings(
        blacks: 0.15,
        contrast: 0.9,
        saturation: 0.85,
      ),
    ),
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'settings': settings.toJson(),
    'thumbnailPath': thumbnailPath,
  };

  factory ColorPreset.fromJson(Map<String, dynamic> json) {
    return ColorPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      settings: ColorGradeSettings.fromJson(
        json['settings'] as Map<String, dynamic>,
      ),
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }
}
