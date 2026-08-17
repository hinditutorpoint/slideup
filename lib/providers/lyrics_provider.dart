import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lyric_line.dart';
import '../services/lyrics_service.dart';

class LyricsState {
  final bool isLoading;
  final LyricsData? data;
  final String? error;
  final String? currentTrackKey;

  const LyricsState({
    this.isLoading = false,
    this.data,
    this.error,
    this.currentTrackKey,
  });

  LyricsState copyWith({
    bool? isLoading,
    LyricsData? data,
    String? error,
    String? currentTrackKey,
  }) {
    return LyricsState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
      currentTrackKey: currentTrackKey ?? this.currentTrackKey,
    );
  }
}

class LyricsNotifier extends Notifier<LyricsState> {
  @override
  LyricsState build() {
    return const LyricsState();
  }

  Future<void> loadLyrics({
    required String title,
    String? artist,
    Duration? duration,
    bool forceRefresh = false,
  }) async {
    final trackKey = '$title|${artist ?? ""}';
    if (!forceRefresh && state.currentTrackKey == trackKey && state.data != null) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentTrackKey: trackKey,
    );

    try {
      final lyrics = await LyricsService.instance.fetchLyrics(
        rawTitle: title,
        rawArtist: artist,
        duration: duration,
      );

      if (lyrics != null && lyrics.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          data: lyrics,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          data: null,
          error: 'No lyrics found for this song.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        data: null,
        error: 'Failed to load lyrics: $e',
      );
    }
  }

  Future<void> searchCustom(String customQuery) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final lyrics = await LyricsService.instance.fetchLyrics(
        rawTitle: customQuery,
      );
      if (lyrics != null && lyrics.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          data: lyrics,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          data: null,
          error: 'No lyrics found for "$customQuery".',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        data: null,
        error: 'Failed to search lyrics: $e',
      );
    }
  }
}

final lyricsProvider =
    NotifierProvider<LyricsNotifier, LyricsState>(LyricsNotifier.new);
