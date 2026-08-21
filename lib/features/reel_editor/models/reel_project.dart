import 'package:flutter/foundation.dart';
import '../core/utils/json_safe.dart';
import '../core/validation/numeric_guard.dart';
import 'canvas_preset.dart';

/// Versioned project model md:194-218, md:926-927
/// Schema version enables future migrations md:212-218
class ReelProject {
  static const int currentVersion = 1;

  final String id;
  final String name;
  final int version;
  final CanvasConfig canvas;
  final Duration duration; // computed, not stored
  final List<ReelVideoTrack> videoTracks;
  final List<ReelAudioTrack> audioTracks;
  final List<ReelOverlayTrack> overlayTracks;
  final List<ReelTextLayer> textLayers;
  final List<ReelStickerLayer> stickerLayers;
  final List<ReelShapeLayer> shapeLayers;
  final ReelFilterSettings filterSettings;
  final List<ReelTransition> transitions;
  final ReelSettings settings;
  final ExportPreset exportPreset;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const ReelProject({
    required this.id,
    required this.name,
    this.version = currentVersion,
    this.canvas = const CanvasConfig(),
    this.duration = Duration.zero,
    this.videoTracks = const [],
    this.audioTracks = const [],
    this.overlayTracks = const [],
    this.textLayers = const [],
    this.stickerLayers = const [],
    this.shapeLayers = const [],
    this.filterSettings = const ReelFilterSettings(),
    this.transitions = const [],
    this.settings = const ReelSettings(),
    this.exportPreset = ExportPreset.socialReel,
    this.metadata = const {},
    required this.createdAt,
    required this.modifiedAt,
  });

  Duration get computedDuration {
    if (videoTracks.isEmpty) return Duration.zero;
    Duration max = Duration.zero;
    for (final t in videoTracks) {
      final end = t.startTime + t.trimmedDuration;
      if (end > max) max = end;
    }
    // fallback to sum if overlapping intentionally
    return NumericGuard.sanitizeDuration(max);
  }

   ReelProject copyWith({
    String? id,
    String? name,
    int? version,
    CanvasConfig? canvas,
    List<ReelVideoTrack>? videoTracks,
    List<ReelAudioTrack>? audioTracks,
    List<ReelOverlayTrack>? overlayTracks,
    List<ReelTextLayer>? textLayers,
    List<ReelStickerLayer>? stickerLayers,
    List<ReelShapeLayer>? shapeLayers,
    ReelFilterSettings? filterSettings,
    List<ReelTransition>? transitions,
    ReelSettings? settings,
    ExportPreset? exportPreset,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) =>
      ReelProject(
        id: id ?? this.id,
        name: name ?? this.name,
        version: version ?? this.version,
        canvas: canvas ?? this.canvas,
        duration: duration,
        videoTracks: videoTracks ?? this.videoTracks,
        audioTracks: audioTracks ?? this.audioTracks,
        overlayTracks: overlayTracks ?? this.overlayTracks,
        textLayers: textLayers ?? this.textLayers,
        stickerLayers: stickerLayers ?? this.stickerLayers,
        shapeLayers: shapeLayers ?? this.shapeLayers,
        filterSettings: filterSettings ?? this.filterSettings,
        transitions: transitions ?? this.transitions,
        settings: settings ?? this.settings,
        exportPreset: exportPreset ?? this.exportPreset,
        metadata: metadata ?? this.metadata,
        createdAt: createdAt ?? this.createdAt,
        modifiedAt: modifiedAt ?? DateTime.now(),
      );

   Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'canvas': canvas.toJson(),
        'videoTracks': videoTracks.map((e) => e.toJson()).toList(),
        'audioTracks': audioTracks.map((e) => e.toJson()).toList(),
        'overlayTracks': overlayTracks.map((e) => e.toJson()).toList(),
        'textLayers': textLayers.map((e) => e.toJson()).toList(),
        'stickerLayers': stickerLayers.map((e) => e.toJson()).toList(),
        'shapeLayers': shapeLayers.map((e) => e.toJson()).toList(),
        'filterSettings': filterSettings.toJson(),
        'transitions': transitions.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
        'exportPreset': exportPreset.toJson(),
        'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
      };

