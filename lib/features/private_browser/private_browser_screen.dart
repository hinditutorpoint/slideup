import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../documents/models/download_task.dart';
import '../video_player/video_player_launcher.dart';
import '../../helpers/audio_playback_helper.dart';
import '../../models/media_file.dart';
import '../../providers/download_providers.dart';
import 'browser_downloads_screen.dart';
import 'browser_settings.dart';
import 'browser_settings_screen.dart';
import 'media_intercept_helper.dart';

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
  ConsumerState<PrivateBrowserScreen> createState() =>
      _PrivateBrowserScreenState();
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

/// Adult, NSFW, Pop-Under, and High-Volume Video Ad Network Domains.
const _kNsfwAndPopunderHosts = <String>{
  // Major Adult & NSFW Ad Networks
  'exoclick.com',
  'exosrv.com',
  'juicyads.com',
  'trafficjunky.com',
  'trafficjunky.net',
  'trafficstars.com',
  'ero-advertising.com',
  'plugrush.com',
  'clickaine.com',
  'adxad.com',
  'adxxx.com',
  'trafficfactory.biz',
  'realsrv.com',
  'adx1.com',
  'hubtraffic.com',
  'adxpansion.com',

  // Pop-Under, Redirect & Push Hijack Networks
  'popads.net',
  'popcash.net',
  'propellerads.com',
  'propellerclick.com',
  'adsterra.com',
  'hilltopads.com',
  'monetag.com',
  'clickadu.com',
  'adcash.com',
  'yllix.com',
  'bidvertiser.com',
  'adtrue.com',
  'admaven.com',
  'richpush.co',
  'evadav.com',
  'pushground.com',
  'rollerads.com',
  'vidoomy.com',
  'adglare.net',
  'a-ads.com',
  'onclickalgo.com',
  'onclickbright.com',
  'onclicktop.com',
  'onclickpredict.com',
  'onclickmega.com',
  'adlightning.com',
  'zergnet.com',
  'mgid.com',
  'revcontent.com',

  // Cam / Landing Page Spam & Push Spam Networks
  'chaturbate.com',
  'stripchat.com',
  'livejasmin.com',
  'camsoda.com',
  'bongacams.com',
  'imlive.com',
  'flirt4free.com',
  'cam4.com',
  'streamate.com',
  'fleshlight.com',
  'webcamgalore.com',
  'jerkmate.com',

  // Malicious Gambling Redirects
  'bet365.com',
  '1xbet.com',
  'parimatch.com',
  'melbet.com',
  'mostbet.com',
  'pin-up.bet',
  '1win.pro',

  // Crypto miners & malware
  'coinhive.com',
  'crypto-loot.com',
  'jsecoin.com',
  'coin-have.com',
  'minr.pw',
};

