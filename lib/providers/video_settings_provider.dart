import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/video_settings.dart';
import '../services/settings_service.dart';

class VideoSettingsNotifier extends Notifier<VideoSettings> {
  @override
  VideoSettings build() {
    // ✅ CRITICAL FIX: Initialize with default, load async separately
    // This ensures the provider always returns a valid state immediately
    _loadSettingsAsync();
    return const VideoSettings();
  }

  // ✅ Load settings asynchronously without blocking build()
  void _loadSettingsAsync() {
    SettingsService.instance
        .loadSettings()
        .then((settings) {
          if (mounted) {
            state = settings;
          }
        })
        .catchError((e) {
          debugPrintStack(label: '❌ Error loading video settings: $e');
        });
  }

  bool get mounted => true; // Notifier is always mounted during load

  Future<void> updateSettings(VideoSettings settings) async {
    state = settings;
    await SettingsService.instance.saveSettings(settings);
  }

  void setBrightness(double value) {
    updateSettings(state.copyWith(brightness: value));
  }

  void setContrast(double value) {
    updateSettings(state.copyWith(contrast: value));
  }

  void setSaturation(double value) {
    updateSettings(state.copyWith(saturation: value));
  }

  void setHue(double value) {
    updateSettings(state.copyWith(hue: value));
  }

  void toggleHardwareDecoder() {
    updateSettings(state.copyWith(hardwareDecoder: !state.hardwareDecoder));
  }

  void togglePip() {
    updateSettings(state.copyWith(pipEnabled: !state.pipEnabled));
  }

  void setSpeed(PlaybackSpeed speed) {
    updateSettings(state.copyWith(speed: speed));
  }

  void toggleSubtitles() {
    updateSettings(state.copyWith(subtitlesEnabled: !state.subtitlesEnabled));
  }
}

final videoSettingsProvider =
    NotifierProvider<VideoSettingsNotifier, VideoSettings>(
      () => VideoSettingsNotifier(),
    );
