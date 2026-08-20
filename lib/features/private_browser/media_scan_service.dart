import 'dart:async';
import 'dart:convert';
import 'models/scanned_media.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MediaScanService {
  MediaScanService._();
  static final MediaScanService instance = MediaScanService._();

  static const String handlerName = 'slideupMediaDetected';
  static const String m3u8ParsedHandler = 'slideupM3u8Parsed';

  static const UserScriptInjectionTime injectionTime =
      UserScriptInjectionTime.AT_DOCUMENT_END;

  static const String scriptSource = _enhancedScript;

  final _controller = StreamController<List<ScannedMedia>>.broadcast();
  Stream<List<ScannedMedia>> get mediaStream => _controller.stream;

  final List<ScannedMedia> _items = [];
  InAppWebViewController? _webView;

  List<ScannedMedia> get items => List.unmodifiable(_items);

  void attach(InAppWebViewController controller) {
    detach();
    _webView = controller;

    controller.addJavaScriptHandler(
      handlerName: handlerName,
      callback: _onReport,
    );

    controller.addJavaScriptHandler(
      handlerName: m3u8ParsedHandler,
      callback: _onM3u8Parsed,
    );
  }

  void detach() {
    _webView?.removeJavaScriptHandler(handlerName: handlerName);
    _webView?.removeJavaScriptHandler(handlerName: m3u8ParsedHandler);
    _webView = null;
    clear();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    _emit();
  }

  Future<List<ScannedMedia>> scanNow() async {
    final wv = _webView;
    if (wv == null) return items;
    try {
      final value = await wv.evaluateJavascript(
        source:
            'JSON.stringify(window.__slideupMediaScan ? '
            'window.__slideupMediaScan.scanNow() : [])',
      );
      if (value is String && value.isNotEmpty) {
        _mergeFromJson(value);
      }
    } catch (e) {
      debugPrint('[MediaScanService] scanNow: $e');
    }
    await ensurePlaylists();
    return items;
  }

  /// Fetches any pending HLS/DASH playlists so quality variants are available
  /// for the media sheet (lazy fetch - keeps page loading fast).
  Future<void> ensurePlaylists() async {
    final wv = _webView;
    if (wv == null) return;
    try {
      await wv.evaluateJavascript(
        source:
            'window.__slideupMediaScan && '
            'window.__slideupMediaScan.ensurePlaylists ? '
            'window.__slideupMediaScan.ensurePlaylists() : null',
      );
    } catch (e) {
      debugPrint('[MediaScanService] ensurePlaylists: $e');
    }
  }

  void _onReport(List<dynamic> args) {
    if (args.isEmpty) return;
    final raw = args.first;
    if (raw is List) {
      _mergeFromList(raw);
    } else if (raw is String && raw.isNotEmpty) {
      _mergeFromJson(raw);
    }
  }

  void _onM3u8Parsed(List<dynamic> args) {
    if (args.isEmpty) return;
    debugPrint('[MediaScanService] M3U8 parsed: ${args.first}');
    _onReport(args);
  }

  void _mergeFromJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) _mergeFromList(decoded);
    } catch (e) {
      debugPrint('[MediaScanService] decode: $e');
    }
  }

  void _mergeFromList(List<dynamic> list) {
    var changed = false;
    final existing = {for (final m in _items) m.url};

    for (final item in list) {
      if (item is! Map) continue;
      final url = (item['url'] ?? '').toString();
      if (url.isEmpty) continue;

      if (existing.contains(url)) {
        // Merge late-arriving HLS/DASH variants into the existing item.
        final variantsRaw = item['variants'];
        if (variantsRaw is List && variantsRaw.isNotEmpty) {
          final idx = _items.indexWhere((m) => m.url == url);
          if (idx != -1 && (_items[idx].variants?.isEmpty ?? true)) {
            final incoming = ScannedMedia.fromMap(item.cast<String, dynamic>());
            _items[idx] = _items[idx].copyWith(variants: incoming.variants);
            changed = true;
          }
        }
        continue;
      }

      existing.add(url);
      _items.add(ScannedMedia.fromMap(item.cast<String, dynamic>()));
      changed = true;
    }

    if (changed) {
      // Sort: HLS/DASH playlists first, then by quality/size
      _items.sort((a, b) {
        // Prioritize playlists over individual files
        if (a.isStream && !b.isStream) return -1;
        if (!a.isStream && b.isStream) return 1;

        // Then by file size
        final sizeCompare = (b.fileSize ?? 0).compareTo(a.fileSize ?? 0);
        if (sizeCompare != 0) return sizeCompare;

        // Then by height
        final heightCompare = (b.height ?? 0).compareTo(a.height ?? 0);
        if (heightCompare != 0) return heightCompare;

        // Then by bitrate
        final bitrateCompare = (b.bitrate ?? 0).compareTo(a.bitrate ?? 0);
        if (bitrateCompare != 0) return bitrateCompare;

        // Then by duration
        return (b.duration ?? 0).compareTo(a.duration ?? 0);
      });

      _emit();
    }
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(List.unmodifiable(_items));
  }

  void dispose() {
    detach();
    _controller.close();
  }
}

