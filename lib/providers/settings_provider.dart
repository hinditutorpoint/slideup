import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppSettings {
  final bool videoPopupEnabled;
  final bool backgroundAudioEnabled;
  final bool autoPlayNext;
  final bool askResumeLastPosition;
  final bool recentHistoryEnabled;
  final bool showUpNextButton;
  final int upNextLeadSeconds;
  final bool swipeToSwitchEnabled;
  final String defaultVideoQuality;
  final String downloadLocation;
  final String? speechService;
  final bool isDefaultMediaPlayer;
  bool? errorDebuggingEnabled;

  AppSettings({
    this.videoPopupEnabled = false,
    this.backgroundAudioEnabled = true,
    this.autoPlayNext = true,
    this.askResumeLastPosition = false,
    this.recentHistoryEnabled = true,
    this.showUpNextButton = true,
    this.upNextLeadSeconds = 15,
    this.swipeToSwitchEnabled = true,
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
    bool? askResumeLastPosition,
    bool? recentHistoryEnabled,
    bool? showUpNextButton,
    int? upNextLeadSeconds,
    bool? swipeToSwitchEnabled,
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
      askResumeLastPosition:
          askResumeLastPosition ?? this.askResumeLastPosition,
      recentHistoryEnabled: recentHistoryEnabled ?? this.recentHistoryEnabled,
      showUpNextButton: showUpNextButton ?? this.showUpNextButton,
      upNextLeadSeconds: upNextLeadSeconds ?? this.upNextLeadSeconds,
      swipeToSwitchEnabled:
          swipeToSwitchEnabled ?? this.swipeToSwitchEnabled,
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
        askResumeLastPosition: _settingsBox.get(
          'askResumeLastPosition',
          defaultValue: false,
        ),
        recentHistoryEnabled: _settingsBox.get(
          'recentHistoryEnabled',
          defaultValue: true,
        ),
        showUpNextButton: _settingsBox.get(
          'showUpNextButton',
          defaultValue: true,
        ),
        upNextLeadSeconds: _settingsBox.get(
          'upNextLeadSeconds',
          defaultValue: 15,
        ),
        swipeToSwitchEnabled: _settingsBox.get(
          'swipeToSwitchEnabled',
          defaultValue: true,
        ),
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

  Future<void> setAskResumeLastPosition(bool enabled) async {
    await _ensureInitialized();
    await _settingsBox.put('askResumeLastPosition', enabled);
    state = state.copyWith(askResumeLastPosition: enabled);
  }

  Future<void> setRecentHistoryEnabled(bool enabled) async {
    await _ensureInitialized();
    await _settingsBox.put('recentHistoryEnabled', enabled);
    state = state.copyWith(recentHistoryEnabled: enabled);
  }

  Future<void> setShowUpNextButton(bool enabled) async {
    await _ensureInitialized();
    await _settingsBox.put('showUpNextButton', enabled);
    state = state.copyWith(showUpNextButton: enabled);
  }

  Future<void> setUpNextLeadSeconds(int seconds) async {
    await _ensureInitialized();
    await _settingsBox.put('upNextLeadSeconds', seconds);
    state = state.copyWith(upNextLeadSeconds: seconds);
  }

  Future<void> setSwipeToSwitchEnabled(bool enabled) async {
    await _ensureInitialized();
    await _settingsBox.put('swipeToSwitchEnabled', enabled);
    state = state.copyWith(swipeToSwitchEnabled: enabled);
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
