/// Core value types and enums shared across the audio/video converter feature.
library;

/// Lifecycle state of a conversion job.
enum ConversionStatus {
  pending,
  queued,
  processing,
  completed,
  failed,
  cancelled,
  interrupted;

  bool get isActive => this == pending || this == queued || this == processing;

  bool get isTerminal => !isActive;

  bool get isRetryable =>
      this == failed || this == cancelled || this == interrupted;

  static ConversionStatus? fromIndex(int? index) {
    if (index == null) return null;
    final values = ConversionStatus.values;
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}

/// Whether the source/target media is audio or video.
enum ConversionMediaKind { audio, video }

/// Where converted output files are written.
enum OutputLocation { sameFolder, appFolder, selectedFolder }

/// What to do when the desired output file already exists.
enum DuplicateStrategy { ask, replace, rename, skip }

/// Hardware acceleration mode for FFmpeg.
enum HardwareMode { auto, cpu, hardware }

/// Supported target container formats.
enum ContainerFormat {
  mp3,
  wav,
  flac,
  aac,
  m4a,
  ogg,
  opus,
  aiff,
  wma,
  mp4,
  mkv,
  avi,
  mov,
  webm,
  m4v,
  mpg,
  ts,
  flv,
  gif;

  static ContainerFormat? fromExtension(String ext) {
    for (final f in ContainerFormat.values) {
      if (f.extension == ext.toLowerCase()) return f;
    }
    return null;
  }
}

extension ContainerFormatX on ContainerFormat {
  /// File extension without the leading dot.
  String get extension {
    switch (this) {
      case ContainerFormat.mp3:
        return 'mp3';
      case ContainerFormat.wav:
        return 'wav';
      case ContainerFormat.flac:
        return 'flac';
      case ContainerFormat.aac:
        return 'aac';
      case ContainerFormat.m4a:
        return 'm4a';
      case ContainerFormat.ogg:
        return 'ogg';
      case ContainerFormat.opus:
        return 'opus';
      case ContainerFormat.aiff:
        return 'aiff';
      case ContainerFormat.wma:
        return 'wma';
      case ContainerFormat.mp4:
        return 'mp4';
      case ContainerFormat.mkv:
        return 'mkv';
      case ContainerFormat.avi:
        return 'avi';
      case ContainerFormat.mov:
        return 'mov';
      case ContainerFormat.webm:
        return 'webm';
      case ContainerFormat.m4v:
        return 'm4v';
      case ContainerFormat.mpg:
        return 'mpg';
      case ContainerFormat.ts:
        return 'ts';
      case ContainerFormat.flv:
        return 'flv';
      case ContainerFormat.gif:
        return 'gif';
    }
  }

  bool get isAudioContainer {
    switch (this) {
      case ContainerFormat.mp3:
      case ContainerFormat.wav:
      case ContainerFormat.flac:
      case ContainerFormat.aac:
      case ContainerFormat.m4a:
      case ContainerFormat.ogg:
      case ContainerFormat.opus:
      case ContainerFormat.aiff:
      case ContainerFormat.wma:
        return true;
      default:
        return false;
    }
  }

  bool get isVideoContainer => !isAudioContainer;

  String get label {
    switch (this) {
      case ContainerFormat.mp3:
        return 'MP3';
      case ContainerFormat.wav:
        return 'WAV';
      case ContainerFormat.flac:
        return 'FLAC';
      case ContainerFormat.aac:
        return 'AAC';
      case ContainerFormat.m4a:
        return 'M4A';
      case ContainerFormat.ogg:
        return 'OGG';
      case ContainerFormat.opus:
        return 'OPUS';
      case ContainerFormat.aiff:
        return 'AIFF';
      case ContainerFormat.wma:
        return 'WMA';
      case ContainerFormat.mp4:
        return 'MP4';
      case ContainerFormat.mkv:
        return 'MKV';
      case ContainerFormat.avi:
        return 'AVI';
      case ContainerFormat.mov:
        return 'MOV';
      case ContainerFormat.webm:
        return 'WebM';
      case ContainerFormat.m4v:
        return 'M4V';
      case ContainerFormat.mpg:
        return 'MPEG';
      case ContainerFormat.ts:
        return 'TS';
      case ContainerFormat.flv:
        return 'FLV';
      case ContainerFormat.gif:
        return 'GIF';
    }
  }

  String get mimeType {
    switch (this) {
      case ContainerFormat.mp3:
        return 'audio/mpeg';
      case ContainerFormat.wav:
        return 'audio/x-wav';
      case ContainerFormat.flac:
        return 'audio/flac';
      case ContainerFormat.aac:
        return 'audio/aac';
      case ContainerFormat.m4a:
        return 'audio/mp4';
      case ContainerFormat.ogg:
        return 'audio/ogg';
      case ContainerFormat.opus:
        return 'audio/opus';
      case ContainerFormat.aiff:
        return 'audio/x-aiff';
      case ContainerFormat.wma:
        return 'audio/x-ms-wma';
      case ContainerFormat.mp4:
        return 'video/mp4';
      case ContainerFormat.mkv:
        return 'video/x-matroska';
      case ContainerFormat.avi:
        return 'video/x-msvideo';
      case ContainerFormat.mov:
        return 'video/quicktime';
      case ContainerFormat.webm:
        return 'video/webm';
      case ContainerFormat.m4v:
        return 'video/x-m4v';
      case ContainerFormat.mpg:
        return 'video/mpeg';
      case ContainerFormat.ts:
        return 'video/mp2t';
      case ContainerFormat.flv:
        return 'video/x-flv';
      case ContainerFormat.gif:
        return 'image/gif';
    }
  }

