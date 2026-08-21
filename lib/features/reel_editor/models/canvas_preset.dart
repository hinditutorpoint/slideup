import 'package:flutter/foundation.dart';
import '../core/validation/numeric_guard.dart';

/// Canvas presets md:62-91 — NEVER hardcode dimensions, dynamically calculate
@immutable
class CanvasPreset {
  final String id;
  final String name;
  final double aspectRatio; // width / height
  final bool isCustom;

  const CanvasPreset._({
    required this.id,
    required this.name,
    required this.aspectRatio,
    this.isCustom = false,
  });

  static const reel916 = CanvasPreset._(id: 'reel_9_16', name: '9:16 Reel', aspectRatio: 9 / 16);
  static const square11 = CanvasPreset._(id: 'square_1_1', name: '1:1 Square', aspectRatio: 1);
  static const portrait45 = CanvasPreset._(id: 'portrait_4_5', name: '4:5 Portrait', aspectRatio: 4 / 5);
  static const landscape169 = CanvasPreset._(id: 'landscape_16_9', name: '16:9 Landscape', aspectRatio: 16 / 9);
  static const landscape43 = CanvasPreset._(id: 'landscape_4_3', name: '4:3', aspectRatio: 4 / 3);
  static const portrait34 = CanvasPreset._(id: 'portrait_3_4', name: '3:4', aspectRatio: 3 / 4);
  static const custom = CanvasPreset._(id: 'custom', name: 'Custom', aspectRatio: 1, isCustom: true);

  static const List<CanvasPreset> all = [
    reel916,
    square11,
    portrait45,
    landscape169,
    landscape43,
    portrait34,
    custom,
  ];

  static CanvasPreset byId(String id) => all.firstWhere((e) => e.id == id, orElse: () => reel916);

  /// Dynamically calculate available size inside [constraints] without hardcoding md:75-78
  ({double width, double height}) calcSize(double maxWidth, double maxHeight, {double? customRatio}) {
    final ratio = isCustom && customRatio != null && NumericGuard.isValidDouble(customRatio) && customRatio > 0
        ? customRatio
        : aspectRatio;
    double w = maxWidth;
    double h = w / ratio;
    if (h > maxHeight) {
      h = maxHeight;
      w = h * ratio;
    }
    if (!NumericGuard.isValidDouble(w) || !NumericGuard.isValidDouble(h) || w <= 0 || h <= 0) {
      return (width: maxWidth, height: maxWidth / ratio);
    }
    return (width: w, height: h);
  }

  Map<String, dynamic> toJson() => {'id': id, 'customRatio': isCustom ? aspectRatio : null};
  factory CanvasPreset.fromJson(Map<String, dynamic>? json) {
    if (json == null) return reel916;
    final id = json['id'] as String? ?? 'reel_9_16';
    if (id == 'custom') {
      final r = (json['customRatio'] as num?)?.toDouble() ?? 1.0;
      final safe = NumericGuard.sanitizeDouble(r, 0.1, 4, 1);
      return CanvasPreset._(id: 'custom', name: 'Custom', aspectRatio: safe, isCustom: true);
    }
    return byId(id);
  }
}

/// Canvas state md:5 — bg color, preset, custom ratio
@immutable
class CanvasConfig {
  final CanvasPreset preset;
  final double? customAspectRatio;
  final int backgroundColor; // ARGB

  const CanvasConfig({
    this.preset = CanvasPreset.reel916,
    this.customAspectRatio,
    this.backgroundColor = 0xFF000000,
  });

  double get effectiveRatio {
    if (preset.isCustom && customAspectRatio != null) {
      return NumericGuard.sanitizeDouble(customAspectRatio!, 0.1, 4, preset.aspectRatio);
    }
    return preset.aspectRatio;
  }

  CanvasConfig copyWith({CanvasPreset? preset, double? customAspectRatio, int? backgroundColor}) =>
      CanvasConfig(preset: preset ?? this.preset, customAspectRatio: customAspectRatio ?? this.customAspectRatio, backgroundColor: backgroundColor ?? this.backgroundColor);

  Map<String, dynamic> toJson() => {'preset': preset.toJson(), 'customAspectRatio': customAspectRatio, 'backgroundColor': backgroundColor};
  factory CanvasConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CanvasConfig();
    return CanvasConfig(
      preset: CanvasPreset.fromJson(json['preset'] as Map<String, dynamic>?),
      customAspectRatio: (json['customAspectRatio'] as num?)?.toDouble(),
      backgroundColor: json['backgroundColor'] as int? ?? 0xFF000000,
    );
  }
}
