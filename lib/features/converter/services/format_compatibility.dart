import '../models/conversion_models.dart';
import '../models/conversion_settings.dart';

/// Rules that prevent invalid container/codec combinations.
///
/// Pure logic only — no platform APIs — so it is unit-testable.
class FormatCompatibility {
  FormatCompatibility._();

  static List<VideoCodec> allowedVideoCodecsFor(ContainerFormat format) {
    switch (format) {
      case ContainerFormat.mp4:
      case ContainerFormat.m4v:
        return const [
          VideoCodec.auto,
          VideoCodec.copy,
          VideoCodec.h264,
          VideoCodec.hevc,
          VideoCodec.av1,
          VideoCodec.mpeg4,
        ];
      case ContainerFormat.mkv:
        return const [
          VideoCodec.auto,
          VideoCodec.copy,
          VideoCodec.h264,
          VideoCodec.hevc,
          VideoCodec.av1,
          VideoCodec.vp8,
          VideoCodec.vp9,
          VideoCodec.mpeg4,
          VideoCodec.mpeg2video,
        ];
      case ContainerFormat.webm:
        return const [
          VideoCodec.auto,
          VideoCodec.copy,
          VideoCodec.vp8,
          VideoCodec.vp9,
          VideoCodec.av1,
        ];
      case ContainerFormat.avi:
        return const [
          VideoCodec.auto,
          VideoCodec.copy,
          VideoCodec.mpeg4,
          VideoCodec.mpeg2video,
          VideoCodec.h264,
        ];
      case ContainerFormat.mov:
        return const [
          VideoCodec.auto,
          VideoCodec.copy,
          VideoCodec.h264,
          VideoCodec.hevc,
          VideoCodec.mpeg4,
        ];
      case ContainerFormat.mpg:
        return const [
          VideoCodec.auto,
          VideoCodec.copy,
          VideoCodec.mpeg2video,
          VideoCodec.mpeg4,
        ];
      case ContainerFormat.ts:
        return const [
          VideoCodec.auto,
          VideoCodec.copy,
          VideoCodec.h264,
          VideoCodec.hevc,
        ];
      case ContainerFormat.flv:
        return const [
          VideoCodec.auto,
          VideoCodec.copy,
          VideoCodec.h264,
        ];
      case ContainerFormat.gif:
        return const [VideoCodec.copy];
      default:
        return const [];
    }
  }

  static List<AudioCodec> allowedAudioCodecsFor(ContainerFormat format) {
    switch (format) {
      case ContainerFormat.mp3:
        return const [AudioCodec.auto, AudioCodec.copy, AudioCodec.mp3];
      case ContainerFormat.wav:
        return const [
          AudioCodec.auto,
          AudioCodec.copy,
          AudioCodec.pcm_s16le,
        ];
      case ContainerFormat.flac:
        return const [AudioCodec.auto, AudioCodec.copy, AudioCodec.flac];
      case ContainerFormat.aac:
        return const [AudioCodec.auto, AudioCodec.copy, AudioCodec.aac];
      case ContainerFormat.m4a:
        return const [
          AudioCodec.auto,
          AudioCodec.copy,
          AudioCodec.aac,
          AudioCodec.ac3,
          AudioCodec.opus,
        ];
      case ContainerFormat.ogg:
        return const [
          AudioCodec.auto,
          AudioCodec.copy,
          AudioCodec.vorbis,
          AudioCodec.flac,
          AudioCodec.opus,
        ];
      case ContainerFormat.opus:
        return const [AudioCodec.auto, AudioCodec.copy, AudioCodec.opus];
      case ContainerFormat.aiff:
        return const [AudioCodec.auto, AudioCodec.copy, AudioCodec.pcm_s16le];
      case ContainerFormat.wma:
        return const [AudioCodec.auto, AudioCodec.copy, AudioCodec.wmapro];
      case ContainerFormat.mp4:
      case ContainerFormat.m4v:
      case ContainerFormat.mov:
        return const [
          AudioCodec.auto,
          AudioCodec.copy,
          AudioCodec.aac,
          AudioCodec.mp3,
          AudioCodec.ac3,
          AudioCodec.opus,
        ];
      case ContainerFormat.mkv:
        return const [
          AudioCodec.auto,
          AudioCodec.copy,
          AudioCodec.aac,
          AudioCodec.mp3,
          AudioCodec.ac3,
          AudioCodec.opus,
          AudioCodec.vorbis,
          AudioCodec.flac,
        ];
      case ContainerFormat.avi:
        return const [
          AudioCodec.auto,
          AudioCodec.copy,
          AudioCodec.mp3,
          AudioCodec.ac3,
          AudioCodec.pcm_s16le,
        ];
      case ContainerFormat.webm:
        return const [
          AudioCodec.auto,
          AudioCodec.copy,
          AudioCodec.vorbis,
          AudioCodec.opus,
        ];
      case ContainerFormat.mpg:
        return const [
          AudioCodec.auto,
          AudioCodec.copy,
          AudioCodec.mp3,
          AudioCodec.ac3,
        ];
      case ContainerFormat.ts:
        return const [
          AudioCodec.auto,
          AudioCodec.copy,
          AudioCodec.aac,
          AudioCodec.mp3,
          AudioCodec.ac3,
        ];
      case ContainerFormat.flv:
        return const [
          AudioCodec.auto,
          AudioCodec.copy,
          AudioCodec.mp3,
          AudioCodec.aac,
        ];
      case ContainerFormat.gif:
        return const [];
    }
  }