  ContainerFormat? get defaultPreset {
    // Most common in-app default targets.
    switch (this) {
      default:
        return this;
    }
  }
}

/// Video encoder choices.
enum VideoCodec {
  auto,
  copy,
  h264,
  hevc,
  av1,
  vp8,
  vp9,
  mpeg4,
  mpeg2video;

  static VideoCodec? fromIndex(int? index) {
    if (index == null) return null;
    final values = VideoCodec.values;
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }

  /// The ffmpeg `-c:v` value (excluding `auto`).
  String get ffmpegName {
    switch (this) {
      case VideoCodec.auto:
        return '';
      case VideoCodec.copy:
        return 'copy';
      case VideoCodec.h264:
        return 'libx264';
      case VideoCodec.hevc:
        return 'libx265';
      case VideoCodec.av1:
        return 'libaom-av1';
      case VideoCodec.vp8:
        return 'libvpx';
      case VideoCodec.vp9:
        return 'libvpx-vp9';
      case VideoCodec.mpeg4:
        return 'mpeg4';
      case VideoCodec.mpeg2video:
        return 'mpeg2video';
    }
  }

  String get label {
    switch (this) {
      case VideoCodec.auto:
        return 'Auto';
      case VideoCodec.copy:
        return 'Copy (no re-encode)';
      case VideoCodec.h264:
        return 'H.264 (libx264)';
      case VideoCodec.hevc:
        return 'H.265 / HEVC (libx265)';
      case VideoCodec.av1:
        return 'AV1 (libaom)';
      case VideoCodec.vp8:
        return 'VP8 (libvpx)';
      case VideoCodec.vp9:
        return 'VP9 (libvpx-vp9)';
      case VideoCodec.mpeg4:
        return 'MPEG-4 Part 2';
      case VideoCodec.mpeg2video:
        return 'MPEG-2';
    }
  }
}

/// Audio encoder choices.
enum AudioCodec {
  auto,
  copy,
  aac,
  mp3,
  ac3,
  flac,
  opus,
  vorbis,
  // ignore: constant_identifier_names
  pcm_s16le,
  wmapro;

  static AudioCodec? fromIndex(int? index) {
    if (index == null) return null;
    final values = AudioCodec.values;
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }

  String get ffmpegName {
    switch (this) {
      case AudioCodec.auto:
        return '';
      case AudioCodec.copy:
        return 'copy';
      case AudioCodec.aac:
        return 'aac';
      case AudioCodec.mp3:
        return 'libmp3lame';
      case AudioCodec.ac3:
        return 'ac3';
      case AudioCodec.flac:
        return 'flac';
      case AudioCodec.opus:
        return 'libopus';
      case AudioCodec.vorbis:
        return 'libvorbis';
      case AudioCodec.pcm_s16le:
        return 'pcm_s16le';
      case AudioCodec.wmapro:
        return 'wmav2';
    }
  }

  String get label {
    switch (this) {
      case AudioCodec.auto:
        return 'Auto';
      case AudioCodec.copy:
        return 'Copy (no re-encode)';
      case AudioCodec.aac:
        return 'AAC';
      case AudioCodec.mp3:
        return 'MP3 (lame)';
      case AudioCodec.ac3:
        return 'AC-3';
      case AudioCodec.flac:
        return 'FLAC';
      case AudioCodec.opus:
        return 'Opus';
      case AudioCodec.vorbis:
        return 'Vorbis';
      case AudioCodec.pcm_s16le:
        return 'PCM 16-bit';
      case AudioCodec.wmapro:
        return 'WMA';
    }
  }
}

/// Frame rate presets.
enum VideoFrameRate {
  auto,
  fps24,
  fps25,
  fps30,
  fps50,
  fps60;

  double? get value {
    switch (this) {
      case VideoFrameRate.auto:
        return null;
      case VideoFrameRate.fps24:
        return 24;
      case VideoFrameRate.fps25:
        return 25;
      case VideoFrameRate.fps30:
        return 30;
      case VideoFrameRate.fps50:
        return 50;
      case VideoFrameRate.fps60:
        return 60;
    }
  }

  String get label => value == null ? 'Source (auto)' : '${value!.round()} fps';

  static VideoFrameRate? fromIndex(int? index) {
    if (index == null) return null;
    final values = VideoFrameRate.values;
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}

/// Pixel format presets.
enum PixelFormat {
  auto,
  yuv420p,
  yuv420p10le,
  gbrp;