  factory ReelProject.fromJson(Map<String, dynamic>? json) {
    if (json == null) throw const FormatException('null project json');
    try {
      final ver = json.safeGet<int>('version', currentVersion)!;
      // migration hook for future versions
      final migrated = _migrate(json, ver);
      return ReelProject(
        id: migrated.safeGet<String>('id', DateTime.now().millisecondsSinceEpoch.toString())!,
        name: migrated.safeGet<String>('name', 'Untitled')!,
        version: currentVersion,
        canvas: CanvasConfig.fromJson(migrated['canvas'] as Map<String, dynamic>?),
        videoTracks: _parseList(migrated['videoTracks'], ReelVideoTrack.fromJson),
        audioTracks: _parseList(migrated['audioTracks'], ReelAudioTrack.fromJson),
        overlayTracks: _parseList(migrated['overlayTracks'], ReelOverlayTrack.fromJson),
        textLayers: _parseList(migrated['textLayers'], ReelTextLayer.fromJson),
        stickerLayers: _parseList(migrated['stickerLayers'], ReelStickerLayer.fromJson),
        shapeLayers: _parseList(migrated['shapeLayers'], ReelShapeLayer.fromJson),
        filterSettings: ReelFilterSettings.fromJson(migrated['filterSettings'] as Map<String, dynamic>?),
        transitions: _parseList(migrated['transitions'], ReelTransition.fromJson),
        settings: ReelSettings.fromJson(migrated['settings'] as Map<String, dynamic>?),
        exportPreset: ExportPreset.fromJson(migrated['exportPreset'] as Map<String, dynamic>?),
        metadata: (migrated['metadata'] as Map<String, dynamic>?) ?? const {},
        createdAt: _parseDate(migrated['createdAt']),
        modifiedAt: _parseDate(migrated['modifiedAt']),
      );
    } catch (e) {
      debugPrint('ReelProject.fromJson error: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> _migrate(Map<String, dynamic> json, int ver) {
    if (ver == currentVersion) return json;
    // future: if ver==1 -> 2 transform here
    return json;
  }

  static List<T> _parseList<T>(dynamic v, T Function(Map<String, dynamic>?) f) {
    if (v is! List) return [];
    return v.map((e) => f(e as Map<String, dynamic>?)).toList();
  }

  static DateTime _parseDate(dynamic v) {
    try {
      if (v is String) return DateTime.parse(v);
    } catch (_) {}
    return DateTime.now();
  }

  factory ReelProject.create(String name, {CanvasConfig canvas = const CanvasConfig()}) {
    final now = DateTime.now();
    return ReelProject(id: now.millisecondsSinceEpoch.toString(), name: name, canvas: canvas, createdAt: now, modifiedAt: now);
  }
}

// ── Tracks / Layers ──────────────────────────────────────────────

@immutable
class ReelVideoTrack {
  final String id;
  final String sourcePath;
  final Duration sourceDuration;
  final Duration startTime; // on timeline
  final Duration trimStart;
  final Duration trimEnd;
  final double speed; // 0.25-4 md:455-472
  final double volume; // 0-2
  final double rotation; // degrees
  final bool flipH;
  final bool flipV;
  final bool mute;
  final String? filterId;
  final String? transitionId;
  // creative crop md:273 — normalized 0-1 rect, null = full frame
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;

  const ReelVideoTrack({
    required this.id,
    required this.sourcePath,
    required this.sourceDuration,
    this.startTime = Duration.zero,
    this.trimStart = Duration.zero,
    required this.trimEnd,
    this.speed = 1.0,
    this.volume = 1.0,
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.mute = false,
    this.filterId,
    this.transitionId,
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 1,
    this.cropBottom = 1,
  });

  bool get hasCrop => cropLeft != 0 || cropTop != 0 || cropRight != 1 || cropBottom != 1;

  Duration get trimmedDuration {
    final d = trimEnd - trimStart;
    if (d.isNegative) return Duration.zero;
    // speed affects timeline duration
    final s = NumericGuard.sanitizeDouble(speed, 0.25, 4, 1);
    return Duration(milliseconds: (d.inMilliseconds / s).round());
  }

   Map<String, dynamic> toJson() => {
        'id': id,
        'sourcePath': sourcePath,
        'sourceDuration': sourceDuration.inMilliseconds,
        'startTime': startTime.inMilliseconds,
        'trimStart': trimStart.inMilliseconds,
        'trimEnd': trimEnd.inMilliseconds,
        'speed': speed,
        'volume': volume,
        'rotation': rotation,
        'flipH': flipH,
        'flipV': flipV,
        'mute': mute,
        'filterId': filterId,
        'transitionId': transitionId,
        'cropLeft': cropLeft,
        'cropTop': cropTop,
        'cropRight': cropRight,
        'cropBottom': cropBottom,
      };
  factory ReelVideoTrack.fromJson(Map<String, dynamic>? j) {
    if (j == null) throw const FormatException('null videoTrack');
    final dur = j.safeDuration('sourceDuration');
    return ReelVideoTrack(
      id: j.safeGet<String>('id', '')!,
      sourcePath: j.safeGet<String>('sourcePath', '')!,
      sourceDuration: dur,
      startTime: j.safeDuration('startTime'),
      trimStart: j.safeDuration('trimStart'),
      trimEnd: j.safeDuration('trimEnd', dur),
      speed: NumericGuard.sanitizeDouble((j['speed'] as num?)?.toDouble() ?? 1, 0.25, 4, 1),
      volume: NumericGuard.sanitizeVolume((j['volume'] as num?)?.toDouble() ?? 1),
      rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
      flipH: j.safeGet<bool>('flipH', false)!,
      flipV: j.safeGet<bool>('flipV', false)!,
      mute: j.safeGet<bool>('mute', false)!,
      filterId: j.safeGet<String>('filterId'),
      transitionId: j.safeGet<String>('transitionId'),
      cropLeft: NumericGuard.sanitizeDouble((j['cropLeft'] as num?)?.toDouble() ?? 0, 0, 1, 0),
      cropTop: NumericGuard.sanitizeDouble((j['cropTop'] as num?)?.toDouble() ?? 0, 0, 1, 0),
      cropRight: NumericGuard.sanitizeDouble((j['cropRight'] as num?)?.toDouble() ?? 1, 0, 1, 1),
      cropBottom: NumericGuard.sanitizeDouble((j['cropBottom'] as num?)?.toDouble() ?? 1, 0, 1, 1),
    );
  }
}

@immutable
class ReelAudioTrack {
  final String id;
  final String sourcePath;
  final Duration startTime;
  final Duration trimStart;
  final Duration trimEnd;
  final double volume;
  final bool mute;
  final Duration fadeIn;
  final Duration fadeOut;
  const ReelAudioTrack({required this.id, required this.sourcePath, this.startTime = Duration.zero, this.trimStart = Duration.zero, required this.trimEnd, this.volume = 1, this.mute = false, this.fadeIn = Duration.zero, this.fadeOut = Duration.zero});
  Map<String, dynamic> toJson() => {'id': id, 'sourcePath': sourcePath, 'startTime': startTime.inMilliseconds, 'trimStart': trimStart.inMilliseconds, 'trimEnd': trimEnd.inMilliseconds, 'volume': volume, 'mute': mute, 'fadeIn': fadeIn.inMilliseconds, 'fadeOut': fadeOut.inMilliseconds};
  factory ReelAudioTrack.fromJson(Map<String, dynamic>? j) => ReelAudioTrack(id: j!.safeGet<String>('id', '')!, sourcePath: j.safeGet<String>('sourcePath', '')!, startTime: j.safeDuration('startTime'), trimStart: j.safeDuration('trimStart'), trimEnd: j.safeDuration('trimEnd'), volume: NumericGuard.sanitizeVolume((j['volume'] as num?)?.toDouble() ?? 1), mute: j.safeGet<bool>('mute', false)!, fadeIn: j.safeDuration('fadeIn'), fadeOut: j.safeDuration('fadeOut'));
}

@immutable
class ReelOverlayTrack {
  final String id;
  final String imagePath;
  final Duration startTime;
  final Duration endTime;
  final double x; // 0-1 normalized
  final double y;
  final double scale;
  final double rotation;
  final double opacity;
  final int zIndex;
  const ReelOverlayTrack({required this.id, required this.imagePath, required this.startTime, required this.endTime, this.x = 0.5, this.y = 0.5, this.scale = 1, this.rotation = 0, this.opacity = 1, this.zIndex = 0});
  Map<String, dynamic> toJson() => {'id': id, 'imagePath': imagePath, 'startTime': startTime.inMilliseconds, 'endTime': endTime.inMilliseconds, 'x': x, 'y': y, 'scale': scale, 'rotation': rotation, 'opacity': opacity, 'zIndex': zIndex};
  factory ReelOverlayTrack.fromJson(Map<String, dynamic>? j) => ReelOverlayTrack(id: j!.safeGet<String>('id', '')!, imagePath: j.safeGet<String>('imagePath', '')!, startTime: j.safeDuration('startTime'), endTime: j.safeDuration('endTime'), x: (j['x'] as num?)?.toDouble() ?? 0.5, y: (j['y'] as num?)?.toDouble() ?? 0.5, scale: NumericGuard.sanitizeScale((j['scale'] as num?)?.toDouble() ?? 1), rotation: (j['rotation'] as num?)?.toDouble() ?? 0, opacity: NumericGuard.sanitizeOpacity((j['opacity'] as num?)?.toDouble() ?? 1), zIndex: j.safeGet<int>('zIndex', 0)!);
}

@immutable
class ReelTextLayer {
  final String id;
  final String text;
  final Duration startTime;
  final Duration endTime;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final double fontSize;
  final String fontFamily;
  final int color; // ARGB
  final int bgColor;
  final double opacity;
  final int zIndex;
  // creative extended md:382-401
  final bool bold;
  final bool italic;
  final int align; // 0 left 1 center 2 right
  final double letterSpacing;
  final double lineSpacing;
  final int strokeColor;
  final double strokeWidth;
  final int shadowColor;
  final double shadowBlur;
  final String animation; // none, fade, slide, pop
  const ReelTextLayer({required this.id, required this.text, required this.startTime, required this.endTime, this.x = 0.5, this.y = 0.5, this.scale = 1, this.rotation = 0, this.fontSize = 24, this.fontFamily = 'Roboto', this.color = 0xFFFFFFFF, this.bgColor = 0x00000000, this.opacity = 1, this.zIndex = 0, this.bold = false, this.italic = false, this.align = 1, this.letterSpacing = 0, this.lineSpacing = 1.2, this.strokeColor = 0x00000000, this.strokeWidth = 0, this.shadowColor = 0x55000000, this.shadowBlur = 4, this.animation = 'none'});
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'startTime': startTime.inMilliseconds, 'endTime': endTime.inMilliseconds, 'x': x, 'y': y, 'scale': scale, 'rotation': rotation, 'fontSize': fontSize, 'color': color, 'bgColor': bgColor, 'opacity': opacity, 'zIndex': zIndex, 'fontFamily': fontFamily, 'bold': bold, 'italic': italic, 'align': align, 'letterSpacing': letterSpacing, 'lineSpacing': lineSpacing, 'strokeColor': strokeColor, 'strokeWidth': strokeWidth, 'shadowColor': shadowColor, 'shadowBlur': shadowBlur, 'animation': animation};
  factory ReelTextLayer.fromJson(Map<String, dynamic>? j) => ReelTextLayer(id: j!.safeGet<String>('id', '')!, text: j.safeGet<String>('text', '')!, startTime: j.safeDuration('startTime'), endTime: j.safeDuration('endTime'), x: (j['x'] as num?)?.toDouble() ?? 0.5, y: (j['y'] as num?)?.toDouble() ?? 0.5, scale: NumericGuard.sanitizeScale((j['scale'] as num?)?.toDouble() ?? 1), rotation: (j['rotation'] as num?)?.toDouble() ?? 0, fontSize: (j['fontSize'] as num?)?.toDouble() ?? 24, fontFamily: j.safeGet<String>('fontFamily', 'Roboto')!, color: j.safeGet<int>('color', 0xFFFFFFFF)!, bgColor: j.safeGet<int>('bgColor', 0x00000000)!, opacity: NumericGuard.sanitizeOpacity((j['opacity'] as num?)?.toDouble() ?? 1), zIndex: j.safeGet<int>('zIndex', 0)!, bold: j.safeGet<bool>('bold', false)!, italic: j.safeGet<bool>('italic', false)!, align: j.safeGet<int>('align', 1)!, letterSpacing: (j['letterSpacing'] as num?)?.toDouble() ?? 0, lineSpacing: (j['lineSpacing'] as num?)?.toDouble() ?? 1.2, strokeColor: j.safeGet<int>('strokeColor', 0x00000000)!, strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 0, shadowColor: j.safeGet<int>('shadowColor', 0x55000000)!, shadowBlur: (j['shadowBlur'] as num?)?.toDouble() ?? 4, animation: j.safeGet<String>('animation', 'none')!);
}

@immutable
class ReelStickerLayer {
  final String id;
  final String asset;
  final Duration startTime;
  final Duration endTime;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final double opacity;
  final int zIndex;
  const ReelStickerLayer({required this.id, required this.asset, required this.startTime, required this.endTime, this.x = 0.5, this.y = 0.5, this.scale = 1, this.rotation = 0, this.opacity = 1, this.zIndex = 0});
  Map<String, dynamic> toJson() => {'id': id, 'asset': asset, 'startTime': startTime.inMilliseconds, 'endTime': endTime.inMilliseconds, 'x': x, 'y': y, 'scale': scale, 'rotation': rotation, 'opacity': opacity, 'zIndex': zIndex};
  factory ReelStickerLayer.fromJson(Map<String, dynamic>? j) => ReelStickerLayer(id: j!.safeGet<String>('id', '')!, asset: j.safeGet<String>('asset', '')!, startTime: j.safeDuration('startTime'), endTime: j.safeDuration('endTime'), x: (j['x'] as num?)?.toDouble() ?? 0.5, y: (j['y'] as num?)?.toDouble() ?? 0.5, scale: NumericGuard.sanitizeScale((j['scale'] as num?)?.toDouble() ?? 1), rotation: (j['rotation'] as num?)?.toDouble() ?? 0, opacity: NumericGuard.sanitizeOpacity((j['opacity'] as num?)?.toDouble() ?? 1), zIndex: j.safeGet<int>('zIndex', 0)!);
}

@immutable
class ReelFilterSettings {
  final String? filterId;
  final double intensity; // 0-1
  const ReelFilterSettings({this.filterId, this.intensity = 1});
  Map<String, dynamic> toJson() => {'filterId': filterId, 'intensity': intensity};
  factory ReelFilterSettings.fromJson(Map<String, dynamic>? j) => ReelFilterSettings(filterId: j?.safeGet<String>('filterId'), intensity: NumericGuard.sanitizeOpacity((j?['intensity'] as num?)?.toDouble() ?? 1));
}

@immutable
class ReelTransition {
  final String id;
  final String type; // fade, slide, wipe, xfade name
  final Duration duration;
  const ReelTransition({required this.id, required this.type, required this.duration});
  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'duration': duration.inMilliseconds};
  factory ReelTransition.fromJson(Map<String, dynamic>? j) => ReelTransition(id: j!.safeGet<String>('id', '')!, type: j.safeGet<String>('type', 'fade')!, duration: j.safeDuration('duration'));
}

