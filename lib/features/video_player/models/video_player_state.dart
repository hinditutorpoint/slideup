import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

enum PlayerMode { normal, pip, fullscreen, background }

enum GestureZone {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

enum SeekDirection { forward, backward, none }

enum ControlsMode { mini, normal, expanded }

enum VideoFit {
  contain, // Default - fit inside
  cover, // Fill and crop
  fill, // Stretch to fill
  fitWidth, // Fit width
  fitHeight, // Fit height
}

@immutable
class VideoPlayerState {
  final bool isInitialized;
  final bool isPlaying;
  final bool isBuffering;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;

  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;

  final double volume;
  final double brightness;
  final double speed;
  final bool isMuted;

  final bool showControls;
  final bool isLocked;
  final bool is2xSpeed;
  final PlayerMode mode;
  final ControlsMode controlsMode;

  final int currentIndex;
  final int playlistLength;

  final String currentTitle;
  final String currentUrl;
  final String? currentFileId;

  final List<AudioTrack> audioTracks;
  final List<SubtitleTrack> subtitleTracks;
  final List<VideoTrack> videoTracks;
  final AudioTrack? currentAudioTrack;
  final SubtitleTrack? currentSubtitleTrack;
  final VideoTrack? currentVideoTrack;

  final SeekDirection seekDirection;
  final int seekSeconds;
  final bool showSeekIndicator;
  final bool showBrightnessIndicator;
  final bool showVolumeIndicator;
  final bool showSpeedIndicator;

  final Duration? seekPreviewPosition;
  final Uint8List? seekPreviewThumbnail;

  final bool showSeekPreview;
  final int accumulatedSeekSeconds;
  final bool isSeekingHorizontally;

  final bool isCompleted;

  final bool showResumePrompt;
  final Duration? resumePosition;
  final String? resumeFileId;

  final bool showSkipIntroPrompt;
  final Duration? skipIntroPosition;

  final VideoFit videoFit;
  final bool isFlippedHorizontally;
  final bool isFlippedVertically;

  const VideoPlayerState({
    this.isInitialized = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.volume = 1.0,
    this.brightness = 0.5,
    this.speed = 1.0,
    this.isMuted = false,
    this.showControls = true,
    this.isLocked = false,
    this.is2xSpeed = false,
    this.mode = PlayerMode.normal,
    this.controlsMode = ControlsMode.normal,
    this.currentIndex = 0,
    this.playlistLength = 0,
    this.currentTitle = '',
    this.currentUrl = '',
    this.currentFileId,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.videoTracks = const [],
    this.currentAudioTrack,
    this.currentSubtitleTrack,
    this.currentVideoTrack,
    this.seekDirection = SeekDirection.none,
    this.seekSeconds = 0,
    this.showSeekIndicator = false,
    this.showBrightnessIndicator = false,
    this.showVolumeIndicator = false,
    this.showSpeedIndicator = false,
    this.seekPreviewPosition,
    this.seekPreviewThumbnail,

    this.showSeekPreview = false,
    this.accumulatedSeekSeconds = 0,
    this.isSeekingHorizontally = false,

    this.isCompleted = false,

    this.showResumePrompt = false,
    this.resumePosition,
    this.resumeFileId,

    this.showSkipIntroPrompt = false,
    this.skipIntroPosition,

    this.videoFit = VideoFit.contain,
    this.isFlippedHorizontally = false,
    this.isFlippedVertically = false,
  });

