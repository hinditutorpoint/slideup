import 'dart:convert';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../models/conversion_models.dart';

/// Media information extracted via FFprobe, used for progress estimation
/// and smart codec defaults.
class MediaProbeInfo {
  const MediaProbeInfo({
    this.durationMs,
    this.videoCodec,
    this.audioCodec,
    this.width,
    this.height,
    this.bitrateKbps,
    this.sampleRate,
    this.channels,
    this.hasVideo = false,
    this.hasAudio = false,
  });

  final int? durationMs;
  final String? videoCodec;
  final String? audioCodec;
  final int? width;
  final int? height;
  final int? bitrateKbps;
  final int? sampleRate;
  final int? channels;
  final bool hasVideo;
  final bool hasAudio;

  bool get isVideoSource => hasVideo;
  bool get isAudioOnly => hasAudio && !hasVideo;

  ConversionMediaKind get kind =>
      hasVideo ? ConversionMediaKind.video : ConversionMediaKind.audio;

  ConversionMediaKind get effectiveKind =>
      kind == ConversionMediaKind.video
          ? ConversionMediaKind.video
          : ConversionMediaKind.audio;
}

/// Runs FFprobe against a local file and parses a compact summary.
class FFprobeService {
  FFprobeService._();

  static final FFprobeService instance = FFprobeService._();

  /// Probes a file path (or content:// uri). Returns `null` on failure.
  Future<MediaProbeInfo?> probe(String path) async {
    if (path.isEmpty) return null;
    try {
      final input = await _resolveReadPath(path);
      final session = await FFprobeKit.executeWithArguments([
        '-v', 'error',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        input,
      ]);
      final returnCode = await session.getReturnCode();
      final output = await session.getOutput();
      if (!ReturnCode.isSuccess(returnCode) ||
          output == null ||
          output.isEmpty) {
        return null;
      }
      final json = jsonDecodeFirst(output);
      final format = json['format'];
      final streams = json['streams'];

      int? durationMs;
      int? bitrate;
      String? videoCodec;
      String? audioCodec;
      int? width;
      int? height;
      int? sampleRate;
      int? channels;
      var hasVideo = false;
      var hasAudio = false;

      if (format is Map) {
        final duration = _num(format['duration']);
        if (duration != null) durationMs = (duration * 1000).round();
        final br = _num(format['bit_rate']);
        if (br != null) bitrate = (br / 1000).round();
      }

      if (streams is List) {
        for (final s in streams) {
          if (s is! Map) continue;
          final type = s['codec_type'];
          if (type == 'video' && !hasVideo) {
            hasVideo = true;
            videoCodec = s['codec_name'] as String?;
            width = _num(s['width'])?.round();
            height = _num(s['height'])?.round();
            if (bitrate == null) {
              final br = _num(s['bit_rate']);
              if (br != null) bitrate = (br / 1000).round();
            }
          } else if (type == 'audio' && !hasAudio) {
            hasAudio = true;
            audioCodec = s['codec_name'] as String?;
            sampleRate = _num(s['sample_rate'])?.round();
            channels = _num(s['channels'])?.round();
            if (bitrate == null) {
              final br = _num(s['bit_rate']);
              if (br != null) bitrate = (br / 1000).round();
            }
          }
        }
      }

      return MediaProbeInfo(
        durationMs: durationMs,
        videoCodec: videoCodec,
        audioCodec: audioCodec,
        width: width,
        height: height,
        bitrateKbps: bitrate,
        sampleRate: sampleRate,
        channels: channels,
        hasVideo: hasVideo,
        hasAudio: hasAudio,
      );
    } catch (e) {
      return null;
    }
  }

  /// Turns a `content://` uri into an ffmpeg-safe `saf://` parameter.
  static Future<String> _resolveReadPath(String path) async {
    if (path.startsWith('content://')) {
      final saf = await FFmpegKitConfig.getSafParameterForRead(path);
      if (saf != null && saf.isNotEmpty) return saf;
    }
    return path;
  }

  static Map<String, dynamic> jsonDecodeFirst(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        return Map<String, dynamic>.from(decoded.first as Map);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  static num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }
}