// Standalone scene settings — isolated from video_editor.
// Persisted as JSON under Hive settingsBox key `scene_settings`.

enum ScenePlatform {
  tiktok,
  youtube,
  instagram,
  facebookReel,
  youtubeShort,
  custom,
}

enum SceneContainer {
  mp4,
  mov,
  webm,
}

enum SceneFit {
  cropCenter,
  padBlur,
  padBlack,
}

enum SceneAudioMode {
  keep,
  remove,
}

enum SceneSaveDestination {
  filesOnly,
  galleryOnly,
  both,
}

class PlatformPreset {
  final int? width;
  final int? height;
  final int bitrateKbps;
  final int fps;
  final String label;

  const PlatformPreset({
    this.width,
    this.height,
    required this.bitrateKbps,
    required this.fps,
    required this.label,
  });
}

/// Preset table — add new platform = one entry (future-proof).
const Map<ScenePlatform, PlatformPreset> scenePresetTable = {
  ScenePlatform.tiktok: PlatformPreset(
    width: 1080,
    height: 1920,
    bitrateKbps: 8000,
    fps: 30,
    label: 'TikTok 9:16 • 1080×1920',
  ),
  ScenePlatform.facebookReel: PlatformPreset(
    width: 1080,
    height: 1920,
    bitrateKbps: 8000,
    fps: 30,
    label: 'FB Reel 9:16 • 1080×1920',
  ),
  ScenePlatform.youtubeShort: PlatformPreset(
    width: 1080,
    height: 1920,
    bitrateKbps: 8000,
    fps: 30,
    label: 'YT Short 9:16 • 1080×1920',
  ),
  ScenePlatform.instagram: PlatformPreset(
    width: 1080,
    height: 1080,
    bitrateKbps: 6000,
    fps: 30,
    label: 'IG Square 1:1 • 1080×1080',
  ),
  ScenePlatform.youtube: PlatformPreset(
    width: 1920,
    height: 1080,
    bitrateKbps: 8000,
    fps: 30,
    label: 'YouTube 16:9 • 1920×1080',
  ),
  ScenePlatform.custom: PlatformPreset(
    width: null,
    height: null,
    bitrateKbps: 8000,
    fps: 30,
    label: 'Custom',
  ),
};

extension SceneContainerX on SceneContainer {
  String get extension {
    switch (this) {
      case SceneContainer.mp4:
        return 'mp4';
      case SceneContainer.mov:
        return 'mov';
      case SceneContainer.webm:
        return 'webm';
    }
  }

  String get label => name;
}

extension ScenePlatformX on ScenePlatform {
  String get label {
    switch (this) {
      case ScenePlatform.tiktok:
        return 'TikTok';
      case ScenePlatform.facebookReel:
        return 'FB Reel';
      case ScenePlatform.youtubeShort:
        return 'YT Short';
      case ScenePlatform.instagram:
        return 'Instagram';
      case ScenePlatform.youtube:
        return 'YouTube';
      case ScenePlatform.custom:
        return 'Custom';
    }
  }
}

extension SceneFitX on SceneFit {
  String get label {
    switch (this) {
      case SceneFit.cropCenter:
        return 'Crop center';
      case SceneFit.padBlur:
        return 'Pad blur';
      case SceneFit.padBlack:
        return 'Pad black';
    }
  }
}

extension SceneSaveDestinationX on SceneSaveDestination {
  String get label {
    switch (this) {
      case SceneSaveDestination.filesOnly:
        return 'Files folder';
      case SceneSaveDestination.galleryOnly:
        return 'Gallery only';
      case SceneSaveDestination.both:
        return 'Files + Gallery';
    }
  }

  String get subtitle {
    switch (this) {
      case SceneSaveDestination.filesOnly:
        return 'Save to chosen folder';
      case SceneSaveDestination.galleryOnly:
        return 'Save to Movies/SlideUpScenes in gallery';
      case SceneSaveDestination.both:
        return 'Save to folder and also copy to gallery';
    }
  }
}

class SceneSettings {
  final ScenePlatform platform;
  final SceneContainer container;
  final int? customWidth;
  final int? customHeight;
  final SceneFit fitMode;
  final int fps;
  final int videoBitrateKbps;
  final SceneAudioMode audioMode;
  final String saveLocation;
  final SceneSaveDestination saveDestination;
  final bool faststart;
  final int schemaVersion;

