import '../models/iptv_models.dart';

/// Parses M3U / M3U8 playlist text into [IptvChannel]s.
class M3uParser {
  M3uParser._();

  static const List<String> _audioExtensions = [
    '.mp3',
    '.aac',
    '.m4a',
    '.ogg',
    '.oga',
    '.flac',
    '.wav',
    '.wma',
    '.opus',
    '.ac3',
    '.aiff',
  ];

  /// Parses raw playlist content. Channels that fail to resolve a URL are
  /// skipped. Returns an empty list for malformed content (no crash).
  /// When [defaultLanguage] is provided, channels without a `tvg-language`
  /// attribute inherit it (useful for per-language iptv-org playlists).
  static List<IptvChannel> parse({
    required String content,
    required String playlistId,
    String? defaultLanguage,
  }) {
    final channels = <IptvChannel>[];
    if (content.trim().isEmpty) return channels;

    final lines = content.split('\n');

    String? pendingName;
    String? pendingLogo;
    String pendingGroup = '';
    String? pendingTvgId;
    String? pendingTvgName;
    String? pendingCountry;
    String? pendingLanguage;
    int position = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        // #EXTINF:-1 tvg-id="x" tvg-name="y" tvg-logo="z" group-title="g" ,Name
        final commaIdx = _findUnquotedComma(line);
        final metaPart = commaIdx > 0 ? line.substring(0, commaIdx) : line;
        final namePart = commaIdx > 0 ? line.substring(commaIdx + 1).trim() : '';

        pendingName = _decode(namePart);
        final attrs = _parseAttributes(metaPart);
        pendingLogo = _nullIfEmpty(_unquote(attrs['tvg-logo'] ?? attrs['logo']));
        final groupTitle = attrs['group-title'];
        if (groupTitle != null && groupTitle.isNotEmpty) {
          pendingGroup = _decode(_unquote(groupTitle));
        }
        pendingTvgId = _unquote(attrs['tvg-id']);
        pendingTvgName = _decode(_unquote(attrs['tvg-name'] ?? ''));
        pendingCountry = _decode(_unquote(attrs['tvg-country'] ?? ''));
        pendingLanguage = _decode(_unquote(attrs['tvg-language'] ?? ''));
        continue;
      }

      if (line.startsWith('#EXTGRP:')) {
        // Older group syntax: #EXTGRP:GroupName
        pendingGroup = line.substring(8).trim();
        continue;
      }

      if (line.startsWith('#EXTVLCOPT:') ||
          line.startsWith('#EXTCONTOPT:') ||
          line.startsWith('#KODIPROP:')) {
        continue;
      }

      if (line.startsWith('#')) {
        continue;
      }

      // A URL line — resolves to a channel.
      final url = line;
      if (!_isUsableUrl(url)) {
        continue;
      }

      final name = (pendingName == null || pendingName.isEmpty)
          ? ((pendingTvgName == null || pendingTvgName.isEmpty)
              ? _nameFromUrl(url)
              : pendingTvgName)
          : pendingName;

      final tvgName = (pendingTvgName == null || pendingTvgName.isEmpty)
          ? null
          : pendingTvgName;

      final channel = IptvChannel(
        id: iptvChannelId(playlistId, url),
        playlistId: playlistId,
        name: name,
        url: url,
        logo: pendingLogo,
        group: pendingGroup.isEmpty ? 'Ungrouped' : pendingGroup,
        tvgId: pendingTvgId,
        tvgName: tvgName,
        country: pendingCountry,
        language:
            (pendingLanguage == null || pendingLanguage.isEmpty)
                ? defaultLanguage
                : pendingLanguage,
        audioOnly: _isAudioUrl(url),
        position: position++,
      );
      channels.add(channel);

      pendingName = null;
      pendingLogo = null;
      pendingGroup = '';
      pendingTvgId = null;
      pendingTvgName = null;
      pendingCountry = null;
      pendingLanguage = null;
    }

    return channels;
  }

  static bool _isUsableUrl(String url) {
    if (url.startsWith('rtsp://') ||
        url.startsWith('rtmp://') ||
        url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('file://') ||
        url.startsWith('mms://')) {
      return true;
    }
    // Relative / protocol-less URLs are common in Xtream playlists.
    if (url.contains('.m3u8') ||
        url.contains('.m3u') ||
        url.contains('.ts') ||
        url.contains('/live/') ||
        url.contains('.mp4') ||
        url.contains('.mp3')) {
      return true;
    }
    return false;
  }

  static bool _isAudioUrl(String url) {
    final lower = url.toLowerCase();
    return _audioExtensions.any((e) => lower.contains(e));
  }

  static String _nameFromUrl(String url) {
    final path = url.split('?').first;
    final segments = path.split('/');
    if (segments.isNotEmpty) {
      final last = _decode(segments.last);
      if (last.isNotEmpty) return last;
    }
    return url;
  }

  /// Finds the index of the first comma that is NOT inside a quoted value.
  /// EXTINF values such as http-user-agent may contain commas.
  static int _findUnquotedComma(String line) {
    var inQuote = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuote = !inQuote;
      } else if (c == ',' && !inQuote) {
        return i;
      }
    }
    return -1;
  }

  /// Parses `key="value" key2=value2` pairs from an EXTINF line.
  static Map<String, String> _parseAttributes(String raw) {
    final map = <String, String>{};
    final re = RegExp(r'([\w\-]+)=("([^"]*)"|([^\s]+))');
    for (final m in re.allMatches(raw)) {
      map[m.group(1)!.toLowerCase()] = m.group(3) ?? m.group(4) ?? '';
    }
    return map;
  }

  static String? _nullIfEmpty(String value) {
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  static String _unquote(String? value) {
    if (value == null) return '';
    var v = value.trim();
    if (v.length >= 2 &&
        ((v.startsWith('"') && v.endsWith('"')) ||
            (v.startsWith("'") && v.endsWith("'")))) {
      v = v.substring(1, v.length - 1);
    }
    return v;
  }

  static String _decode(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}

/// Builds XTream Codes API URLs from server credentials.
class XtreamClient {
  XtreamClient._();

  /// Server URL like `http://host:port` (no trailing slash).
  static String normalizeServer(String server) {
    var s = server.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static Uri playerApiUri({
    required String server,
    required String username,
    required String password,
  }) {
    final base = normalizeServer(server);
    return Uri.parse(
      '$base/player_api.php?username=$username&password=$password',
    );
  }

  /// M3U export endpoint — gives us a full playlist incl. groups & logos.
  static Uri m3uUri({
    required String server,
    required String username,
    required String password,
  }) {
    final base = normalizeServer(server);
    return Uri.parse(
      '$base/get.php?username=$username&password=$password&type=m3u_plus&output=ts',
    );
  }

  /// Live-stream category list from the player API.
  static Uri liveCategoriesUri({
    required String server,
    required String username,
    required String password,
  }) {
    final base = normalizeServer(server);
    return Uri.parse(
      '$base/player_api.php?username=$username&password=$password&action=get_live_categories',
    );
  }

  static Uri liveStreamsUri({
    required String server,
    required String username,
    required String password,
  }) {
    final base = normalizeServer(server);
    return Uri.parse(
      '$base/player_api.php?username=$username&password=$password&action=get_live_streams',
    );
  }

  /// Validates credentials via the player API (non-empty auth info check).
  static bool hasCredentials({
    required String server,
    required String username,
    required String password,
  }) {
    return server.trim().isNotEmpty &&
        username.trim().isNotEmpty &&
        password.trim().isNotEmpty;
  }
}