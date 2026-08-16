import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'm3u_parser.dart';

/// Downloads raw playlist content (M3U URL or XTream server) over HTTP.
class IptvDatasource {
  IptvDatasource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 30);

  /// Downloads a remote M3U/M3U8 playlist and returns its text content.
  /// Throws [IptvNetworkException] on failure.
  Future<String> fetchM3uUrl(String url) async {
    try {
      final resp = await _client
          .get(Uri.parse(url), headers: const {
            'User-Agent': 'Mozilla/5.0 SlideUp-IPTV',
            'Accept': '*/*',
          })
          .timeout(_timeout);

      if (resp.statusCode != 200) {
        throw IptvNetworkException(
          'Server responded with ${resp.statusCode}',
        );
      }
      return _decodeBody(resp.bodyBytes, resp.headers['content-type']);
    } catch (e) {
      if (e is IptvNetworkException) rethrow;
      throw IptvNetworkException('Failed to download playlist: $e');
    }
  }

  /// Fetches a local M3U file's content.
  Future<String> readLocalFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw IptvNetworkException('File not found: $path');
      }
      return await file.readAsString(encoding: utf8);
    } catch (e) {
      if (e is IptvNetworkException) rethrow;
      throw IptvNetworkException('Failed to read file: $e');
    }
  }

  /// Downloads the XTream m3u_plus export for the given credentials.
  Future<String> fetchXtreamM3u({
    required String server,
    required String username,
    required String password,
  }) {
    final uri = XtreamClient.m3uUri(
      server: server,
      username: username,
      password: password,
    );
    return fetchM3uUrl(uri.toString());
  }

  String _decodeBody(List<int> bytes, String? contentType) {
    // Prefer UTF-8; fall back to latin1 for legacy playlists.
    if (contentType != null && contentType.toLowerCase().contains('charset')) {
      final charsetMatch = RegExp(r'charset=([\w\-]+)').firstMatch(contentType);
      final charset = charsetMatch?.group(1)?.toLowerCase();
      if (charset == 'latin-1' || charset == 'latin1' || charset == 'iso-8859-1') {
        return latin1.decode(bytes);
      }
    }
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return latin1.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
    }
  }

  void close() => _client.close();
}

class IptvNetworkException implements Exception {
  final String message;
  IptvNetworkException(this.message);

  @override
  String toString() => message;
}