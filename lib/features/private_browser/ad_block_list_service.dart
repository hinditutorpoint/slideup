import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Fetches, parses and persists AdGuard's third-party advertising-network
/// domain list (`adservers.txt`) into a set of bare hostnames suitable for
/// host matching.
///
/// The raw file uses AdGuard rule syntax: `||host^` rules, `$`-modifiers,
/// leading-dot suffix rules (`.host^`), bare hostnames, comments (`!`), and
/// occasionally IP / regex `$network` rules or `!#include` directives.
///
/// Only clean hostname rules are kept. Wildcard patterns (`host*.com`),
/// exception rules (`@@`), URL-path rules, pure-IP lines and regex network
/// rules are dropped — they cannot be expressed as a plain host match.
///
/// The parsed list is cached in memory and mirrored to a local file so the
/// browser can load it without re-downloading on every start. The
/// `BrowserSettingsScreen` exposes an explicit "Check for updates" flow so
/// the user controls when the database is refreshed.
class AdBlockListService {
  AdBlockListService._();

  static const adserversUrl =
      'https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/refs/heads/master/BaseFilter/sections/adservers.txt';

  static const _timeout = Duration(seconds: 20);

  /// In-memory cache shared across browser screen instances for the app run.
  static Set<String>? _cache;

  static final RegExp _hostRe = RegExp(r'^[a-z0-9][a-z0-9\-]*(\.[a-z0-9\-]+)+$');
  static final RegExp _ipRe = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  static const _hostsFileName = 'adguard_adservers_hosts.txt';
  static const _metaFileName = 'adguard_adservers_meta.json';

  /// Returns the ad-server hostnames to use for blocking.
  ///
  /// Priority: in-memory cache, then the locally-stored database (avoids a
  /// network request on every browser start). Only when neither exists does
  /// it fetch the remote list — and the result is persisted locally so the
  /// next start is served from disk.
  static Future<Set<String>> fetchAdservers() async {
    final cached = _cache;
    if (cached != null) return cached;

    final local = await loadLocalAdservers();
    if (local.isNotEmpty) return local;

    try {
      final resp = await http
          .get(Uri.parse(adserversUrl))
          .timeout(_timeout);
      if (resp.statusCode != 200) return const {};
      final parsed = _parse(resp.body);
      if (parsed.isNotEmpty) {
        _cache = parsed;
        await saveLocalAdservers(parsed);
      }
      return parsed;
    } catch (_) {
      return const {};
    }
  }

  /// Loads the locally-stored database (from disk), if present.
  static Future<Set<String>> loadLocalAdservers() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final file = await _hostsFile();
      if (!await file.exists()) return const {};
      final hosts = file
          .readAsStringSync()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && _hostRe.hasMatch(l))
          .toSet();
      if (hosts.isNotEmpty) _cache = hosts;
      return hosts;
    } catch (e) {
      debugPrint('AdBlockListService load error: $e');
      return const {};
    }
  }

  /// Last time the local database was updated, or null if never.
  static Future<DateTime?> loadLastUpdated() async {
    try {
      final file = await _metaFile();
      if (!await file.exists()) return null;
      final map = jsonDecode(await file.readAsString());
      final raw = map['updated_at'];
      if (raw is String) {
        final dt = DateTime.tryParse(raw);
        if (dt != null) return dt.toLocal();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Persists a host set as the local database and updates the in-memory cache.
  static Future<void> saveLocalAdservers(
    Set<String> hosts, {
    DateTime? updatedAt,
  }) async {
    try {
      final file = await _hostsFile();
      await file.writeAsString(hosts.join('\n'));
      _cache = hosts;
      final meta = await _metaFile();
      await meta.writeAsString(
        jsonEncode({
          'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
          'count': hosts.length,
        }),
      );
    } catch (e) {
      debugPrint('AdBlockListService save error: $e');
    }
  }

  /// Checks the remote list against the local database.
  ///
  /// Returns the freshly-parsed remote hosts, the remote `Last-Modified`
  /// timestamp (may be null when the server omits it), and whether the remote
  /// list differs from what is stored locally (`changed`).
  static Future<({Set<String> hosts, DateTime? lastModified, bool changed})>
      checkForUpdate() async {
    final local = await loadLocalAdservers();
    try {
      final resp = await http
          .get(Uri.parse(adserversUrl))
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        return (hosts: local, lastModified: null, changed: false);
      }
      final parsed = _parse(resp.body);
      DateTime? lastModified;
      final lmRaw = resp.headers['last-modified'];
      if (lmRaw != null) {
        try {
          lastModified = HttpDate.parse(lmRaw).toLocal();
        } catch (_) {
          lastModified = null;
        }
      }
      final changed = !_sameHosts(parsed, local);
      return (hosts: parsed, lastModified: lastModified, changed: changed);
    } catch (_) {
      return (hosts: local, lastModified: null, changed: false);
    }
  }

  static bool _sameHosts(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final h in a) {
      if (!b.contains(h)) return false;
    }
    return true;
  }

  static Future<File> _hostsFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_hostsFileName');
  }

  static Future<File> _metaFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_metaFileName');
  }

  /// Converts one AdGuard rule line into a bare hostname, or null when the
  /// line is not a plain hostname rule.
  static String? _hostFromLine(String line) {
    var h = line.toLowerCase();
    if (h.startsWith('@@')) return null; // exception rule
    if (h.startsWith('||')) h = h.substring(2);
    if (h.startsWith('.')) h = h.substring(1); // `.host^` suffix rule
    // Strip the `^` anchor and everything after it.
    final caret = h.indexOf('^');
    if (caret != -1) h = h.substring(0, caret);
    // Strip `$modifiers`.
    final dollar = h.indexOf('\$');
    if (dollar != -1) h = h.substring(0, dollar);
    // Drop URL-path, wildcard, pure-IP and regex lines.
    if (h.contains('/') || h.contains('*')) return null;
    if (_ipRe.hasMatch(h)) return null;
    if (!_hostRe.hasMatch(h)) return null;
    return h;
  }

  static Set<String> _parse(String body) {
    final hosts = <String>{};
    for (final raw in body.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('!') || line.startsWith('#')) continue;
      final h = _hostFromLine(line);
      if (h != null) hosts.add(h);
    }
    return hosts;
  }
}