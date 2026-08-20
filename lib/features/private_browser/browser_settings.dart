import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persisted privacy browser control settings.
///
/// Values survive between browser sessions; the toggles themselves live in
/// the `BrowserSettingsScreen` and on the browser home page.
enum TrackerBlockMode {
  normal('normal', 'Normal', 'Basic blocklist — most common trackers'),
  advanced(
    'advanced',
    'Advanced',
    'Extended blocklist — more ad & tracking networks',
  ),
  enhanced(
    'enhanced',
    'Enhanced',
    'Aggressive — also blocks ad-detectable URLs',
  );

  const TrackerBlockMode(this.key, this.label, this.description);

  final String key;
  final String label;
  final String description;

  static TrackerBlockMode fromKey(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'advanced':
        return TrackerBlockMode.advanced;
      case 'enhanced':
        return TrackerBlockMode.enhanced;
      default:
        return TrackerBlockMode.normal;
    }
  }
}

class BrowserSettings {
  BrowserSettings._();

  static final BrowserSettings instance = BrowserSettings._();

  static const _storage = FlutterSecureStorage();

  static const _httpsOnlyKey = 'browser_https_only';
  static const _blockTrackersKey = 'browser_tracker_mode';
  static const _javaScriptKey = 'browser_javascript';
  static const _blockPopupsKey = 'browser_block_popups';
  static const _pullToRefreshKey = 'browser_pull_to_refresh';
  static const _allowAutoPlayKey = 'browser_allow_autoplay';

  bool httpsOnly = true;
  TrackerBlockMode trackerMode = TrackerBlockMode.normal;
  bool javaScriptEnabled = true;
  bool blockPopups = true;
  bool pullToRefresh = true;
  bool allowAutoPlay = true;

  /// Reads every preference from secure storage (fast, idempotent).
  Future<void> load() async {
    httpsOnly = await _readBool(_httpsOnlyKey, true);
    trackerMode = TrackerBlockMode.fromKey(
      await _readString(_blockTrackersKey, 'normal'),
    );
    javaScriptEnabled = await _readBool(_javaScriptKey, true);
    blockPopups = await _readBool(_blockPopupsKey, true);
    pullToRefresh = await _readBool(_pullToRefreshKey, true);
    allowAutoPlay = await _readBool(_allowAutoPlayKey, true);
  }

  Future<void> setHttpsOnly(bool value) async {
    httpsOnly = value;
    await _write(_httpsOnlyKey, value.toString());
  }

  Future<void> setTrackerMode(TrackerBlockMode value) async {
    trackerMode = value;
    await _write(_blockTrackersKey, value.key);
  }

  Future<void> setJavaScriptEnabled(bool value) async {
    javaScriptEnabled = value;
    await _write(_javaScriptKey, value.toString());
  }

  Future<void> setBlockPopups(bool value) async {
    blockPopups = value;
    await _write(_blockPopupsKey, value.toString());
  }

  Future<void> setPullToRefresh(bool value) async {
    pullToRefresh = value;
    await _write(_pullToRefreshKey, value.toString());
  }

  Future<void> setAllowAutoPlay(bool value) async {
    allowAutoPlay = value;
    await _write(_allowAutoPlayKey, value.toString());
  }

  Future<bool> _readBool(String key, bool fallback) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return fallback;
      return raw.toLowerCase() == 'true';
    } catch (e) {
      return fallback;
    }
  }

  Future<String?> _readString(String key, String fallback) async {
    try {
      return await _storage.read(key: key) ?? fallback;
    } catch (e) {
      return fallback;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('BrowserSettings write error: $e');
    }
  }
}
