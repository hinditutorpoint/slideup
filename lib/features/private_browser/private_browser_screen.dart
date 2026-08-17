import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:uuid/uuid.dart';

import '../../../features/video_player/video_player_launcher.dart';
import '../../../helpers/audio_playback_helper.dart';
import '../../../models/media_file.dart';
import '../documents/screens/unified_reader_screen.dart';
import '../iptv/providers/iptv_providers.dart';
import '../iptv/screens/iptv_player_screen.dart';
import '../iptv/services/m3u_parser.dart';
import 'browser_settings.dart';
import 'browser_settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PLATFORM LIMITATIONS (read before modifying):
//
// flutter_inappwebview ^6.1.5, InAppWebViewSettings.incognito = true.
//
// Android (WebView):
//   incognito:true → WebView.setPrivateBrowsingEnabled(true).
//   The OS minimises persistence of cookies, localStorage, and cache for this
//   WebView instance. This IS NOT equivalent to Android Chrome Incognito which
//   uses a separate process and credential store.
//
// iOS (WKWebView):
//   The plugin uses an ephemeral WKWebViewConfiguration
//   (dataStore = .nonPersistent), preventing cookies and WebStorage from being
//   written to disk for this WKWebView instance.
//
// HTTPS-only:
//   Enforces HTTPS for main-frame navigations via shouldOverrideUrlLoading.
//   Sub-resource requests are NOT individually interceptable at the network
//   layer. Mixed content is blocked via mixedContentMode on Android.
//
// Tracker blocking:
//   ContentBlocker rules block known hostname-anchored tracker/ad domains.
//   This will NOT catch obfuscated domains not in the blocklist and is NOT
//   equivalent to uBlock Origin.
//
// Cookie/cache clearing:
//   CookieManager.deleteAllCookies(), WebStorageManager.deleteAllData(), and
//   InAppWebViewController.clearAllCache() are GLOBAL operations affecting
//   all WebViews in the app. They are ONLY called on explicit user action
//   and NEVER from dispose().
// ─────────────────────────────────────────────────────────────────────────────

/// Privacy-first in-app browser.
///
/// Private session mode uses [InAppWebViewSettings.incognito] to minimise
/// persistent browsing data on the device. In private mode the platform WebView
/// avoids persisting cookies, localStorage, and cache to disk.
/// History is kept only in memory and discarded when the screen closes.
///
/// See the file-level platform notes above for precise platform guarantees.
class PrivateBrowserScreen extends ConsumerStatefulWidget {
  final String? initialUrl;

  const PrivateBrowserScreen({super.key, this.initialUrl});

  @override
  ConsumerState<PrivateBrowserScreen> createState() => _PrivateBrowserScreenState();
}

// ─── Data model ───────────────────────────────────────────────────────────────

/// A browsing-history entry whose [title] can be updated after the page loads.
class _HistoryEntry {
  final String url;
  String? title;
  _HistoryEntry(this.url);
}

/// A media element (video/audio) found on the current page by the scanner.
class _ScannedMedia {
  final String url;
  final String title;
  final bool isVideo;
  _ScannedMedia({
    required this.url,
    required this.title,
    required this.isVideo,
  });
}

// ─── Tracker / ad-network hostname lists ─────────────────────────────────────

/// Core tracker and ad-network hostnames (Normal mode).
const _kTrackerHosts = <String>{
  'doubleclick.net',
  'google-analytics.com',
  'googlesyndication.com',
  'googletagmanager.com',
  'googleadservices.com',
  'scorecardresearch.com',
  'facebook.net',
  'connect.facebook.net',
  'adsrvr.org',
  'amazon-adsystem.com',
  'adnxs.com',
  'rubiconproject.com',
  'openx.net',
  'pubmatic.com',
  'criteo.com',
  'taboola.com',
  'outbrain.com',
  'quantserve.com',
  'krxd.net',
  'bidswitch.net',
  'serving-sys.com',
  'mookie1.com',
  'onetag.com',
  'rlcdn.com',
};

/// Extended ad and tracking networks (Advanced mode).
const _kAdvancedTrackerHosts = <String>{
  'ads.google.com',
  'pagead2.googlesyndication.com',
  'securepubads.g.doubleclick.net',
  'static.doubleclick.net',
  'adservice.google.com',
  'td.doubleclick.net',
  '2mdn.net',
  'adclick.g.doubleclick.net',
  'partner.googleadservices.com',
  'ads.twitter.com',
  'analytics.twitter.com',
  'ads.yahoo.com',
  'analytics.yahoo.com',
  'adserver.adtechus.com',
  'smartadserver.com',
  'casalemedia.com',
  'appnexus.com',
  'indexexchange.com',
  'triplelift.com',
  'sharethrough.com',
  'yieldmo.com',
  'adroll.com',
  'lijit.com',
  'contextweb.com',
  'spotxchange.com',
  'springserve.com',
};

