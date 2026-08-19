import 'dart:async';

import 'package:http/http.dart' as http;

/// Fetches and parses AdGuard's third-party advertising-network domain list
/// (`adservers.txt`) into a set of bare hostnames suitable for host matching.
///
/// The raw file uses AdGuard rule syntax: `||host^` rules, `$`-modifiers,
/// leading-dot suffix rules (`.host^`), bare hostnames, comments (`!`), and
/// occasionally IP / regex `$network` rules or `!#include` directives.
///
/// Only clean hostname rules are kept. Wildcard patterns (`host*.com`),
/// exception rules (`@@`), URL-path rules, pure-IP lines and regex network
/// rules are dropped — they cannot be expressed as a plain host match.
class AdBlockListService {
  AdBlockListService._();

  static const adserversUrl =
      'https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/refs/heads/master/BaseFilter/sections/adservers.txt';

  static const _timeout = Duration(seconds: 20);

  /// In-memory cache shared across browser screen instances for the app run.
  static Set<String>? _cache;

  static final RegExp _hostRe = RegExp(r'^[a-z0-9][a-z0-9\-]*(\.[a-z0-9\-]+)+$');
  static final RegExp _ipRe = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

  /// Returns the parsed ad-server hostnames.
  ///
  /// Results are cached in memory for the lifetime of the app run. On any
  /// failure (offline, timeout, non-200) the last good set is returned, or an
  /// empty set if nothing has ever been fetched.
  static Future<Set<String>> fetchAdservers() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final resp = await http
          .get(Uri.parse(adserversUrl))
          .timeout(_timeout);
      if (resp.statusCode != 200) return const {};
      final parsed = _parse(resp.body);
      if (parsed.isNotEmpty) _cache = parsed;
      return parsed;
    } catch (_) {
      return const {};
    }
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