  VideoPlayerState copyWith({
    bool? isInitialized,
    bool? isPlaying,
    bool? isBuffering,
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    bool clearError = false,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    double? volume,
    double? brightness,
    double? speed,
    bool? isMuted,
    bool? showControls,
    bool? isLocked,
    bool? is2xSpeed,
    PlayerMode? mode,
    ControlsMode? controlsMode,
    int? currentIndex,
    int? playlistLength,
    String? currentTitle,
    String? currentUrl,
    String? currentFileId,
    bool clearCurrentFileId = false,
    List<AudioTrack>? audioTracks,
    List<SubtitleTrack>? subtitleTracks,
    List<VideoTrack>? videoTracks,
    AudioTrack? currentAudioTrack,
    SubtitleTrack? currentSubtitleTrack,
    VideoTrack? currentVideoTrack,
    bool clearCurrentAudioTrack = false,
    bool clearCurrentSubtitleTrack = false,
    bool clearCurrentVideoTrack = false,
    SeekDirection? seekDirection,
    int? seekSeconds,
    bool? showSeekIndicator,
    bool? showBrightnessIndicator,
    bool? showVolumeIndicator,
    bool? showSpeedIndicator,
    Duration? seekPreviewPosition,
    Uint8List? seekPreviewThumbnail,
    bool clearSeekPreview = false,

    bool? showSeekPreview,
    int? accumulatedSeekSeconds,
    bool? isSeekingHorizontally,
    bool? isCompleted,

    bool? showResumePrompt,
    Duration? resumePosition,
    String? resumeFileId,
    bool clearResumePrompt = false,

    bool? showSkipIntroPrompt,
    Duration? skipIntroPosition,
    bool clearSkipIntroPrompt = false,

    VideoFit? videoFit,
    bool? isFlippedHorizontally,
    bool? isFlippedVertically,
  }) {
    return VideoPlayerState(
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isLoading: isLoading ?? this.isLoading,
      hasError: clearError ? false : (hasError ?? this.hasError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      volume: volume ?? this.volume,
      brightness: brightness ?? this.brightness,
      speed: speed ?? this.speed,
      isMuted: isMuted ?? this.isMuted,
      showControls: showControls ?? this.showControls,
      isLocked: isLocked ?? this.isLocked,
      is2xSpeed: is2xSpeed ?? this.is2xSpeed,
      mode: mode ?? this.mode,
      controlsMode: controlsMode ?? this.controlsMode,
      currentIndex: currentIndex ?? this.currentIndex,
      playlistLength: playlistLength ?? this.playlistLength,
      currentTitle: currentTitle ?? this.currentTitle,
      currentUrl: currentUrl ?? this.currentUrl,
      currentFileId: clearCurrentFileId
          ? null
          : (currentFileId ?? this.currentFileId),
      audioTracks: audioTracks ?? this.audioTracks,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks,
      videoTracks: videoTracks ?? this.videoTracks,
      currentAudioTrack: clearCurrentAudioTrack
          ? null
          : (currentAudioTrack ?? this.currentAudioTrack),
      currentSubtitleTrack: clearCurrentSubtitleTrack
          ? null
          : (currentSubtitleTrack ?? this.currentSubtitleTrack),
      currentVideoTrack: clearCurrentVideoTrack
          ? null
          : (currentVideoTrack ?? this.currentVideoTrack),
      seekDirection: seekDirection ?? this.seekDirection,
      seekSeconds: seekSeconds ?? this.seekSeconds,
      showSeekIndicator: showSeekIndicator ?? this.showSeekIndicator,
      showBrightnessIndicator:
          showBrightnessIndicator ?? this.showBrightnessIndicator,
      showVolumeIndicator: showVolumeIndicator ?? this.showVolumeIndicator,
      showSpeedIndicator: showSpeedIndicator ?? this.showSpeedIndicator,
      seekPreviewPosition: clearSeekPreview
          ? null
          : (seekPreviewPosition ?? this.seekPreviewPosition),
      seekPreviewThumbnail: clearSeekPreview
          ? null
          : (seekPreviewThumbnail ?? this.seekPreviewThumbnail),

      showSeekPreview: showSeekPreview ?? this.showSeekPreview,
      accumulatedSeekSeconds:
          accumulatedSeekSeconds ?? this.accumulatedSeekSeconds,
      isSeekingHorizontally:
          isSeekingHorizontally ?? this.isSeekingHorizontally,
      isCompleted: isCompleted ?? this.isCompleted,

      showResumePrompt: clearResumePrompt
          ? false
          : (showResumePrompt ?? this.showResumePrompt),
      resumePosition: clearResumePrompt
          ? null
          : (resumePosition ?? this.resumePosition),
      resumeFileId: clearResumePrompt
          ? null
          : (resumeFileId ?? this.resumeFileId),

      showSkipIntroPrompt: clearSkipIntroPrompt
          ? false
          : (showSkipIntroPrompt ?? this.showSkipIntroPrompt),
      skipIntroPosition: clearSkipIntroPrompt
          ? null
          : (skipIntroPosition ?? this.skipIntroPosition),

      videoFit: videoFit ?? this.videoFit,
      isFlippedHorizontally:
          isFlippedHorizontally ?? this.isFlippedHorizontally,
      isFlippedVertically: isFlippedVertically ?? this.isFlippedVertically,
    );
  }

  bool get canPlayPrevious => currentIndex > 0;
  bool get canPlayNext => currentIndex < playlistLength - 1;
  bool get hasPlaylist => playlistLength > 1;

  double get progress => duration.inMilliseconds > 0
      ? position.inMilliseconds / duration.inMilliseconds
      : 0.0;

  double get bufferedProgress => duration.inMilliseconds > 0
      ? bufferedPosition.inMilliseconds / duration.inMilliseconds
      : 0.0;

  String get displayTitle =>
      currentTitle.isNotEmpty ? currentTitle : 'Video Player';

  @override
  String toString() {
    return 'VideoPlayerState(isPlaying: $isPlaying, position: $position, '
        'currentIndex: $currentIndex, currentTitle: $currentTitle, '
        'audioTracks: ${audioTracks.length}, videoTracks: ${videoTracks.length})';
  }
}