/// Suspicious URL path segments (Enhanced mode only).
///
/// Words like `sponsor`, `affiliate`, `advert`, and `banner` are deliberately
/// EXCLUDED because they appear in many legitimate URLs.
const _kEnhancedPathSegments = <String>[
  '/ads/',
  '/adserver/',
  '/adframe/',
  '/adunit/',
  '/doubleclick/',
  '/pagead/',
  '/trackingpixel',
  '/beacon.js',
  '/beacon.gif',
  '/beacon.png',
  '/ad_unit',
  '/pop-under',
];

// ─── State ────────────────────────────────────────────────────────────────────

class _PrivateBrowserScreenState extends ConsumerState<PrivateBrowserScreen>
    with WidgetsBindingObserver {
  // Controllers / keys
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocus = FocusNode();
  InAppWebViewController? _controller;

  /// Replacing this key tears down the old InAppWebView and creates a fresh one.
  /// Used when [_incognito] is toggled — incognito cannot be changed on a live
  /// WebView and must be set at creation time.
  Key _webViewKey = UniqueKey();

  // Navigation state
  /// URL to load once the WebView controller becomes available.
  String? _pendingNavigationUrl;
  String? _currentUrl;
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  double _loadingProgress = 0;

  // History (in-memory only; never persisted to disk)
  final List<_HistoryEntry> _history = [];

  // Settings
  bool _httpsOnly = true;
  TrackerBlockMode _trackerMode = TrackerBlockMode.normal;
  bool _javaScriptEnabled = true;
  bool _blockPopups = true;
  bool _settingsReady = false;

  // UI state
  bool _incognito = true;

  /// True once [_cleanupAndPop] has started, preventing duplicate calls.
  bool _exitInProgress = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final initial = widget.initialUrl?.trim();
    if (initial != null && initial.isNotEmpty) {
      _pendingNavigationUrl = _normalizeAddress(initial);
      _currentUrl = _pendingNavigationUrl;
      _urlController.text = _pendingNavigationUrl!;
    }

    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _urlFocus.dispose();
    // No async work here. In incognito mode, the platform WebView handles
    // session cleanup when the widget is destroyed by the Flutter engine.
    // Explicit user-triggered cleanup lives in _clearSessionNow() and
    // _cleanupAndPop().
    super.dispose();
  }

  // ── Settings ─────────────────────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    await BrowserSettings.instance.load();
    if (!mounted) return;
    setState(() {
      _httpsOnly = BrowserSettings.instance.httpsOnly;
      _trackerMode = BrowserSettings.instance.trackerMode;
      _javaScriptEnabled = BrowserSettings.instance.javaScriptEnabled;
      _blockPopups = BrowserSettings.instance.blockPopups;
      _settingsReady = true;
    });
  }

  /// Applies updated settings AND reloads. Required when content-blocker
  /// rules change (they are embedded in the WebView settings object).
  Future<void> _applySettingsAndReload() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      await ctrl.setSettings(settings: _buildWebViewSettings());
      await ctrl.reload();
    } catch (e) {
      debugPrint('[PrivateBrowser] applySettingsAndReload: $e');
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BrowserSettingsScreen()));
    if (!mounted) return;
    await _loadSettings();
    await _applySettingsAndReload();
  }

  // ── Incognito toggle ──────────────────────────────────────────────────────────

  /// Toggles private-session mode.
  ///
  /// Incognito cannot be changed on a live WebView — it is a creation-time
  /// setting. We:
  ///   1. Save the current URL so browsing can resume.
  ///   2. Null the old controller reference.
  ///   3. Replace [_webViewKey] → Flutter destroys the old InAppWebView widget
  ///      and builds a new one with the updated incognito setting.
  ///   4. History is cleared; private history must not carry over to a
  ///      standard session and vice versa.
  void _toggleIncognito() {
    if (!mounted) return;
    final resumeUrl =
        (_currentUrl?.isNotEmpty == true && _currentUrl != 'about:blank')
        ? _currentUrl
        : null;

    setState(() {
      _incognito = !_incognito;
      _pendingNavigationUrl = resumeUrl;
      _controller = null;
      _history.clear();
      _canGoBack = false;
      _canGoForward = false;
      _isLoading = false;
      _webViewKey = UniqueKey(); // ← triggers WebView recreation
    });

    _showSnack(
      _incognito
          ? 'Private session active — browsing data not saved to disk'
          : 'Standard session — browsing data may be saved locally',
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────────

  static const _kSearchEngine = 'https://duckduckgo.com/?q=';

  /// Converts user input to a fully-qualified URL or DuckDuckGo search URL.
  ///
  /// Recognised as a URL:
  ///   • Starts with http:// or https://
  ///   • Bare domain matching [_kDomainPattern] (e.g. example.com)
  ///   • localhost / 127.0.0.1
  ///   • IPv4 address
  ///
  /// Everything else → DuckDuckGo search query.
  String _normalizeAddress(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'about:blank';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed == 'about:blank') return 'about:blank';
    if (_kLocalHostPattern.hasMatch(trimmed)) return 'http://$trimmed';
    if (_kIpv4Pattern.hasMatch(trimmed)) return 'http://$trimmed';
    if (_kDomainPattern.hasMatch(trimmed)) return 'https://$trimmed';
    return '$_kSearchEngine${Uri.encodeQueryComponent(trimmed)}';
  }

  static final _kLocalHostPattern = RegExp(
    r'^localhost(:\d{1,5})?(/.*)?$',
    caseSensitive: false,
  );

  static final _kIpv4Pattern = RegExp(
    r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d{1,5})?(/.*)?$',
  );

  /// Bare domain pattern — requires at least one dot with a 2+ letter TLD,
  /// no spaces, starts with alphanumeric.
  static final _kDomainPattern = RegExp(
    r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?'
    r'(\.[a-zA-Z0-9\-]+)*\.[a-zA-Z]{2,}(:\d{1,5})?(/[^\s]*)?$',
  );

  void _submitAddress() {
    final raw = _urlController.text;
    if (raw.trim().isEmpty) return;
    final url = _normalizeAddress(raw);
    _urlFocus.unfocus();

    // For HTTP URLs in HTTPS-only mode, attempt an automatic upgrade.
    if (_httpsOnly && _isInsecureHttpUrl(url)) {
      _navigate(_upgradeToHttps(url));
      return;
    }
    _navigate(url);
  }

  bool _isInsecureHttpUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'http';
  }

  String _upgradeToHttps(String url) => url.replaceFirst('http://', 'https://');

  /// Navigates to [url].
  ///
  /// If the controller is ready, calls loadUrl immediately.
  /// Otherwise stores the URL in [_pendingNavigationUrl]; it will be consumed
  /// in onWebViewCreated once the controller is initialised.
  void _navigate(String url) {
    final ctrl = _controller;
    if (ctrl != null) {
      if (mounted) {
        setState(() {
          _currentUrl = url;
          _urlController.text = url;
        });
      }
      ctrl.loadUrl(urlRequest: URLRequest(url: WebUri(url))).catchError((
        Object e,
      ) {
        debugPrint('[PrivateBrowser] loadUrl: $e');
      });
    } else {
      if (mounted) {
        setState(() {
          _pendingNavigationUrl = url;
          _currentUrl = url;
          _urlController.text = url;
        });
      } else {
        _pendingNavigationUrl = url;
      }
    }
  }

  void _goHome() {
    _navigate('about:blank');
  }

  Future<void> _goBack() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (await ctrl.canGoBack()) {
      await ctrl.goBack();
    } else if (mounted) {
      await _cleanupAndPop();
    }
  }

  Future<void> _goForward() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (await ctrl.canGoForward()) await ctrl.goForward();
  }

  // ── Exit / cleanup ────────────────────────────────────────────────────────────

  /// Stops loading, clears in-memory state, then pops the route.
  ///
  /// In incognito mode the platform WebView destroys its non-persistent session
  /// when the InAppWebView widget is disposed by Flutter. We do NOT call the
  /// global CookieManager / WebStorageManager / clearAllCache APIs here because
  /// they affect all WebViews in the app.
  Future<void> _cleanupAndPop() async {
    if (_exitInProgress) return;
    _exitInProgress = true;

    try {
      await _controller?.stopLoading();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _history.clear();
      _controller = null;
    });

    if (mounted) Navigator.of(context).pop();
  }

  // ── Clear Session (explicit user action) ─────────────────────────────────────

  /// Wipes all browsing data and resets to the home page.
  ///
  /// WARNING: [InAppWebViewController.clearAllCache],
  /// [WebStorageManager.instance().deleteAllData], and
  /// [CookieManager.instance().deleteAllCookies] are GLOBAL — they affect every
  /// WebView in this process. This method is called only on explicit user action,
  /// never automatically from dispose().
  Future<void> _clearSessionNow() async {
    try {
      await _controller?.stopLoading();
      await InAppWebViewController.clearAllCache();
      await WebStorageManager.instance().deleteAllData();
      await CookieManager.instance().deleteAllCookies();
    } catch (e) {
      debugPrint('[PrivateBrowser] clearSession: $e');
    }

    if (!mounted) return;
    setState(() {
      _history.clear();
      _currentUrl = null;
      _urlController.clear();
      _canGoBack = false;
      _canGoForward = false;
      _isLoading = false;
      _loadingProgress = 0;
    });

    _navigate('about:blank');
    _showSnack('Session cleared — cookies, cache and history wiped');
  }

  // ── Tracker / ad blocking ─────────────────────────────────────────────────────

  bool _isBlockedHost(Uri uri) {
    final host = uri.host.toLowerCase();
    if (_hostMatch(host, _kTrackerHosts)) return true;
    if (_trackerMode == TrackerBlockMode.normal) return false;
    if (_hostMatch(host, _kAdvancedTrackerHosts)) return true;
    return false;
  }

  bool _hostMatch(String host, Set<String> list) =>
      list.any((t) => host == t || host.endsWith('.$t'));

  /// Builds hostname-anchored ContentBlocker rules.
  ///
  /// Pattern: ^https?://([a-z0-9\-]+\.)*{escaped_host}(/|\?|#|$)
  ///   • ^ anchors to URL start.
  ///   • Subdomain prefix ([a-z0-9\-]+\.)* allows any subdomain depth.
  ///   • Terminates at / ? # or end-of-string to avoid matching the hostname
  ///     when it appears in a URL path or query string.
  List<ContentBlocker> _buildContentBlockers() {
    final rules = <ContentBlocker>[];

    void addHostRule(String host) {
      final escaped = host.replaceAll('.', '\\.');
      final pattern = '^https?://([a-z0-9\\-]+\\.)*$escaped(/|\\?|#|\$)';
      rules.add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: pattern),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
      );
    }

    for (final h in _kTrackerHosts) {
      addHostRule(h);
    }
    if (_trackerMode.index >= TrackerBlockMode.advanced.index) {
      for (final h in _kAdvancedTrackerHosts) {
        addHostRule(h);
      }
    }
    if (_trackerMode == TrackerBlockMode.enhanced) {
      for (final seg in _kEnhancedPathSegments) {
        rules.add(
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: _escapePath(seg)),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
        );
      }
    }

    return rules;
  }

  String _escapePath(String seg) {
    const specials = r'\.^$*+?()[]{}-';
    final buf = StringBuffer();
    for (final ch in seg.split('')) {
      if (specials.contains(ch)) {
        buf.write('\\$ch');
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  // ── WebView settings ──────────────────────────────────────────────────────────

  InAppWebViewSettings _buildWebViewSettings() {
    return InAppWebViewSettings(
      // Real private-session flag — see platform notes at top of file.
      incognito: _incognito,

      javaScriptEnabled: _javaScriptEnabled,

      // No disk cache in either mode.
      cacheEnabled: false,

      // No cross-site cookies.
      thirdPartyCookiesEnabled: false,

      // File system access — locked down.
      allowFileAccess: false,
      allowContentAccess: true, // needed for legitimate content:// URIs
      allowUniversalAccessFromFileURLs: false,
      allowFileAccessFromFileURLs: false,

      // Block HTTP sub-resources on HTTPS pages (Android).
      mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,

      // supportMultipleWindows must be true to receive onCreateWindow callbacks.
      // Actual allow/block logic lives in onCreateWindow.
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: false,

      // Require a user gesture to start media (prevents autoplaying ads).
      mediaPlaybackRequiresUserGesture: true,

      // Android Safe Browsing — warns on known malicious URLs.
      safeBrowsingEnabled: true,

      useHybridComposition: true,
      contentBlockers: _buildContentBlockers(),
      transparentBackground: false,
    );
  }

  // ── History ───────────────────────────────────────────────────────────────────

  void _recordNavigation(String url) {
    if (url.isEmpty || url == 'about:blank') return;
    if (_history.isNotEmpty && _history.last.url == url) return;
    _history.add(_HistoryEntry(url));
  }

  /// Updates the title of the most recent history entry matching [url].
  ///
  /// Called from onTitleChanged, which fires AFTER onUpdateVisitedHistory.
  /// Patching the existing entry avoids stale null-title records.
  void _updateLastHistoryTitle(String? url, String? title) {
    if (url == null || title == null || title.isEmpty) return;
    for (var i = _history.length - 1; i >= 0; i--) {
      if (_history[i].url == url) {
        _history[i].title = title;
        break;
      }
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showHistorySheet() {
    if (_history.isEmpty) {
      _showSnack('No pages visited this session');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final entries = List<_HistoryEntry>.from(_history.reversed);
        return SizedBox(
          height: 420,
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final display = entry.title?.isNotEmpty == true
                  ? entry.title!
                  : entry.url;
              return ListTile(
                dense: true,
                leading: const Icon(Icons.public, size: 18),
                title: Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  entry.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _navigate(entry.url);
                },
              );
            },
          ),
        );
      },
    );
  }

  // ── Scan Media ────────────────────────────────────────────────────────────────

  /// Scans the current page for `<video>` / `<audio>` elements and their
  /// source URLs, then shows a sheet with the found media.
  ///
  /// Uses `evaluateJavascript` to inspect the DOM. Blob/data URLs are skipped
  /// (they are not directly playable by external players).
  Future<void> _scanPageMedia() async {
    final ctrl = _controller;
    if (ctrl == null) {
      _showSnack('No active page to scan');
      return;
    }

    const script = '''
(function() {
  const found = [];
  const seen = new Set();
  function collect(node, type) {
    const sources = [];
    if (node.currentSrc) sources.push(node.currentSrc);
    if (node.getAttribute('src')) sources.push(node.getAttribute('src'));
    node.querySelectorAll('source').forEach(function(s) {
      if (s.getAttribute('src')) sources.push(s.getAttribute('src'));
    });
    sources.forEach(function(raw) {
      var abs = new URL(raw, location.href).href;
      if (/^(blob:|data:)/.test(abs)) return;
      if (seen.has(abs)) return;
      seen.add(abs);
      found.push({type: type, url: abs, title: node.getAttribute('title') || document.title || ''});
    });
  }
  document.querySelectorAll('video').forEach(function(v) { collect(v, 'video'); });
  document.querySelectorAll('audio').forEach(function(a) { collect(a, 'audio'); });
  // Also look for playlist manifests referenced in source list.
  document.querySelectorAll('link[rel="alternate"][type*="hls"]').forEach(function(l) {
    var abs = new URL(l.getAttribute('href'), location.href).href;
    if (seen.has(abs)) return;
    seen.add(abs);
    found.push({type: 'video', url: abs, title: document.title || ''});
  });
  return JSON.stringify(found);
})();
''';

    String? result;
    try {
      final value = await ctrl.evaluateJavascript(source: script);
      result = value is String ? value : null;
    } catch (e) {
      debugPrint('[PrivateBrowser] scanMedia: $e');
    }

    if (!mounted) return;

    final media = <_ScannedMedia>[];
    if (result != null && result.isNotEmpty) {
      try {
        final decoded = jsonDecode(result);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              media.add(
                _ScannedMedia(
                  url: (item['url'] ?? '').toString(),
                  title: (item['title'] ?? '').toString(),
                  isVideo: (item['type'] ?? '').toString() == 'video',
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[PrivateBrowser] scanMedia decode: $e');
      }
    }

    if (media.isEmpty) {
      _showSnack('No media found on this page');
      return;
    }

    _showScannedMediaSheet(media);
  }

  void _showScannedMediaSheet(List<_ScannedMedia> media) {
    final videoCount = media.where((m) => m.isVideo).length;
    final audioCount = media.length - videoCount;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.video_library_outlined,
                    size: 20,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Media on this page',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$videoCount video · $audioCount audio',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: media.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final m = media[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      m.isVideo
                          ? Icons.videocam_outlined
                          : Icons.audiotrack_outlined,
                      size: 18,
                      color: m.isVideo ? Colors.teal : Colors.orange,
                    ),
                    title: Text(
                      m.title.isEmpty ? m.url : m.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      m.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      tooltip: 'Play',
                      icon: const Icon(Icons.play_circle_outline, size: 22),
                      color: Colors.teal,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _playScannedMedia(m.url, isVideo: m.isVideo);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static const _kDocumentExtensions = [
    '.pdf', '.epub', '.txt', '.doc', '.docx', '.rtf', '.fb2', '.mobi',
  ];

  static const _kAudioExtensions = [
    '.mp3', '.wav', '.flac', '.aac', '.m4a', '.ogg', '.wma', '.opus',
    '.aiff', '.ape', '.alac', '.wv', '.tta', '.ac3', '.dts', '.mka',
    '.ra', '.ram', '.oga', '.mogg', '.mid', '.midi', '.mus', '.psf',
    '.spc', '.m4b', '.amr',
  ];

  static const _kVideoExtensions = [
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.3gp', '.webm',
    '.m4v', '.mpg', '.mpeg', '.ts', '.m3u8', '.mpd', '.f4v', '.vob',
    '.ogv', '.drc', '.gifv', '.mng', '.qt', '.yuv', '.rm', '.rmvb',
    '.asf', '.amv', '.mp2', '.mpe', '.mpv', '.m2v', '.svi', '.3g2',
    '.mxf', '.roq', '.nsv',
  ];

  static bool _isM3uUrl(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.endsWith('.m3u') ||
        path.endsWith('.m3u_plus') ||
        path.endsWith('.m3u8_plus');
  }

  static bool _isDocumentUrl(Uri uri) {
    final path = uri.path.toLowerCase();
    return _kDocumentExtensions.any((ext) => path.endsWith(ext));
  }

  static bool _isAudioUrl(Uri uri) {
    final path = uri.path.toLowerCase();
    return _kAudioExtensions.any((ext) => path.endsWith(ext));
  }

  static bool _isVideoUrl(Uri uri) {
    final path = uri.path.toLowerCase();
    return _kVideoExtensions.any((ext) => path.endsWith(ext));
  }

  static String _getFileNameFromUri(Uri uri, String fallback) {
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty) {
      try {
        return Uri.decodeComponent(uri.pathSegments.last);
      } catch (_) {
        return uri.pathSegments.last;
      }
    }
    return fallback;
  }

  /// Intercepts and handles M3U Playlists, Documents (PDF/EPUB/TXT), Audio (MP3/etc), and Video.
  /// Returns true if the URL was handled.
  bool _handleSpecialUrl(Uri uri) {
    if (!mounted) return false;
    final urlStr = uri.toString();

    // 1. M3U / IPTV Playlist files -> Parse and open in IPTV Player
    if (_isM3uUrl(uri)) {
      final fileName = _getFileNameFromUri(uri, 'IPTV Playlist');
      _openM3uPlaylist(urlStr, fileName);
      return true;
    }

    // 2. Documents (PDF, EPUB, TXT, etc.) -> Open in UnifiedReaderScreen
    if (_isDocumentUrl(uri)) {
      final fileName = _getFileNameFromUri(uri, 'Document');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UnifiedReaderScreen(
            documentUrl: urlStr,
            title: fileName,
          ),
        ),
      );
      _showSnack('Opening $fileName in reader');
      return true;
    }

    // 3. Audio files (MP3, WAV, FLAC, etc.) -> Open in Audio Player
    if (_isAudioUrl(uri)) {
      final fileName = _getFileNameFromUri(uri, 'Audio Stream');
      final mediaFile = MediaFile(
        id: urlStr,
        name: fileName,
        path: urlStr,
        displayPath: urlStr,
        type: MediaType.audio,
        size: 0,
        dateModified: DateTime.now(),
        dateAdded: DateTime.now(),
      );
      AudioPlaybackHelper.playAudio(ref, mediaFile, [mediaFile]);
      _showSnack('Playing $fileName in audio player');
      return true;
    }

    // 4. Video files -> Open in Video Player
    if (_isVideoUrl(uri)) {
      VideoPlayerLauncher.smart(source: urlStr, context: context);
      return true;
    }

    return false;
  }

  Future<void> _openM3uPlaylist(String url, String name) async {
    _showSnack('Loading IPTV playlist: $name...');
    try {
      final datasource = ref.read(iptvDatasourceProvider);
      final content = await datasource.fetchM3uUrl(url);
      final playlistId = const Uuid().v4().replaceAll('-', '');
      final channels = M3uParser.parse(content: content, playlistId: playlistId);

      if (!mounted) return;
      if (channels.isNotEmpty) {
        // Persist to IPTV playlists database in background
        unawaited(
          ref.read(iptvPlaylistsProvider.notifier).addFromUrl(
                url: url,
                name: name,
              ),
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IptvPlayerScreen(
              channels: channels,
              playlistName: name,
              startIndex: 0,
            ),
          ),
        );
      } else {
        VideoPlayerLauncher.smart(source: url, context: context);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Opening stream in video player...');
        VideoPlayerLauncher.smart(source: url, context: context);
      }
    }
  }

  Future<void> _playScannedMedia(String url, {bool isVideo = true}) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (_handleSpecialUrl(uri)) {
        return;
      }

      if (!isVideo) {
        final fileName = _getFileNameFromUri(uri, 'Audio Stream');
        final mediaFile = MediaFile(
          id: url,
          name: fileName,
          path: url,
          displayPath: url,
          type: MediaType.audio,
          size: 0,
          dateModified: DateTime.now(),
          dateAdded: DateTime.now(),
        );
        AudioPlaybackHelper.playAudio(ref, mediaFile, [mediaFile]);
        _showSnack('Playing $fileName in audio player');
        return;
      } else {
        await VideoPlayerLauncher.smart(source: url, context: context);
        return;
      }
    }

    // Fallback: browse to the URL in the current WebView.
    _navigate(url);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return PopScope(
      // Never allow the OS back gesture to pop without going through _goBack().
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: dark
            ? const Color(0xFF121212)
            : const Color(0xFFFFFFFF),
        body: SafeArea(
          child: Column(
            children: [
              _buildUrlBar(dark),
              if (_isLoading &&
                  _currentUrl != null &&
                  _currentUrl != 'about:blank')
                LinearProgressIndicator(
                  minHeight: 2,
                  value: _loadingProgress,
                  color: Colors.teal,
                  backgroundColor: Colors.teal.withValues(alpha: 0.15),
                ),
              Expanded(
                child: Stack(
                  children: [
                    if (_settingsReady) _buildWebView(),
                    if (_currentUrl == null || _currentUrl == 'about:blank')
                      _buildHomePage(theme, dark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── URL bar ───────────────────────────────────────────────────────────────────

  Widget _buildUrlBar(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _canGoBack ? _goBack : null,
          ),
          IconButton(
            tooltip: 'Forward',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: _canGoForward ? _goForward : null,
          ),
          IconButton(
            tooltip: 'Home',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.home_outlined),
            onPressed: _goHome,
          ),
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF2B2B2B) : const Color(0xFFF1F3F4),
                borderRadius: BorderRadius.circular(19),
              ),
              child: TextField(
                controller: _urlController,
                focusNode: _urlFocus,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submitAddress(),
                style: const TextStyle(fontSize: 13),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search or enter URL',
                  isDense: true,
                  filled: false,
                  isCollapsed: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  border: InputBorder.none,
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 28,
                  ),
                  prefixIcon: Icon(
                    _httpsOnly ? Icons.lock_outline : Icons.public,
                    size: 15,
                    color: _httpsOnly ? Colors.teal : Colors.grey,
                  ),
                  suffixIcon: _isLoading
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _controller?.stopLoading(),
                        )
                      : IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _controller?.reload(),
                        ),
                ),
              ),
            ),
          ),
          _buildMoreMenu(),
        ],
      ),
    );
  }

  Widget _buildMoreMenu() {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      onSelected: (value) {
        switch (value) {
          case 'history':
            _showHistorySheet();
          case 'scan_media':
            _scanPageMedia();
          case 'incognito':
            _toggleIncognito();
          case 'clear':
            _clearSessionNow();
          case 'settings':
            _openSettings();
          case 'exit':
            _cleanupAndPop();
        }
      },
      itemBuilder: (context) => [
        _compactMenuItem(
          value: 'history',
          icon: Icons.history_rounded,
          label: 'History',
        ),
        _compactMenuDivider(),
        _compactMenuItem(
          value: 'scan_media',
          icon: Icons.video_library_outlined,
          label: 'Scan Media',
          color: Colors.teal,
        ),
        _compactMenuDivider(),
        _compactMenuItemChecked(
          value: 'incognito',
          icon: Icons.visibility_off_outlined,
          label: 'Private session',
          checked: _incognito,
        ),
        _compactMenuDivider(),
        _compactMenuItem(
          value: 'clear',
          icon: Icons.delete_sweep_outlined,
          label: 'Clear session',
          color: Colors.orange,
        ),
        _compactMenuDivider(),
        _compactMenuItem(
          value: 'settings',
          icon: Icons.tune_rounded,
          label: 'Settings',
        ),
        _compactMenuDivider(),
        _compactMenuItem(
          value: 'exit',
          icon: Icons.logout_rounded,
          label: 'Exit',
          color: Colors.redAccent,
        ),
      ],
    );
  }

  PopupMenuEntry<String> _compactMenuItem({
    required String value,
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color ?? Colors.grey[700]),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<String> _compactMenuItemChecked({
    required String value,
    required IconData icon,
    required String label,
    required bool checked,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          if (checked)
            const Icon(Icons.check_rounded, size: 15, color: Colors.teal),
        ],
      ),
    );
  }

  PopupMenuEntry<String> _compactMenuDivider() =>
      const PopupMenuDivider(height: 1);

  // ── WebView ───────────────────────────────────────────────────────────────────

  Widget _buildWebView() {
    return InAppWebView(
      key: _webViewKey,
      initialUrlRequest: URLRequest(
        url: WebUri(_pendingNavigationUrl ?? 'about:blank'),
      ),
      initialSettings: _buildWebViewSettings(),
      onWebViewCreated: (controller) {
        _controller = controller;
        // Consume the pending navigation, if any.
        final pending = _pendingNavigationUrl;
        if (pending != null && pending != 'about:blank') {
          _pendingNavigationUrl = null;
          controller
              .loadUrl(urlRequest: URLRequest(url: WebUri(pending)))
              .catchError((Object e) {
                debugPrint('[PrivateBrowser] pending loadUrl: $e');
              });
        } else {
          _pendingNavigationUrl = null;
        }
      },
      onLoadStart: (controller, url) {
        if (!mounted) return;
        final urlStr = url?.toString() ?? '';
        setState(() {
          _isLoading = true;
          _loadingProgress = 0;
          if (urlStr.isNotEmpty) {
            _currentUrl = urlStr;
            _urlController.text = urlStr;
          }
        });
      },
      onProgressChanged: (controller, progress) {
        if (!mounted) return;
        setState(() => _loadingProgress = progress / 100.0);
      },
      onLoadStop: (controller, url) async {
        final canBack = await controller.canGoBack();
        final canFwd = await controller.canGoForward();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _loadingProgress = 1;
          _canGoBack = canBack;
          _canGoForward = canFwd;
        });
      },
      onTitleChanged: (controller, title) {
        if (!mounted) return;
        // Patch the most recent matching history entry with the now-known title.
        _updateLastHistoryTitle(_currentUrl, title);
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        // isReload == true: same URL reloaded; skip new history entry.
        if (isReload == true) return;
        final urlStr = url?.toString() ?? '';
        if (urlStr.isEmpty) return;

        if (mounted && _currentUrl != urlStr) {
          setState(() {
            _currentUrl = urlStr;
            _urlController.text = urlStr;
          });
        } else {
          _urlController.text = urlStr;
        }

        _recordNavigation(urlStr);
      },
      onDownloadStartRequest: (controller, downloadStartRequest) async {
        final uri = downloadStartRequest.url.uriValue;
        if (_handleSpecialUrl(uri)) {
          return;
        }
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url;
        if (url == null) return NavigationActionPolicy.ALLOW;

        final isMainFrame = navigationAction.isForMainFrame == true;
        final scheme = url.scheme.toLowerCase();

        // Non-web schemes (about:, data:, blob:, etc.) are always allowed.
        if (scheme != 'http' && scheme != 'https') {
          return NavigationActionPolicy.ALLOW;
        }

        // Main-frame tracker host blocking.
        if (isMainFrame && _isBlockedHost(url)) {
          if (mounted) {
            _showSnack('Blocked: ${url.host} is a known tracker/ad network');
          }
          return NavigationActionPolicy.CANCEL;
        }

        // Handle direct documents (PDF, EPUB, TXT), Audio, and Video files.
        if (isMainFrame && _handleSpecialUrl(url.uriValue)) {
          return NavigationActionPolicy.CANCEL;
        }

        // HTTPS-only: attempt automatic HTTPS upgrade for main-frame HTTP.
        // We upgrade rather than block to reduce user friction.
        if (_httpsOnly && isMainFrame && scheme == 'http') {
          final upgraded = _upgradeToHttps(url.toString());
          if (mounted) _showSnack('Upgrading to HTTPS...');
          unawaited(
            controller.loadUrl(urlRequest: URLRequest(url: WebUri(upgraded))),
          );
          return NavigationActionPolicy.CANCEL;
        }

        return NavigationActionPolicy.ALLOW;
      },
      onCreateWindow: (controller, createWindowAction) async {
        // This is a single-tab browser.
        //
        // Popup blocking ON  → cancel the new window (return false immediately).
        // Popup blocking OFF → open the URL in the current tab, return false
        //                      (we handled it; don't create a new WebView).
        if (_blockPopups) return false;

        final url = createWindowAction.request.url;
        if (url != null) _navigate(url.toString());
        return false;
      },
      onReceivedError: (controller, request, error) {
        // Navigation cancellations from shouldOverrideUrlLoading are not errors.
        if (error.type == WebResourceErrorType.CANCELLED) return;

        // Only surface errors for the main frame. Sub-resource errors
        // (broken images, blocked third-party scripts) are suppressed.
        if (request.isForMainFrame != true) return;

        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _loadingProgress = 0;
        });

        // Generic message — do not expose raw error.description to users.
        _showSnack('Page could not be loaded. Check your connection.');
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        if (request.isForMainFrame != true) return;
        final status = errorResponse.statusCode ?? 0;
        if (status >= 400 && mounted) {
          _showSnack('Server returned error $status');
        }
      },
    );
  }

  // ── Home page ─────────────────────────────────────────────────────────────────

  Widget _buildHomePage(ThemeData theme, bool dark) {
    final bg = dark ? const Color(0xFF16181D) : const Color(0xFFF7F8FA);
    final card = dark ? const Color(0xFF23262E) : Colors.white;
    final muted = theme.colorScheme.onSurfaceVariant;

    const links = <(String, String, IconData, Color)>[
      (
        'Google',
        'https://www.google.com',
        Icons.g_translate,
        Color(0xFF4285F4),
      ),
      (
        'YouTube',
        'https://www.youtube.com',
        Icons.play_circle_filled,
        Color(0xFFEA4335),
      ),
      (
        'DuckDuckGo',
        'https://duckduckgo.com',
        Icons.travel_explore,
        Color(0xFFDE5833),
      ),
      (
        'Wikipedia',
        'https://www.wikipedia.org',
        Icons.public,
        Color(0xFF346DA4),
      ),
      ('GitHub', 'https://github.com', Icons.code, Color(0xFF24292F)),
      ('X', 'https://x.com', Icons.alternate_email, Color(0xFF1DA1F2)),
      (
        'Gmail',
        'https://mail.google.com',
        Icons.mail_outline,
        Color(0xFFD93025),
      ),
      (
        'Archive.org',
        'https://archive.org',
        Icons.menu_book,
        Color(0xFFF9A603),
      ),
      (
        'IA TV',
        'https://www.archive.org/details/',
        Icons.live_tv,
        Color(0xFFE12E1A),
      ),
      (
        'Reddit',
        'https://www.reddit.com',
        Icons.forum_outlined,
        Color(0xFFFF4500),
      ),
      (
        'Stack Overflow',
        'https://stackoverflow.com',
        Icons.help_outline,
        Color(0xFFF48024),
      ),
      (
        'BBC News',
        'https://www.bbc.com/news',
        Icons.newspaper_outlined,
        Color(0xFFBB1919),
      ),
    ];

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF26A69A), Color(0xFF00796B)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                    if (_incognito)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.teal.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.visibility_off,
                            size: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _incognito ? 'Private Browser' : 'Browser',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _incognito
                  ? 'Private session active. The platform WebView minimises '
                        'disk persistence of cookies, cache and browsing data. '
                        'History is kept only in memory and cleared on exit.'
                  : 'Standard browsing session. Cookies and cache may be '
                        'saved locally by the WebView.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 28),
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _urlController,
                focusNode: _urlFocus,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submitAddress(),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search the web privately...',
                  hintStyle: TextStyle(fontSize: 14, color: muted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  prefixIcon: Icon(Icons.search, size: 20, color: muted),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    color: Colors.teal,
                    tooltip: 'Search with DuckDuckGo',
                    onPressed: _submitAddress,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'QUICK START',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final link in links.take(4))
                  Expanded(
                    child: _buildQuickTile(
                      icon: link.$3,
                      color: link.$4,
                      label: link.$1,
                      url: link.$2,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.start,
              children: [
                for (final link in links.skip(4))
                  _buildQuickTile(
                    icon: link.$3,
                    color: link.$4,
                    label: link.$1,
                    url: link.$2,
                  ),
              ],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTile({
    required IconData icon,
    required Color color,
    required String label,
    required String url,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        _urlController.text = url;
        _navigate(url);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
