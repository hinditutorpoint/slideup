import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../navigation_service.dart';
import '../../../../models/media_file.dart';
import '../../../../helpers/audio_playback_helper.dart';
import '../models/iptv_models.dart';
import '../screens/iptv_player_screen.dart';
import '../services/iptv_database_service.dart';
import '../services/iptv_datasource.dart';
import '../services/m3u_parser.dart';

final iptvDatasourceProvider = Provider<IptvDatasource>((ref) {
  final ds = IptvDatasource();
  ref.onDispose(ds.close);
  return ds;
});

/// Sample public playlist used as a quick-start template.
const String kIptvSampleUrl =
    'https://iptv-org.github.io/iptv/languages/hin.m3u';

// ═══════════════════════════════════════════════════════
// Playlists list
// ═══════════════════════════════════════════════════════

final iptvPlaylistsProvider =
    NotifierProvider<IptvPlaylistsNotifier, List<IptvPlaylist>>(
  IptvPlaylistsNotifier.new,
);

class IptvPlaylistsNotifier extends Notifier<List<IptvPlaylist>> {
  bool get mounted => true;

  @override
  List<IptvPlaylist> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final playlists = await IptvDatabaseService.instance.getAllPlaylists();
      if (mounted) state = playlists;
    } catch (e) {
      if (mounted) state = const [];
    }
  }

  Future<IptvPlaylist> addFromUrl({
    required String url,
    String? name,
    String? language,
  }) async {
    final trimmed = url.trim();
    final datasource = ref.read(iptvDatasourceProvider);
    final content = await datasource.fetchM3uUrl(trimmed);
    final playlistId = const Uuid().v4().replaceAll('-', '');
    final channels = M3uParser.parse(
      content: content,
      playlistId: playlistId,
      defaultLanguage: language,
    );
    final groups = groupChannels(channels);

    final now = DateTime.now();
    final playlist = IptvPlaylist(
      id: playlistId,
      name: (name == null || name.trim().isEmpty)
          ? _playlistNameFromUrl(trimmed)
          : name.trim(),
      sourceType: IptvSourceType.url,
      source: trimmed,
      language: language,
      channelCount: channels.length,
      groupCount: groups.length,
      lastUpdated: now,
      createdAt: now,
    );
    await _persist(playlist, channels);
    return playlist;
  }

  Future<IptvPlaylist> addFromFile({
    required String path,
    String? name,
  }) async {
    final datasource = ref.read(iptvDatasourceProvider);
    final content = await datasource.readLocalFile(path);
    final playlistId = const Uuid().v4().replaceAll('-', '');
    final channels = M3uParser.parse(content: content, playlistId: playlistId);
    final groups = groupChannels(channels);

    final now = DateTime.now();
    final playlist = IptvPlaylist(
      id: playlistId,
      name: (name == null || name.trim().isEmpty)
          ? _fileNameFromPath(path)
          : name.trim(),
      sourceType: IptvSourceType.file,
      source: path,
      channelCount: channels.length,
      groupCount: groups.length,
      lastUpdated: now,
      createdAt: now,
    );
    await _persist(playlist, channels);
    return playlist;
  }

  Future<IptvPlaylist> addFromXtream({
    required String server,
    required String username,
    required String password,
    String? name,
  }) async {
    if (!XtreamClient.hasCredentials(
      server: server,
      username: username,
      password: password,
    )) {
      throw IptvNetworkException('Server, username and password are required.');
    }

    final datasource = ref.read(iptvDatasourceProvider);
    final content = await datasource.fetchXtreamM3u(
      server: server,
      username: username,
      password: password,
    );
    final playlistId = const Uuid().v4().replaceAll('-', '');
    final channels = M3uParser.parse(content: content, playlistId: playlistId);
    final groups = groupChannels(channels);

    final now = DateTime.now();
    final playlist = IptvPlaylist(
      id: playlistId,
      name: (name == null || name.trim().isEmpty)
          ? 'XTream ${username.trim()}'
          : name.trim(),
      sourceType: IptvSourceType.xtream,
      source: XtreamClient.normalizeServer(server),
      username: username.trim(),
      password: password.trim(),
      channelCount: channels.length,
      groupCount: groups.length,
      lastUpdated: now,
      createdAt: now,
    );
    await _persist(playlist, channels);
    return playlist;
  }

  Future<void> refreshPlaylist(String playlistId) async {
    final existing = await IptvDatabaseService.instance.getPlaylist(playlistId);
    if (existing == null) return;

    final datasource = ref.read(iptvDatasourceProvider);
    String content;
    switch (existing.sourceType) {
      case IptvSourceType.url:
        content = await datasource.fetchM3uUrl(existing.source);
      case IptvSourceType.file:
        content = await datasource.readLocalFile(existing.source);
      case IptvSourceType.xtream:
        content = await datasource.fetchXtreamM3u(
          server: existing.source,
          username: existing.username ?? '',
          password: existing.password ?? '',
        );
    }

    final channels = M3uParser.parse(
      content: content,
      playlistId: playlistId,
      defaultLanguage: existing.language,
    );
    final groups = groupChannels(channels);

    final updated = existing.copyWith(
      channelCount: channels.length,
      groupCount: groups.length,
      lastUpdated: DateTime.now(),
    );
    await IptvDatabaseService.instance.upsertPlaylist(updated);
    await IptvDatabaseService.instance.replaceChannels(playlistId, channels);

    // Reload state and refresh the channels notifier for this playlist.
    await _load();
    if (mounted) {
      final notifier = ref.read(iptvChannelsProvider(playlistId).notifier);
      notifier.refresh();
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    await IptvDatabaseService.instance.deletePlaylist(playlistId);
    await _load();
  }

  Future<void> _persist(
    IptvPlaylist playlist,
    List<IptvChannel> channels,
  ) async {
    await IptvDatabaseService.instance.upsertPlaylist(playlist);
    await IptvDatabaseService.instance.replaceChannels(playlist.id, channels);
    await _load();
  }

  String _playlistNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        return segments.last
            .replaceAll(RegExp(r'\.m3u8?$', caseSensitive: false), '');
      }
      return uri.host.isEmpty ? url : uri.host;
    } catch (_) {
      return 'Playlist';
    }
  }

  String _fileNameFromPath(String path) {
    final segments = path.split('/');
    final name = segments.last.split('\\').last;
    return name.replaceAll(RegExp(r'\.m3u8?$', caseSensitive: false), '');
  }
}