/// Script injected into WebView to neutralize click-hijack overlays, popunder window.open abuse,
/// and hide adult banner elements cosmetically with CSS.
const _kAdBlockUserScript = '''
(function() {
  'use strict';

  // 1. Anti-Adblock Defeat (Prevents sites from freezing when ads are blocked)
  window.adBlock = false;
  window.canRunAds = true;
  window.google_ad_status = 1;
  window.adblocker = false;
  window.isAdBlockActive = false;

  // 2. Anti-Popunder: Neutralize window.open abuse
  var _origOpen = window.open;
  window.open = function(url, target, features) {
    if (!url || url === 'about:blank' || url === '') {
      return {
        closed: false,
        close: function() {},
        focus: function() {},
        blur: function() {},
        location: { href: '' },
        document: { write: function() {}, close: function() {} }
      };
    }
    var lowerUrl = (url + '').toLowerCase();
    var adKeywords = [
      'popads', 'popcash', 'exoclick', 'juicyads', 'trafficjunky',
      'adsterra', 'propellerads', 'onclick', 'stripchat', 'chaturbate',
      'livejasmin', 'bongacams', 'camsoda', 'bet365', '1xbet', 'adcash',
      'clickadu', 'hilltopads', 'monetag', 'adtrue', 'admaven', 'rollerads'
    ];
    for (var i = 0; i < adKeywords.length; i++) {
      if (lowerUrl.indexOf(adKeywords[i]) !== -1) {
        return null;
      }
    }
    return _origOpen.apply(this, arguments);
  };

  // 3. Intercept dynamic clickjacking (<a target="_blank"> created and clicked in code)
  var _origClick = HTMLElement.prototype.click;
  HTMLElement.prototype.click = function() {
    if (this.tagName === 'A' && this.target === '_blank') {
      var href = (this.href || '').toLowerCase();
      var adKeywords = [
        'popads', 'popcash', 'exoclick', 'juicyads', 'trafficjunky',
        'adsterra', 'propellerads', 'onclick', 'stripchat', 'chaturbate',
        'livejasmin', 'bongacams', 'camsoda', 'bet365', '1xbet'
      ];
      for (var i = 0; i < adKeywords.length; i++) {
        if (href.indexOf(adKeywords[i]) !== -1) {
          return;
        }
      }
    }
    return _origClick.apply(this, arguments);
  };

  // 4. Remove transparent click-hijack overlays
  function removeOverlays() {
    try {
      var allDivs = document.querySelectorAll('div, a, span');
      for (var i = 0; i < allDivs.length; i++) {
        var el = allDivs[i];
        var style = window.getComputedStyle(el);
        if (style.position === 'fixed' || style.position === 'absolute') {
          var zIndex = parseInt(style.zIndex, 10);
          var opacity = parseFloat(style.opacity);
          if ((zIndex > 999 && opacity <= 0.05) ||
              (zIndex > 9999 && el.offsetWidth >= window.innerWidth * 0.9 && el.offsetHeight >= window.innerHeight * 0.9)) {
            if (!el.getAttribute('role') && !el.querySelector('video, audio, input, form')) {
              el.remove();
            }
          }
        }
      }
    } catch(e) {}
  }

  // 5. Cosmetic CSS Element Hiding for Adult & Video Ads
  var css = `
    iframe[src*="exoclick"],
    iframe[src*="juicyads"],
    iframe[src*="trafficjunky"],
    iframe[src*="popads"],
    iframe[src*="adsterra"],
    iframe[src*="propellerads"],
    iframe[src*="clickadu"],
    .juicyads,
    .exo-native-widget,
    .trafficjunky,
    .ad-container,
    .ad_container,
    .banner-ad,
    .banner_ad,
    [id*="ad_banner"],
    [class*="ad_banner"],
    [class*="ad-banner"],
    [id*="ad-banner"],
    [class*="native-ad"],
    [id*="popunder"],
    [class*="popunder"],
    [id*="overlay-ad"],
    [class*="overlay-ad"],
    div[class*="floating-ad"],
    div[id*="floating-ad"],
    div[class*="sticky-ad"],
    div[id*="sticky-ad"],
    div[class*="banner_advertisement"],
    div[class*="sponsor-banner"],
    div[id*="sponsored-ad"] {
      display: none !important;
      visibility: hidden !important;
      height: 0 !important;
      width: 0 !important;
      opacity: 0 !important;
      pointer-events: none !important;
    }
  `;

  function injectCSS() {
    if (document.head) {
      var style = document.createElement('style');
      style.type = 'text/css';
      style.appendChild(document.createTextNode(css));
      document.head.appendChild(style);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      injectCSS();
      removeOverlays();
    });
  } else {
    injectCSS();
    removeOverlays();
  }

  window.addEventListener('load', function() {
    setTimeout(removeOverlays, 1000);
    setTimeout(removeOverlays, 3000);
  });

  var observer = new MutationObserver(function() {
    removeOverlays();
  });
  if (document.body) {
    observer.observe(document.body, { childList: true, subtree: true });
  } else {
    document.addEventListener('DOMContentLoaded', function() {
      if (document.body) observer.observe(document.body, { childList: true, subtree: true });
    });
  }
})();
''';

