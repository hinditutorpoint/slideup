import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slideup/features/converter/models/conversion_models.dart';
import 'package:slideup/features/converter/models/conversion_settings.dart';
import 'package:slideup/features/converter/services/ffmpeg_command_builder.dart';
import 'package:slideup/features/converter/services/ffmpeg_probe_service.dart';
import 'package:slideup/features/converter/services/format_compatibility.dart';
import 'package:slideup/features/converter/services/output_naming.dart';

void main() {
  group('OutputNaming', () {
    test('basename strips the last extension only', () {
      expect(OutputNaming.basename('movie.mkv'), 'movie');
      expect(OutputNaming.basename('my.video.mov'), 'my.video');
      expect(OutputNaming.basename('no_ext'), 'no_ext');
      expect(OutputNaming.basename(''), 'output');
    });

    test('outputFileName replaces the extension, never appends', () {
      expect(
        OutputNaming.outputFileName('movie.mkv', ContainerFormat.mp4),
        'movie.mp4',
      );
      expect(
        OutputNaming.outputFileName('song.flac', ContainerFormat.mp3),
        'song.mp3',
      );
      expect(
        OutputNaming.outputFileName('clip.mov', ContainerFormat.mkv),
        'clip.mkv',
      );
    });

    test('uniqueFilePath produces (1), (2) suffixes when taken', () {
      final dir = Directory.systemTemp.createTempSync('conv_out');
      expect(
        OutputNaming.uniqueFilePath(dir.path, 'movie.mp4'),
        '${dir.path}${Platform.pathSeparator}movie.mp4',
      );
      File('${dir.path}${Platform.pathSeparator}movie.mp4')
          .writeAsStringSync('x');
      expect(
        OutputNaming.uniqueFilePath(dir.path, 'movie.mp4'),
        '${dir.path}${Platform.pathSeparator}movie (1).mp4',
      );
      File('${dir.path}${Platform.pathSeparator}movie (1).mp4')
          .writeAsStringSync('x');
      expect(
        OutputNaming.uniqueFilePath(dir.path, 'movie.mp4'),
        '${dir.path}${Platform.pathSeparator}movie (2).mp4',
      );
      dir.deleteSync(recursive: true);
    });

    test('validateFileName rejects dangerous names', () {
      expect(OutputNaming.validateFileName(''), isNotNull);
      expect(OutputNaming.validateFileName('   '), isNotNull);
      expect(OutputNaming.validateFileName('..'), isNotNull);
      expect(OutputNaming.validateFileName('a/b.mp4'), isNotNull);
      expect(OutputNaming.validateFileName('a\\b.mp4'), isNotNull);
      expect(OutputNaming.validateFileName('a..b.mp4'), isNotNull);
      expect(OutputNaming.validateFileName('-x.mp4'), isNotNull);
      expect(OutputNaming.validateFileName('movie.mp3.mp4'), isNotNull);
      expect(OutputNaming.validateFileName('safe_name.mp4'), isNull);
    });

    test('wouldOverwriteSource detects the exact same file', () {
      expect(
        OutputNaming.wouldOverwriteSource('/a/movie.mp4', '/a/movie.mp4'),
        isTrue,
      );
      expect(
        OutputNaming.wouldOverwriteSource('/a/movie.mp4', '/a/movie.mp4_'),
        isFalse,
      );
    });
  });

  group('FormatCompatibility', () {
    test('MP4 accepts common video codecs but not VP9', () {
      expect(
        FormatCompatibility.isVideoCodecAllowed(
          ContainerFormat.mp4,
          VideoCodec.hevc,
        ),
        isTrue,
      );
      expect(
        FormatCompatibility.isVideoCodecAllowed(
          ContainerFormat.mp4,
          VideoCodec.mpeg4,
        ),
        isTrue,
      );
      expect(
        FormatCompatibility.isVideoCodecAllowed(
          ContainerFormat.mp4,
          VideoCodec.vp9,
        ),
        isFalse,
      );
    });

    test('WebM restricts video to VP8/VP9/AV1', () {
      for (final codec in [VideoCodec.vp8, VideoCodec.vp9, VideoCodec.av1]) {
        expect(
          FormatCompatibility.isVideoCodecAllowed(ContainerFormat.webm, codec),
          isTrue,
          reason: codec.name,
        );
      }
      expect(
        FormatCompatibility.isVideoCodecAllowed(
          ContainerFormat.webm,
          VideoCodec.hevc,
        ),
        isFalse,
      );
    });

    test('MP3 audio container only allows MP3 audio', () {
      expect(
        FormatCompatibility.isAudioCodecAllowed(
          ContainerFormat.mp3,
          AudioCodec.mp3,
        ),
        isTrue,
      );
      expect(
        FormatCompatibility.isAudioCodecAllowed(
          ContainerFormat.mp3,
          AudioCodec.flac,
        ),
        isFalse,
      );
    });

    test('resolve picks format-appropriate default encoders', () {
      final mp4 = FormatCompatibility.resolve(
        ContainerFormat.mp4,
        hasVideo: true,
        hasAudio: true,
      );
      expect(mp4.video, VideoCodec.h264);
      expect(mp4.audio, AudioCodec.aac);

      final webm = FormatCompatibility.resolve(
        ContainerFormat.webm,
        hasVideo: true,
      );
      expect(webm.video, VideoCodec.vp9);
      expect(webm.audio, AudioCodec.opus);

      final mp3 = FormatCompatibility.resolve(ContainerFormat.mp3);
      expect(mp3.audio, AudioCodec.mp3);
    });

    test('validate flags copy + resize/bitrate conflicts', () {
      final bad = const ConversionSettings(
        format: ContainerFormat.mp4,
        videoCodec: VideoCodec.copy,
        width: 1280,
      );
      expect(FormatCompatibility.validate(bad), isNotEmpty);

      final ok = const ConversionSettings(
        format: ContainerFormat.mp4,
        videoCodec: VideoCodec.h264,
        width: 1280,
      );
      expect(FormatCompatibility.validate(ok), isEmpty);
    });
  });

  group('FFmpegCommandBuilder', () {
    const settings = ConversionSettings();

    MediaProbeInfo probe({
      bool hasVideo = false,
      bool hasAudio = true,
      int? durationMs,
    }) {
      return MediaProbeInfo(
        hasVideo: hasVideo,
        hasAudio: hasAudio,
        durationMs: durationMs,
      );
    }

    test('audio -> audio drops video and maps nothing but encodes audio',
        () {
      final args = FFmpegCommandBuilder.instance.build(
        sourcePath: '/src/song.flac',
        outputPath: '/out/song.mp3',
        probe: probe(),
        settings: const ConversionSettings(
          format: ContainerFormat.mp3,
          audioCodec: AudioCodec.mp3,
        ),
      );
      expect(args, contains('-vn'));
      expect(args, isNot(contains('-map')));
      expect(args, contains('libmp3lame'));
      expect(args.last, '/out/song.mp3');
    });

    test('video -> video maps both streams and uses libx264 + faststart', () {
      final args = FFmpegCommandBuilder.instance.build(
        sourcePath: '/src/movie.mkv',
        outputPath: '/out/movie.mp4',
        probe: probe(hasVideo: true),
        settings: const ConversionSettings(
          format: ContainerFormat.mp4,
          videoCodec: VideoCodec.h264,
          faststart: true,
        ),
      );
      expect(args, contains('0:v:0'));
      expect(args, contains('0:a:0'));
      expect(args, contains('libx264'));
      expect(args, contains('-movflags'));
      expect(args, contains('+faststart'));
      expect(args[args.indexOf('-i') + 1], '/src/movie.mkv');
      expect(args.last, '/out/movie.mp4');
      expect(args, isNot(contains('-vn')));
    });

    test('adds scale filter when resizing', () {
      final args = FFmpegCommandBuilder.instance.build(
        sourcePath: '/src/clip.mp4',
        outputPath: '/out/clip.webm',
        probe: probe(hasVideo: true),
        settings: const ConversionSettings(
          format: ContainerFormat.webm,
          videoCodec: VideoCodec.vp9,
          width: 1280,
          height: 720,
        ),
      );
      final vf = args[args.indexOf('-vf') + 1];
      expect(vf, contains('scale=1280:720'));
      expect(args, contains('libvpx-vp9'));
    });

    test('uses hwaccel mediacodec only in hardware mode', () {
      final hw = FFmpegCommandBuilder.instance.build(
        sourcePath: '/src/a.mp4',
        outputPath: '/out/b.mp4',
        probe: probe(hasVideo: true),
        settings: const ConversionSettings(
          hardwareMode: HardwareMode.hardware,
          videoCodec: VideoCodec.h264,
        ),
      );
      expect(hw, contains('-hwaccel'));
      expect(hw, contains('h264_mediacodec'));

      final cpu = FFmpegCommandBuilder.instance.build(
        sourcePath: '/src/a.mp4',
        outputPath: '/out/b.mp4',
        probe: probe(hasVideo: true),
        settings: const ConversionSettings(
          hardwareMode: HardwareMode.cpu,
          videoCodec: VideoCodec.h264,
        ),
      );
      expect(cpu, isNot(contains('-hwaccel')));
      expect(cpu, contains('libx264'));
    });

    test('keeps subtitle-free mapping: no extra stream selection', () {
      final args = FFmpegCommandBuilder.instance.build(
        sourcePath: '/src/movie.mkv',
        outputPath: '/out/movie.mp4',
        probe: probe(hasVideo: true),
        settings: settings.copyWith(format: ContainerFormat.mp4),
      );
      expect(args, isNot(contains('0:s:0')));
    });

    test('volume filter appended when not 1.0', () {
      final args = FFmpegCommandBuilder.instance.build(
        sourcePath: '/src/song.flac',
        outputPath: '/out/song.m4a',
        probe: probe(),
        settings: const ConversionSettings(
          format: ContainerFormat.m4a,
          volume: 0.5,
        ),
      );
      final af = args[args.indexOf('-af') + 1];
      expect(af, 'volume=0.5');
    });

    test('trim adds -ss and -to after the input', () {
      final args = FFmpegCommandBuilder.instance.build(
        sourcePath: '/src/song.flac',
        outputPath: '/out/song.mp3',
        probe: probe(),
        settings: const ConversionSettings(
          format: ContainerFormat.mp3,
          audioCodec: AudioCodec.mp3,
          trimStart: Duration(minutes: 1, seconds: 5),
          trimEnd: Duration(minutes: 2, seconds: 30),
        ),
      );
      final inputIndex = args.indexOf('-i');
      expect(args[args.indexOf('-ss') + 1], '00:01:05');
      expect(args[args.indexOf('-to') + 1], '00:02:30');
      expect(args.indexOf('-ss'), greaterThan(inputIndex));
      expect(args.indexOf('-to'), greaterThan(inputIndex));
    });

    test('trim omits -to when end is not after start', () {
      final args = FFmpegCommandBuilder.instance.build(
        sourcePath: '/src/song.flac',
        outputPath: '/out/song.mp3',
        probe: probe(),
        settings: const ConversionSettings(
          format: ContainerFormat.mp3,
          audioCodec: AudioCodec.mp3,
          trimStart: Duration(seconds: 30),
          trimEnd: Duration(seconds: 10),
        ),
      );
      expect(args, contains('-ss'));
      expect(args, isNot(contains('-to')));
    });
  });
}