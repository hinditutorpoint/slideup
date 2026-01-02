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

  // ✅ ADD: Current media info
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

  final bool isCompleted;

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
    // ✅ ADD defaults
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
    this.isCompleted = false,
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
    // ✅ ADD parameters
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
    bool? isCompleted,
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
      // ✅ ADD to copyWith
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
      isCompleted: isCompleted ?? this.isCompleted,
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

  // ✅ ADD: Helper for display title
  String get displayTitle =>
      currentTitle.isNotEmpty ? currentTitle : 'Video Player';

  @override
  String toString() {
    return 'VideoPlayerState(isPlaying: $isPlaying, position: $position, '
        'currentIndex: $currentIndex, currentTitle: $currentTitle, '
        'audioTracks: ${audioTracks.length}, videoTracks: ${videoTracks.length})';
  }
}
