/// Comprehensive list of common ad serving domains
/// Organized by ad network/service for easy maintenance
class AdDomains {
  /// Get all blocked ad domains
  static List<String> get blockedDomains => [
    ..._googleAds,
    ..._facebookAds,
    ..._amazonAds,
    ..._twitterAds,
    ..._adMobDomains,
    ..._doubleClickDomains,
    ..._analyticsTrackers,
    ..._otherAdNetworks,
    ..._videoStreamingAds,
    ..._blogspotAds,
    ..._indianAdNetworks,
    ..._affiliateNetworks,
    ..._popupRedirectDomains,
  ];

  /// Google Ads domains
  static const List<String> _googleAds = [
    'googlesyndication.com',
    'googleadservices.com',
    'google-analytics.com',
    'googletagmanager.com',
    'googletagservices.com',
    'adservice.google.com',
    'pagead2.googlesyndication.com',
    'tpc.googlesyndication.com',
    'adtrafficquality.google',
    'ep1.adtrafficquality.google',
    'adwords.google.com',
    'afs.googlesyndication.com',
  ];

  /// Facebook Ads domains
  static const List<String> _facebookAds = [
    'facebook.com/tr',
    'connect.facebook.net',
    'an.facebook.com',
    'pixel.facebook.com',
    'facebook.net',
  ];

  /// Amazon Ads domains
  static const List<String> _amazonAds = [
    'amazon-adsystem.com',
    'amazonclix.com',
    'assoc-amazon.com',
    'aax.amazon-adsystem.com',
  ];

  /// Twitter Ads domains
  static const List<String> _twitterAds = [
    'ads-twitter.com',
    'analytics.twitter.com',
    'static.ads-twitter.com',
  ];

  /// AdMob domains
  static const List<String> _adMobDomains = [
    'admob.com',
    'app-measurement.com',
    'crashlytics.com',
  ];

  /// DoubleClick domains
  static const List<String> _doubleClickDomains = [
    'doubleclick.net',
    'ad.doubleclick.net',
    'static.doubleclick.net',
    'googleads.g.doubleclick.net',
    'pubads.g.doubleclick.net',
  ];

  /// Analytics and tracking domains
  static const List<String> _analyticsTrackers = [
    'scorecardresearch.com',
    'quantserve.com',
    'chartbeat.com',
    'newrelic.com',
    'hotjar.com',
    'mouseflow.com',
    'crazyegg.com',
    'mixpanel.com',
    'segment.com',
    'amplitude.com',
    'moengage.com',
    'sdk-03.moengage.com',
    'clevertap.com',
    'appsflyer.com',
    'adjust.com',
    'branch.io',
    'kochava.com',
  ];

  /// Blogspot/Blogger ad frames
  static const List<String> _blogspotAds = [
    'blogspot.com/comment/frame',
    'blogger.com/comment',
    'blogspot.com/static',
  ];

  /// Indian ad networks and affiliate sites
  static const List<String> _indianAdNetworks = [
    'lalluram.com',
    'anandabazar.com/health-and-wellness',
    'mn_digital',
    'bollywoodpapa',
    'infolinks.com',
    'mgid.com',
    'revenuehits.com',
    'bidvertiser.com',
    'clickadu.com',
    'razorpay.com',
    'checkout.razorpay.com',
  ];

  /// Affiliate and redirect networks
  static const List<String> _affiliateNetworks = [
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'Affiliates',
    'affiliate',
    'cid=',
    'clickid=',
    'aff_sub=',
  ];