  static VideoCodec defaultVideoCodecFor(ContainerFormat format) {
    switch (format) {
      case ContainerFormat.webm:
        return VideoCodec.vp9;
      case ContainerFormat.avi:
        return VideoCodec.mpeg4;
      case ContainerFormat.mpg:
        return VideoCodec.mpeg2video;
      default:
        return VideoCodec.h264;
    }
  }

  static AudioCodec defaultAudioCodecFor(ContainerFormat format) {
    switch (format) {
      case ContainerFormat.mp3:
        return AudioCodec.mp3;
      case ContainerFormat.wav:
        return AudioCodec.pcm_s16le;
      case ContainerFormat.flac:
        return AudioCodec.flac;
      case ContainerFormat.aac:
        return AudioCodec.aac;
      case ContainerFormat.m4a:
        return AudioCodec.aac;
      case ContainerFormat.ogg:
        return AudioCodec.vorbis;
      case ContainerFormat.opus:
        return AudioCodec.opus;
      case ContainerFormat.aiff:
        return AudioCodec.pcm_s16le;
      case ContainerFormat.wma:
        return AudioCodec.wmapro;
      case ContainerFormat.webm:
        return AudioCodec.opus;
      case ContainerFormat.ts:
      case ContainerFormat.m4v:
      case ContainerFormat.mp4:
      case ContainerFormat.mov:
        return AudioCodec.aac;
      case ContainerFormat.avi:
      case ContainerFormat.mpg:
      case ContainerFormat.flv:
        return AudioCodec.mp3;
      case ContainerFormat.mkv:
        return AudioCodec.aac;
      case ContainerFormat.gif:
        return AudioCodec.auto;
    }
  }

  static bool isVideoCodecAllowed(ContainerFormat format, VideoCodec codec) {
    if (codec == VideoCodec.auto) return true;
    return allowedVideoCodecsFor(format).contains(codec);
  }

  static bool isAudioCodecAllowed(ContainerFormat format, AudioCodec codec) {
    if (codec == AudioCodec.auto) return true;
    return allowedAudioCodecsFor(format).contains(codec);
  }

  static bool isCombinationAllowed(
    ContainerFormat format, {
    VideoCodec? videoCodec,
    AudioCodec? audioCodec,
  }) {
    if (videoCodec != null && !isVideoCodecAllowed(format, videoCodec)) {
      return false;
    }
    if (audioCodec != null && !isAudioCodecAllowed(format, audioCodec)) {
      return false;
    }
    return true;
  }

  /// Resolves `auto` codecs into concrete encoders for a given container.
  static ResolvedCodecs resolve(
    ContainerFormat format, {
    VideoCodec videoCodec = VideoCodec.auto,
    AudioCodec audioCodec = AudioCodec.auto,
    bool hasVideo = false,
    bool hasAudio = true,
  }) {
    VideoCodec v = videoCodec;
    if (v == VideoCodec.auto && format.isVideoContainer && hasVideo) {
      v = defaultVideoCodecFor(format);
    }
    AudioCodec a = audioCodec;
    if (a == AudioCodec.auto && hasAudio) {
      a = defaultAudioCodecFor(format);
    }
    return ResolvedCodecs(video: v, audio: a);
  }

  /// Human readable problems with a settings combo; empty when valid.
  static List<String> validate(ConversionSettings settings) {
    final problems = <String>[];
    if (!isVideoCodecAllowed(settings.format, settings.videoCodec)) {
      problems.add(
        '${settings.videoCodec.label} is not supported in ${settings.format.label}',
      );
    }
    if (!isAudioCodecAllowed(settings.format, settings.audioCodec)) {
      problems.add(
        '${settings.audioCodec.label} is not supported in ${settings.format.label}',
      );
    }
    if (settings.videoCodec == VideoCodec.copy &&
        settings.format.isVideoContainer &&
        (settings.width != null ||
            settings.height != null ||
            settings.videoBitrateKbps != null ||
            settings.crf != null ||
            settings.frameRate != VideoFrameRate.auto)) {
      problems.add(
        'Video is set to "copy" but resize/bitrate/CRF options were provided.',
      );
    }
    return problems;
  }
}

class ResolvedCodecs {
  const ResolvedCodecs({required this.video, required this.audio});
  final VideoCodec video;
  final AudioCodec audio;
}