import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slideup/features/converter/models/conversion_job.dart';
import 'package:slideup/features/converter/models/conversion_models.dart';
import 'package:slideup/features/converter/models/conversion_settings.dart';
import 'package:slideup/features/converter/models/converter_preferences.dart';
import 'package:slideup/features/converter/models/converter_preset.dart';

void main() {
  group('ConversionSettings JSON round-trip', () {
    test('preserves every option', () {
      final original = const ConversionSettings(
        format: ContainerFormat.mkv,
        videoCodec: VideoCodec.hevc,
        audioCodec: AudioCodec.flac,
        width: 1920,
        height: 1080,
        frameRate: VideoFrameRate.fps30,
        pixelFormat: PixelFormat.yuv420p,
        encoderPreset: EncoderPreset.veryfast,
        profile: VideoProfile.main,
        videoBitrateKbps: 5000,
        audioBitrateKbps: 320,
        crf: 24,
        audioSampleRate: AudioSampleRate.hz44100,
        audioChannels: AudioChannels.stereo,
        audioQuality: 6,
        volume: 0.8,
        faststart: true,
        keepMetadata: false,
        audioMute: true,
        videoMute: false,
        hardwareMode: HardwareMode.cpu,
        outputLocation: OutputLocation.sameFolder,
        selectedFolderPath: '/storage/emulated/0/Movies',
        duplicateStrategy: DuplicateStrategy.replace,
      );

      final restored = ConversionSettings.fromJson(original.toJson());
      expect(restored.format, original.format);
      expect(restored.videoCodec, original.videoCodec);
      expect(restored.audioCodec, original.audioCodec);
      expect(restored.width, original.width);
      expect(restored.height, original.height);
      expect(restored.frameRate, original.frameRate);
      expect(restored.pixelFormat, original.pixelFormat);
      expect(restored.encoderPreset, original.encoderPreset);
      expect(restored.profile, original.profile);
      expect(restored.videoBitrateKbps, original.videoBitrateKbps);
      expect(restored.audioBitrateKbps, original.audioBitrateKbps);
      expect(restored.crf, original.crf);
      expect(restored.audioSampleRate, original.audioSampleRate);
      expect(restored.audioChannels, original.audioChannels);
      expect(restored.audioQuality, original.audioQuality);
      expect(restored.volume, original.volume);
      expect(restored.faststart, original.faststart);
      expect(restored.keepMetadata, original.keepMetadata);
      expect(restored.audioMute, original.audioMute);
      expect(restored.videoMute, original.videoMute);
      expect(restored.hardwareMode, original.hardwareMode);
      expect(restored.outputLocation, original.outputLocation);
      expect(restored.selectedFolderPath, original.selectedFolderPath);
      expect(restored.duplicateStrategy, original.duplicateStrategy);
    });

    test('defaults used for missing/invalid fields', () {
      final restored = ConversionSettings.fromJson(const {});
      expect(restored.format, ContainerFormat.mp4);
      expect(restored.videoCodec, VideoCodec.auto);
      expect(restored.audioCodec, AudioCodec.auto);
      expect(restored.volume, 1.0);
      expect(restored.duplicateStrategy, DuplicateStrategy.rename);
    });
  });

  group('ConverterPreferences JSON round-trip', () {
    test('preserves every option', () {
      const original = ConverterPreferences(
        defaultPresetId: 'system_mp4_1080p',
        outputLocation: OutputLocation.sameFolder,
        maxSimultaneous: 2,
        duplicateStrategy: DuplicateStrategy.skip,
        keepHistory: false,
        autoOpenOutput: true,
        notificationsEnabled: false,
        backgroundConversion: false,
        hardwareMode: HardwareMode.hardware,
        keepAwake: true,
      );

      final restored = ConverterPreferences.fromJson(original.toJson());
      expect(restored.defaultPresetId, original.defaultPresetId);
      expect(restored.outputLocation, original.outputLocation);
      expect(restored.maxSimultaneous, original.maxSimultaneous);
      expect(restored.duplicateStrategy, original.duplicateStrategy);
      expect(restored.keepHistory, original.keepHistory);
      expect(restored.autoOpenOutput, original.autoOpenOutput);
      expect(restored.notificationsEnabled, original.notificationsEnabled);
      expect(restored.backgroundConversion, original.backgroundConversion);
      expect(restored.hardwareMode, original.hardwareMode);
      expect(restored.keepAwake, original.keepAwake);
    });

    test('copyWith clearDefaultPreset nulls the id', () {
      const original = ConverterPreferences(defaultPresetId: 'abc');
      final cleared = original.copyWith(clearDefaultPreset: true);
      expect(cleared.defaultPresetId, isNull);
    });
  });

  group('ConverterPreset JSON round-trip', () {
    test('preserves name, system flag and settings', () {
      final original = ConverterPreset(
        id: 'custom_1',
        name: 'My preset',
        isSystem: false,
        isDefault: true,
        settings: const ConversionSettings(
          format: ContainerFormat.mp3,
          audioBitrateKbps: 192,
        ),
        createdAt: DateTime(2026, 1, 1),
        description: 'A test preset',
      );

      final restored = ConverterPreset.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.isSystem, original.isSystem);
      expect(restored.isDefault, original.isDefault);
      expect(restored.description, original.description);
      expect(restored.settings.format, ContainerFormat.mp3);
      expect(restored.settings.audioBitrateKbps, 192);
    });

    test('handles missing/default fields', () {
      final restored = ConverterPreset.fromJson(const {'id': 'x'});
      expect(restored.name, 'Preset');
      expect(restored.isSystem, isFalse);
      expect(restored.settings.format, ContainerFormat.mp4);
    });
  });

  group('ConversionJob JSON round-trip', () {
    test('preserves all fields including nested settingsJson', () {
      final original = ConversionJob(
        id: 'job1',
        sourcePath: '/src/movie.mkv',
        sourceName: 'movie.mkv',
        outputPath: '/out/movie.mp4',
        settings: const ConversionSettings(
          format: ContainerFormat.mp4,
          videoCodec: VideoCodec.h264,
        ),
        status: ConversionStatus.processing,
        progress: 42,
        durationMs: 120000,
        errorMessage: null,
        ffmpegLog: 'log-line\nsecond',
        notificationId: 6001,
        queuedAt: DateTime(2026, 1, 1, 10, 0),
        startedAt: DateTime(2026, 1, 1, 10, 1),
        completedAt: DateTime(2026, 1, 1, 10, 2),
        outputSize: 123456,
      );

      final map = original.toJson();
      expect(map['settingsJson'], isA<String>());
      final decodedSettings =
          jsonDecode(map['settingsJson'] as String) as Map<String, dynamic>;
      expect(decodedSettings['format'], ContainerFormat.mp4.index);

      final restored = ConversionJob.fromJson(map);
      expect(restored.id, original.id);
      expect(restored.sourcePath, original.sourcePath);
      expect(restored.outputPath, original.outputPath);
      expect(restored.settings.format, ContainerFormat.mp4);
      expect(restored.settings.videoCodec, VideoCodec.h264);
      expect(restored.status, ConversionStatus.processing);
      expect(restored.progress, 42);
      expect(restored.durationMs, 120000);
      expect(restored.ffmpegLog, 'log-line\nsecond');
      expect(restored.notificationId, 6001);
      expect(restored.startedAt, DateTime(2026, 1, 1, 10, 1));
      expect(restored.completedAt, DateTime(2026, 1, 1, 10, 2));
      expect(restored.outputSize, 123456);
    });

    test('recovers from malformed settings without throwing', () {
      final jsonMap = {
        'id': 'j',
        'settingsJson': '{ not json',
        'status': 999,
        'queuedAt': 'not-a-date',
      };
      final restored = ConversionJob.fromJson(jsonMap);
      expect(restored.settings.format, ContainerFormat.mp4);
      expect(restored.status, ConversionStatus.pending);
    });
  });
}