  String get ffmpegName {
    switch (this) {
      case PixelFormat.auto:
        return '';
      case PixelFormat.yuv420p:
        return 'yuv420p';
      case PixelFormat.yuv420p10le:
        return 'yuv420p10le';
      case PixelFormat.gbrp:
        return 'gbrp';
    }
  }

  String get label {
    switch (this) {
      case PixelFormat.auto:
        return 'Auto';
      case PixelFormat.yuv420p:
        return 'YUV420p (compatible)';
      case PixelFormat.yuv420p10le:
        return 'YUV420p10le (10-bit)';
      case PixelFormat.gbrp:
        return 'GBRP';
    }
  }

  static PixelFormat? fromIndex(int? index) {
    if (index == null) return null;
    final values = PixelFormat.values;
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}

/// Encoder speed/quality presets.
enum EncoderPreset {
  ultrafast,
  superfast,
  veryfast,
  faster,
  fast,
  medium,
  slow,
  slower,
  veryslow;

  String get value => name;

  String get label {
    switch (this) {
      case EncoderPreset.ultrafast:
        return 'Ultrafast';
      case EncoderPreset.superfast:
        return 'Superfast';
      case EncoderPreset.veryfast:
        return 'Veryfast';
      case EncoderPreset.faster:
        return 'Faster';
      case EncoderPreset.fast:
        return 'Fast';
      case EncoderPreset.medium:
        return 'Medium';
      case EncoderPreset.slow:
        return 'Slow';
      case EncoderPreset.slower:
        return 'Slower';
      case EncoderPreset.veryslow:
        return 'Veryslow';
    }
  }

  static EncoderPreset? fromIndex(int? index) {
    if (index == null) return null;
    final values = EncoderPreset.values;
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}

/// H.264/H.265 profile presets.
enum VideoProfile {
  auto,
  baseline,
  main,
  high;

  String get label {
    switch (this) {
      case VideoProfile.auto:
        return 'Auto';
      case VideoProfile.baseline:
        return 'Baseline';
      case VideoProfile.main:
        return 'Main';
      case VideoProfile.high:
        return 'High';
    }
  }

  static VideoProfile? fromIndex(int? index) {
    if (index == null) return null;
    final values = VideoProfile.values;
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}

/// Audio sample rate presets (Hz).
enum AudioSampleRate {
  auto,
  hz8000,
  hz22050,
  hz44100,
  hz48000,
  hz96000;

  int? get value {
    switch (this) {
      case AudioSampleRate.auto:
        return null;
      case AudioSampleRate.hz8000:
        return 8000;
      case AudioSampleRate.hz22050:
        return 22050;
      case AudioSampleRate.hz44100:
        return 44100;
      case AudioSampleRate.hz48000:
        return 48000;
      case AudioSampleRate.hz96000:
        return 96000;
    }
  }

  String get label => value == null ? 'Source (auto)' : '${value!} Hz';

  static AudioSampleRate? fromIndex(int? index) {
    if (index == null) return null;
    final values = AudioSampleRate.values;
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}

/// Audio channel presets.
enum AudioChannels {
  auto,
  mono,
  stereo,
  surround51;

  int? get value {
    switch (this) {
      case AudioChannels.auto:
        return null;
      case AudioChannels.mono:
        return 1;
      case AudioChannels.stereo:
        return 2;
      case AudioChannels.surround51:
        return 6;
    }
  }

  String get label {
    switch (this) {
      case AudioChannels.auto:
        return 'Source (auto)';
      case AudioChannels.mono:
        return 'Mono';
      case AudioChannels.stereo:
        return 'Stereo';
      case AudioChannels.surround51:
        return '5.1 Surround';
    }
  }

  static AudioChannels? fromIndex(int? index) {
    if (index == null) return null;
    final values = AudioChannels.values;
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}

/// Progressive snapshot of an in-flight conversion.
class ConversionProgress {
  const ConversionProgress({
    this.jobId,
    this.fraction = 0,
    this.timeMs = 0,
    this.speed = 0,
    this.sizeBytes = 0,
  });

  final String? jobId;

  /// 0.0 - 1.0 completion estimate derived from real FFmpeg statistics.
  final double fraction;

  /// Current elapsed media time in milliseconds (FFmpeg `out_time_ms`).
  final int timeMs;

  /// Current processing speed e.g. 2.5 = 2.5x realtime.
  final double speed;

  /// Bytes processed so far.
  final int sizeBytes;

  int get percent => (fraction.clamp(0, 1) * 100).round();

  ConversionProgress copyWith({
    double? fraction,
    int? timeMs,
    double? speed,
    int? sizeBytes,
  }) {
    return ConversionProgress(
      jobId: jobId,
      fraction: fraction ?? this.fraction,
      timeMs: timeMs ?? this.timeMs,
      speed: speed ?? this.speed,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}

/// Compression quality for lossy audio (0-9, higher = better quality).
const int kDefaultAudioQuality = 5;
const int kMinAudioQuality = 0;
const int kMaxAudioQuality = 9;

/// Safe indexed access for optional stored enum indexes.
extension Indexable<T> on List<T> {
  T? elementAtOrNull(int? index) {
    if (index == null || index < 0 || index >= length) return null;
    return this[index];
  }
}