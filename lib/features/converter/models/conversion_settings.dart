import 'conversion_models.dart';

/// All user-configurable options for a single conversion.
///
/// This object is deliberately UI-independent. The FFmpeg command builder
/// reads it to produce structured arguments — commands are never assembled
/// in widgets.
class ConversionSettings {
  const ConversionSettings({
    this.format = ContainerFormat.mp4,
    this.videoCodec = VideoCodec.auto,
    this.audioCodec = AudioCodec.auto,
    this.width,
    this.height,
    this.frameRate = VideoFrameRate.auto,
    this.pixelFormat = PixelFormat.auto,
    this.encoderPreset = EncoderPreset.medium,
    this.profile = VideoProfile.auto,
    this.videoBitrateKbps,
    this.audioBitrateKbps,
    this.crf,
    this.audioSampleRate = AudioSampleRate.auto,
    this.audioChannels = AudioChannels.auto,
    this.audioQuality,
    this.volume = 1.0,
    this.trimStart = Duration.zero,
    this.trimEnd = Duration.zero,
    this.faststart = false,
    this.keepMetadata = true,
    this.audioMute = false,
    this.videoMute = false,
    this.hardwareMode = HardwareMode.auto,
    this.outputLocation = OutputLocation.appFolder,
    this.selectedFolderPath,
    this.duplicateStrategy = DuplicateStrategy.rename,
  });

  final ContainerFormat format;
  final VideoCodec videoCodec;
  final AudioCodec audioCodec;

  /// Output video dimensions. `null` keeps the source resolution.
  final int? width;
  final int? height;

  final VideoFrameRate frameRate;
  final PixelFormat pixelFormat;
  final EncoderPreset encoderPreset;
  final VideoProfile profile;

  /// Video bitrate in kilobits per second. `null` uses CRF mode.
  final int? videoBitrateKbps;

  /// Audio bitrate in kilobits per second. `null` lets the encoder decide.
  final int? audioBitrateKbps;

  /// Constant rate factor for libx264/libx265/libvpx (0-51, default 23).
  final int? crf;

  final AudioSampleRate audioSampleRate;
  final AudioChannels audioChannels;

  /// Encoder-specific quality (0-9). `null` = default.
  final int? audioQuality;

  /// Linear volume multiplier (0.0 = silent).
  final double volume;

  /// Extract only a segment of the media. [Duration.zero] means "no trim".
  final Duration trimStart;
  final Duration trimEnd;

  final bool faststart;
  final bool keepMetadata;

  /// Drop audio / video streams (e.g. image-only outputs).
  final bool audioMute;
  final bool videoMute;

  final HardwareMode hardwareMode;
  final OutputLocation outputLocation;
  final String? selectedFolderPath;
  final DuplicateStrategy duplicateStrategy;

  bool get isAudioTarget => format.isAudioContainer;
  bool get isVideoTarget => format.isVideoContainer;

  /// True when a full video re-encode is expected.
  bool get wantsVideo => format.isVideoContainer && !videoMute;

