// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
class PrivateBrowserScreen extends StatefulWidget {
  final String? initialUrl;

  const PrivateBrowserScreen({super.key, this.initialUrl});

  @override
  State<PrivateBrowserScreen> createState() => _PrivateBrowserScreenState();
}

// ─── Data model ───────────────────────────────────────────────────────────────

/// A browsing-history entry whose [title] can be updated after the page loads.
class _HistoryEntry {
  final String url;
  String? title;
  _HistoryEntry(this.url);
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

class _PrivateBrowserScreenState extends State<PrivateBrowserScreen>
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

  void _setHttpsOnly(bool value) {
    setState(() => _httpsOnly = value);
    BrowserSettings.instance.setHttpsOnly(value);
    // No reload needed — HTTPS enforcement applies to future navigations.
  }

  void _setTrackerMode(TrackerBlockMode mode) {
    setState(() => _trackerMode = mode);
    BrowserSettings.instance.setTrackerMode(mode);
    // Content blockers are baked into WebView settings; push+reload.
    _applySettingsAndReload();
  }

  void _setJavaScript(bool value) {
    setState(() => _javaScriptEnabled = value);
    BrowserSettings.instance.setJavaScriptEnabled(value);
    _applySettingsLive();
  }

  void _setBlockPopups(bool value) {
    setState(() => _blockPopups = value);
    BrowserSettings.instance.setBlockPopups(value);
    _applySettingsLive();
  }

  /// Pushes updated settings to the live WebView without reloading.
  void _applySettingsLive() {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      ctrl.setSettings(settings: _buildWebViewSettings());
    } catch (e) {
      debugPrint('[PrivateBrowser] applySettingsLive: $e');
    }
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BrowserSettingsScreen()),
    );
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

  String _upgradeToHttps(String url) =>
      url.replaceFirst('http://', 'https://');

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
      ctrl
          .loadUrl(urlRequest: URLRequest(url: WebUri(url)))
          .catchError((Object e) {
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
      final pattern =
          '^https?://([a-z0-9\\-]+\\.)*$escaped(/|\\?|#|\$)';
      rules.add(ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: pattern),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ));
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
        rules.add(ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: _escapePath(seg)),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
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
              final display =
                  entry.title?.isNotEmpty == true ? entry.title! : entry.url;
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
        backgroundColor:
            dark ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
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
                color: dark
                    ? const Color(0xFF2B2B2B)
                    : const Color(0xFFF1F3F4),
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

        // HTTPS-only: attempt automatic HTTPS upgrade for main-frame HTTP.
        // We upgrade rather than block to reduce user friction.
        if (_httpsOnly && isMainFrame && scheme == 'http') {
          final upgraded = _upgradeToHttps(url.toString());
          if (mounted) _showSnack('Upgrading to HTTPS...');
          unawaited(
            controller.loadUrl(
              urlRequest: URLRequest(url: WebUri(upgraded)),
            ),
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
        'DuckDuckGo',
        'https://duckduckgo.com',
        Icons.travel_explore,
        Color(0xFFDE5833),
      ),
      (
        'Archive.org',
        'https://archive.org',
        Icons.menu_book,
        Color(0xFFF9A603),
      ),
      (
        'Wikipedia',
        'https://www.wikipedia.org',
        Icons.public,
        Color(0xFF346DA4),
      ),
      (
        'IA TV',
        'https://www.archive.org/details/',
        Icons.live_tv,
        Color(0xFFE12E1A),
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
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
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
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
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
            Material(
              color: card,
              elevation: 1,
              borderRadius: BorderRadius.circular(26),
              child: InkWell(
                borderRadius: BorderRadius.circular(26),
                onTap: () => _urlFocus.requestFocus(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 20, color: muted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Search the web privately...',
                          style: TextStyle(fontSize: 14, color: muted),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: muted),
                    ],
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
                for (final link in links)
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
            const SizedBox(height: 28),
            _buildPrivacyCard(theme, card, muted),
            const SizedBox(height: 20),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Privacy card ──────────────────────────────────────────────────────────────

  Widget _buildPrivacyCard(ThemeData theme, Color card, Color muted) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_rounded, size: 18, color: Colors.teal),
              SizedBox(width: 8),
              Text(
                'Privacy & security',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildPrivacySwitch(
            theme,
            'HTTPS-only',
            'Block non-encrypted http:// pages (auto-upgrades when possible)',
            Icons.lock_outline,
            _httpsOnly,
            _setHttpsOnly,
          ),
          _buildTrackerModeTile(),
          _buildPrivacySwitch(
            theme,
            'JavaScript',
            'Disable for maximum privacy',
            Icons.code_outlined,
            _javaScriptEnabled,
            _setJavaScript,
          ),
          _buildPrivacySwitch(
            theme,
            'Block pop-ups',
            _blockPopups
                ? 'New windows are blocked'
                : 'New windows open in current tab',
            Icons.open_in_new_outlined,
            _blockPopups,
            _setBlockPopups,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerModeTile() {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      dense: true,
      leading: const Icon(Icons.block_outlined, size: 20),
      title: const Text(
        'Block known trackers & ads',
        style: TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        'Level: ${_trackerMode.label.toLowerCase()}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: _showTrackerModePicker,
    );
  }

  void _showTrackerModePicker() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Block known trackers & ads',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Known tracker/ad hostnames are blocked according to the '
                'configured ruleset. This is not equivalent to a full '
                'content-blocker extension.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            for (final mode in TrackerBlockMode.values)
              RadioListTile<TrackerBlockMode>(
                value: mode,
                groupValue: _trackerMode,
                activeColor: Colors.teal,
                title: Text(mode.label),
                subtitle: Text(mode.description),
                onChanged: (selected) {
                  Navigator.of(sheetContext).pop();
                  if (selected != null) _setTrackerMode(selected);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySwitch(
    ThemeData theme,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      activeColor: Colors.teal,
      dense: true,
      secondary: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}