// ═══════════════════════════════════════════════════════
// Channels per playlist (family)
// ═══════════════════════════════════════════════════════

class IptvChannelsState {
  final bool isLoading;
  final List<IptvChannel> channels;
  final List<String> groups;
  final String selectedGroup;
  final String searchQuery;
  final String? error;

  const IptvChannelsState({
    this.isLoading = true,
    this.channels = const [],
    this.groups = const [],
    this.selectedGroup = '',
    this.searchQuery = '',
    this.error,
  });

  IptvChannelsState copyWith({
    bool? isLoading,
    List<IptvChannel>? channels,
    List<String>? groups,
    String? selectedGroup,
    String? searchQuery,
    String? error,
  }) {
    return IptvChannelsState(
      isLoading: isLoading ?? this.isLoading,
      channels: channels ?? this.channels,
      groups: groups ?? this.groups,
      selectedGroup: selectedGroup ?? this.selectedGroup,
      searchQuery: searchQuery ?? this.searchQuery,
      error: error ?? this.error,
    );
  }

  List<IptvChannel> get visibleChannels {
    if (searchQuery.trim().isNotEmpty) return channels;
    if (selectedGroup.isEmpty) return channels;
    final group = selectedGroup == 'Ungrouped' ? '' : selectedGroup;
    return channels.where((c) => c.group == group).toList();
  }
}

final iptvChannelsProvider =
    NotifierProvider.family<IptvChannelsNotifier, IptvChannelsState, String>(
  (playlistId) => IptvChannelsNotifier(playlistId),
);

class IptvChannelsNotifier extends Notifier<IptvChannelsState> {
  IptvChannelsNotifier(this.playlistId);

  final String playlistId;

  bool get mounted => true;

  @override
  IptvChannelsState build() {
    Future.microtask(refresh);
    return const IptvChannelsState();
  }

  Future<void> refresh() async {
    state = IptvChannelsState(isLoading: true, channels: state.channels);
    try {
      final channels = await IptvDatabaseService.instance
          .getChannels(playlistId);
      final groups = await IptvDatabaseService.instance.getGroups(playlistId);
      if (mounted) {
        state = IptvChannelsState(
          isLoading: false,
          channels: channels,
          groups: groups,
          selectedGroup: state.selectedGroup,
        );
      }
    } catch (e) {
      if (mounted) {
        state = IptvChannelsState(
          isLoading: false,
          channels: state.channels,
          error: 'Failed to load channels',
        );
      }
    }
  }

  void selectGroup(String group) {
    state = state.copyWith(selectedGroup: group, searchQuery: '');
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchQuery: '');
      return;
    }
    final results = await IptvDatabaseService.instance
        .searchChannels(playlistId, query.trim());
    state = state.copyWith(searchQuery: query.trim(), channels: results);
  }

  Future<void> toggleFavorite(String channelId) async {
    await IptvDatabaseService.instance.toggleFavoriteChannel(channelId);
    await refresh();
  }
}

// ═══════════════════════════════════════════════════════
// Playback helper
// ═══════════════════════════════════════════════════════

/// Plays a channel (or list of channels) using the existing media stack.
/// Video channels go through media_kit (VideoPlayerLauncher); audio-only
/// channels go through the audio handler (just_audio + mini player).
class IptvPlaybackHelper {
  IptvPlaybackHelper._();

  static Future<void> play(
    WidgetRef ref, {
    required List<IptvChannel> channels,
    required int index,
    BuildContext? context,
    String playlistName = 'IPTV',
  }) async {
    if (channels.isEmpty) return;
    final current = channels[index];

    if (current.audioOnly) {
      final mediaFiles = _toMediaFiles(channels);
      final file = mediaFiles[index];
      await AudioPlaybackHelper.playAudio(
        ref,
        file,
        mediaFiles,
        startIndex: index,
      );
      return;
    }

    if (context != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => IptvPlayerScreen(
            channels: channels,
            playlistName: playlistName,
            startIndex: index,
          ),
        ),
      );
    } else {
      final nav = rootNavigatorKey.currentState;
      await nav?.push(
        MaterialPageRoute<void>(
          builder: (_) => IptvPlayerScreen(
            channels: channels,
            playlistName: playlistName,
            startIndex: index,
          ),
        ),
      );
    }
  }

  static List<MediaFile> _toMediaFiles(List<IptvChannel> channels) {
    return channels
        .map(
          (c) => MediaFile(
            id: c.id,
            name: c.displayName,
            path: c.url,
            type: c.audioOnly ? MediaType.audio : MediaType.video,
            size: 0,
            dateModified: DateTime.now(),
            mimeType: c.audioOnly
                ? 'audio/*'
                : 'application/vnd.apple.mpegurl',
            thumbnailPath: c.logo,
            duration: null,
            parentFolder: c.group,
          ),
        )
        .toList();
  }
}