  ConversionSettings copyWith({
    ContainerFormat? format,
    VideoCodec? videoCodec,
    AudioCodec? audioCodec,
    int? width,
    int? height,
    VideoFrameRate? frameRate,
    PixelFormat? pixelFormat,
    EncoderPreset? encoderPreset,
    VideoProfile? profile,
    int? videoBitrateKbps,
    int? audioBitrateKbps,
    int? crf,
    AudioSampleRate? audioSampleRate,
    AudioChannels? audioChannels,
    int? audioQuality,
    double? volume,
    Duration? trimStart,
    Duration? trimEnd,
    bool? faststart,
    bool? keepMetadata,
    bool? audioMute,
    bool? videoMute,
    HardwareMode? hardwareMode,
    OutputLocation? outputLocation,
    String? selectedFolderPath,
    DuplicateStrategy? duplicateStrategy,
  }) {
    return ConversionSettings(
      format: format ?? this.format,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      width: width ?? this.width,
      height: height ?? this.height,
      frameRate: frameRate ?? this.frameRate,
      pixelFormat: pixelFormat ?? this.pixelFormat,
      encoderPreset: encoderPreset ?? this.encoderPreset,
      profile: profile ?? this.profile,
      videoBitrateKbps: videoBitrateKbps ?? this.videoBitrateKbps,
      audioBitrateKbps: audioBitrateKbps ?? this.audioBitrateKbps,
      crf: crf ?? this.crf,
      audioSampleRate: audioSampleRate ?? this.audioSampleRate,
      audioChannels: audioChannels ?? this.audioChannels,
      audioQuality: audioQuality ?? this.audioQuality,
      volume: volume ?? this.volume,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      faststart: faststart ?? this.faststart,
      keepMetadata: keepMetadata ?? this.keepMetadata,
      audioMute: audioMute ?? this.audioMute,
      videoMute: videoMute ?? this.videoMute,
      hardwareMode: hardwareMode ?? this.hardwareMode,
      outputLocation: outputLocation ?? this.outputLocation,
      selectedFolderPath: selectedFolderPath ?? this.selectedFolderPath,
      duplicateStrategy: duplicateStrategy ?? this.duplicateStrategy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'format': format.index,
      'videoCodec': videoCodec.index,
      'audioCodec': audioCodec.index,
      'width': width,
      'height': height,
      'frameRate': frameRate.index,
      'pixelFormat': pixelFormat.index,
      'encoderPreset': encoderPreset.index,
      'profile': profile.index,
      'videoBitrateKbps': videoBitrateKbps,
      'audioBitrateKbps': audioBitrateKbps,
      'crf': crf,
      'audioSampleRate': audioSampleRate.index,
      'audioChannels': audioChannels.index,
      'audioQuality': audioQuality,
      'volume': volume,
      'trimStartMs': trimStart.inMilliseconds,
      'trimEndMs': trimEnd.inMilliseconds,
      'faststart': faststart,
      'keepMetadata': keepMetadata,
      'audioMute': audioMute,
      'videoMute': videoMute,
      'hardwareMode': hardwareMode.index,
      'outputLocation': outputLocation.index,
      'selectedFolderPath': selectedFolderPath,
      'duplicateStrategy': duplicateStrategy.index,
    };
  }

  factory ConversionSettings.fromJson(Map<String, dynamic> json) {
    final videoCodec = VideoCodec.fromIndex(json['videoCodec'] as int?);
    final audioCodec = AudioCodec.fromIndex(json['audioCodec'] as int?);
    final formatIndex = json['format'] as int?;
    final outputLocation = json['outputLocation'] as int?;
    final duplicateStrategy = json['duplicateStrategy'] as int?;
    final hardwareMode = json['hardwareMode'] as int?;
    return ConversionSettings(
      format: formatIndex != null && formatIndex >= 0 && formatIndex < ContainerFormat.values.length
          ? ContainerFormat.values[formatIndex]
          : ContainerFormat.mp4,
      videoCodec: videoCodec ?? VideoCodec.auto,
      audioCodec: audioCodec ?? AudioCodec.auto,
      width: json['width'] as int?,
      height: json['height'] as int?,
      frameRate: VideoFrameRate.fromIndex(json['frameRate'] as int?) ?? VideoFrameRate.auto,
      pixelFormat: PixelFormat.fromIndex(json['pixelFormat'] as int?) ?? PixelFormat.auto,
      encoderPreset: EncoderPreset.fromIndex(json['encoderPreset'] as int?) ?? EncoderPreset.medium,
      profile: VideoProfile.fromIndex(json['profile'] as int?) ?? VideoProfile.auto,
      videoBitrateKbps: json['videoBitrateKbps'] as int?,
      audioBitrateKbps: json['audioBitrateKbps'] as int?,
      crf: json['crf'] as int?,
      audioSampleRate: AudioSampleRate.fromIndex(json['audioSampleRate'] as int?) ?? AudioSampleRate.auto,
      audioChannels: AudioChannels.fromIndex(json['audioChannels'] as int?) ?? AudioChannels.auto,
      audioQuality: json['audioQuality'] as int?,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      trimStart: Duration(milliseconds: json['trimStartMs'] as int? ?? 0),
      trimEnd: Duration(milliseconds: json['trimEndMs'] as int? ?? 0),
      faststart: json['faststart'] as bool? ?? false,
      keepMetadata: json['keepMetadata'] as bool? ?? true,
      audioMute: json['audioMute'] as bool? ?? false,
      videoMute: json['videoMute'] as bool? ?? false,
      hardwareMode: HardwareMode.values.elementAtOrNull(hardwareMode) ?? HardwareMode.auto,
      outputLocation: OutputLocation.values.elementAtOrNull(outputLocation) ?? OutputLocation.appFolder,
      selectedFolderPath: json['selectedFolderPath'] as String?,
      duplicateStrategy: DuplicateStrategy.values.elementAtOrNull(duplicateStrategy) ?? DuplicateStrategy.rename,
    );
  }
}