/// Script injected at document end that detects media elements (video/audio
/// sources, HLS/DASH manifests, and direct media file links) in real time.
///
/// Reports the found media to Flutter via the `mediaDetected` JavaScript
/// handler. Uses a MutationObserver so media added after page load (SPA /
/// dynamic players) is also captured.
const _kMediaDetectorUserScript = '''
(function() {
  'use strict';
  if (window.__slideupMediaDetector) return;
  window.__slideupMediaDetector = true;

  function report() {
    var found = [];
    var seen = {};
    function push(abs, type, title) {
      if (!abs) return;
      if (/^(blob:|data:)/.test(abs)) return;
      if (seen[abs]) return;
      seen[abs] = true;
      found.push({type: type, url: abs, title: title || document.title || ''});
    }
    function collect(node, type) {
      var title = node.getAttribute('title') || '';
      if (node.currentSrc) push(new URL(node.currentSrc, location.href).href, type, title);
      var src = node.getAttribute('src');
      if (src) push(new URL(src, location.href).href, type, title);
      var sources = node.querySelectorAll('source');
      for (var i = 0; i < sources.length; i++) {
        var s = sources[i];
        var ssrc = s.getAttribute('src');
        if (ssrc) push(new URL(ssrc, location.href).href, type, s.getAttribute('title') || title);
      }
    }
    var videos = document.querySelectorAll('video');
    for (var v = 0; v < videos.length; v++) collect(videos[v], 'video');
    var audios = document.querySelectorAll('audio');
    for (var a = 0; a < audios.length; a++) collect(audios[a], 'audio');
    // HLS / DASH manifests
    var links = document.querySelectorAll('link[rel="alternate"]');
    for (var l = 0; l < links.length; l++) {
      var href = links[l].getAttribute('href');
      if (!href) continue;
      var lt = (links[l].getAttribute('type') || '').toLowerCase();
      if (lt.indexOf('hls') !== -1 || lt.indexOf('mpegurl') !== -1 || lt.indexOf('dash') !== -1) {
        push(new URL(href, location.href).href, 'video', document.title);
      }
    }
    // Direct media file links (IDM-style detection)
    var anchors = document.querySelectorAll('a[href]');
    for (var i2 = 0; i2 < anchors.length; i2++) {
      var h = anchors[i2].href;
      if (!h) continue;
      var lower = h.split('#')[0].split('?')[0].toLowerCase();
      if (!/\\.(mp4|m4v|mkv|webm|avi|mov|flv|ts|m3u8|mpd|mp3|wav|flac|aac|m4a|ogg|opus|pdf|epub|doc|docx|txt|rtf|fb2|mobi)\$/.test(lower)) continue;
      var isAudio = /\\.(mp3|wav|flac|aac|m4a|ogg|opus|wma)\$/.test(lower);
      push(h, isAudio ? 'audio' : 'video', anchors[i2].getAttribute('title') || anchors[i2].textContent || '');
    }
    if (found.length > 0 && window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('mediaDetected', found);
    }
  }

  function start() {
    report();
    if (window.__slideupMediaObserver) return;
    var timer = null;
    window.__slideupMediaObserver = new MutationObserver(function() {
      if (timer) return;
      timer = setTimeout(function() { timer = null; report(); }, 800);
    });
    if (document.body) {
      window.__slideupMediaObserver.observe(document.body, { childList: true, subtree: true });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
  window.addEventListener('load', function() {
    setTimeout(report, 600);
    setTimeout(report, 2000);
  });
})();
''';

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

  /// Media detected in real time on the current page by the injected
  /// detector script. Cleared on each navigation; drives the download FAB.
  final List<_ScannedMedia> _detectedMedia = [];

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
      _detectedMedia.clear();
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
      _detectedMedia.clear();
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
      _detectedMedia.clear();
    });

    _navigate('about:blank');
    _showSnack('Session cleared — cookies, cache and history wiped');
  }

  // ── Tracker / ad blocking ─────────────────────────────────────────────────────

  bool _isBlockedHost(Uri uri) {
    final host = uri.host.toLowerCase();
    if (_hostMatch(host, _kTrackerHosts)) return true;
    if (_hostMatch(host, _kNsfwAndPopunderHosts)) return true;
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
    for (final h in _kNsfwAndPopunderHosts) {
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

      // Required so the onDownloadStartRequest / shouldOverrideUrlLoading
      // callbacks are actually invoked by the platform WebView.
      useShouldOverrideUrlLoading: true,
      useOnDownloadStart: true,

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

  /// Handles media pushed in real time from the injected
  /// [_kMediaDetectorUserScript] via the `mediaDetected` JS handler. Merges the
  /// results into [_detectedMedia] (deduped by URL) and shows the FAB.
  void _onMediaDetected(List<dynamic> args) {
    if (!mounted || args.isEmpty) return;

    final newMedia = <_ScannedMedia>[];
    final raw = args.first;
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          newMedia.add(
            _ScannedMedia(
              url: (item['url'] ?? '').toString(),
              title: (item['title'] ?? '').toString(),
              isVideo: (item['type'] ?? '').toString() == 'video',
            ),
          );
        }
      }
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              newMedia.add(
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
        debugPrint('[PrivateBrowser] mediaDetected decode: $e');
      }
    }

    if (newMedia.isEmpty) return;
    setState(() {
      final existing = {for (final m in _detectedMedia) m.url};
      for (final m in newMedia) {
        if (existing.add(m.url)) _detectedMedia.add(m);
      }
    });
  }

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
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
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
                  final uri = Uri.tryParse(m.url);
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Download',
                          icon: const Icon(Icons.download_rounded, size: 20),
                          color: Colors.teal,
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _startDownloadFromBrowser(
                              url: m.url,
                              title: m.title.isNotEmpty ? m.title : 'Media File',
                              mediaType: m.isVideo ? 'video' : 'audio',
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Play',
                          icon: const Icon(Icons.play_circle_outline, size: 22),
                          color: Colors.teal,
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _playScannedMedia(m.url, isVideo: m.isVideo);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      if (uri != null) {
                        _showInterceptChoiceModal(
                          uri,
                          customTitle: m.title.isNotEmpty ? m.title : null,
                        );
                      } else {
                        _playScannedMedia(m.url, isVideo: m.isVideo);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      ),
    );
  }

  /// Intercepts and handles M3U Playlists, Documents (PDF/EPUB/TXT), Audio (MP3/etc), and Video.
  /// Shows modal asking user to Download | Play/Read | Cancel.
  /// Returns true if the URL was handled.
  bool _handleSpecialUrl(Uri uri) {
    if (!mounted) return false;

    if (isMediaUri(uri)) {
      _showInterceptChoiceModal(uri);
      return true;
    }

    return false;
  }

  /// Shows the Download | Play/Read | Cancel interception bottom sheet.
  void _showInterceptChoiceModal(Uri uri, {String? customTitle}) {
    if (!mounted) return;
    showMediaActionSheet(
      context,
      ref,
      uri,
      customTitle: customTitle,
      onOpenDownloads: _openDownloads,
    );
  }

  /// Starts downloading the intercepted file in background with notifications.
  Future<void> _startDownloadFromBrowser({
    required String url,
    required String title,
    required String mediaType,
  }) {
    return startBrowserDownload(
      context,
      ref,
      url: url,
      title: title,
      mediaType: mediaType,
      onOpenDownloads: _openDownloads,
    );
  }

  void _openDownloads() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BrowserDownloadsScreen()),
    );
  }

  Future<void> _playScannedMedia(String url, {bool isVideo = true}) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (_handleSpecialUrl(uri)) {
        return;
      }

      if (!isVideo) {
        final fileName = fileNameFromUri(uri, 'Audio Stream');
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
                    if (_detectedMedia.isNotEmpty)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: _buildMediaFab(),
                      ),
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
          _buildDownloadsButton(),
          _buildMoreMenu(),
        ],
      ),
    );
  }

  Widget _buildDownloadsButton() {
    final downloadsState = ref.watch(downloadsProvider);
    final activeCount = downloadsState.activeDownloads
        .where((t) => t.status == DownloadStatus.downloading)
        .length;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Downloads',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.download_rounded, size: 21),
          onPressed: _openDownloads,
        ),
        if (activeCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$activeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
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
          case 'downloads':
            _openDownloads();
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
          value: 'downloads',
          icon: Icons.download_rounded,
          label: 'Downloads',
          color: Colors.teal,
        ),
        _compactMenuDivider(),
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

  /// Floating download button shown when media was detected in real time on the
  /// current page. Tapping it opens the scanned-media sheet.
  Widget _buildMediaFab() {
    final count = _detectedMedia.length;
    return GestureDetector(
      onTap: () => _showScannedMediaSheet(_detectedMedia),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.teal,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.download_rounded, color: Colors.white, size: 20),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
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
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: _kAdBlockUserScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
        UserScript(
          source: _kMediaDetectorUserScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        ),
      ]),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'mediaDetected',
          callback: (args) {
            _onMediaDetected(args);
            return null;
          },
        );
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
          _detectedMedia.clear();
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
        if (!_handleSpecialUrl(uri)) {
          _showInterceptChoiceModal(
            uri,
            customTitle: downloadStartRequest.suggestedFilename,
          );
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

        // iOS marks download navigations (server-protected files, attachment
        // responses) via shouldPerformDownload. Intercept them here so the
        // user gets the Download/Play dialog instead of the native download.
        if (navigationAction.shouldPerformDownload == true) {
          if (mounted) {
            _showInterceptChoiceModal(url.uriValue);
          }
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
      ('Twitter', 'https://x.com', Icons.alternate_email, Color(0xFF1DA1F2)),
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
