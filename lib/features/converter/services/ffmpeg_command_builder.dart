import '../models/conversion_models.dart';
import '../models/conversion_settings.dart';
import 'ffmpeg_probe_service.dart';
import 'format_compatibility.dart';

/// Builds the full FFmpeg argument list from a [ConversionSettings] and the
/// probed source metadata. Pure logic — never calls the platform.
class FFmpegCommandBuilder {
  FFmpegCommandBuilder._();

  static final FFmpegCommandBuilder instance = FFmpegCommandBuilder._();

  /// Returns the ordered argument list for `-y -i <src> ... <out>`.
  List<String> build({
    required String sourcePath,
    required String outputPath,
    required MediaProbeInfo probe,
    required ConversionSettings settings,
  }) {
    final resolved = FormatCompatibility.resolve(
      settings.format,
      videoCodec: settings.videoCodec,
      audioCodec: settings.audioCodec,
      hasVideo: probe.hasVideo && !settings.videoMute,
      hasAudio: probe.hasAudio && !settings.audioMute,
    );

    final args = <String>[
      '-hide_banner',
      '-nostdin',
      '-loglevel', 'info',
      '-y',
    ];

    if (settings.format.isVideoContainer &&
        probe.hasVideo &&
        settings.hardwareMode == HardwareMode.hardware) {
      args.addAll(['-hwaccel', 'mediacodec']);
    }

    args.addAll(['-i', _readablePath(sourcePath)]);

    if (settings.audioMute || !probe.hasAudio) {
      args.add('-an');
    } else if (settings.format.isVideoContainer && probe.hasVideo) {
      args.addAll(['-map', '0:a:0']);
    }

    if (settings.videoMute || !probe.hasVideo) {
      args.add('-vn');
    } else if (settings.format.isVideoContainer) {
      // Keep only the video (and possibly audio) streams; drop subtitles.
      args.addAll(['-map', '0:v:0']);
      _appendVideoOptions(args, resolved.video, probe, settings);
    } else {
      // Audio-only containers must drop any video stream.
      args.add('-vn');
    }

    if (!settings.audioMute && probe.hasAudio) {
      _appendAudioOptions(args, resolved.audio, settings);
    }

    if (settings.format.isVideoContainer &&
        settings.faststart &&
        (settings.format == ContainerFormat.mp4 ||
            settings.format == ContainerFormat.m4v ||
            settings.format == ContainerFormat.mov)) {
      args.add('-movflags');
      args.add('+faststart');
    }

    if (settings.keepMetadata &&
        (settings.format.isVideoContainer || settings.format == ContainerFormat.m4a)) {
      args.add('-map_metadata');
      args.add('0');
    }

    args.add(_readablePath(outputPath));
    return args;
  }

  void _appendVideoOptions(
    List<String> args,
    VideoCodec videoCodec,
    MediaProbeInfo probe,
    ConversionSettings settings,
  ) {
    final useHardware =
        videoCodec == VideoCodec.h264 &&
        settings.hardwareMode == HardwareMode.hardware;

    if (videoCodec != VideoCodec.auto) {
      args.add('-c:v');
      args.add(useHardware ? 'h264_mediacodec' : videoCodec.ffmpegName);
    }

    if (settings.width != null || settings.height != null) {
      final w = settings.width ?? -2;
      final h = settings.height ?? -2;
      final extent = (settings.width != null && settings.height != null)
          ? 'force_original_aspect_ratio=decrease'
          : 'force_original_aspect_ratio=decrease';
      args.add('-vf');
      args.add('scale=$w:$h:$extent');
    } else if (settings.pixelFormat != PixelFormat.auto) {
      args.add('-pix_fmt');
      args.add(settings.pixelFormat.ffmpegName);
    }

    if (settings.frameRate != VideoFrameRate.auto && settings.frameRate.value != null) {
      args.add('-r');
      args.add(settings.frameRate.value!.toInt().toString());
    }

    if (settings.pixelFormat != PixelFormat.auto) {
      args.add('-pix_fmt');
      args.add(settings.pixelFormat.ffmpegName);
    }

    if (settings.videoCodec != VideoCodec.copy) {
      if ((videoCodec == VideoCodec.h264 || videoCodec == VideoCodec.hevc) &&
          settings.profile != VideoProfile.auto) {
        args.add('-profile:v');
        args.add(settings.profile.label.toLowerCase());
      }

      if ((videoCodec == VideoCodec.h264 ||
              videoCodec == VideoCodec.hevc) &&
          !useHardware) {
        args.add('-preset');
        args.add(settings.encoderPreset.value);
      }

      if (settings.videoBitrateKbps != null) {
        args.add('-b:v');
        args.add('${settings.videoBitrateKbps}k');
      } else if (settings.crf != null &&
          (videoCodec == VideoCodec.h264 ||
              videoCodec == VideoCodec.hevc ||
              videoCodec == VideoCodec.vp8 ||
              videoCodec == VideoCodec.vp9 ||
              videoCodec == VideoCodec.av1)) {
        args.add('-crf');
        args.add(settings.crf.toString());
      }
    }
  }

  void _appendAudioOptions(
    List<String> args,
    AudioCodec audioCodec,
    ConversionSettings settings,
  ) {
    if (audioCodec != AudioCodec.auto) {
      args.add('-c:a');
      args.add(audioCodec.ffmpegName);
    }

    final copy = audioCodec == AudioCodec.copy;
    if (!copy) {
      if (settings.audioBitrateKbps != null) {
        args.add('-b:a');
        args.add('${settings.audioBitrateKbps}k');
      }
      if (settings.audioSampleRate != AudioSampleRate.auto &&
          settings.audioSampleRate.value != null) {
        args.add('-ar');
        args.add(settings.audioSampleRate.value.toString());
      }
      if (settings.audioChannels != AudioChannels.auto &&
          settings.audioChannels.value != null) {
        args.add('-ac');
        args.add(settings.audioChannels.value.toString());
      }
      if (settings.audioQuality != null) {
        args.add('-q:a');
        args.add(settings.audioQuality.toString());
      }
      if (settings.volume != 1.0) {
        args.add('-af');
        args.add('volume=${settings.volume}');
      }
    }
  }

  static String _readablePath(String path) => path;
}