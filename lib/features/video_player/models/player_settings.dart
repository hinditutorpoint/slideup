import 'package:flutter/foundation.dart';

@immutable
class PlayerSettings {
  final double defaultSpeed;
  final double defaultVolume;
  final double defaultBrightness;
  final bool rememberPosition;
  final bool autoPlay;
  final bool loopPlaylist;
  final bool shufflePlaylist;
  final int seekDuration; // seconds
  final int doubleTapSeekDuration;
  final bool enableGestures;
  final bool enableHapticFeedback;
  final bool enablePiP;
  final bool enableBackgroundAudio;
  final bool enableLockScreenControls;
  final String preferredQuality;
  final String preferredAudioLanguage;
  final String preferredSubtitleLanguage;
  final bool showSubtitlesByDefault;
  final double subtitleFontSize;
  final String subtitleFontColor;
  final String subtitleBackgroundColor;

  const PlayerSettings({
    this.defaultSpeed = 1.0,
    this.defaultVolume = 1.0,
    this.defaultBrightness = 0.5,
    this.rememberPosition = true,
    this.autoPlay = true,
    this.loopPlaylist = false,
    this.shufflePlaylist = false,
    this.seekDuration = 10,
    this.doubleTapSeekDuration = 10,
    this.enableGestures = true,
    this.enableHapticFeedback = true,
    this.enablePiP = true,
    this.enableBackgroundAudio = true,
    this.enableLockScreenControls = true,
    this.preferredQuality = 'auto',
    this.preferredAudioLanguage = 'en',
    this.preferredSubtitleLanguage = 'en',
    this.showSubtitlesByDefault = false,
    this.subtitleFontSize = 16.0,
    this.subtitleFontColor = '#FFFFFF',
    this.subtitleBackgroundColor = '#80000000',
  });

  PlayerSettings copyWith({
    double? defaultSpeed,
    double? defaultVolume,
    double? defaultBrightness,
    bool? rememberPosition,
    bool? autoPlay,
    bool? loopPlaylist,
    bool? shufflePlaylist,
    int? seekDuration,
    int? doubleTapSeekDuration,
    bool? enableGestures,
    bool? enableHapticFeedback,
    bool? enablePiP,
    bool? enableBackgroundAudio,
    bool? enableLockScreenControls,
    String? preferredQuality,
    String? preferredAudioLanguage,
    String? preferredSubtitleLanguage,
    bool? showSubtitlesByDefault,
    double? subtitleFontSize,
    String? subtitleFontColor,
    String? subtitleBackgroundColor,
  }) {
    return PlayerSettings(
      defaultSpeed: defaultSpeed ?? this.defaultSpeed,
      defaultVolume: defaultVolume ?? this.defaultVolume,
      defaultBrightness: defaultBrightness ?? this.defaultBrightness,
      rememberPosition: rememberPosition ?? this.rememberPosition,
      autoPlay: autoPlay ?? this.autoPlay,
      loopPlaylist: loopPlaylist ?? this.loopPlaylist,
      shufflePlaylist: shufflePlaylist ?? this.shufflePlaylist,
      seekDuration: seekDuration ?? this.seekDuration,
      doubleTapSeekDuration:
          doubleTapSeekDuration ?? this.doubleTapSeekDuration,
      enableGestures: enableGestures ?? this.enableGestures,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      enablePiP: enablePiP ?? this.enablePiP,
      enableBackgroundAudio:
          enableBackgroundAudio ?? this.enableBackgroundAudio,
      enableLockScreenControls:
          enableLockScreenControls ?? this.enableLockScreenControls,
      preferredQuality: preferredQuality ?? this.preferredQuality,
      preferredAudioLanguage:
          preferredAudioLanguage ?? this.preferredAudioLanguage,
      preferredSubtitleLanguage:
          preferredSubtitleLanguage ?? this.preferredSubtitleLanguage,
      showSubtitlesByDefault:
          showSubtitlesByDefault ?? this.showSubtitlesByDefault,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      subtitleFontColor: subtitleFontColor ?? this.subtitleFontColor,
      subtitleBackgroundColor:
          subtitleBackgroundColor ?? this.subtitleBackgroundColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultSpeed': defaultSpeed,
      'defaultVolume': defaultVolume,
      'defaultBrightness': defaultBrightness,
      'rememberPosition': rememberPosition,
      'autoPlay': autoPlay,
      'loopPlaylist': loopPlaylist,
      'shufflePlaylist': shufflePlaylist,
      'seekDuration': seekDuration,
      'doubleTapSeekDuration': doubleTapSeekDuration,
      'enableGestures': enableGestures,
      'enableHapticFeedback': enableHapticFeedback,
      'enablePiP': enablePiP,
      'enableBackgroundAudio': enableBackgroundAudio,
      'enableLockScreenControls': enableLockScreenControls,
      'preferredQuality': preferredQuality,
      'preferredAudioLanguage': preferredAudioLanguage,
      'preferredSubtitleLanguage': preferredSubtitleLanguage,
      'showSubtitlesByDefault': showSubtitlesByDefault,
      'subtitleFontSize': subtitleFontSize,
      'subtitleFontColor': subtitleFontColor,
      'subtitleBackgroundColor': subtitleBackgroundColor,
    };
  }

  factory PlayerSettings.fromJson(Map<String, dynamic> json) {
    return PlayerSettings(
      defaultSpeed: (json['defaultSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultVolume: (json['defaultVolume'] as num?)?.toDouble() ?? 1.0,
      defaultBrightness: (json['defaultBrightness'] as num?)?.toDouble() ?? 0.5,
      rememberPosition: json['rememberPosition'] as bool? ?? true,
      autoPlay: json['autoPlay'] as bool? ?? true,
      loopPlaylist: json['loopPlaylist'] as bool? ?? false,
      shufflePlaylist: json['shufflePlaylist'] as bool? ?? false,
      seekDuration: json['seekDuration'] as int? ?? 10,
      doubleTapSeekDuration: json['doubleTapSeekDuration'] as int? ?? 10,
      enableGestures: json['enableGestures'] as bool? ?? true,
      enableHapticFeedback: json['enableHapticFeedback'] as bool? ?? true,
      enablePiP: json['enablePiP'] as bool? ?? true,
      enableBackgroundAudio: json['enableBackgroundAudio'] as bool? ?? true,
      enableLockScreenControls:
          json['enableLockScreenControls'] as bool? ?? true,
      preferredQuality: json['preferredQuality'] as String? ?? 'auto',
      preferredAudioLanguage: json['preferredAudioLanguage'] as String? ?? 'en',
      preferredSubtitleLanguage:
          json['preferredSubtitleLanguage'] as String? ?? 'en',
      showSubtitlesByDefault: json['showSubtitlesByDefault'] as bool? ?? false,
      subtitleFontSize: (json['subtitleFontSize'] as num?)?.toDouble() ?? 16.0,
      subtitleFontColor: json['subtitleFontColor'] as String? ?? '#FFFFFF',
      subtitleBackgroundColor:
          json['subtitleBackgroundColor'] as String? ?? '#80000000',
    );
  }
}
