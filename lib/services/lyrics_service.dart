import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/lyric_line.dart';

class LyricsService {
  LyricsService._();
  static final LyricsService instance = LyricsService._();

  // In-memory cache: "title|artist" -> LyricsData
  final Map<String, LyricsData> _cache = {};

  /// Audio file extensions stripped from a title that is really a filename.
  static final RegExp _extensionPattern = RegExp(
    r'\.(mp3|m4a|aac|flac|wav|ogg|opus|wma|amr|aiff|aif|m4b|m4p|m4r|3gp|ape|mid|midi|caf|mka|oga|mp2|wv|spx|tta|dsf|dff|ac3|dts|vorbis)$',
    caseSensitive: false,
  );

  /// Clean song name / title from common tags, extensions, file artefacts
  static String cleanQuery(String raw) {
    String cleaned = raw;

    // Remove file extension
    cleaned = cleaned.replaceAll(_extensionPattern, '');

    // Remove leading track numbers like "01 - ", "01. ", "01 "
    cleaned = cleaned.replaceAll(RegExp(r'^\d+[\s\.\-_]+'), '');

    // Remove common promotional / video tags in brackets or parentheses
    cleaned = cleaned.replaceAll(
      RegExp(
        r'[\(\[\{](?:official\s*(?:video|audio|music\s*video|lyric\s*video)?|lyrical|video\s*song|full\s*song|audio\s*song|320kbps|128kbps|pagalworld|djpunjab|ringtone|remix|from\s*["\u201c\u201d\w\s]+)[\)\]\}]',
        caseSensitive: false,
      ),
      '',
    );

    // Remove feat / ft
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:feat|ft)\.?\s+.*$', caseSensitive: false), '');

    // Strip any embedded URL / domain (e.g. "Song www.abc.com")
    cleaned = cleaned.replaceAll(_urlPattern, '');

