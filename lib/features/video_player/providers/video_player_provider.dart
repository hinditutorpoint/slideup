import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

import '../../../models/media_file.dart';
import '../../../providers/media_provider.dart';
import '../models/video_player_state.dart';
import '../models/player_settings.dart';
import '../models/player_media.dart';
import '../services/video_player_service.dart';
import '../services/settings_storage_service.dart';

// ═══════════════════════════════════════════════════════
// ✅ VIDEO PLAYER PROVIDERS - PERSISTENT
// ═══════════════════════════════════════════════════════

final videoPlayerServiceProvider = Provider<VideoPlayerService>((ref) {
  final service = VideoPlayerService();

  ref.onDispose(() {
    debugPrint('🧹 Provider disposing VideoPlayerService...');
    debugPrint('🧹 Service state before provider disposal:');
    debugPrint('   - isInitialized: ${service.isInitialized}');
    debugPrint('   - isDisposed: ${service.isDisposed}');

    try {
      debugPrint('🧹 Calling service.dispose()...');
      service.dispose();
      debugPrint('✅ VideoPlayerService disposed successfully by provider');
    } catch (e) {
      debugPrint('❌ VideoPlayerService disposal error: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  });

  return service;
});

final videoPlayerProvider =
    NotifierProvider<VideoPlayerNotifier, VideoPlayerState>(
      VideoPlayerNotifier.new,
    );

final videoPlayerInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(videoPlayerServiceProvider);
  if (!service.isInitialized && !service.isDisposed) {
    debugPrint('🎬 Initializing VideoPlayerService...');
    await service.initialize();
    debugPrint('✅ VideoPlayerService initialized');
  }
});

// ═══════════════════════════════════════════════════════
// ✅ VIDEO PLAYER NOTIFIER
// ═══════════════════════════════════════════════════════

class VideoPlayerNotifier extends Notifier<VideoPlayerState> {
  StreamSubscription? _stateSubscription;
  PlayerPlaylist? _currentPlaylist;

  Timer? _thumbnailDebounceTimer;
  Timer? _seekExecutionTimer;

  // Access service via getter
  VideoPlayerService get _service => ref.read(videoPlayerServiceProvider);

  @override
  VideoPlayerState build() {
    // Set up listener and disposal
    _listenToService();

    ref.onDispose(() {
      debugPrint('🧹 Disposing VideoPlayerNotifier...');
      _thumbnailDebounceTimer?.cancel();
      _seekExecutionTimer?.cancel();
      _stateSubscription?.cancel();
      _stateSubscription = null;
      _currentPlaylist = null;
    });

    return const VideoPlayerState();
  }

  VideoPlayerService get service {
    if (_service.isDisposed) {
      throw Exception('VideoPlayerService not available');
    }
    return _service;
  }

  VideoController get videoController => service.videoController;
  mk.Player get player => service.player;
  PlayerSettings get settings => service.settings;
  PlayerPlaylist? get currentPlaylist => _currentPlaylist;
  bool get isDisposed => _service.isDisposed;

  void _listenToService() {
    _stateSubscription?.cancel();
    _stateSubscription = _service.stateStream.listen(
      (newState) {
        // Safe state update
        try {
          state = newState;
        } catch (_) {
          // Notifier may have been disposed
        }
      },
      onError: (e) {
        debugPrint('❌ Player state stream error: $e');
      },
    );
  }

  Future<void> releasePlayer() async {
    try {
      await _addCurrentToRecent();
      await _service.stop();
      _currentPlaylist = null;
      state = const VideoPlayerState();
    } catch (e) {
      debugPrint('❌ Release player error: $e');
    }
  }

  /// Save the currently playing video to recent history on close/exit.
  /// Works for any source (media files, playlists, network URLs).
  Future<void> _addCurrentToRecent() async {
    try {
      final url = state.currentUrl;
      if (url.isEmpty) return;

      final current = currentMedia;
      final isNetwork = url.startsWith('http://') || url.startsWith('https://');
      final file = MediaFile(
        id: isNetwork
            ? url
            : (state.currentFileId ?? current?.id ?? url),
        name: current?.title ?? state.currentTitle,
        path: url,
        type: MediaType.video,
        size: current?.metadata?['size'] as int? ?? 0,
        dateModified:
            DateTime.tryParse(
              current?.metadata?['dateModified'] as String? ?? '',
            ) ??
            DateTime.now(),
        parentFolder: current?.metadata?['parentFolder'] as String?,
        duration: current?.duration?.inMilliseconds,
        lastPosition: state.position.inSeconds > 0
            ? state.position.inMilliseconds
            : null,
      );

      // Always record position/access (independent of Recent History setting)
      // so "Ask to Resume" keeps working even when history is disabled.
      await ref.read(mediaProvider.notifier).recordPlayback(
        file,
        position: state.position,
      );

      final enabled = Hive.box('settings').get(
        'recentHistoryEnabled',
        defaultValue: true,
      ) as bool;
      if (!enabled) return;

      await ref.read(mediaProvider.notifier).addToRecent(file);
    } catch (e) {
      debugPrint('⚠️ Failed to save recent history: $e');
    }
  }

  /// Manual disposal method for explicit cleanup
  Future<void> disposeService() async {
    try {
      debugPrint('🧹 Manual disposal of VideoPlayerService requested');
      debugPrint('🧹 Service state before manual disposal:');
      debugPrint('   - isInitialized: ${_service.isInitialized}');
      debugPrint('   - isDisposed: ${_service.isDisposed}');

      await _service.dispose();
      debugPrint('✅ VideoPlayerService manually disposed');
    } catch (e) {
      debugPrint('❌ Manual disposal error: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Force disposal of the service (for auto-dispose scenarios)
  void forceDisposeService() {
    try {
      debugPrint('🧹 Force disposing VideoPlayerService...');
      debugPrint('🧹 Service state before force disposal:');
      debugPrint('   - isInitialized: ${_service.isInitialized}');
      debugPrint('   - isDisposed: ${_service.isDisposed}');

      _service.dispose();
      debugPrint('✅ VideoPlayerService force disposed');
    } catch (e) {
      debugPrint('❌ Force disposal error: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Safe disposal for auto-dispose scenarios
  Future<void> safeDisposeService() async {
    try {
      debugPrint('🧹 Safe disposing VideoPlayerService...');
      debugPrint('🧹 Service state before safe disposal:');
      debugPrint('   - isInitialized: ${_service.isInitialized}');
      debugPrint('   - isDisposed: ${_service.isDisposed}');
      debugPrint('   - isPlaying: ${_service.state.isPlaying}');

      // Stop playback first
      if (_service.state.isPlaying) {
        debugPrint('🧹 Stopping playback before disposal...');
        await _service.stop();
        debugPrint('✅ Playback stopped');
      }

      // Then dispose
      await _service.dispose();
      debugPrint('✅ VideoPlayerService safely disposed');
    } catch (e) {
      debugPrint('❌ Safe disposal error: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Save current playback position
  Future<void> savePosition() async {
    if (isDisposed) return;
    try {
      final position = state.position;
      final fileId = state.currentFileId;

      if (fileId != null && position.inSeconds > 0) {
        await SettingsStorageService.savePlaybackPosition(fileId, position);
        debugPrint('✅ Position saved: ${position.inSeconds}s');
      }

      // Mirror the position into the always-on playback record too, so resume
      // survives when the "Recent History" setting is off.
      final url = state.currentUrl;
      if (url.isNotEmpty) {
        final current = currentMedia;
        final file = MediaFile(
          id: fileId ?? url,
          name: current?.title ?? state.currentTitle,
          path: url,
          type: MediaType.video,
          size: current?.metadata?['size'] as int? ?? 0,
          dateModified: DateTime.now(),
          duration: current?.duration?.inMilliseconds,
          lastPosition: position.inMilliseconds,
        );
        await ref.read(mediaProvider.notifier).recordPlayback(
          file,
          position: position,
        );
      }
    } catch (e) {
      debugPrint('❌ Save position error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ YOUTUBE-STYLE SEEKING
  // ═══════════════════════════════════════════════════════

  void startHorizontalSeek() {
    if (isDisposed) return;
    try {
      service.startHorizontalSeek();
    } catch (e) {
      debugPrint('❌ Start horizontal seek error: $e');
    }
  }

  void updateHorizontalSeek(double delta) {
    if (isDisposed) return;
    try {
      service.updateHorizontalSeek(delta);
    } catch (e) {
      debugPrint('❌ Update horizontal seek error: $e');
    }
  }

  Future<void> endHorizontalSeek() async {
    if (isDisposed) return;
    try {
      await service.endHorizontalSeek();
    } catch (e) {
      debugPrint('❌ End horizontal seek error: $e');
    }
  }

  void hideSeekPreview() {
    if (isDisposed) return;
    try {
      service.hideSeekPreview();
    } catch (e) {
      debugPrint('❌ Hide seek preview error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYLIST
  // ═══════════════════════════════════════════════════════

  Future<void> openPlaylist(PlayerPlaylist playlist) async {
    if (isDisposed) return;

    if (playlist.isEmpty) {
      throw Exception('Cannot open empty playlist');
    }

    try {
      _currentPlaylist = playlist;

      // ✅ Extract titles and file IDs from playlist
      final titles = playlist.items.map((item) => item.title ?? '').toList();
      final fileIds = playlist.items.map((item) => item.id).toList();

      await service.openMedia(
        url: playlist.urls[playlist.currentIndex],
        fileId: playlist.items[playlist.currentIndex].id,
        playlist: playlist.urls,
        startIndex: playlist.currentIndex,
        titles: titles, // ✅ ADD
        fileIds: fileIds, // ✅ ADD
      );
    } catch (e) {
      debugPrint('❌ Open playlist error: $e');
      rethrow;
    }
  }

  PlayerMedia? get currentMedia {
    try {
      if (_currentPlaylist == null) return null;
      final index = state.currentIndex;
      if (index < 0 || index >= _currentPlaylist!.items.length) return null;
      return _currentPlaylist!.items[index];
    } catch (e) {
      return null;
    }
  }

  String get currentTitle => currentMedia?.title ?? 'Video Player';

  // ═══════════════════════════════════════════════════════
  // ✅ MEDIA CONTROL
  // ═══════════════════════════════════════════════════════

  Future<void> openMedia({
    required String url,
    String? fileId,
    List<String>? playlist,
    int startIndex = 0,
  }) async {
    if (isDisposed) return;
    try {
      await service.openMedia(
        url: url,
        fileId: fileId,
        playlist: playlist,
        startIndex: startIndex,
      );
    } catch (e) {
      debugPrint('❌ Open media error: $e');
      state = state.copyWith(
        hasError: true,
        errorMessage: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> playOrPause() async {
    if (isDisposed) return;
    try {
      await service.playOrPause();
    } catch (e) {
      debugPrint('❌ Play/pause error: $e');
    }
  }

  Future<void> play() async {
    if (isDisposed) return;
    try {
      await service.play();
    } catch (e) {
      debugPrint('❌ Play error: $e');
    }
  }

  Future<void> pause() async {
    if (isDisposed) return;
    try {
      await service.pause();
    } catch (e) {
      debugPrint('❌ Pause error: $e');
    }
  }

  Future<void> stop() async {
    if (isDisposed) return;
    try {
      await _addCurrentToRecent();
      await service.stop();
    } catch (e) {
      debugPrint('❌ Stop error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    if (isDisposed) return;
    try {
      await service.seek(position);
    } catch (e) {
      debugPrint('❌ Seek error: $e');
    }
  }

  Future<void> seekRelative(int seconds) async {
    if (isDisposed) return;
    try {
      await service.seekRelative(seconds);
    } catch (e) {
      debugPrint('❌ Seek relative error: $e');
    }
  }

  /// Resume from the saved position shown in the in-player prompt.
  Future<void> resumeFromPrompt() async {
    if (isDisposed) return;
    final position = state.resumePosition;
    state = state.copyWith(clearResumePrompt: true);
    if (position == null) return;
    try {
      await service.resumeFromPosition(position);
    } catch (e) {
      debugPrint('❌ Resume from prompt error: $e');
    }
  }

  /// Cancel the resume prompt and forget the saved position.
  Future<void> cancelResumePrompt() async {
    if (isDisposed) return;
    final fileId = state.resumeFileId;
    state = state.copyWith(clearResumePrompt: true);
    if (fileId == null) return;
    try {
      await service.clearResumePosition(fileId);
    } catch (e) {
      debugPrint('❌ Cancel resume prompt error: $e');
    }
  }

  /// Skip the intro from the in-player prompt (seeks to the lead time).
  Future<void> skipIntroFromPrompt() async {
    if (isDisposed) return;
    final position = state.skipIntroPosition;
    state = state.copyWith(clearSkipIntroPrompt: true);
    if (position == null) return;
    try {
      await service.skipIntroSeek(position);
    } catch (e) {
      debugPrint('❌ Skip intro error: $e');
    }
  }

  /// Cancel the skip-intro prompt without seeking.
  Future<void> cancelSkipIntroPrompt() async {
    if (isDisposed) return;
    state = state.copyWith(clearSkipIntroPrompt: true);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYLIST NAVIGATION
  // ═══════════════════════════════════════════════════════

  Future<void> playNext() async {
    if (isDisposed) return;
    try {
      await service.playNext();
    } catch (e) {
      debugPrint('❌ Play next error: $e');
    }
  }

  Future<void> playPrevious() async {
    if (isDisposed) return;
    try {
      await service.playPrevious();
    } catch (e) {
      debugPrint('❌ Play previous error: $e');
    }
  }

  Future<void> jumpToIndex(int index) async {
    if (isDisposed) return;
    try {
      await service.jumpToIndex(index);
    } catch (e) {
      debugPrint('❌ Jump to index error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VOLUME & BRIGHTNESS
  // ═══════════════════════════════════════════════════════

  Future<void> setVolume(double volume) async {
    if (isDisposed) return;
    try {
      await service.setVolume(volume);
    } catch (e) {
      debugPrint('❌ Set volume error: $e');
    }
  }

  Future<void> adjustVolume(double delta) async {
    if (isDisposed) return;
    try {
      await service.adjustVolume(delta);
    } catch (e) {
      debugPrint('❌ Adjust volume error: $e');
    }
  }

  Future<void> toggleMute() async {
    if (isDisposed) return;
    try {
      await service.toggleMute();
    } catch (e) {
      debugPrint('❌ Toggle mute error: $e');
    }
  }

  Future<void> setBrightness(double brightness) async {
    if (isDisposed) return;
    try {
      await service.setBrightness(brightness);
    } catch (e) {
      debugPrint('❌ Set brightness error: $e');
    }
  }

  Future<void> adjustBrightness(double delta) async {
    if (isDisposed) return;
    try {
      await service.adjustBrightness(delta);
    } catch (e) {
      debugPrint('❌ Adjust brightness error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SPEED
  // ═══════════════════════════════════════════════════════

  Future<void> setSpeed(double speed) async {
    if (isDisposed) return;
    try {
      await service.setSpeed(speed);
    } catch (e) {
      debugPrint('❌ Set speed error: $e');
    }
  }

  Future<void> enable2xSpeed() async {
    if (isDisposed) return;
    try {
      await service.enable2xSpeed();
    } catch (e) {
      debugPrint('❌ Enable 2x speed error: $e');
    }
  }

  Future<void> disable2xSpeed() async {
    if (isDisposed) return;
    try {
      await service.disable2xSpeed();
    } catch (e) {
      debugPrint('❌ Disable 2x speed error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VIDEO FIT & FLIP
  // ═══════════════════════════════════════════════════════

  void setVideoFit(VideoFit fit) {
    if (isDisposed) return;
    try {
      service.setVideoFit(fit);
    } catch (e) {
      debugPrint('❌ Set video fit error: $e');
    }
  }

  void cycleVideoFit() {
    if (isDisposed) return;
    try {
      service.cycleVideoFit();
    } catch (e) {
      debugPrint('❌ Cycle video fit error: $e');
    }
  }

  void toggleFlipHorizontal() {
    if (isDisposed) return;
    try {
      service.toggleFlipHorizontal();
    } catch (e) {
      debugPrint('❌ Toggle flip horizontal error: $e');
    }
  }

  void toggleFlipVertical() {
    if (isDisposed) return;
    try {
      service.toggleFlipVertical();
    } catch (e) {
      debugPrint('❌ Toggle flip vertical error: $e');
    }
  }

  void resetFlip() {
    if (isDisposed) return;
    try {
      service.resetFlip();
    } catch (e) {
      debugPrint('❌ Reset flip error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TRACKS
  // ═══════════════════════════════════════════════════════

  Future<void> setAudioTrack(mk.AudioTrack track) async {
    if (isDisposed) return;
    try {
      await service.setAudioTrack(track);
    } catch (e) {
      debugPrint('❌ Set audio track error: $e');
    }
  }

  Future<void> setSubtitleTrack(mk.SubtitleTrack track) async {
    if (isDisposed) return;
    try {
      await service.setSubtitleTrack(track);
    } catch (e) {
      debugPrint('❌ Set subtitle track error: $e');
    }
  }

  Future<void> disableSubtitles() async {
    if (isDisposed) return;
    try {
      await service.disableSubtitles();
    } catch (e) {
      debugPrint('❌ Disable subtitles error: $e');
    }
  }

  Future<void> loadExternalSubtitle(String path) async {
    if (isDisposed) return;
    try {
      await service.loadExternalSubtitle(path);
    } catch (e) {
      debugPrint('❌ Load external subtitle error: $e');
    }
  }

  Future<void> setVideoTrack(mk.VideoTrack track) async {
    if (isDisposed) return;
    try {
      await service.setVideoTrack(track);
    } catch (e) {
      debugPrint('❌ Set video track error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CONTROLS & UI
  // ═══════════════════════════════════════════════════════

  void showControls() {
    if (isDisposed) return;
    service.showControls();
  }

  void hideControls() {
    if (isDisposed) return;
    service.hideControls();
  }

  void toggleControls() {
    if (isDisposed) return;
    service.toggleControls();
  }

  void lockControls() {
    if (isDisposed) return;
    service.lockControls();
  }

  void unlockControls() {
    if (isDisposed) return;
    service.unlockControls();
  }

  void setControlsMode(ControlsMode mode) {
    if (isDisposed) return;
    service.setControlsMode(mode);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ FULLSCREEN & MODE
  // ═══════════════════════════════════════════════════════

  Future<void> enterFullscreen() async {
    if (isDisposed) return;
    try {
      await service.enterFullscreen();
    } catch (e) {
      debugPrint('❌ Enter fullscreen error: $e');
    }
  }

  Future<void> exitFullscreen() async {
    if (isDisposed) return;
    try {
      await service.exitFullscreen();
    } catch (e) {
      debugPrint('❌ Exit fullscreen error: $e');
    }
  }

  Future<void> toggleFullscreen() async {
    if (isDisposed) return;
    try {
      await service.toggleFullscreen();
    } catch (e) {
      debugPrint('❌ Toggle fullscreen error: $e');
    }
  }

  void enterPiPMode() {
    if (isDisposed) return;
    service.enterPiPMode();
  }

  void exitPiPMode() {
    if (isDisposed) return;
    service.exitPiPMode();
  }

  void enterBackgroundMode() {
    if (isDisposed) return;
    service.enterBackgroundMode();
  }

  void exitBackgroundMode() {
    if (isDisposed) return;
    service.exitBackgroundMode();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SCREENSHOT
  // ═══════════════════════════════════════════════════════

  Future<Uint8List?> takeScreenshot() async {
    if (isDisposed) return null;
    try {
      return await service.takeScreenshot();
    } catch (e) {
      debugPrint('❌ Screenshot error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SETTINGS
  // ═══════════════════════════════════════════════════════

  Future<void> updateSettings(PlayerSettings newSettings) async {
    if (isDisposed) return;
    try {
      await service.updateSettings(newSettings);
    } catch (e) {
      debugPrint('❌ Update settings error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ CONVENIENCE PROVIDERS (FIXED)
// ═══════════════════════════════════════════════════════

/// Current title - rebuilds when currentTitle changes in state
final currentTitleProvider = Provider<String>((ref) {
  return ref.watch(videoPlayerProvider.select((s) => s.displayTitle));
});

/// Current index
final currentIndexProvider = Provider<int>((ref) {
  return ref.watch(videoPlayerProvider.select((s) => s.currentIndex));
});

/// Current media info - rebuilds when index changes
final currentMediaProvider = Provider<PlayerMedia?>((ref) {
  final currentIndex = ref.watch(
    videoPlayerProvider.select((s) => s.currentIndex),
  );

  final notifier = ref.read(videoPlayerProvider.notifier);
  final playlist = notifier.currentPlaylist;

  if (playlist == null) return null;
  if (currentIndex < 0 || currentIndex >= playlist.items.length) return null;

  return playlist.items[currentIndex];
});

final isPlayerInitializedProvider = Provider<bool>((ref) {
  return ref.watch(videoPlayerProvider.select((s) => s.isInitialized));
});

final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(videoPlayerProvider.select((s) => s.isPlaying));
});

final positionProvider = Provider<Duration>((ref) {
  return ref.watch(videoPlayerProvider.select((s) => s.position));
});

final durationProvider = Provider<Duration>((ref) {
  return ref.watch(videoPlayerProvider.select((s) => s.duration));
});

final progressProvider = Provider<double>((ref) {
  return ref.watch(videoPlayerProvider.select((s) => s.progress));
});

final playlistInfoProvider =
    Provider<({int current, int total, bool hasPlaylist})>((ref) {
      final state = ref.watch(videoPlayerProvider);
      return (
        current: state.currentIndex,
        total: state.playlistLength,
        hasPlaylist: state.hasPlaylist,
      );
    });

// ═══════════════════════════════════════════════════════
// ✅ SETTINGS PROVIDER
// ═══════════════════════════════════════════════════════

final playerSettingsProvider = FutureProvider<PlayerSettings>((ref) async {
  ref.keepAlive();
  return SettingsStorageService.loadPlayerSettings();
});

// ═══════════════════════════════════════════════════════
// ✅ AUTO-DISPOSE SAFE PROVIDERS (DISABLED)
// ═══════════════════════════════════════════════════════

// Note: Auto-dispose providers are disabled to prevent premature disposal
// Use the regular providers (videoPlayerServiceProvider, videoPlayerInitProvider) instead

/// Auto-dispose safe video player provider that prevents premature disposal
/// ⚠️ DISABLED: Use videoPlayerServiceProvider instead
final videoPlayerAutoDisposeProvider = Provider.autoDispose<VideoPlayerService>(
  (ref) {
    final service = VideoPlayerService();

    // Keep the service alive while it's being used
    ref.keepAlive();

    ref.onDispose(() {
      debugPrint('🧹 Auto-dispose: Disposing VideoPlayerService...');
      try {
        // Only dispose if service is not playing
        if (service.state.isPlaying) {
          debugPrint('⚠️ Video is playing, scheduling disposal...');
          // Schedule disposal after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (!service.isDisposed) {
              service.dispose();
              debugPrint('✅ VideoPlayerService disposed after delay');
            }
          });
        } else {
          service.dispose();
          debugPrint('✅ VideoPlayerService disposed immediately');
        }
      } catch (e) {
        debugPrint('❌ Auto-dispose error: $e');
      }
    });

    return service;
  },
);

/// Auto-dispose safe init provider
/// ⚠️ DISABLED: Use videoPlayerInitProvider instead
final videoPlayerAutoInitProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final service = ref.watch(videoPlayerAutoDisposeProvider);
  if (!service.isInitialized && !service.isDisposed) {
    debugPrint('🎬 Auto-dispose: Initializing VideoPlayerService...');
    await service.initialize();
    debugPrint('✅ Auto-dispose: VideoPlayerService initialized');
  }
});