@immutable
class ReelShapeLayer {
  final String id;
  final String shapeType; // rect, circle, triangle, arrow, star
  final Duration startTime;
  final Duration endTime;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final double opacity;
  final int fillColor;
  final int strokeColor;
  final double strokeWidth;
  final int zIndex;
  const ReelShapeLayer({required this.id, this.shapeType = 'rect', required this.startTime, required this.endTime, this.x = 0.5, this.y = 0.5, this.scale = 1, this.rotation = 0, this.opacity = 1, this.fillColor = 0xFFFF3366, this.strokeColor = 0x00000000, this.strokeWidth = 0, this.zIndex = 0});
  Map<String, dynamic> toJson() => {'id': id, 'shapeType': shapeType, 'startTime': startTime.inMilliseconds, 'endTime': endTime.inMilliseconds, 'x': x, 'y': y, 'scale': scale, 'rotation': rotation, 'opacity': opacity, 'fillColor': fillColor, 'strokeColor': strokeColor, 'strokeWidth': strokeWidth, 'zIndex': zIndex};
  factory ReelShapeLayer.fromJson(Map<String, dynamic>? j) => ReelShapeLayer(id: j!.safeGet<String>('id', '')!, shapeType: j.safeGet<String>('shapeType', 'rect')!, startTime: j.safeDuration('startTime'), endTime: j.safeDuration('endTime'), x: (j['x'] as num?)?.toDouble() ?? 0.5, y: (j['y'] as num?)?.toDouble() ?? 0.5, scale: NumericGuard.sanitizeScale((j['scale'] as num?)?.toDouble() ?? 1), rotation: (j['rotation'] as num?)?.toDouble() ?? 0, opacity: NumericGuard.sanitizeOpacity((j['opacity'] as num?)?.toDouble() ?? 1), fillColor: j.safeGet<int>('fillColor', 0xFFFF3366)!, strokeColor: j.safeGet<int>('strokeColor', 0x00000000)!, strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 0, zIndex: j.safeGet<int>('zIndex', 0)!);
}