  const SceneSettings({
    this.platform = ScenePlatform.tiktok,
    this.container = SceneContainer.mp4,
    this.customWidth,
    this.customHeight,
    this.fitMode = SceneFit.cropCenter,
    this.fps = 30,
    this.videoBitrateKbps = 8000,
    this.audioMode = SceneAudioMode.keep,
    this.saveLocation = '/storage/emulated/0/Download/SlideUpScenes',
    this.saveDestination = SceneSaveDestination.filesOnly,
    this.faststart = true,
    this.schemaVersion = 2,
  });

  PlatformPreset get resolvedPreset {
    if (platform == ScenePlatform.custom) {
      return PlatformPreset(
        width: customWidth,
        height: customHeight,
        bitrateKbps: videoBitrateKbps,
        fps: fps,
        label: 'Custom ${customWidth ?? '?'}×${customHeight ?? '?'}',
      );
    }
    return scenePresetTable[platform]!;
  }

  bool get hasCustomResolution =>
      platform == ScenePlatform.custom && (customWidth != null || customHeight != null);

  SceneSettings copyWith({
    ScenePlatform? platform,
    SceneContainer? container,
    int? customWidth,
    int? customHeight,
    SceneFit? fitMode,
    int? fps,
    int? videoBitrateKbps,
    SceneAudioMode? audioMode,
    String? saveLocation,
    SceneSaveDestination? saveDestination,
    bool? faststart,
    int? schemaVersion,
    bool clearCustom = false,
  }) {
    return SceneSettings(
      platform: platform ?? this.platform,
      container: container ?? this.container,
      customWidth: clearCustom ? null : (customWidth ?? this.customWidth),
      customHeight: clearCustom ? null : (customHeight ?? this.customHeight),
      fitMode: fitMode ?? this.fitMode,
      fps: fps ?? this.fps,
      videoBitrateKbps: videoBitrateKbps ?? this.videoBitrateKbps,
      audioMode: audioMode ?? this.audioMode,
      saveLocation: saveLocation ?? this.saveLocation,
      saveDestination: saveDestination ?? this.saveDestination,
      faststart: faststart ?? this.faststart,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'platform': platform.index,
        'container': container.index,
        'customWidth': customWidth,
        'customHeight': customHeight,
        'fitMode': fitMode.index,
        'fps': fps,
        'videoBitrateKbps': videoBitrateKbps,
        'audioMode': audioMode.index,
        'saveLocation': saveLocation,
        'saveDestination': saveDestination.index,
        'faststart': faststart,
        'schemaVersion': schemaVersion,
      };

  factory SceneSettings.fromJson(Map<String, dynamic> json) {
    ScenePlatform platform = ScenePlatform.tiktok;
    final pi = json['platform'];
    if (pi is int && pi >= 0 && pi < ScenePlatform.values.length) {
      platform = ScenePlatform.values[pi];
    }
    SceneContainer container = SceneContainer.mp4;
    final ci = json['container'];
    if (ci is int && ci >= 0 && ci < SceneContainer.values.length) {
      container = SceneContainer.values[ci];
    }
    SceneFit fit = SceneFit.cropCenter;
    final fi = json['fitMode'];
    if (fi is int && fi >= 0 && fi < SceneFit.values.length) {
      fit = SceneFit.values[fi];
    }
    SceneAudioMode audio = SceneAudioMode.keep;
    final ai = json['audioMode'];
    if (ai is int && ai >= 0 && ai < SceneAudioMode.values.length) {
      audio = SceneAudioMode.values[ai];
    }
    // Migrate old saveToGallery bool -> new enum
    SceneSaveDestination dest = SceneSaveDestination.filesOnly;
    final di = json['saveDestination'];
    if (di is int && di >= 0 && di < SceneSaveDestination.values.length) {
      dest = SceneSaveDestination.values[di];
    } else if (json['saveToGallery'] is bool) {
      dest = (json['saveToGallery'] as bool) ? SceneSaveDestination.both : SceneSaveDestination.filesOnly;
    }
    // Migrate old default Download -> dedicated SlideUpScenes subfolder
    String loc = (json['saveLocation'] as String?) ?? '/storage/emulated/0/Download/SlideUpScenes';
    if (loc == '/storage/emulated/0/Download') {
      loc = '/storage/emulated/0/Download/SlideUpScenes';
    }
    return SceneSettings(
      platform: platform,
      container: container,
      customWidth: json['customWidth'] as int?,
      customHeight: json['customHeight'] as int?,
      fitMode: fit,
      fps: (json['fps'] as int?) ?? 30,
      videoBitrateKbps: (json['videoBitrateKbps'] as int?) ?? 8000,
      audioMode: audio,
      saveLocation: loc,
      saveDestination: dest,
      faststart: (json['faststart'] as bool?) ?? true,
      schemaVersion: (json['schemaVersion'] as int?) ?? 2,
    );
  }
}
