import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../documents/models/download_task.dart';
import '../video_player/video_player_launcher.dart';
import '../../helpers/audio_playback_helper.dart';
import '../../models/media_file.dart';
import '../../providers/download_providers.dart';
import '../../data/ad_domains.dart';
import 'ad_block_list_service.dart';
import 'browser_downloads_screen.dart';
import 'browser_settings.dart';
import 'browser_settings_screen.dart';
import 'media_intercept_helper.dart';
import 'media_scan_service.dart';
import 'models/scanned_media.dart' hide MediaType;
import 'widgets/media_list_sheet.dart';

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
//   Advanced tier adds AdDomains (ad_domains.dart); Enhanced tier adds AdGuard's
//   adservers.txt (fetched once per app run, cached in memory).
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

final RegExp _kAdHostnamePattern = RegExp(
  r'^[a-z0-9][a-z0-9\-]*(\.[a-z0-9\-]+)+$',
);
final RegExp _kAdSuffixPattern = RegExp(r'^\.[a-z0-9\-]+$');

/// Hostname-only entries extracted from [AdDomains.blockedDomains]
/// (e.g. `googlesyndication.com`). Path/query patterns (`facebook.com/tr`,
/// `utm_source`) and generic keywords are dropped — they are not host matches.
final Set<String> _kAppAdHosts = AdDomains.blockedDomains
    .where((d) => _kAdHostnamePattern.hasMatch(d.toLowerCase()))
    .toSet();

