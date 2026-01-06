import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppSettings {
  final bool videoPopupEnabled;
  final bool backgroundAudioEnabled;
  final bool autoPlayNext;
  final String defaultVideoQuality;
  final String downloadLocation;
  final String? speechService;
  final bool isDefaultMediaPlayer;
  bool? errorDebuggingEnabled;

  AppSettings({
    this.videoPopupEnabled = false,
    this.backgroundAudioEnabled = true,
    this.autoPlayNext = true,
    this.defaultVideoQuality = 'Auto',
    this.downloadLocation = '/storage/emulated/0/Download',
    this.speechService,
    this.isDefaultMediaPlayer = false,
    this.errorDebuggingEnabled = false,
  });

  AppSettings copyWith({
    bool? videoPopupEnabled,
    bool? backgroundAudioEnabled,
    bool? autoPlayNext,
    String? defaultVideoQuality,
    String? downloadLocation,
    String? speechService,
    bool? isDefaultMediaPlayer,
    bool? errorDebuggingEnabled,
  }) {
    return AppSettings(
      videoPopupEnabled: videoPopupEnabled ?? this.videoPopupEnabled,
      backgroundAudioEnabled:
          backgroundAudioEnabled ?? this.backgroundAudioEnabled,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      defaultVideoQuality: defaultVideoQuality ?? this.defaultVideoQuality,
      downloadLocation: downloadLocation ?? this.downloadLocation,
      speechService: speechService ?? this.speechService,
      isDefaultMediaPlayer: isDefaultMediaPlayer ?? this.isDefaultMediaPlayer,
      errorDebuggingEnabled:
          errorDebuggingEnabled ?? this.errorDebuggingEnabled,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  late Box _settingsBox;
  bool _isInitialized = false;

  @override
  AppSettings build() {
    _init();
    return AppSettings();
  }

  Future<void> _init() async {
    if (_isInitialized) return;

    try {
      _settingsBox = await Hive.openBox('settings');

      state = AppSettings(
        videoPopupEnabled: _settingsBox.get(
          'videoPopupEnabled',
          defaultValue: false,
        ),
        backgroundAudioEnabled: _settingsBox.get(
          'backgroundAudioEnabled',
          defaultValue: true,
        ),
        autoPlayNext: _settingsBox.get('autoPlayNext', defaultValue: true),
        errorDebuggingEnabled: _settingsBox.get(
          'errorDebuggingEnabled',
          defaultValue: false,
        ),
        defaultVideoQuality: _settingsBox.get(
          'defaultVideoQuality',
          defaultValue: 'Auto',
        ),
        downloadLocation: _settingsBox.get(
          'downloadLocation',
          defaultValue: '/storage/emulated/0/Download',
        ),
        speechService: _settingsBox.get('speechService'),
        isDefaultMediaPlayer: _settingsBox.get(
          'isDefaultMediaPlayer',
          defaultValue: false,
        ),
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing settings: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _init();
    }
  }

  Future<void> setVideoPopupEnabled(bool enabled) async {
    await _ensureInitialized();
    await _settingsBox.put('videoPopupEnabled', enabled);
    state = state.copyWith(videoPopupEnabled: enabled);
  }

  Future<void> setBackgroundAudioEnabled(bool enabled) async {
    await _ensureInitialized();
    await _settingsBox.put('backgroundAudioEnabled', enabled);
    state = state.copyWith(backgroundAudioEnabled: enabled);
  }

  Future<void> setAutoPlayNext(bool enabled) async {
    await _ensureInitialized();
    await _settingsBox.put('autoPlayNext', enabled);
    state = state.copyWith(autoPlayNext: enabled);
  }

  Future<void> setErrorDebuggingEnabled(bool enabled) async {
    await _ensureInitialized();
    await _settingsBox.put('errorDebuggingEnabled', enabled);
    state = state.copyWith(errorDebuggingEnabled: enabled);
  }

  Future<void> setVideoQuality(String quality) async {
    await _ensureInitialized();
    await _settingsBox.put('defaultVideoQuality', quality);
    state = state.copyWith(defaultVideoQuality: quality);
  }

  Future<void> setDownloadLocation(String location) async {
    await _ensureInitialized();
    await _settingsBox.put('downloadLocation', location);
    state = state.copyWith(downloadLocation: location);
  }

  Future<void> setAsDefaultPlayer(bool isDefault) async {
    await _ensureInitialized();
    await _settingsBox.put('isDefaultMediaPlayer', isDefault);
    state = state.copyWith(isDefaultMediaPlayer: isDefault);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