  /// THE MAIN AD POPUPS AND REDIRECTS FROM YOUR LOGS
  static const List<String> _popupRedirectDomains = [
    // Primary ad redirect domains from your logs
    'felspartreen.shop',
    'um.felspartreen.shop',
    'mks98.com',
    'nurturesnook.com',
    'vthbkvnhxsgwzjefnucjjl.nurturesnook.com',
    'aliveforfood.com',
    'gjrdtfbqjpgwgsejql.aliveforfood.com',
    'rtmark.net',
    'my.rtmark.net',

    // Common redirect patterns
    '.shop',
    '/afu.php',
    '/rhd?',
    '/link2?',
    'pub_rfid=',
    'zoneid=',

    // Generic popup/redirect domains
    'popunderclick.com',
    'redirectvoluum.com',
    'adskeeper.co.uk',
    'clksite.com',
    'propush.me',
    'go.oclaserver.com',
    'realsrv.com',
    'tsyndicate.com',
  ];

  /// Video streaming specific ads
  static const List<String> _videoStreamingAds = [
    'popads.net',
    'popcash.net',
    'propellerads.com',
    'exoclick.com',
    'juicyads.com',
    'trafficjunky.com',
    'trafficstars.com',
    'adsterra.com',
    'a-ads.com',
    'adshares.net',
    'ad2games.com',
    'adverticum.net',
    'advertising.com',
    'adriver.ru',
    'adultadworld.com',
    'banner.t-online.de',
    'bannerconnect.net',
  ];

  /// Other popular ad networks
  static const List<String> _otherAdNetworks = [
    // General ad networks
    'adnxs.com',
    'advertising.com',
    'adform.net',
    'criteo.com',
    'criteo.net',
    'outbrain.com',
    'taboola.com',
    'media.net',
    'pubmatic.com',
    'rubiconproject.com',
    'openx.net',
    'indexww.com',
    'contextweb.com',
    'adtech.de',
    'smartadserver.com',

    // Mobile ad networks
    'applovin.com',
    'unity3d.com',
    'chartboost.com',
    'vungle.com',
    'tapjoy.com',
    'inmobi.com',
    'startapp.com',
    'appnext.com',
    'smaato.net',

    // Video ad networks
    'videohub.tv',
    'brightcove.com',
    'spotxchange.com',
    'teads.tv',
    'freewheel.tv',
    'innovid.com',

    // Native ad networks
    'sharethrough.com',
    'nativo.com',
    'triplelift.com',
    'plista.com',
    'revcontent.com',

    // Retargeting
    'adroll.com',
    'retargeter.com',
    'perfectaudience.com',
    'fetchback.com',

    // Common ad servers
    'serving-sys.com',
    'adsrvr.org',
    'exponential.com',
    'undertone.com',
    'yieldmo.com',
    'sovrn.com',
    'lijit.com',
    '33across.com',
    'sonobi.com',
    'adsafeprotected.com',
    'moatads.com',
    'doubleverify.com',
    'integralads.com',
    'casalemedia.com',
    'adition.com',
    'turn.com',
    'advertisers.com',
  ];

  /// Check if a domain matches any blocked domain pattern
  static bool isDomainBlocked(
    String domain, {
    List<String> customBlocklist = const [],
  }) {
    final allBlockedDomains = [...blockedDomains, ...customBlocklist];

    for (final blockedDomain in allBlockedDomains) {
      if (domain.contains(blockedDomain)) {
        return true;
      }
    }
    return false;
  }

  /// Check if a URL matches any blocked domain pattern
  static bool isUrlBlocked(
    String url, {
    List<String> customBlocklist = const [],
    List<String> whitelist = const [],
  }) {
    try {
      final uri = Uri.parse(url);
      final domain = uri.host;

      // Check whitelist first
      for (final whitelistedDomain in whitelist) {
        if (domain.contains(whitelistedDomain)) {
          return false;
        }
      }

      // Block URLs with tracking parameters
      if (url.contains('utm_') ||
          url.contains('?aff') ||
          url.contains('&aff') ||
          url.contains('pub_rfid=') ||
          url.contains('zoneid=') ||
          url.contains('/afu.php') ||
          url.contains('/rhd?')) {
        return true;
      }

      // Block .shop domains (commonly used for redirects)
      if (domain.endsWith('.shop')) {
        return true;
      }

      return isDomainBlocked(domain, customBlocklist: customBlocklist);
    } catch (e) {
      return false;
    }
  }
}
