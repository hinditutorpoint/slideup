import '../models/conversion_models.dart';
import '../models/conversion_settings.dart';
import '../models/converter_preset.dart';

/// Static metadata used across the converter feature: supported source
/// formats, seeded system presets, and default option values.
class ConverterConstants {
  ConverterConstants._();

  static const String dbTableJobs = 'conversion_jobs';
  static const String dbTablePresets = 'converter_presets';

  /// Source extensions the converter accepts (video + audio).
  static const List<String> supportedVideoInputs = [
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v',
    '3gp', 'mpg', 'mpeg', 'ts',
  ];

  static const List<String> supportedAudioInputs = [
    'mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg', 'opus', 'wma', 'aiff', 'm4b',
  ];

  static const List<String> supportedInputs = [
    ...supportedVideoInputs,
    ...supportedAudioInputs,
  ];

  /// Estimated size multiplier used when checking available disk space.
  static const double outputSizeEstimateFactor = 1.5;

  /// Maximum characters of FFmpeg log kept per job.
  static const int maxLogLength = 8000;

  /// Default maximum simultaneous conversions.
  static const int defaultMaxSimultaneous = 1;

  /// Seed system presets (shown as "System" in the presets screen).
  static List<ConverterPreset> createSystemPresets() {
    DateTime now = DateTime.now();

    ConverterPreset build(String name, String description, ConversionSettings s) {
      return ConverterPreset(
        id: 'system_${name.toLowerCase().replaceAll(' ', '_')}',
        name: name,
        isSystem: true,
        isDefault: name == 'MP3 High Quality',
        settings: s,
        createdAt: now,
        description: description,
      );
    }

    return [
      build(
        'MP3 High Quality',
        '320 kbps MP3 for audio files',
        const ConversionSettings(
          format: ContainerFormat.mp3,
          audioCodec: AudioCodec.mp3,
          audioBitrateKbps: 320,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        'MP3 Balanced',
        '192 kbps MP3, good size/quality',
        const ConversionSettings(
          format: ContainerFormat.mp3,
          audioCodec: AudioCodec.mp3,
          audioBitrateKbps: 192,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        'M4A AAC High',
        '256 kbps AAC in M4A container',
        const ConversionSettings(
          format: ContainerFormat.m4a,
          audioCodec: AudioCodec.aac,
          audioBitrateKbps: 256,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        'FLAC Lossless',
        'Lossless compression',
        const ConversionSettings(
          format: ContainerFormat.flac,
          audioCodec: AudioCodec.flac,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        'Opus Compact',
        '192 kbps Opus, great compression',
        const ConversionSettings(
          format: ContainerFormat.opus,
          audioCodec: AudioCodec.opus,
          audioBitrateKbps: 192,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        'WAV Uncompressed',
        'CD-quality PCM (large files)',
        const ConversionSettings(
          format: ContainerFormat.wav,
          audioCodec: AudioCodec.pcm_s16le,
          audioSampleRate: AudioSampleRate.hz44100,
          audioChannels: AudioChannels.stereo,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        'MP4 H.264 1080p',
        'H.264 + AAC in MP4, full HD',
        const ConversionSettings(
          format: ContainerFormat.mp4,
          videoCodec: VideoCodec.h264,
          audioCodec: AudioCodec.aac,
          height: 1080,
          pixelFormat: PixelFormat.yuv420p,
          encoderPreset: EncoderPreset.medium,
          faststart: true,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        'MP4 H.264 720p',
        'H.264 + AAC in MP4, HD 720p',
        const ConversionSettings(
          format: ContainerFormat.mp4,
          videoCodec: VideoCodec.h264,
          audioCodec: AudioCodec.aac,
          height: 720,
          pixelFormat: PixelFormat.yuv420p,
          encoderPreset: EncoderPreset.medium,
          faststart: true,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        'MP4 HEVC Compact',
        'H.265, smaller files at same quality',
        const ConversionSettings(
          format: ContainerFormat.mp4,
          videoCodec: VideoCodec.hevc,
          audioCodec: AudioCodec.aac,
          pixelFormat: PixelFormat.yuv420p,
          encoderPreset: EncoderPreset.medium,
          faststart: true,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        'MKV HEVC',
        'H.265 in MKV container',
        const ConversionSettings(
          format: ContainerFormat.mkv,
          videoCodec: VideoCodec.hevc,
          audioCodec: AudioCodec.aac,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        'WebM VP9',
        'VP9 video + Opus audio',
        const ConversionSettings(
          format: ContainerFormat.webm,
          videoCodec: VideoCodec.vp9,
          audioCodec: AudioCodec.opus,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        'AVI Compatible',
        'MPEG-4 + MP3 for old devices',
        const ConversionSettings(
          format: ContainerFormat.avi,
          videoCodec: VideoCodec.mpeg4,
          audioCodec: AudioCodec.mp3,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
      build(
        '3GP Old Phone',
        'H.263 + AMR-NB in 3GP, plays on old phones',
        const ConversionSettings(
          format: ContainerFormat.threeGp,
          videoCodec: VideoCodec.h263,
          audioCodec: AudioCodec.amr_nb,
          height: 240,
          outputLocation: OutputLocation.appFolder,
        ),
      ),
    ];
  }

  /// Standard CRF defaults per encoder (quality 18-28 range).
  static int defaultCrfFor(VideoCodec codec) {
    switch (codec) {
      case VideoCodec.hevc:
        return 28;
      case VideoCodec.av1:
        return 40;
      case VideoCodec.vp9:
        return 31;
      case VideoCodec.vp8:
        return 28;
      default:
        return 23;
    }
  }
}