enum ExportPresetId { socialReel, high, small, custom }

@immutable
class ExportPreset {
  final ExportPresetId id;
  final String name;
  final int width;
  final int height;
  final int fps;
  final String vCodec;
  final String aCodec;
  final int vBitrate; // kbps
  final int aBitrate;
  const ExportPreset._({required this.id, required this.name, required this.width, required this.height, required this.fps, required this.vCodec, required this.aCodec, required this.vBitrate, required this.aBitrate});
  static const socialReel = ExportPreset._(id: ExportPresetId.socialReel, name: 'Social Reel 1080x1920', width: 1080, height: 1920, fps: 30, vCodec: 'libx264', aCodec: 'aac', vBitrate: 8000, aBitrate: 128);
  static const high = ExportPreset._(id: ExportPresetId.high, name: 'High 1080x1920', width: 1080, height: 1920, fps: 30, vCodec: 'libx264', aCodec: 'aac', vBitrate: 12000, aBitrate: 192);
  static const small = ExportPreset._(id: ExportPresetId.small, name: 'Small 720x1280', width: 720, height: 1280, fps: 30, vCodec: 'libx264', aCodec: 'aac', vBitrate: 4000, aBitrate: 96);
  static const custom = ExportPreset._(id: ExportPresetId.custom, name: 'Custom', width: 1080, height: 1920, fps: 30, vCodec: 'libx264', aCodec: 'aac', vBitrate: 8000, aBitrate: 128);
  static const values = [socialReel, high, small, custom];
  static ExportPreset byId(String s) => values.firstWhere((e) => e.id.name == s, orElse: () => socialReel);
  Map<String, dynamic> toJson() => {'id': id.name, 'width': width, 'height': height, 'fps': fps, 'vCodec': vCodec, 'aCodec': aCodec, 'vBitrate': vBitrate, 'aBitrate': aBitrate};
  factory ExportPreset.fromJson(Map<String, dynamic>? j) { if (j == null) return socialReel; final id = j.safeGet<String>('id', 'socialReel')!; final base = byId(id); if (id == 'custom') return ExportPreset._(id: ExportPresetId.custom, name: 'Custom', width: j.safeGet<int>('width', 1080)!, height: j.safeGet<int>('height', 1920)!, fps: j.safeGet<int>('fps', 30)!, vCodec: j.safeGet<String>('vCodec', 'libx264')!, aCodec: j.safeGet<String>('aCodec', 'aac')!, vBitrate: j.safeGet<int>('vBitrate', 8000)!, aBitrate: j.safeGet<int>('aBitrate', 128)!); return base; }
}

@immutable
class ReelSettings {
  final int fps;
  final int width;
  final int height;
  final bool snapEnabled;
  const ReelSettings({this.fps = 30, this.width = 1080, this.height = 1920, this.snapEnabled = true});
  Map<String, dynamic> toJson() => {'fps': fps, 'width': width, 'height': height, 'snapEnabled': snapEnabled};
  factory ReelSettings.fromJson(Map<String, dynamic>? j) => ReelSettings(fps: j?.safeGet<int>('fps', 30) ?? 30, width: j?.safeGet<int>('width', 1080) ?? 1080, height: j?.safeGet<int>('height', 1920) ?? 1920, snapEnabled: j?.safeGet<bool>('snapEnabled', true) ?? true);
}