/// TLD / suffix-only entries from [AdDomains.blockedDomains] (e.g. `.shop`),
/// matched with `host.endsWith(suffix)`.
final Set<String> _kAppAdSuffixes = AdDomains.blockedDomains
    .where((d) => _kAdSuffixPattern.hasMatch(d.toLowerCase()))
    .map((d) => d.toLowerCase())
    .toSet();

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

    // Capture "external player" media URLs opened via window.open
    var MEDIA_RE = /\\.(mp4|m4v|mkv|webm|avi|mov|flv|wmv|mpg|mpeg|3gp|ogv|m3u8|m3u|mpd)(\\?|#)/i;
    var STREAM_RE = /(videoplayback|googlevideo|\\/hls\\/|\\/dash\\/|\\/manifest\\/|\\/media\\/|\\/stream\\/|\\/playlist\\/|\\/chunklist)/i;
    if (MEDIA_RE.test(lowerUrl) || STREAM_RE.test(lowerUrl)) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('slideupMediaDetected', [{
          url: url,
          mediaType: 'directFile',
          title: document.title || 'External Player'
        }]);
      }
      return null;
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

  // 4. Clipboard interception: capture media URLs copied by "external player" buttons
  if (navigator.clipboard && navigator.clipboard.writeText) {
    var _origWriteText = navigator.clipboard.writeText.bind(navigator.clipboard);
    navigator.clipboard.writeText = function(text) {
      if (text) {
        var lower = (text + '').toLowerCase();
        var MEDIA_RE = /\\.(mp4|m4v|mkv|webm|avi|mov|flv|wmv|mpg|mpeg|3gp|ogv|m3u8|m3u|mpd)(\\?|#)/i;
        var STREAM_RE = /(videoplayback|googlevideo|\\/hls\\/|\\/dash\\/|\\/manifest\\/|\\/media\\/|\\/stream\\/|\\/playlist\\/|\\/chunklist)/i;
        if (MEDIA_RE.test(lower) || STREAM_RE.test(lower)) {
          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('slideupMediaDetected', [{
              url: text,
              mediaType: 'directFile',
              title: document.title || 'External Player'
            }]);
          }
        }
      }
      return _origWriteText(text);
    };
  }

  // 5. Remove transparent click-hijack overlays
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

  // 5. Cosmetic Ad Hiding (JS-driven so real media containers are NEVER hidden)
  var adSelector =
    'iframe[src*="exoclick"], ' +
    'iframe[src*="juicyads"], ' +
    'iframe[src*="trafficjunky"], ' +
    'iframe[src*="popads"], ' +
    'iframe[src*="adsterra"], ' +
    'iframe[src*="propellerads"], ' +
    'iframe[src*="clickadu"], ' +
    '.juicyads, .exo-native-widget, .trafficjunky, ' +
    '.ad-container, .ad_container, .banner-ad, .banner_ad, ' +
    '[id*="ad_banner"], [class*="ad_banner"], [class*="ad-banner"], [id*="ad-banner"], ' +
    '[class*="native-ad"], [id*="popunder"], [class*="popunder"], ' +
    '[id*="overlay-ad"], [class*="overlay-ad"], ' +
    'div[class*="floating-ad"], div[id*="floating-ad"], ' +
    'div[class*="sticky-ad"], div[id*="sticky-ad"], ' +
    'div[class*="banner_advertisement"], div[class*="sponsor-banner"], ' +
    'div[id*="sponsored-ad"]';
  var adHiddenAttr = 'data-slideup-adhidden';

  // An element is treated as real media content if it contains (or is) a
  // video/audio element or an interactive form control.
  function isMediaContainer(el) {
    return !!el.querySelector('video, audio, input, form');
  }

  function hideAd(el) {
    el.setAttribute(adHiddenAttr, '1');
    el.style.setProperty('display', 'none', 'important');
    el.style.setProperty('visibility', 'hidden', 'important');
    el.style.setProperty('height', '0', 'important');
    el.style.setProperty('width', '0', 'important');
    el.style.setProperty('opacity', '0', 'important');
    el.style.setProperty('pointer-events', 'none', 'important');
  }

  function showEl(el) {
    el.removeAttribute(adHiddenAttr);
    el.style.removeProperty('display');
    el.style.removeProperty('visibility');
    el.style.removeProperty('height');
    el.style.removeProperty('width');
    el.style.removeProperty('opacity');
    el.style.removeProperty('pointer-events');
  }

  function applyAdHiding() {
    if (!document.body) return;
    // 1. Un-hide anything that now contains real media (e.g. an ad slot
    //    reused for the actual video after the pre-roll).
    var hidden = document.querySelectorAll('[' + adHiddenAttr + ']');
    for (var i = 0; i < hidden.length; i++) {
      if (isMediaContainer(hidden[i])) showEl(hidden[i]);
    }
    // 2. Hide ad matches that do not contain real media.
    var matches = document.querySelectorAll(adSelector);
    for (var j = 0; j < matches.length; j++) {
      var m = matches[j];
      if (isMediaContainer(m) || m.hasAttribute(adHiddenAttr)) continue;
      hideAd(m);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      applyAdHiding();
      removeOverlays();
    });
  } else {
    applyAdHiding();
    removeOverlays();
  }

  window.addEventListener('load', function() {
    setTimeout(function() { applyAdHiding(); removeOverlays(); }, 1000);
    setTimeout(function() { applyAdHiding(); removeOverlays(); }, 3000);
  });

  var observer = new MutationObserver(function() {
    applyAdHiding();
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

// ─── State ────────────────────────────────────────────────────────────────────

class _PrivateBrowserScreenState extends ConsumerState<PrivateBrowserScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Controllers / keys
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocus = FocusNode();
  final FocusNode _homeFocus = FocusNode();
  InAppWebViewController? _controller;

  /// Native pull-to-refresh control attached to the WebView (Android
  /// SwipeRefreshLayout / iOS UIRefreshControl). Reloads the current page.
  PullToRefreshController? _pullToRefreshController;

  /// Creates (or recreates) the native pull-to-refresh control. Recreated
  /// whenever the WebView itself is recreated ([_toggleIncognito]).
  void _initPullToRefreshController() {
    _pullToRefreshController?.dispose();
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Colors.teal,
        backgroundColor: const Color(0xFF1B1E26),
      ),
      onRefresh: () {
        _controller?.reload();
      },
    );
  }

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
  bool _allowAutoPlay = true;
  bool _settingsReady = false;

  /// Ad-server hostnames fetched from AdGuard's adservers.txt (Enhanced
  /// blocking tier). Empty until the background fetch completes.
  Set<String> _remoteAdHosts = const {};

  // UI state
  bool _incognito = true;

  /// Live media detected on the current page by [MediaScanService] (drives
  /// the download FAB). Cleared on each navigation.
  List<ScannedMedia> get _detectedMedia => MediaScanService.instance.items;
  StreamSubscription<List<ScannedMedia>>? _mediaSub;

  /// True while the media scanner is actively working (pulses the lightning
  /// bolt in the URL bar). Auto-settles after a quiet window.
  bool _isScanning = false;
  Timer? _scanIdleTimer;

  /// Pulsing animation for the scanning lightning-bolt indicator.
  late final AnimationController _scanPulse;
  late final Animation<double> _scanPulseAnim;

  /// Breathing rounded-border ring around the URL field while the page loads.
  late final AnimationController _loadRing;
  late final Animation<Color?> _loadRingColor;
  late final Animation<double> _loadRingWidth;

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

    _initPullToRefreshController();

    _loadSettings();
    unawaited(_loadAdBlockHosts());
    _scanPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scanPulseAnim = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(parent: _scanPulse, curve: Curves.easeInOut),
    );
    _loadRing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadRingColor = ColorTween(
      begin: Colors.teal.withValues(alpha: 0.0),
      end: Colors.teal,
    ).animate(CurvedAnimation(parent: _loadRing, curve: Curves.easeInOut));
    _loadRingWidth = Tween<double>(begin: 1.0, end: 2.4).animate(
      CurvedAnimation(parent: _loadRing, curve: Curves.easeInOut),
    );
    _mediaSub = MediaScanService.instance.mediaStream.listen((_) {
      if (mounted) setState(() {});
      _kickScanIndicator();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _urlFocus.dispose();
    _homeFocus.dispose();
    _pullToRefreshController?.dispose();
    _mediaSub?.cancel();
    _scanIdleTimer?.cancel();
    _scanPulse.dispose();
    _loadRing.dispose();
    MediaScanService.instance.detach();
    // No async work here. In incognito mode, the platform WebView handles
    // session cleanup when the widget is destroyed by the Flutter engine.
    // Explicit user-triggered cleanup lives in _clearSessionNow() and
    // _cleanupAndPop().
    super.dispose();
  }

  // ── Settings ─────────────────────────────────────────────────────────────────

  /// Fetches AdGuard's ad-server hostname list in the background and merges it
  /// into the blocklist. Content-blocker settings are refreshed (no reload) so
  /// iOS rule lists pick up the new hosts for future navigations; Android's
  /// request-level checks read [_remoteAdHosts] live.
  Future<void> _loadAdBlockHosts() async {
    final hosts = await AdBlockListService.fetchAdservers();
    if (!mounted || hosts.isEmpty) return;
    setState(() => _remoteAdHosts = hosts);
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      await ctrl.setSettings(settings: _buildWebViewSettings());
    } catch (e) {
      debugPrint('[PrivateBrowser] apply ad block list: $e');
    }
  }

  Future<void> _loadSettings() async {
    await BrowserSettings.instance.load();
    if (!mounted) return;
    setState(() {
      _httpsOnly = BrowserSettings.instance.httpsOnly;
      _trackerMode = BrowserSettings.instance.trackerMode;
      _javaScriptEnabled = BrowserSettings.instance.javaScriptEnabled;
      _blockPopups = BrowserSettings.instance.blockPopups;
      _allowAutoPlay = BrowserSettings.instance.allowAutoPlay;
      _settingsReady = true;
    });
    unawaited(
      _pullToRefreshController
          ?.setEnabled(BrowserSettings.instance.pullToRefresh),
    );
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
      MediaScanService.instance.clear();
      _initPullToRefreshController();
    });
    _stopLoadRing();

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
      MediaScanService.instance.clear();
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
      MediaScanService.instance.clear();
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
    // Advanced tier: app-hosted AdDomains hostnames and `.suffix` rules.
    if (_trackerMode == TrackerBlockMode.advanced) {
      if (_hostMatch(host, _kAppAdHosts)) return true;
      if (_suffixMatch(host, _kAppAdSuffixes)) return true;
    }
    // Enhanced tier: dynamically fetched AdGuard ad-server hostnames.
    if (_trackerMode == TrackerBlockMode.enhanced) {
      if (_hostMatch(host, _remoteAdHosts)) return true;
    }
    return false;
  }

  bool _hostMatch(String host, Set<String> list) =>
      list.any((t) => host == t || host.endsWith('.$t'));

  bool _suffixMatch(String host, Set<String> suffixes) =>
      suffixes.any((s) => host.endsWith(s));

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
    // Advanced tier: app-hosted AdDomains hosts + `.suffix` rules.
    if (_trackerMode == TrackerBlockMode.advanced) {
      for (final h in _kAppAdHosts) {
        addHostRule(h);
      }
      // `.shop`-style suffix rules: block any host ending with the suffix.
      for (final s in _kAppAdSuffixes) {
        addHostRule(s.substring(1));
      }
    }
    // Enhanced tier: dynamically fetched AdGuard ad-server hostnames.
    if (_trackerMode == TrackerBlockMode.enhanced) {
      for (final h in _remoteAdHosts) {
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
      mediaPlaybackRequiresUserGesture: !_allowAutoPlay,

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

  /// Turns on the pulsing lightning-bolt indicator and keeps it alive while
  /// scan reports keep arriving; settles to idle after [_scanIdleSettle] of
  /// quiet.
  void _kickScanIndicator() {
    _scanIdleTimer?.cancel();
    _scanIdleTimer = Timer(_scanIdleSettle, () {
      if (mounted) _stopScanIndicator();
    });
    if (!_isScanning) _startScanIndicator();
  }

  void _startScanIndicator() {
    if (!mounted) return;
    setState(() => _isScanning = true);
    _scanPulse.repeat(reverse: true);
  }

  void _stopScanIndicator() {
    _scanPulse.stop();
    _scanPulse.reset();
    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  /// Starts the breathing rounded-border ring while the page loads.
  void _startLoadRing() {
    if (_isLoading && _loadRing.isAnimating) return;
    _loadRing.repeat(reverse: true);
  }

  void _stopLoadRing() {
    if (_loadRing.isAnimating) {
      _loadRing.stop();
      _loadRing.reset();
    }
  }

  /// How long the lightning indicator stays lit after the last scan report.
  static const Duration _scanIdleSettle = Duration(milliseconds: 1400);

  /// Scans the current page with the enhanced IDM/Vidmate-style detector
  /// ([MediaScanService]), then shows a sheet with the found media.
  Future<void> _scanPageMedia() async {
    if (_controller == null) {
      _showSnack('No active page to scan');
      return;
    }
    final media = await MediaScanService.instance.scanNow();
    if (!mounted) return;
    if (media.isEmpty) {
      _showSnack('No media found on this page');
      return;
    }
    _showScannedMediaSheet(media);
  }

  void _showScannedMediaSheet(List<ScannedMedia> media) {
    // Lazily resolve HLS/DASH quality variants while the sheet is open.
    unawaited(MediaScanService.instance.ensurePlaylists());
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
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
                child: MediaListSheet(
                  items: media,
                  onDownload: (m, {variant}) async {
                    Navigator.of(sheetContext).pop();
                    await _startDownloadFromBrowser(
                      url: variant?.url ?? m.url,
                      title: variant != null
                          ? '${m.title.isNotEmpty ? m.title : 'Media File'} - '
                              '${variant.displayName}'
                          : (m.title.isNotEmpty ? m.title : 'Media File'),
                      mediaType: m.isVideo ? 'video' : 'audio',
                    );
                  },
                  onPlay: (m) {
                    Navigator.of(sheetContext).pop();
                    _playScannedMedia(m.url, isVideo: m.isVideo);
                  },
                  onOpen: (m) {
                    Navigator.of(sheetContext).pop();
                    final uri = Uri.tryParse(m.url);
                    if (uri != null) {
                      _showInterceptChoiceModal(
                        uri,
                        customTitle: m.title.isNotEmpty ? m.title : null,
                      );
                    } else {
                      _playScannedMedia(m.url, isVideo: m.isVideo);
                    }
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BrowserDownloadsScreen()));
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
            child: AnimatedBuilder(
              animation: _loadRing,
              builder: (context, _) => Container(
                height: 38,
                decoration: BoxDecoration(
                  color:
                      dark ? const Color(0xFF2B2B2B) : const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: _loadRingColor.value ?? Colors.transparent,
                    width: _loadRingWidth.value,
                  ),
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
          ),
          _buildScanIndicator(dark),
          _buildDownloadsButton(),
          _buildMoreMenu(),
        ],
      ),
    );
  }

  /// Pulsing lightning-bolt icon shown in the URL bar while the media scanner
  /// is active. Hidden (zero-width) when idle.
  Widget _buildScanIndicator(bool dark) {
    if (!_isScanning) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: ScaleTransition(
        key: ValueKey('scanning'),
        scale: _scanPulseAnim,
        child: Tooltip(
          message: 'Scanning for media…',
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.bolt_rounded,
              size: 20,
              color: dark ? Colors.amberAccent : Colors.orange,
            ),
          ),
        ),
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
      pullToRefreshController: _pullToRefreshController,
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: _kAdBlockUserScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
        UserScript(
          source: MediaScanService.scriptSource,
          injectionTime: MediaScanService.injectionTime,
        ),
      ]),
      onWebViewCreated: (controller) {
        _controller = controller;
        MediaScanService.instance.attach(controller);
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
          MediaScanService.instance.clear();
          if (urlStr.isNotEmpty) {
            _currentUrl = urlStr;
            _urlController.text = urlStr;
          }
        });
        _startLoadRing();
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
        _stopLoadRing();
        // Page fully loaded → run a scan pass and light up the lightning bolt.
        _kickScanIndicator();
        unawaited(MediaScanService.instance.scanNow());
        _pullToRefreshController?.endRefreshing();
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
        // Always intercept direct media URLs (external player links)
        // regardless of popup blocking setting.
        final url = createWindowAction.request.url;
        if (url != null) {
          final uri = url.uriValue;
          if (isMediaUri(uri)) {
            _showInterceptChoiceModal(uri);
            return false;
          }
        }

        // Popup blocking ON  → cancel the new window (return false immediately).
        // Popup blocking OFF → open the URL in the current tab, return false
        //                      (we handled it; don't create a new WebView).
        if (_blockPopups) return false;

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
        _stopLoadRing();

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
                focusNode: _homeFocus,
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
