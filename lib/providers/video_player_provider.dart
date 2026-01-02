import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/whisper_service.dart';
import '../models/subtitle_segment.dart';

class VideoPlayerState {
  final bool showControls;
  final bool isFullScreen;
  final bool isPip;
  final List<SubtitleSegment> subtitles;
  final bool isTranscribing;
  final bool isTranslating;
  final String? selectedAudioTrack;
  final String? selectedSubtitleTrack;
  final int currentIndex;

  const VideoPlayerState({
    this.showControls = true,
    this.isFullScreen = false,
    this.isPip = false,
    this.subtitles = const [],
    this.isTranscribing = false,
    this.isTranslating = false,
    this.selectedAudioTrack,
    this.selectedSubtitleTrack,
    this.currentIndex = 0,
  });

  VideoPlayerState copyWith({
    bool? showControls,
    bool? isFullScreen,
    bool? isPip,
    List<SubtitleSegment>? subtitles,
    bool? isTranscribing,
    bool? isTranslating,
    String? selectedAudioTrack,
    String? selectedSubtitleTrack,
    int? currentIndex,
  }) {
    return VideoPlayerState(
      showControls: showControls ?? this.showControls,
      isFullScreen: isFullScreen ?? this.isFullScreen,
      isPip: isPip ?? this.isPip,
      subtitles: subtitles ?? this.subtitles,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      isTranslating: isTranslating ?? this.isTranslating,
      selectedAudioTrack: selectedAudioTrack ?? this.selectedAudioTrack,
      selectedSubtitleTrack:
          selectedSubtitleTrack ?? this.selectedSubtitleTrack,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class VideoPlayerNotifier extends Notifier<VideoPlayerState> {
  @override
  VideoPlayerState build() {
    return const VideoPlayerState();
  }

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void showControls() {
    state = state.copyWith(showControls: true);
  }

  void hideControls() {
    state = state.copyWith(showControls: false);
  }

  void toggleFullScreen() {
    state = state.copyWith(isFullScreen: !state.isFullScreen);
  }

  void enterPip() {
    state = state.copyWith(isPip: true, showControls: false);
  }

  void exitPip() {
    state = state.copyWith(isPip: false);
  }

  Future<void> transcribeVideo(String videoPath) async {
    state = state.copyWith(isTranscribing: true);

    try {
      final segments = await WhisperService.instance.getTimedTranscription(
        videoPath,
      );
      state = state.copyWith(subtitles: segments, isTranscribing: false);
    } catch (e) {
      state = state.copyWith(isTranscribing: false);
      print('Error transcribing: $e');
    }
  }

  void setSubtitles(List<SubtitleSegment> subtitles) {
    state = state.copyWith(subtitles: subtitles);
  }

  void setCurrentIndex(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void clearSubtitles() {
    state = state.copyWith(subtitles: []);
  }

  void setTranscribing(bool isTranscribing) {
    state = state.copyWith(isTranscribing: isTranscribing);
  }

  void setTranslating(bool isTranslating) {
    state = state.copyWith(isTranslating: isTranslating);
  }
}

final videoPlayerProvider =
    NotifierProvider.autoDispose<VideoPlayerNotifier, VideoPlayerState>(
      () => VideoPlayerNotifier(),
    );
