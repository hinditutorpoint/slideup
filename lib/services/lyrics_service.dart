import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/lyric_line.dart';

class LyricsService {
  LyricsService._();
  static final LyricsService instance = LyricsService._();

  // In-memory cache: "title|artist" -> LyricsData
  final Map<String, LyricsData> _cache = {};

  /// Clean song name / title from common tags, extensions, file artefacts
  static String cleanQuery(String raw) {
    String cleaned = raw;

    // Remove file extension
    cleaned = cleaned.replaceAll(RegExp(r'\.(mp3|m4a|aac|flac|wav|ogg|opus)$', caseSensitive: false), '');

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

    // Collapse multiple spaces & trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned.isNotEmpty ? cleaned : raw.trim();
  }

  /// Primary fetch method: Tries LRCLIB first, falls back to JioSaavn API for Bollywood/Indian tracks.
  Future<LyricsData?> fetchLyrics({
    required String rawTitle,
    String? rawArtist,
    Duration? duration,
  }) async {
    final title = cleanQuery(rawTitle);
    final artist = (rawArtist != null && rawArtist.toLowerCase() != 'unknown artist')
        ? cleanQuery(rawArtist)
        : null;

    final cacheKey = '$title|${artist ?? ""}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // 1. Try LRCLIB (Best for Synced Karaoke Lyrics)
    LyricsData? result = await _fetchFromLrcLib(title: title, artist: artist, duration: duration);

    // 2. If no synced lyrics or not found, try JioSaavn API fallback (Best for Bollywood)
    if (result == null || result.isEmpty) {
      result = await _fetchFromSaavn(title: title, artist: artist);
    }

    if (result != null && result.isNotEmpty) {
      _cache[cacheKey] = result;
      return result;
    }

    return null;
  }

  /// LRCLIB API Integration (https://lrclib.net)
  Future<LyricsData?> _fetchFromLrcLib({
    required String title,
    String? artist,
    Duration? duration,
  }) async {
    try {
      // Step A: Exact get request
      final queryParams = <String, String>{
        'track_name': title,
      };
      if (artist != null && artist.isNotEmpty) {
        queryParams['artist_name'] = artist;
      }
      if (duration != null && duration.inSeconds > 0) {
        queryParams['duration'] = duration.inSeconds.toString();
      }

      final uri = Uri.https('lrclib.net', '/api/get', queryParams);
      final response = await http.get(uri, headers: {
        'User-Agent': 'SlideUpMusicPlayer/1.0.0 (https://github.com)',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final lyrics = _parseLrcLibResponse(data);
        if (lyrics != null && lyrics.isNotEmpty) {
          return lyrics;
        }
      }

      // Step B: Search request fallback on LRCLIB
      final searchUri = Uri.https('lrclib.net', '/api/search', {
        'q': artist != null && artist.isNotEmpty ? '$title $artist' : title,
      });

      final searchResponse = await http.get(searchUri, headers: {
        'User-Agent': 'SlideUpMusicPlayer/1.0.0 (https://github.com)',
      }).timeout(const Duration(seconds: 5));

      if (searchResponse.statusCode == 200) {
        final List results = jsonDecode(searchResponse.body) as List;
        if (results.isNotEmpty) {
          // Find first result with synced lyrics or plain lyrics
          for (final item in results) {
            final parsed = _parseLrcLibResponse(item as Map<String, dynamic>);
            if (parsed != null && parsed.isNotEmpty) {
              return parsed;
            }
          }
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

  /// JioSaavn Public API Integration for Indian & Bollywood Tracks
  Future<LyricsData?> _fetchFromSaavn({
    required String title,
    String? artist,
  }) async {
    const endpoints = [
      'https://saavn.dev/api',
      'https://saavn.me/api',
    ];

    for (final base in endpoints) {
      try {
        final query = artist != null && artist.isNotEmpty ? '$title $artist' : title;
        final searchUrl = Uri.parse('$base/search/songs?query=${Uri.encodeComponent(query)}&limit=5');

        final response = await http.get(searchUrl).timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) continue;

        final body = jsonDecode(response.body);
        final dynamic resultsData = body['data'];
        final List? songs = resultsData is Map ? resultsData['results'] as List? : (resultsData is List ? resultsData : null);

        if (songs == null || songs.isEmpty) continue;

        for (final song in songs) {
          final songId = song['id']?.toString();
          final bool hasLyrics = song['hasLyrics'] == 'true' || song['hasLyrics'] == true || song['lyrics'] != null;

          if (songId != null && hasLyrics) {
            // Check if lyrics are directly included
            if (song['lyrics'] != null && song['lyrics'].toString().isNotEmpty) {
              final rawLyrics = _cleanHtml(song['lyrics'].toString());
              return LyricsData(
                isSynced: false,
                lines: _plainTextToLines(rawLyrics),
                plainLyrics: rawLyrics,
                source: 'JioSaavn',
                trackName: song['name'] ?? song['title'],
                artistName: song['primaryArtists'] ?? song['artist'],
              );
            }

            // Otherwise fetch lyrics by song ID
            final lyricsUrl = Uri.parse('$base/lyrics?id=$songId');
            final lyricsResp = await http.get(lyricsUrl).timeout(const Duration(seconds: 4));

            if (lyricsResp.statusCode == 200) {
              final lBody = jsonDecode(lyricsResp.body);
              final lData = lBody['data'];
              final rawLyricText = lData is Map ? (lData['lyrics'] as String?) : (lData as String?);

              if (rawLyricText != null && rawLyricText.isNotEmpty) {
                final cleanedLyrics = _cleanHtml(rawLyricText);
                return LyricsData(
                  isSynced: false,
                  lines: _plainTextToLines(cleanedLyrics),
                  plainLyrics: cleanedLyrics,
                  source: 'JioSaavn',
                  trackName: song['name'] ?? song['title'],
                  artistName: song['primaryArtists'] ?? song['artist'],
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('JioSaavn fetch error via $base: $e');
      }
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

  static String _cleanHtml(String htmlString) {
    return htmlString
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }
}