    // Collapse multiple spaces & trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned.isNotEmpty ? cleaned : raw.trim();
  }

  /// Matches bare domains / URLs (e.g. www.example.com, example.org,
  /// https://site.in) or placeholder metadata ("Unknown Track/Artist/Album").
  static final RegExp _urlPattern = RegExp(
    r'(?:https?://|www\.)|\b[\w-]+\.(?:com|org|net|in|io|co|info|tv|xyz|site|me|us|uk|ru|de|fr|jp|cn|au|ca|biz|eu|download|zip|rar)(?:[/\s]|$)',
    caseSensitive: false,
  );

  /// Returns true when metadata is a placeholder or looks like a URL, so the
  /// lyrics API is not queried with meaningless values.
  static bool isPlaceholderOrUrl(String? value) {
    if (value == null) return true;
    final v = value.trim();
    if (v.isEmpty) return true;
    final lower = v.toLowerCase();
    if (lower == 'unknown track' ||
        lower == 'unknown title' ||
        lower == 'unknown artist' ||
        lower == 'unknown album' ||
        lower == 'unknown') {
      return true;
    }
    return _urlPattern.hasMatch(v);
  }

  /// Primary fetch method using LRCLIB.
  Future<LyricsData?> fetchLyrics({
    required String rawTitle,
    String? rawArtist,
    Duration? duration,
    bool force = false,
  }) async {
    final title = cleanQuery(rawTitle);
    final artist = (rawArtist != null && !isPlaceholderOrUrl(rawArtist) && rawArtist.toLowerCase() != 'unknown artist')
        ? cleanQuery(rawArtist)
        : null;

    // Skip the lookup entirely when the metadata is meaningless (placeholder
    // like "Unknown Track"/"Unknown Artist" or a promotional URL).
    if (isPlaceholderOrUrl(title)) {
      return null;
    }

    final cacheKey = '$title|${artist ?? ""}';
    if (!force && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    final result = await _fetchFromLrcLib(title: title, artist: artist, duration: duration);

    if (result != null && result.isNotEmpty) {
      _cache[cacheKey] = result;
      return result;
    }

    return null;
  }

  /// LRCLIB API Integration (https://lrclib.net/docs)
  ///
  /// Doc requirements enforced here:
  ///  - Lyrics are always resolved through `/api/search` (max 20 results,
  ///    no pagination). The free-text `q` param matches keywords in ANY field
  ///    (title, artist, album) and takes precedence over the structured
  ///    `track_name`/`artist_name` params — the same search the LRCLIB website
  ///    uses, so results match what users see there.
  ///  - Requests must identify the client via User-Agent.
  ///  - On 429 Too Many Requests, honor the Retry-After header.
  Future<LyricsData?> _fetchFromLrcLib({
    required String title,
    String? artist,
    Duration? duration,
  }) async {
    const userAgent = 'SlideUpMusicPlayer/1.0.0 (https://github.com)';
    const timeout = Duration(seconds: 6);

    try {
      // /api/search requires at least ONE of `q` OR `track_name`. Using `q`
      // (title + artist keywords) mirrors the LRCLIB website search.
      final q = artist != null && artist.isNotEmpty ? '$title $artist' : title;
      final searchUri = Uri.https('lrclib.net', '/api/search', {
        'q': q,
      });

      debugPrint('🎤 LRCLIB request: $searchUri');
      final searchResponse = await http.get(searchUri, headers: {
        'User-Agent': userAgent,
      }).timeout(timeout);
      debugPrint(
        '🎤 LRCLIB response: status=${searchResponse.statusCode} '
        'body=${searchResponse.body.length} chars',
      );

      if (searchResponse.statusCode == 200) {
        final List results = jsonDecode(searchResponse.body) as List;
        if (results.isNotEmpty) {
          // Find first result with synced lyrics or plain lyrics.
          // Prefer one whose duration matches (within ±2s) when provided.
          List<dynamic> ordered = results;
          if (duration != null && duration.inSeconds > 0) {
            ordered = results.toList()
              ..sort((a, b) {
                final aDur = ((a as Map<String, dynamic>)['duration'] ?? 0) as int;
                final bDur = ((b as Map<String, dynamic>)['duration'] ?? 0) as int;
                final aDiff = (aDur - duration.inSeconds).abs();
                final bDiff = (bDur - duration.inSeconds).abs();
                return aDiff.compareTo(bDiff);
              });
          }
          for (final item in ordered) {
            final parsed = _parseLrcLibResponse(item as Map<String, dynamic>);
            if (parsed != null && parsed.isNotEmpty) {
              return parsed;
            }
          }
        }
      } else if (searchResponse.statusCode == 429) {
        // Honoring Retry-After as required by the LRCLIB docs.
        final retryAfter = searchResponse.headers['retry-after'];
        final seconds = int.tryParse(retryAfter ?? '');
        if (seconds != null && seconds > 0 && seconds <= 30) {
          await Future<void>.delayed(Duration(seconds: seconds));
        }
      }
    } catch (e) {
      debugPrint('LRCLIB fetch error: $e');
    }
    return null;
  }

  LyricsData? _parseLrcLibResponse(Map<String, dynamic> data) {
    final syncedLyrics = data['syncedLyrics'] as String?;
    final plainLyrics = data['plainLyrics'] as String?;
    final trackName = data['trackName'] as String?;
    final artistName = data['artistName'] as String?;

    if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
      final lines = parseLrc(syncedLyrics);
      if (lines.isNotEmpty) {
        return LyricsData(
          isSynced: true,
          lines: lines,
          plainLyrics: plainLyrics,
          source: 'LRCLIB (Synced)',
          trackName: trackName,
          artistName: artistName,
        );
      }
    }

    if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
      final lines = _plainTextToLines(plainLyrics);
      return LyricsData(
        isSynced: false,
        lines: lines,
        plainLyrics: plainLyrics,
        source: 'LRCLIB (Plain)',
        trackName: trackName,
        artistName: artistName,
      );
    }

    return null;
  }

  /// Parse standard LRC string format: [mm:ss.xx] Lyric text
  static List<LyricLine> parseLrc(String lrcContent) {
    final List<LyricLine> result = [];
    final lines = lrcContent.split('\n');

    // RegEx for timestamp format: [01:23.45] or [01:23.456] or [01:23]
    final regExp = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:[\.:](\d{1,3}))?\]');

    for (var rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final matches = regExp.allMatches(trimmed);
      if (matches.isEmpty) continue;

      // The text is after the last timestamp match
      final lastMatch = matches.last;
      final text = trimmed.substring(lastMatch.end).trim();

      for (final match in matches) {
        final min = int.tryParse(match.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(match.group(2) ?? '0') ?? 0;
        final fractionStr = match.group(3) ?? '0';

        int ms = 0;
        if (fractionStr.length == 3) {
          ms = int.tryParse(fractionStr) ?? 0;
        } else if (fractionStr.length == 2) {
          ms = (int.tryParse(fractionStr) ?? 0) * 10;
        } else if (fractionStr.length == 1) {
          ms = (int.tryParse(fractionStr) ?? 0) * 100;
        }

        final duration = Duration(minutes: min, seconds: sec, milliseconds: ms);
        result.add(LyricLine(time: duration, text: text));
      }
    }

    // Sort by timestamp
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  static List<LyricLine> _plainTextToLines(String plainText) {
    return plainText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => LyricLine(time: Duration.zero, text: l))
        .toList();
  }
}