/// Enhanced JavaScript with HLS/TS support
const _enhancedScript = '''
(function() {
  'use strict';
  if (window.__slideupMediaScan) return;

  // File patterns
  var VIDEO_EXT = /\\.(mp4|m4v|mkv|webm|avi|mov|flv|wmv|mpg|mpeg|3gp|ogv)(\\?|#|\$)/i;
  var AUDIO_EXT = /\\.(mp3|wav|flac|aac|m4a|ogg|opus|wma|ape)(\\?|#|\$)/i;
  var HLS_EXT = /\\.(m3u8|m3u)(\\?|#|\$)/i;
  var DASH_EXT = /\\.(mpd)(\\?|#|\$)/i;
  var TS_EXT = /\\.(ts)(\\?|#|\$)/i;
  
  var STREAM_RE = /(videoplayback|googlevideo|\\/hls\\/|\\/dash\\/|\\/manifest\\/|\\/media\\/|\\/stream\\/|\\/playlist\\/|\\/chunklist)/i;
  
  // Thumbnail/preview patterns
  var THUMB_RE = /(thumb|thumbnail|preview|sprite|poster|placeholder|avatar|icon|logo|banner|badge)/i;
  
  // Ad patterns
  var AD_VIDEO_RE = /(ad-creative|adcreative|advertising|preroll|midroll|postroll|vast\\/|vpaid\\/|ima\\/|freewheel|tremor|spotx)/i;

  var AD_HOSTS = [
    'doubleclick', 'googlesyndication', 'googleadservices', 'googleadsserving',
    'adservice', 'adsystem', 'adnxs', 'adsrvr', 'taboola', 'outbrain',
    'criteo', 'casalemedia', 'amazon-adsystem', 'adform', 'adroll',
    'rubiconproject', 'openx', 'pubmatic', 'sharethrough', 'spotx',
    'adcolony', 'adition', 'adkernel', 'adman', 'adsafeprotected',
    'adscale', 'adshuffle', 'adsnative', 'adthrive', 'adtelligent',
    'advertising', 'adverticum', 'bluekai', 'brightroll', 'contextweb',
    'districtm', 'exelator', 'flashtalking', 'indexexchange', 'innovid',
    'liadm', 'liveramp', 'media.net', 'mediavine', 'mgid', 'moatads',
    'mopub', 'nativo', 'nexage', 'onemobile', 'onnetwork', 'opinary',
    'orbitsoft', 'pixfuture', 'popads', 'popcash', 'exoclick', 'juicyads',
    'trafficjunky', 'adsterra', 'propellerads', 'clickadu', 'monetag',
    'hilltopads', 'quantserve', 'revcontent', 'rlcdn', 'smaato', 'sonobi',
    'stickyadstv', 'teads', 'theadexchange', 'tubemogul', 'undertone',
    'vidible', 'videology', 'yieldmo', 'zedo', 'imasdk', 'video-ad-stats'
  ];

  var AD_WRAP_RE = /(ad-container|ad_container|ad-wrapper|ad_wrapper|banner-?ad|ad_banner|ad-banner|native-?ad|popunder|overlay-?ad|floating-?ad|sticky-?ad|sponsored|sponsor|advertisement|advert|promoted|ad-slot|ad_slot)/i;

  // Thresholds
  var MIN_WIDTH = 240;
  var MIN_HEIGHT = 180;
  var MIN_DURATION = 3;

  // Track found items
  var foundItems = {};
  var hlsPlaylists = {};
  var tsSegments = {};

  // Performance guards
  var didShadowSweep = false;
  var resourceProcessed = 0;
  var linkSweepCount = 0;
  var MAX_MEDIA_ITEMS = 50;
  var foundCount = 0;
  var MAX_HLS_FETCHES = 3;
  var hlsFetches = 0;
  var pendingHls = [];
  var resourceObserver = null;

  function isAdHost(abs) {
    try {
      var host = new URL(abs, location.href).hostname.toLowerCase();
      for (var i = 0; i < AD_HOSTS.length; i++) {
        if (host.indexOf(AD_HOSTS[i]) !== -1) return true;
      }
    } catch (e) {}
    return false;
  }

  function isAdUrl(url) {
    return AD_VIDEO_RE.test(url) || THUMB_RE.test(url);
  }

  function inAdContainer(el) {
    var cur = el;
    var depth = 0;
    while (cur && cur !== document.documentElement && depth < 10) {
      depth++;
      if (cur.id && AD_WRAP_RE.test(cur.id)) return true;
      if (cur.className && AD_WRAP_RE.test(String(cur.className))) return true;
      cur = cur.parentElement;
    }
    return false;
  }

  function isLikelyAd(el, url) {
    if (inAdContainer(el)) return true;
    if (isAdUrl(url)) return true;
    
    if (el.autoplay && el.muted) {
      var w = el.videoWidth || el.width || 0;
      var h = el.videoHeight || el.height || 0;
      if (w > 0 && h > 0 && w <= 400 && h <= 300) return true;
    }
    
    if (el.duration > 0 && el.duration < MIN_DURATION) return true;
    return false;
  }

  function isThumbnail(el, url) {
    if (THUMB_RE.test(url)) return true;
    
    var w = el.videoWidth || el.width || 0;
    var h = el.videoHeight || el.height || 0;
    if (w > 0 && h > 0 && (w < MIN_WIDTH || h < MIN_HEIGHT)) return true;
    
    return false;
  }

  function extractQuality(url, width, height, bitrate) {
    // From URL
    var match = url.match(/[_\\/-](\\d{3,4})p[_\\/-]/i);
    if (match) return match[1] + 'p';
    
    match = url.match(/quality[=_](\\d+)/i);
    if (match) return match[1] + 'p';
    
    // From bitrate (approximate)
    if (bitrate) {
      var mbps = bitrate / 1000000;
      if (mbps >= 15) return '4K';
      if (mbps >= 8) return '1080p';
      if (mbps >= 5) return '720p';
      if (mbps >= 2.5) return '480p';
      return '360p';
    }
    
    // From dimensions
    if (height >= 2160 || width >= 3840) return '4K';
    if (height >= 1440 || width >= 2560) return '1440p';
    if (height >= 1080 || width >= 1920) return '1080p';
    if (height >= 720 || width >= 1280) return '720p';
    if (height >= 480 || width >= 854) return '480p';
    if (height >= 360 || width >= 640) return '360p';
    
    return null;
  }

  function getBetterTitle(el) {
    var title = el.getAttribute('title') || 
                el.getAttribute('data-title') ||
                el.getAttribute('aria-label') ||
                '';
    
    if (!title) {
      var parent = el.parentElement;
      if (parent) {
        var heading = parent.querySelector('h1, h2, h3, h4, .title, .video-title, [class*="title"]');
        if (heading) title = heading.textContent.trim();
      }
    }
    
    return title || document.title || 'Unknown';
  }

  // Parse m3u8 playlist content
  function parseM3U8(content, baseUrl) {
    var lines = content.split('\\n');
    var variants = [];
    var isMasterPlaylist = false;
    var currentVariant = null;
    
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      
      // Check if it's a master playlist
      if (line.indexOf('#EXT-X-STREAM-INF') === 0) {
        isMasterPlaylist = true;
        currentVariant = {};
        
        // Parse bandwidth
        var bwMatch = line.match(/BANDWIDTH=(\\d+)/i);
        if (bwMatch) currentVariant.bitrate = parseInt(bwMatch[1]);
        
        // Parse resolution
        var resMatch = line.match(/RESOLUTION=(\\d+)x(\\d+)/i);
        if (resMatch) {
          currentVariant.width = parseInt(resMatch[1]);
          currentVariant.height = parseInt(resMatch[2]);
        }
        
        // Parse codecs
        var codecMatch = line.match(/CODECS="([^"]+)"/i);
        if (codecMatch) currentVariant.codec = codecMatch[1];
        
      } else if (currentVariant && line && !line.startsWith('#')) {
        // This is the URL for the current variant
        try {
          currentVariant.url = new URL(line, baseUrl).href;
          currentVariant.quality = extractQuality(
            currentVariant.url,
            currentVariant.width,
            currentVariant.height,
            currentVariant.bitrate
          );
          variants.push(currentVariant);
        } catch (e) {}
        currentVariant = null;
      }
    }
    
    return {
      isMaster: isMasterPlaylist,
      variants: variants
    };
  }

  // Fetch and parse m3u8 playlist
  function fetchM3U8(url) {
    if (hlsPlaylists[url]) return; // Already fetched
    hlsPlaylists[url] = true;
    
    fetch(url)
      .then(function(response) { return response.text(); })
      .then(function(content) {
        var parsed = parseM3U8(content, url);
        
        if (parsed.isMaster && parsed.variants.length > 0) {
          // Report master playlist with variants
          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('slideupM3u8Parsed', [{
              url: url,
              mediaType: 'hls',
              title: document.title || 'HLS Stream',
              variants: parsed.variants
            }]);
          }
        }
      })
      .catch(function(e) {
        console.log('Failed to fetch m3u8:', url, e);
      });
  }

  // Lazy HLS manifest fetch: only a few during page load, the rest on demand
  // (when the media sheet opens) so loading stays fast.
  function scheduleHlsFetch(url) {
    if (pendingHls.indexOf(url) !== -1) return;
    pendingHls.push(url);
    if (hlsFetches < MAX_HLS_FETCHES) {
      hlsFetches++;
      setTimeout(function() { fetchM3U8(url); }, 500);
    }
  }

  // Fetch any remaining playlists now (used when the sheet opens).
  function ensurePlaylists() {
    for (var i = 0; i < pendingHls.length; i++) {
      var u = pendingHls[i];
      if (!hlsPlaylists[u]) fetchM3U8(u);
    }
  }

  function report() {
    var found = [];
    var seen = {};

    function push(abs, mediaType, metadata) {
      if (!abs) return;
      if (/^(blob:|data:)/i.test(abs)) return;
      if (isAdHost(abs)) return;
      if (seen[abs]) return;
      if (foundCount >= MAX_MEDIA_ITEMS) return;
      
      seen[abs] = true;
      foundItems[abs] = true;
      foundCount++;
      
      found.push({
        url: abs,
        mediaType: mediaType,
        title: metadata.title || document.title || 'Unknown',
        duration: metadata.duration || null,
        width: metadata.width || null,
        height: metadata.height || null,
        fileSize: metadata.fileSize || null,
        quality: metadata.quality || null,
        bitrate: metadata.bitrate || null,
        codec: metadata.codec || null,
        variants: metadata.variants || null
      });
    }

    function collectMediaEl(el, docBase) {
      var isVideo = el.tagName === 'VIDEO';
      var src = el.currentSrc || el.getAttribute('src');
      
      if (!src) {
        var sources = el.querySelectorAll('source');
        if (sources.length > 0) src = sources[0].getAttribute('src');
      }
      
      if (!src) return;
      
      var abs = new URL(src, docBase).href;
      
      if (isLikelyAd(el, abs)) return;
      if (isThumbnail(el, abs)) return;
      
      var metadata = {
        title: getBetterTitle(el),
        duration: el.duration && el.duration !== Infinity ? Math.round(el.duration) : null,
        width: el.videoWidth || el.width || null,
        height: el.videoHeight || el.height || null,
        quality: null
      };
      
      // Determine media type
      var mediaType = 'video';
      if (!isVideo) mediaType = 'audio';
      else if (HLS_EXT.test(abs)) mediaType = 'hls';
      else if (DASH_EXT.test(abs)) mediaType = 'dash';
      else mediaType = 'directFile';
      
      if (metadata.width && metadata.height) {
        metadata.quality = extractQuality(abs, metadata.width, metadata.height);
      }
      
      if (metadata.duration && metadata.duration < MIN_DURATION) return;
      
      push(abs, mediaType, metadata);
      
      // For HLS, try to fetch and parse the playlist lazily
      if (mediaType === 'hls') {
        scheduleHlsFetch(abs);
      }
      
      // Collect source variants
      var sources = el.querySelectorAll('source');
      for (var i = 0; i < sources.length; i++) {
        var sSrc = sources[i].getAttribute('src');
        if (sSrc) {
          var sAbs = new URL(sSrc, docBase).href;
          if (sAbs !== abs) {
            var sMeta = Object.assign({}, metadata);
            var sType = mediaType;
            if (HLS_EXT.test(sAbs)) sType = 'hls';
            else if (DASH_EXT.test(sAbs)) sType = 'dash';
            sMeta.quality = extractQuality(sAbs, metadata.width, metadata.height);
            push(sAbs, sType, sMeta);
            
            if (sType === 'hls') {
              scheduleHlsFetch(sAbs);
            }
          }
        }
      }
    }

    function scanDoc(root) {
      var doc = root.document || root;
      var docBase = doc.baseURI || location.href;

      // Media elements
      var mediaEls = doc.querySelectorAll('video, audio');
      for (var i = 0; i < mediaEls.length; i++) {
        collectMediaEl(mediaEls[i], docBase);
      }

      // Manifest links
      var links = doc.querySelectorAll('link[rel="alternate"]');
      for (var k = 0; k < links.length; k++) {
        var href = links[k].getAttribute('href');
        if (!href) continue;
        var lt = (links[k].getAttribute('type') || '').toLowerCase();
        var abs = new URL(href, docBase).href;
        
        if (isAdUrl(abs)) continue;
        
        if (lt.indexOf('hls') !== -1 || lt.indexOf('mpegurl') !== -1) {
          push(abs, 'hls', { title: document.title });
          scheduleHlsFetch(abs);
        } else if (lt.indexOf('dash') !== -1) {
          push(abs, 'dash', { title: document.title });
        }
      }

      // Links (only scanned on the first two reports - anchors rarely change,
      // and media elements / resource timing still catch late additions)
      if (linkSweepCount < 2) {
        var anchors = doc.querySelectorAll('a[href]');
        for (var m = 0; m < anchors.length; m++) {
          var h = anchors[m].href;
          if (!h) continue;
          var lower = h.split('#')[0].toLowerCase();
          
          if (isAdUrl(h) || THUMB_RE.test(h)) continue;
          
          var aTitle = anchors[m].getAttribute('title') || 
                       anchors[m].getAttribute('download') ||
                       anchors[m].textContent.trim() || '';
          
          var mediaType = 'video';
          
          if (HLS_EXT.test(lower)) {
            push(h, 'hls', { title: aTitle });
            scheduleHlsFetch(h);
          } else if (DASH_EXT.test(lower)) {
            push(h, 'dash', { title: aTitle });
          } else if (VIDEO_EXT.test(lower)) {
            push(h, 'directFile', { title: aTitle });
          } else if (AUDIO_EXT.test(lower)) {
            push(h, 'audio', { title: aTitle });
          } else if (STREAM_RE.test(h)) {
            push(h, 'video', { title: aTitle });
          }
        }
        linkSweepCount++;
      }

      // Shadow DOM (the querySelectorAll('*') walk is expensive, so only
      // run it once; late shadow media is caught via resource timing)
      if (!didShadowSweep) {
        var all = doc.querySelectorAll('*');
        for (var n = 0; n < all.length; n++) {
          if (all[n].shadowRoot) scanShadow(all[n].shadowRoot);
        }
        didShadowSweep = true;
      }
    }

    function scanShadow(shadow) {
      var docBase = document.baseURI || location.href;
      var els = shadow.querySelectorAll('video, audio, link[rel="alternate"], a[href]');
      
      for (var i = 0; i < els.length; i++) {
        var el = els[i];
        var tag = el.tagName;
        
        if (tag === 'VIDEO' || tag === 'AUDIO') {
          collectMediaEl(el, docBase);
        } else if (tag === 'LINK') {
          var href = el.getAttribute('href');
          if (!href || isAdUrl(href)) continue;
          var abs = new URL(href, docBase).href;
          var lt = (el.getAttribute('type') || '').toLowerCase();
          
          if (lt.indexOf('hls') !== -1 || lt.indexOf('mpegurl') !== -1) {
            push(abs, 'hls', { title: document.title });
            scheduleHlsFetch(abs);
          } else if (lt.indexOf('dash') !== -1) {
            push(abs, 'dash', { title: document.title });
          }
        } else if (tag === 'A') {
          var h2 = el.href;
          if (!h2 || isAdUrl(h2) || THUMB_RE.test(h2)) continue;
          var l2 = h2.split('#')[0].toLowerCase();
          var aTitle = el.getAttribute('title') || el.textContent.trim() || '';
          
          if (HLS_EXT.test(l2)) {
            push(h2, 'hls', { title: aTitle });
            scheduleHlsFetch(h2);
          } else if (DASH_EXT.test(l2)) {
            push(h2, 'dash', { title: aTitle });
          } else if (VIDEO_EXT.test(l2) || STREAM_RE.test(h2)) {
            push(h2, 'directFile', { title: aTitle });
          } else if (AUDIO_EXT.test(l2)) {
            push(h2, 'audio', { title: aTitle });
          }
        }
      }
    }

    scanDoc(document);

    // Same-origin iframes
    var frames = document.querySelectorAll('iframe');
    for (var f = 0; f < frames.length; f++) {
      try {
        var fd = frames[f].contentDocument;
        if (fd) scanDoc(fd);
      } catch (e) {}
    }

    // Resource Timing API (each entry is examined only once)
    try {
      var entries = performance.getEntriesByType('resource');
      if (entries.length < resourceProcessed) resourceProcessed = 0;
      for (var r = resourceProcessed; r < entries.length; r++) {
        var ru = entries[r].name;
        if (!ru || isAdUrl(ru) || THUMB_RE.test(ru)) continue;
        
        var rl = ru.toLowerCase();
        var meta = {
          title: '',
          fileSize: entries[r].transferSize || entries[r].encodedBodySize || null
        };
        
        if (HLS_EXT.test(rl)) {
          push(ru, 'hls', meta);
          scheduleHlsFetch(ru);
        } else if (DASH_EXT.test(rl)) {
          push(ru, 'dash', meta);
        } else if (TS_EXT.test(rl)) {
          // Track .ts segments but don't report individual chunks
          // Group them by base URL
          var baseUrl = ru.replace(/\\/[^\\/]+\\.ts(\\?.*)?\$/, '');
          if (!tsSegments[baseUrl]) {
            tsSegments[baseUrl] = { count: 0, totalSize: 0, urls: [] };
          }
          tsSegments[baseUrl].count++;
          tsSegments[baseUrl].totalSize += meta.fileSize || 0;
          tsSegments[baseUrl].urls.push(ru);
        } else if (VIDEO_EXT.test(rl) || STREAM_RE.test(rl)) {
          push(ru, 'directFile', meta);
        } else if (AUDIO_EXT.test(rl)) {
          push(ru, 'audio', meta);
        }
      }
      resourceProcessed = entries.length;
    } catch (e) {}

    // Report to Flutter
    if (found.length > 0 && window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('slideupMediaDetected', found);
    }
    
    return found;
  }

  var debounceTimer = null;
  
  function scheduleReport() {
    if (debounceTimer) return;
    debounceTimer = setTimeout(function() {
      debounceTimer = null;
      report();
    }, 800);
  }

  var observer = new MutationObserver(scheduleReport);

  function start() {
    report();
    
    if (document.body) {
      observer.observe(document.body, { 
        childList: true, 
        subtree: true
      });
    }
    
    try {
      resourceObserver = new PerformanceObserver(scheduleReport);
      resourceObserver.observe({ entryTypes: ['resource'] });
    } catch (e) {}
  }

  window.__slideupMediaScan = { 
    scanNow: report,
    ensurePlaylists: ensurePlaylists,
    getSegments: function() { return tsSegments; },
    getPlaylists: function() { return hlsPlaylists; }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
  
  window.addEventListener('load', function() {
    setTimeout(report, 600);
    setTimeout(report, 2000);
    setTimeout(report, 5000);
    // Stop watching once the page has settled so long-lived tabs stay fast.
    setTimeout(function() {
      try { observer.disconnect(); } catch (e) {}
      try { if (resourceObserver) resourceObserver.disconnect(); } catch (e) {}
    }, 20000);
  });
})();
''';
