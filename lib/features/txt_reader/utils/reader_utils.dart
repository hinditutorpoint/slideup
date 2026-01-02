import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// --------------------
/// Models
/// --------------------

class ReadingPosition {
  final String identifier;
  final int page;
  final double scrollOffset;
  final double progress;
  final DateTime lastRead;
  final String? chapter;
  final Map<String, dynamic>? metadata;

  ReadingPosition({
    required this.identifier,
    required this.page,
    this.scrollOffset = 0.0,
    this.progress = 0.0,
    DateTime? lastRead,
    this.chapter,
    this.metadata,
  }) : lastRead = lastRead ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'page': page,
    'scrollOffset': scrollOffset,
    'progress': progress,
    'lastRead': lastRead.toIso8601String(),
    'chapter': chapter,
    'metadata': metadata,
  };

  factory ReadingPosition.fromJson(Map<String, dynamic> json) {
    return ReadingPosition(
      identifier: json['identifier'] ?? '',
      page: json['page'] ?? 1,
      scrollOffset: (json['scrollOffset'] ?? 0.0).toDouble(),
      progress: (json['progress'] ?? 0.0).toDouble(),
      lastRead: json['lastRead'] != null
          ? DateTime.parse(json['lastRead'])
          : DateTime.now(),
      chapter: json['chapter'],
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }

  ReadingPosition copyWith({
    String? identifier,
    int? page,
    double? scrollOffset,
    double? progress,
    DateTime? lastRead,
    String? chapter,
    Map<String, dynamic>? metadata,
  }) {
    return ReadingPosition(
      identifier: identifier ?? this.identifier,
      page: page ?? this.page,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      progress: progress ?? this.progress,
      lastRead: lastRead ?? this.lastRead,
      chapter: chapter ?? this.chapter,
      metadata: metadata ?? this.metadata,
    );
  }
}

class Bookmark {
  final String id;
  final String identifier;
  final int page;
  final String? title;
  final String? note;
  final DateTime createdAt;
  final String? chapterId;
  final double? scrollOffset;

  Bookmark({
    String? id,
    required this.identifier,
    required this.page,
    this.title,
    this.note,
    DateTime? createdAt,
    this.chapterId,
    this.scrollOffset,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'identifier': identifier,
    'page': page,
    'title': title,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'chapterId': chapterId,
    'scrollOffset': scrollOffset,
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'],
      identifier: json['identifier'] ?? '',
      page: json['page'] ?? 1,
      title: json['title'],
      note: json['note'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      chapterId: json['chapterId'],
      scrollOffset: json['scrollOffset']?.toDouble(),
    );
  }

  Bookmark copyWith({
    String? id,
    String? identifier,
    int? page,
    String? title,
    String? note,
    DateTime? createdAt,
    String? chapterId,
    double? scrollOffset,
  }) {
    return Bookmark(
      id: id ?? this.id,
      identifier: identifier ?? this.identifier,
      page: page ?? this.page,
      title: title ?? this.title,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      chapterId: chapterId ?? this.chapterId,
      scrollOffset: scrollOffset ?? this.scrollOffset,
    );
  }
}

class Highlight {
  final String id;
  final String identifier;
  final int page;
  final String text;
  final int startOffset;
  final int endOffset;
  final String? color;
  final String? note;
  final DateTime createdAt;

  Highlight({
    String? id,
    required this.identifier,
    required this.page,
    required this.text,
    required this.startOffset,
    required this.endOffset,
    this.color,
    this.note,
    DateTime? createdAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'identifier': identifier,
    'page': page,
    'text': text,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'color': color,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Highlight.fromJson(Map<String, dynamic> json) {
    return Highlight(
      id: json['id'],
      identifier: json['identifier'] ?? '',
      page: json['page'] ?? 1,
      text: json['text'] ?? '',
      startOffset: json['startOffset'] ?? 0,
      endOffset: json['endOffset'] ?? 0,
      color: json['color'],
      note: json['note'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Highlight copyWith({
    String? id,
    String? identifier,
    int? page,
    String? text,
    int? startOffset,
    int? endOffset,
    String? color,
    String? note,
    DateTime? createdAt,
  }) {
    return Highlight(
      id: id ?? this.id,
      identifier: identifier ?? this.identifier,
      page: page ?? this.page,
      text: text ?? this.text,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      color: color ?? this.color,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Translation Settings for auto-translate feature
class TranslationSettings {
  final bool autoTranslateOnPageChange;
  final String targetLanguage;
  final bool showOriginalWithTranslation;
  final bool cacheTranslations;

  const TranslationSettings({
    this.autoTranslateOnPageChange = false,
    this.targetLanguage = 'en',
    this.showOriginalWithTranslation = false,
    this.cacheTranslations = true,
  });

  Map<String, dynamic> toJson() => {
    'autoTranslateOnPageChange': autoTranslateOnPageChange,
    'targetLanguage': targetLanguage,
    'showOriginalWithTranslation': showOriginalWithTranslation,
    'cacheTranslations': cacheTranslations,
  };

  factory TranslationSettings.fromJson(Map<String, dynamic> json) {
    return TranslationSettings(
      autoTranslateOnPageChange: json['autoTranslateOnPageChange'] ?? false,
      targetLanguage: json['targetLanguage'] ?? 'en',
      showOriginalWithTranslation: json['showOriginalWithTranslation'] ?? false,
      cacheTranslations: json['cacheTranslations'] ?? true,
    );
  }

  TranslationSettings copyWith({
    bool? autoTranslateOnPageChange,
    String? targetLanguage,
    bool? showOriginalWithTranslation,
    bool? cacheTranslations,
  }) {
    return TranslationSettings(
      autoTranslateOnPageChange:
          autoTranslateOnPageChange ?? this.autoTranslateOnPageChange,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      showOriginalWithTranslation:
          showOriginalWithTranslation ?? this.showOriginalWithTranslation,
      cacheTranslations: cacheTranslations ?? this.cacheTranslations,
    );
  }
}

class ReaderSettings {
  final double fontSize;
  final String fontFamily;
  final double lineHeight;
  final String theme;
  final double brightness;
  final bool keepScreenOn;
  final bool showPageNumber;
  final double margin;
  final String textAlign;
  final bool enablePageCurl;
  final bool enableSwipeNavigation;
  final bool autoPlayNextPage;
  final SwipeDirection swipeDirection;
  final PageTransitionType pageTransition;
  final TranslationSettings translationSettings;
  final AudiobookSettings? audiobookSettings;
  const ReaderSettings({
    this.fontSize = 16.0,
    this.fontFamily = 'System',
    this.lineHeight = 1.5,
    this.theme = 'dark',
    this.brightness = 1.0,
    this.keepScreenOn = true,
    this.showPageNumber = true,
    this.margin = 16.0,
    this.textAlign = 'left',
    this.enablePageCurl = true,
    this.enableSwipeNavigation = true,
    this.autoPlayNextPage = false,
    this.swipeDirection = SwipeDirection.both,
    this.pageTransition = PageTransitionType.curl,
    this.translationSettings = const TranslationSettings(),
    this.audiobookSettings = const AudiobookSettings(),
  });

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'fontFamily': fontFamily,
    'lineHeight': lineHeight,
    'theme': theme,
    'brightness': brightness,
    'keepScreenOn': keepScreenOn,
    'showPageNumber': showPageNumber,
    'margin': margin,
    'textAlign': textAlign,
    'enablePageCurl': enablePageCurl,
    'enableSwipeNavigation': enableSwipeNavigation,
    'autoPlayNextPage': autoPlayNextPage,
    'swipeDirection': swipeDirection.name,
    'pageTransition': pageTransition.name,
    'translationSettings': translationSettings.toJson(),
    'audiobookSettings': audiobookSettings!.toJson(),
  };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    return ReaderSettings(
      fontSize: (json['fontSize'] ?? 16.0).toDouble(),
      fontFamily: json['fontFamily'] ?? 'System',
      lineHeight: (json['lineHeight'] ?? 1.5).toDouble(),
      theme: json['theme'] ?? 'dark',
      brightness: (json['brightness'] ?? 1.0).toDouble(),
      keepScreenOn: json['keepScreenOn'] ?? true,
      showPageNumber: json['showPageNumber'] ?? true,
      margin: (json['margin'] ?? 16.0).toDouble(),
      textAlign: json['textAlign'] ?? 'left',
      enablePageCurl: json['enablePageCurl'] ?? true,
      enableSwipeNavigation: json['enableSwipeNavigation'] ?? true,
      autoPlayNextPage: json['autoPlayNextPage'] ?? true,
      swipeDirection: SwipeDirection.values.firstWhere(
        (e) => e.name == json['swipeDirection'],
        orElse: () => SwipeDirection.both,
      ),
      pageTransition: PageTransitionType.values.firstWhere(
        (e) => e.name == json['pageTransition'],
        orElse: () => PageTransitionType.curl,
      ),
      translationSettings: json['translationSettings'] != null
          ? TranslationSettings.fromJson(
              Map<String, dynamic>.from(json['translationSettings']),
            )
          : const TranslationSettings(),
      audiobookSettings: json['audiobookSettings'] != null
          ? AudiobookSettings.fromJson(
              Map<String, dynamic>.from(json['audiobookSettings']),
            )
          : const AudiobookSettings(),
    );
  }

  ReaderSettings copyWith({
    double? fontSize,
    String? fontFamily,
    double? lineHeight,
    String? theme,
    double? brightness,
    bool? keepScreenOn,
    bool? showPageNumber,
    double? margin,
    String? textAlign,
    bool? enablePageCurl,
    bool? enableSwipeNavigation,
    bool? autoPlayNextPage,
    SwipeDirection? swipeDirection,
    PageTransitionType? pageTransition,
    TranslationSettings? translationSettings,
    AudiobookSettings? audiobookSettings,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
      theme: theme ?? this.theme,
      brightness: brightness ?? this.brightness,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      showPageNumber: showPageNumber ?? this.showPageNumber,
      margin: margin ?? this.margin,
      textAlign: textAlign ?? this.textAlign,
      enablePageCurl: enablePageCurl ?? this.enablePageCurl,
      autoPlayNextPage: autoPlayNextPage ?? this.autoPlayNextPage,
      enableSwipeNavigation:
          enableSwipeNavigation ?? this.enableSwipeNavigation,
      swipeDirection: swipeDirection ?? this.swipeDirection,
      pageTransition: pageTransition ?? this.pageTransition,
      translationSettings: translationSettings ?? this.translationSettings,
      audiobookSettings: audiobookSettings ?? this.audiobookSettings,
    );
  }
}

enum DocumentType { pdf, epub, txt, unknown }

enum SwipeDirection { horizontal, vertical, both }

enum PageTransitionType { curl, slide, fade, none }

enum SortOrder { nameAsc, nameDesc, dateAsc, dateDesc, sizeAsc, sizeDesc }

enum PdfViewMode { grid, list }

enum PdfFileFilter { all, pdf, epub, txt, other }

/// --------------------
/// Translation Language Model
/// --------------------

class TranslationLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String emoji;

  const TranslationLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.emoji,
  });

  static const List<TranslationLanguage> supported = [
    TranslationLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      emoji: '🇺🇸',
    ),
    TranslationLanguage(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      emoji: '🇪🇸',
    ),
    TranslationLanguage(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      emoji: '🇫🇷',
    ),
    TranslationLanguage(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      emoji: '🇩🇪',
    ),
    TranslationLanguage(
      code: 'it',
      name: 'Italian',
      nativeName: 'Italiano',
      emoji: '🇮🇹',
    ),
    TranslationLanguage(
      code: 'pt',
      name: 'Portuguese',
      nativeName: 'Português',
      emoji: '🇵🇹',
    ),
    TranslationLanguage(
      code: 'ru',
      name: 'Russian',
      nativeName: 'Русский',
      emoji: '🇷🇺',
    ),
    TranslationLanguage(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      emoji: '🇨🇳',
    ),
    TranslationLanguage(
      code: 'ja',
      name: 'Japanese',
      nativeName: '日本語',
      emoji: '🇯🇵',
    ),
    TranslationLanguage(
      code: 'ko',
      name: 'Korean',
      nativeName: '한국어',
      emoji: '🇰🇷',
    ),
    TranslationLanguage(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      emoji: '🇸🇦',
    ),
    TranslationLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      emoji: '🇮🇳',
    ),
    TranslationLanguage(
      code: 'bn',
      name: 'Bengali',
      nativeName: 'বাংলা',
      emoji: '🇧🇩',
    ),
    TranslationLanguage(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      emoji: '🇵🇰',
    ),
    TranslationLanguage(
      code: 'tr',
      name: 'Turkish',
      nativeName: 'Türkçe',
      emoji: '🇹🇷',
    ),
    TranslationLanguage(
      code: 'vi',
      name: 'Vietnamese',
      nativeName: 'Tiếng Việt',
      emoji: '🇻🇳',
    ),
    TranslationLanguage(
      code: 'th',
      name: 'Thai',
      nativeName: 'ไทย',
      emoji: '🇹🇭',
    ),
    TranslationLanguage(
      code: 'nl',
      name: 'Dutch',
      nativeName: 'Nederlands',
      emoji: '🇳🇱',
    ),
    TranslationLanguage(
      code: 'pl',
      name: 'Polish',
      nativeName: 'Polski',
      emoji: '🇵🇱',
    ),
    TranslationLanguage(
      code: 'uk',
      name: 'Ukrainian',
      nativeName: 'Українська',
      emoji: '🇺🇦',
    ),
  ];

  static TranslationLanguage? fromCode(String code) {
    try {
      return supported.firstWhere((l) => l.code == code);
    } catch (_) {
      return null;
    }
  }
}

/// --------------------
/// Reader Tool Item Model
/// --------------------

class ReaderToolItem {
  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isLoading;
  final Color? activeColor;

  const ReaderToolItem({
    required this.id,
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
    this.isLoading = false,
    this.activeColor,
  });

  ReaderToolItem copyWith({
    String? id,
    IconData? icon,
    String? label,
    VoidCallback? onTap,
    bool? isActive,
    bool? isLoading,
    Color? activeColor,
  }) {
    return ReaderToolItem(
      id: id ?? this.id,
      icon: icon ?? this.icon,
      label: label ?? this.label,
      onTap: onTap ?? this.onTap,
      isActive: isActive ?? this.isActive,
      isLoading: isLoading ?? this.isLoading,
      activeColor: activeColor ?? this.activeColor,
    );
  }
}

/// Audiobook specific settings
class AudiobookSettings {
  final bool enabled;
  final bool autoTranslateBeforeSpeak;
  final bool continueInBackground;
  final bool showFloatingControls;
  final double delayBetweenPages; // seconds
  final int preloadPagesCount;
  final bool pauseOnPageChange; // manual page change pauses audiobook

  const AudiobookSettings({
    this.enabled = false,
    this.autoTranslateBeforeSpeak = false,
    this.continueInBackground = true,
    this.showFloatingControls = true,
    this.delayBetweenPages = 0.5,
    this.preloadPagesCount = 3,
    this.pauseOnPageChange = true,
  });

  AudiobookSettings copyWith({
    bool? enabled,
    bool? autoTranslateBeforeSpeak,
    bool? continueInBackground,
    bool? showFloatingControls,
    double? delayBetweenPages,
    int? preloadPagesCount,
    bool? pauseOnPageChange,
  }) {
    return AudiobookSettings(
      enabled: enabled ?? this.enabled,
      autoTranslateBeforeSpeak:
          autoTranslateBeforeSpeak ?? this.autoTranslateBeforeSpeak,
      continueInBackground: continueInBackground ?? this.continueInBackground,
      showFloatingControls: showFloatingControls ?? this.showFloatingControls,
      delayBetweenPages: delayBetweenPages ?? this.delayBetweenPages,
      preloadPagesCount: preloadPagesCount ?? this.preloadPagesCount,
      pauseOnPageChange: pauseOnPageChange ?? this.pauseOnPageChange,
    );
  }

  factory AudiobookSettings.fromJson(Map<String, dynamic> json) =>
      AudiobookSettings(
        enabled: json['enabled'] ?? false,
        autoTranslateBeforeSpeak: json['autoTranslateBeforeSpeak'] ?? false,
        continueInBackground: json['continueInBackground'] ?? true,
        showFloatingControls: json['showFloatingControls'] ?? true,
        delayBetweenPages: json['delayBetweenPages'] ?? 0.5,
        preloadPagesCount: json['preloadPagesCount'] ?? 3,
        pauseOnPageChange: json['pauseOnPageChange'] ?? true,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'autoTranslateBeforeSpeak': autoTranslateBeforeSpeak,
    'continueInBackground': continueInBackground,
    'showFloatingControls': showFloatingControls,
    'delayBetweenPages': delayBetweenPages,
    'preloadPagesCount': preloadPagesCount,
    'pauseOnPageChange': pauseOnPageChange,
  };
}

/// --------------------
/// Screen Size Helper
/// --------------------

class ScreenSizeHelper {
  final BuildContext context;

  ScreenSizeHelper(this.context);

  Size get size => MediaQuery.of(context).size;
  double get width => size.width;
  double get height => size.height;
  EdgeInsets get padding => MediaQuery.of(context).padding;
  double get safeTop => padding.top;
  double get safeBottom => padding.bottom;

  bool get isSmallScreen => width < 360;
  bool get isMediumScreen => width >= 360 && width < 600;
  bool get isLargeScreen => width >= 600;
  bool get isTablet => width >= 600;

  double get effectiveWidth => width - padding.left - padding.right;
  double get effectiveHeight => height - safeTop - safeBottom;

  // Responsive value based on screen size
  T responsive<T>({required T small, T? medium, T? large}) {
    if (isLargeScreen) return large ?? medium ?? small;
    if (isMediumScreen) return medium ?? small;
    return small;
  }

  // Scale factor for fonts and spacing
  double get scaleFactor {
    if (isSmallScreen) return 0.85;
    if (isLargeScreen) return 1.1;
    return 1.0;
  }
}

/// --------------------
/// Translation Cache Manager
/// --------------------

class TranslationCacheManager {
  static final TranslationCacheManager _instance =
      TranslationCacheManager._internal();
  factory TranslationCacheManager() => _instance;
  TranslationCacheManager._internal();

  final Map<String, String> _cache = {};
  static const int _maxCacheSize = 500;

  String _generateKey(String text, String targetLang) {
    final hash = md5.convert(utf8.encode('$text|$targetLang')).toString();
    return hash;
  }

  String? get(String text, String targetLang) {
    final key = _generateKey(text, targetLang);
    return _cache[key];
  }

  void set(String text, String targetLang, String translation) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entries (first 100)
      final keysToRemove = _cache.keys.take(100).toList();
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    }
    final key = _generateKey(text, targetLang);
    _cache[key] = translation;
  }

  void clear() {
    _cache.clear();
  }

  int get size => _cache.length;
}

/// --------------------
/// Storage Manager (Hive Implementation)
/// --------------------

class ReaderStorageManager {
  static final ReaderStorageManager _instance =
      ReaderStorageManager._internal();
  factory ReaderStorageManager() => _instance;
  ReaderStorageManager._internal();

  // Box Names
  static const String _positionsBoxName = 'reading_positions';
  static const String _bookmarksBoxName = 'bookmarks';
  static const String _highlightsBoxName = 'highlights';
  static const String _settingsBoxName = 'reader_settings';
  static const String _recentBoxName = 'recent_reads';
  static const String _translationsBoxName = 'translations_cache';

  // Hive Boxes
  late Box _positionsBox;
  late Box _bookmarksBox;
  late Box _highlightsBox;
  late Box _settingsBox;
  late Box _recentBox;
  late Box _translationsBox;

  // Memory Caches
  Map<String, ReadingPosition>? _positionsCache;
  Map<String, List<Bookmark>>? _bookmarksCache;
  Map<String, List<Highlight>>? _highlightsCache;
  ReaderSettings? _settingsCache;
  List<String>? _recentReadsCache;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();

      await Future.wait([
        _openPositionsBox(),
        _openBookmarksBox(),
        _openHighlightsBox(),
        _openSettingsBox(),
        _openRecentBox(),
        _openTranslationsBox(),
      ]);

      _loadPositionsCache();
      _loadBookmarksCache();
      _loadHighlightsCache();
      _loadSettingsCache();
      _loadRecentReadsCache();

      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ ReaderStorageManager init error: $e');
      _initialized = true;
    }
  }

  Future<void> _openPositionsBox() async {
    _positionsBox = await Hive.openBox(_positionsBoxName);
  }

  Future<void> _openBookmarksBox() async {
    _bookmarksBox = await Hive.openBox(_bookmarksBoxName);
  }

  Future<void> _openHighlightsBox() async {
    _highlightsBox = await Hive.openBox(_highlightsBoxName);
  }

  Future<void> _openSettingsBox() async {
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  Future<void> _openRecentBox() async {
    _recentBox = await Hive.openBox(_recentBoxName);
  }

  Future<void> _openTranslationsBox() async {
    _translationsBox = await Hive.openBox(_translationsBoxName);
  }

  // ========== Reading Positions ==========

  void _loadPositionsCache() {
    _positionsCache = {};
    for (var key in _positionsBox.keys) {
      final raw = _positionsBox.get(key);
      if (raw != null) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          _positionsCache![key.toString()] = ReadingPosition.fromJson(map);
        } catch (e) {
          debugPrint('Error loading position for $key: $e');
        }
      }
    }
  }

  Future<void> saveReadingPosition(ReadingPosition position) async {
    if (!_initialized) await initialize();
    _positionsCache ??= {};
    _positionsCache![position.identifier] = position;

    try {
      await _positionsBox.put(position.identifier, position.toJson());
      await _updateRecentReads(position.identifier);
    } catch (e) {
      debugPrint('⚠️ Failed to save position to Hive: $e');
    }
  }

  Future<ReadingPosition?> getReadingPosition(String identifier) async {
    if (!_initialized) await initialize();
    return _positionsCache?[identifier];
  }

  Future<void> deleteReadingPosition(String identifier) async {
    if (!_initialized) await initialize();
    _positionsCache?.remove(identifier);
    await _positionsBox.delete(identifier);
    await _removeFromRecentReads(identifier);
  }

  Future<Map<String, ReadingPosition>> getAllReadingPositions() async {
    if (!_initialized) await initialize();
    return Map.unmodifiable(_positionsCache ?? {});
  }

  // ========== Recent Reads ==========

  void _loadRecentReadsCache() {
    final raw = _recentBox.get('list');
    if (raw != null) {
      try {
        _recentReadsCache = List<String>.from(raw);
      } catch (_) {
        _recentReadsCache = [];
      }
    } else {
      _recentReadsCache = [];
    }
  }

  Future<void> _updateRecentReads(String identifier) async {
    _recentReadsCache ??= [];
    _recentReadsCache!.remove(identifier);
    _recentReadsCache!.insert(0, identifier);
    if (_recentReadsCache!.length > 100) {
      _recentReadsCache = _recentReadsCache!.sublist(0, 100);
    }
    await _recentBox.put('list', _recentReadsCache);
  }

  Future<void> _removeFromRecentReads(String identifier) async {
    _recentReadsCache?.remove(identifier);
    await _recentBox.put('list', _recentReadsCache);
  }

  Future<List<String>> getRecentReads() async {
    if (!_initialized) await initialize();
    return List.unmodifiable(_recentReadsCache ?? []);
  }

  Future<void> clearRecentReads() async {
    _recentReadsCache = [];
    await _recentBox.delete('list');
  }

  // ========== Bookmarks ==========

  void _loadBookmarksCache() {
    _bookmarksCache = {};
    for (var key in _bookmarksBox.keys) {
      final rawList = _bookmarksBox.get(key);
      if (rawList != null && rawList is List) {
        try {
          final bookmarks = rawList.map((b) {
            final map = Map<String, dynamic>.from(b as Map);
            return Bookmark.fromJson(map);
          }).toList();
          _bookmarksCache![key.toString()] = bookmarks;
        } catch (e) {
          debugPrint('Error loading bookmarks for $key: $e');
        }
      }
    }
  }

  Future<void> _persistBookmarks(String identifier) async {
    final list = _bookmarksCache?[identifier];
    if (list != null) {
      final jsonList = list.map((b) => b.toJson()).toList();
      await _bookmarksBox.put(identifier, jsonList);
    } else {
      await _bookmarksBox.delete(identifier);
    }
  }

  Future<void> addBookmark(Bookmark bookmark) async {
    if (!_initialized) await initialize();
    _bookmarksCache ??= {};
    _bookmarksCache![bookmark.identifier] ??= [];
    _bookmarksCache![bookmark.identifier]!.removeWhere(
      (b) => b.page == bookmark.page,
    );
    _bookmarksCache![bookmark.identifier]!.add(bookmark);
    await _persistBookmarks(bookmark.identifier);
  }

  Future<List<Bookmark>> getBookmarks(String identifier) async {
    if (!_initialized) await initialize();
    final bookmarks = _bookmarksCache?[identifier] ?? [];
    final sorted = List<Bookmark>.from(bookmarks);
    sorted.sort((a, b) => a.page.compareTo(b.page));
    return List.unmodifiable(sorted);
  }

  Future<List<Bookmark>> getAllBookmarks() async {
    if (!_initialized) await initialize();
    final all = <Bookmark>[];
    _bookmarksCache?.forEach((_, list) => all.addAll(list));
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(all);
  }

  Future<void> removeBookmark(String identifier, String bookmarkId) async {
    if (!_initialized) await initialize();
    final list = _bookmarksCache?[identifier];
    if (list != null) {
      list.removeWhere((b) => b.id == bookmarkId);
      await _persistBookmarks(identifier);
    }
  }

  Future<void> updateBookmark(Bookmark bookmark) async {
    if (!_initialized) await initialize();
    final list = _bookmarksCache?[bookmark.identifier];
    if (list == null) return;
    final index = list.indexWhere((b) => b.id == bookmark.id);
    if (index != -1) {
      list[index] = bookmark;
      await _persistBookmarks(bookmark.identifier);
    }
  }

  // ========== Highlights ==========

  void _loadHighlightsCache() {
    _highlightsCache = {};
    for (var key in _highlightsBox.keys) {
      final rawList = _highlightsBox.get(key);
      if (rawList != null && rawList is List) {
        try {
          final highlights = rawList.map((h) {
            final map = Map<String, dynamic>.from(h as Map);
            return Highlight.fromJson(map);
          }).toList();
          _highlightsCache![key.toString()] = highlights;
        } catch (e) {
          debugPrint('Error loading highlights for $key: $e');
        }
      }
    }
  }

  Future<void> _persistHighlights(String identifier) async {
    final list = _highlightsCache?[identifier];
    if (list != null) {
      final jsonList = list.map((h) => h.toJson()).toList();
      await _highlightsBox.put(identifier, jsonList);
    } else {
      await _highlightsBox.delete(identifier);
    }
  }

  Future<void> addHighlight(Highlight highlight) async {
    if (!_initialized) await initialize();
    _highlightsCache ??= {};
    _highlightsCache![highlight.identifier] ??= [];
    _highlightsCache![highlight.identifier]!.add(highlight);
    await _persistHighlights(highlight.identifier);
  }

  Future<List<Highlight>> getHighlights(String identifier) async {
    if (!_initialized) await initialize();
    final highlights = _highlightsCache?[identifier] ?? [];
    final sorted = List<Highlight>.from(highlights);
    sorted.sort((a, b) => a.page.compareTo(b.page));
    return List.unmodifiable(sorted);
  }

  Future<void> removeHighlight(String identifier, String highlightId) async {
    if (!_initialized) await initialize();
    final list = _highlightsCache?[identifier];
    if (list != null) {
      list.removeWhere((h) => h.id == highlightId);
      await _persistHighlights(identifier);
    }
  }

  // ========== Settings ==========

  void _loadSettingsCache() {
    final raw = _settingsBox.get('current');
    if (raw != null) {
      try {
        final map = Map<String, dynamic>.from(raw as Map);
        _settingsCache = ReaderSettings.fromJson(map);
      } catch (_) {
        _settingsCache = const ReaderSettings();
      }
    } else {
      _settingsCache = const ReaderSettings();
    }
  }

  Future<ReaderSettings> getSettings() async {
    if (!_initialized) await initialize();
    return _settingsCache ?? const ReaderSettings();
  }

  Future<void> saveSettings(ReaderSettings settings) async {
    if (!_initialized) await initialize();
    _settingsCache = settings;
    try {
      await _settingsBox.put('current', settings.toJson());
    } catch (e) {
      debugPrint('⚠️ Failed to save settings: $e');
    }
  }

  // ========== Translations Cache (Persistent) ==========

  Future<String?> getCachedTranslation(String text, String targetLang) async {
    if (!_initialized) await initialize();
    final key = md5.convert(utf8.encode('$text|$targetLang')).toString();
    return _translationsBox.get(key);
  }

  Future<void> cacheTranslation(
    String text,
    String targetLang,
    String translation,
  ) async {
    if (!_initialized) await initialize();
    final key = md5.convert(utf8.encode('$text|$targetLang')).toString();
    await _translationsBox.put(key, translation);
  }

  Future<void> clearTranslationsCache() async {
    if (!_initialized) await initialize();
    await _translationsBox.clear();
  }

  // ========== Clear All ==========

  Future<void> clearAllData() async {
    if (!_initialized) await initialize();

    _positionsCache = {};
    _bookmarksCache = {};
    _highlightsCache = {};
    _recentReadsCache = [];
    _settingsCache = const ReaderSettings();

    try {
      await _positionsBox.clear();
      await _bookmarksBox.clear();
      await _highlightsBox.clear();
      await _recentBox.clear();
      await _translationsBox.clear();
    } catch (e) {
      debugPrint('⚠️ Failed to clear all data: $e');
    }
  }

  Future<void> clearAllIncludingSettings() async {
    await clearAllData();
    try {
      await _settingsBox.clear();
    } catch (e) {
      debugPrint('⚠️ Failed to clear settings: $e');
    }
  }
}

/// --------------------
/// Directory helper
/// --------------------

class AppDirectoryProvider {
  static Future<Directory> preferredBaseDir() async {
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    }
    return getApplicationSupportDirectory();
  }

  static Future<Directory> tempDir() async {
    return getTemporaryDirectory();
  }

  static Future<Directory> cacheDir() async {
    final base = await preferredBaseDir();
    final dir = Directory('${base.path}/cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

/// --------------------
/// Cache Manager
/// --------------------

class DocumentCacheManager {
  static final DocumentCacheManager _instance =
      DocumentCacheManager._internal();
  factory DocumentCacheManager() => _instance;
  DocumentCacheManager._internal();

  Directory? _cacheDir;

  Future<Directory> get cacheDirectory async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await AppDirectoryProvider.preferredBaseDir();
    _cacheDir = Directory('${base.path}/document_cache');
    if (!await _cacheDir!.exists()) await _cacheDir!.create(recursive: true);
    return _cacheDir!;
  }

  String cacheKeyForUrl(String url) => md5.convert(utf8.encode(url)).toString();

  String _getExtensionFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final path = uri.path.toLowerCase();
    if (path.endsWith('.pdf')) return '.pdf';
    if (path.endsWith('.epub')) return '.epub';
    if (path.endsWith('.txt')) return '.txt';
    return '';
  }

  Future<File> getCacheFileForUrl(String url, {String? extension}) async {
    final dir = await cacheDirectory;
    final key = cacheKeyForUrl(url);
    final ext = extension ?? _getExtensionFromUrl(url);
    return File('${dir.path}/$key$ext');
  }

  Future<File?> getCachedFileIfValid(
    String url, {
    String? extension,
    Duration maxAge = const Duration(days: 7),
  }) async {
    try {
      final file = await getCacheFileForUrl(url, extension: extension);
      if (!await file.exists()) return null;
      if (await file.length() == 0) return null;
      final stat = await file.stat();
      if (DateTime.now().difference(stat.modified) > maxAge) return null;
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCache() async {
    try {
      final dir = await cacheDirectory;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to clear cache: $e');
    }
  }

  Future<int> getCacheSize() async {
    try {
      final dir = await cacheDirectory;
      if (!await dir.exists()) return 0;
      int size = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
      return size;
    } catch (_) {
      return 0;
    }
  }
}

/// --------------------
/// Download Helpers
/// --------------------

class DocumentDownloadManager {
  static String normalizeArchiveUrl(String url) {
    if (url.contains('archive.org') && !url.contains('/download/')) {
      return url.replaceAll('/stream/', '/download/');
    }
    return url;
  }
}

class DioPdfDownloader {
  final Dio dio;

  DioPdfDownloader({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 5),
              sendTimeout: const Duration(seconds: 20),
              headers: const {
                'User-Agent': 'Mozilla/5.0 (compatible; ArchiveApp/1.0)',
                'Accept': 'application/pdf,*/*',
              },
            ),
          );

  Future<File> downloadToFile(
    String url,
    File outFile, {
    required CancelToken cancelToken,
    void Function(double? progress)? onProgress,
  }) async {
    final normalized = DocumentDownloadManager.normalizeArchiveUrl(url);
    await outFile.parent.create(recursive: true);

    final tmpPath = '${outFile.path}.part';

    try {
      await dio.download(
        normalized,
        tmpPath,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (onProgress == null) return;
          if (total <= 0) {
            onProgress(null);
          } else {
            onProgress(received / total);
          }
        },
      );

      final tmp = File(tmpPath);
      if (!await tmp.exists() || await tmp.length() == 0) {
        throw Exception('Downloaded file is empty');
      }

      if (await outFile.exists()) await outFile.delete();
      return tmp.rename(outFile.path);
    } catch (e) {
      final tmp = File(tmpPath);
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  void dispose() => dio.close(force: true);
}

/// --------------------
/// Downloads Library
/// --------------------

class DownloadedPdfItem {
  final String id;
  String title;
  final String? sourceUrl;
  String fileName;
  final DateTime addedAt;
  DateTime? lastOpened;
  int? sizeBytes;
  final String? thumbnailUrl;
  final Map<String, dynamic>? metadata;

  DownloadedPdfItem({
    required this.id,
    required this.title,
    required this.fileName,
    required this.addedAt,
    this.sourceUrl,
    this.lastOpened,
    this.sizeBytes,
    this.thumbnailUrl,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sourceUrl': sourceUrl,
    'fileName': fileName,
    'addedAt': addedAt.toIso8601String(),
    'lastOpened': lastOpened?.toIso8601String(),
    'sizeBytes': sizeBytes,
    'thumbnailUrl': thumbnailUrl,
    'metadata': metadata,
  };

  factory DownloadedPdfItem.fromJson(Map<String, dynamic> json) {
    return DownloadedPdfItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      sourceUrl: json['sourceUrl'],
      fileName: json['fileName'] ?? '',
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
      lastOpened: json['lastOpened'] != null
          ? DateTime.parse(json['lastOpened'])
          : null,
      sizeBytes: json['sizeBytes'],
      thumbnailUrl: json['thumbnailUrl'],
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }

  DownloadedPdfItem copyWith({
    String? id,
    String? title,
    String? sourceUrl,
    String? fileName,
    DateTime? addedAt,
    DateTime? lastOpened,
    int? sizeBytes,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) {
    return DownloadedPdfItem(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      fileName: fileName ?? this.fileName,
      addedAt: addedAt ?? this.addedAt,
      lastOpened: lastOpened ?? this.lastOpened,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  String get extension {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  bool get isPdf => extension == 'pdf';
  bool get isEpub => extension == 'epub';
  bool get isTxt => extension == 'txt';
}

class DownloadLibraryManager {
  static final DownloadLibraryManager _instance =
      DownloadLibraryManager._internal();
  factory DownloadLibraryManager() => _instance;
  DownloadLibraryManager._internal();

  Directory? _downloadsDir;
  File? _indexFile;

  final Map<String, DownloadedPdfItem> _items = {};
  bool _loaded = false;

  Future<Directory> get downloadsDirectory async {
    if (_downloadsDir != null) return _downloadsDir!;
    final base = await AppDirectoryProvider.preferredBaseDir();
    _downloadsDir = Directory('${base.path}/downloads');
    if (!await _downloadsDir!.exists()) {
      await _downloadsDir!.create(recursive: true);
    }
    return _downloadsDir!;
  }

  Future<File> _getIndexFile() async {
    if (_indexFile != null) return _indexFile!;
    final dir = await downloadsDirectory;
    _indexFile = File('${dir.path}/downloads_index.json');
    return _indexFile!;
  }

  String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

  String _idForUrlOrRandom(String? url) {
    if (url != null && url.isNotEmpty) {
      return md5.convert(utf8.encode(url)).toString();
    }
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    return md5.convert(utf8.encode(now)).toString();
  }

  String _suggestFileName(String title, String id, {String ext = 'pdf'}) {
    final safe = _sanitize(title);
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;
    return '${safe.isEmpty ? "document" : safe}_$shortId.$ext';
  }

  Future<void> initialize() async {
    if (_loaded) return;
    await _loadIndex();
    _loaded = true;
  }

  Future<void> _loadIndex() async {
    try {
      final file = await _getIndexFile();
      if (!await file.exists()) return;
      final txt = await file.readAsString();
      final List list = jsonDecode(txt);
      for (final e in list) {
        final item = DownloadedPdfItem.fromJson(
          (e as Map).cast<String, dynamic>(),
        );
        if (item.id.isNotEmpty) _items[item.id] = item;
      }
      await _cleanupMissingFiles();
    } catch (e) {
      debugPrint('⚠️ Download index load error: $e');
    }
  }

  Future<void> _saveIndex() async {
    try {
      final file = await _getIndexFile();
      final list = _items.values.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(list), flush: true);
    } catch (e) {
      debugPrint('⚠️ Download index save error: $e');
    }
  }

  Future<void> _cleanupMissingFiles() async {
    final dir = await downloadsDirectory;
    final toRemove = <String>[];
    for (final item in _items.values) {
      final f = File('${dir.path}/${item.fileName}');
      if (!await f.exists()) toRemove.add(item.id);
    }
    for (final id in toRemove) {
      _items.remove(id);
    }
    if (toRemove.isNotEmpty) await _saveIndex();
  }

  Future<List<DownloadedPdfItem>> listDownloads({
    SortOrder sortOrder = SortOrder.dateDesc,
    String? searchQuery,
    PdfFileFilter filter = PdfFileFilter.all,
  }) async {
    await initialize();

    var list = _items.values.toList();

    if (filter != PdfFileFilter.all) {
      list = list.where((item) {
        switch (filter) {
          case PdfFileFilter.pdf:
            return item.isPdf;
          case PdfFileFilter.epub:
            return item.isEpub;
          case PdfFileFilter.txt:
            return item.isTxt;
          case PdfFileFilter.other:
            return !item.isPdf && !item.isEpub && !item.isTxt;
          case PdfFileFilter.all:
            return true;
        }
      }).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      list = list.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.fileName.toLowerCase().contains(query);
      }).toList();
    }

    list.sort((a, b) {
      switch (sortOrder) {
        case SortOrder.nameAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case SortOrder.nameDesc:
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
        case SortOrder.dateAsc:
          final ad = a.lastOpened ?? a.addedAt;
          final bd = b.lastOpened ?? b.addedAt;
          return ad.compareTo(bd);
        case SortOrder.dateDesc:
          final ad = a.lastOpened ?? a.addedAt;
          final bd = b.lastOpened ?? b.addedAt;
          return bd.compareTo(ad);
        case SortOrder.sizeAsc:
          return (a.sizeBytes ?? 0).compareTo(b.sizeBytes ?? 0);
        case SortOrder.sizeDesc:
          return (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0);
      }
    });

    return list;
  }

  Future<int> get totalCount async {
    await initialize();
    return _items.length;
  }

  Future<int> get totalSize async {
    await initialize();
    int total = 0;
    for (final item in _items.values) {
      total += item.sizeBytes ?? 0;
    }
    return total;
  }

  Future<File> getFileForItem(DownloadedPdfItem item) async {
    final dir = await downloadsDirectory;
    return File('${dir.path}/${item.fileName}');
  }

  Future<DownloadedPdfItem?> getItemById(String id) async {
    await initialize();
    return _items[id];
  }

  Future<DownloadedPdfItem?> getItemByUrl(String url) async {
    await initialize();
    final id = _idForUrlOrRandom(url);
    return _items[id];
  }

  Future<bool> isDownloaded(String url) async {
    final item = await getItemByUrl(url);
    if (item == null) return false;
    final file = await getFileForItem(item);
    return file.exists();
  }

  Future<DownloadedPdfItem> saveFromExistingFile({
    required File sourceFile,
    required String title,
    String? sourceUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) async {
    await initialize();
    final id = _idForUrlOrRandom(sourceUrl);

    final existing = _items[id];
    if (existing != null) {
      existing.lastOpened = DateTime.now();
      await _saveIndex();
      return existing;
    }

    final dir = await downloadsDirectory;
    final ext = sourceFile.path.split('.').last.toLowerCase();
    String fileName = _suggestFileName(title, id, ext: ext);
    File out = File('${dir.path}/$fileName');

    if (await out.exists()) {
      fileName = _suggestFileName(
        '$title ${DateTime.now().millisecondsSinceEpoch}',
        id,
        ext: ext,
      );
      out = File('${dir.path}/$fileName');
    }

    await out.parent.create(recursive: true);
    await sourceFile.copy(out.path);

    final size = await out.length();

    final item = DownloadedPdfItem(
      id: id,
      title: title,
      sourceUrl: sourceUrl,
      fileName: fileName,
      addedAt: DateTime.now(),
      sizeBytes: size,
      thumbnailUrl: thumbnailUrl,
      metadata: metadata,
    );

    _items[id] = item;
    await _saveIndex();
    return item;
  }

  Future<DownloadedPdfItem> downloadAndSave({
    required String url,
    required String title,
    required DioPdfDownloader downloader,
    required CancelToken cancelToken,
    void Function(double? p)? onProgress,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) async {
    await initialize();

    final normalized = DocumentDownloadManager.normalizeArchiveUrl(url);
    final id = _idForUrlOrRandom(normalized);

    final existing = _items[id];
    if (existing != null) {
      final file = await getFileForItem(existing);
      if (await file.exists() && await file.length() > 0) {
        return existing;
      }
    }

    final dir = await downloadsDirectory;
    final ext = normalized.contains('.epub') ? 'epub' : 'pdf';
    final fileName = _suggestFileName(title, id, ext: ext);
    final outFile = File('${dir.path}/$fileName');

    await downloader.downloadToFile(
      normalized,
      outFile,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );

    final size = await outFile.length();

    final item = DownloadedPdfItem(
      id: id,
      title: title,
      sourceUrl: normalized,
      fileName: fileName,
      addedAt: DateTime.now(),
      sizeBytes: size,
      thumbnailUrl: thumbnailUrl,
      metadata: metadata,
    );

    _items[id] = item;
    await _saveIndex();
    return item;
  }

  Future<void> markOpened(String id) async {
    await initialize();
    final item = _items[id];
    if (item == null) return;
    item.lastOpened = DateTime.now();
    await _saveIndex();
  }

  Future<void> delete(String id) async {
    await initialize();
    final item = _items[id];
    if (item == null) return;

    final file = await getFileForItem(item);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        debugPrint('⚠️ Delete file error: $e');
      }
    }

    _items.remove(id);
    await _saveIndex();
  }

  Future<void> deleteMultiple(List<String> ids) async {
    for (final id in ids) {
      await delete(id);
    }
  }

  Future<void> rename(
    String id,
    String newTitle, {
    bool renameFileOnDisk = true,
  }) async {
    await initialize();
    final item = _items[id];
    if (item == null) return;

    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    item.title = trimmed;

    if (renameFileOnDisk) {
      final dir = await downloadsDirectory;
      final oldFile = File('${dir.path}/${item.fileName}');
      if (await oldFile.exists()) {
        var newFileName = _suggestFileName(trimmed, id, ext: item.extension);
        var newFile = File('${dir.path}/$newFileName');

        if (await newFile.exists()) {
          newFileName = _suggestFileName(
            '$trimmed ${DateTime.now().millisecondsSinceEpoch}',
            id,
            ext: item.extension,
          );
          newFile = File('${dir.path}/$newFileName');
        }

        try {
          await oldFile.rename(newFile.path);
          item.fileName = newFileName;
        } catch (e) {
          debugPrint('⚠️ Rename file error: $e');
        }
      }
    }

    await _saveIndex();
  }

  Future<void> clearAll() async {
    await initialize();
    final dir = await downloadsDirectory;

    for (final item in _items.values) {
      final file = File('${dir.path}/${item.fileName}');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    _items.clear();
    await _saveIndex();
  }
}

/// --------------------
/// Thumbnails
/// --------------------

class ArchivePageThumbnailManager {
  static final ArchivePageThumbnailManager _instance =
      ArchivePageThumbnailManager._internal();
  factory ArchivePageThumbnailManager() => _instance;
  ArchivePageThumbnailManager._internal();

  final http.Client _client = http.Client();

  final Map<String, Uint8List> _thumbnailCache = {};
  int _thumbBytes = 0;
  static const int _maxThumbBytes = 20 * 1024 * 1024;
  static const int _maxThumbEntries = 300;

  final Set<String> _failedUrls = {};
  final Map<String, Future<Uint8List?>> _inFlight = {};

  String getPageThumbnailUrl(String identifier, int page, {int scale = 2}) {
    return 'https://archive.org/download/$identifier/page/n$page.jpg';
  }

  Future<Directory> _thumbDir() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/thumbnails');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    return cacheDir;
  }

  Future<Uint8List?> _loadFromDiskCache(String key) async {
    try {
      final dir = await _thumbDir();
      final file = File('${dir.path}/$key.jpg');
      if (await file.exists()) return await file.readAsBytes();
    } catch (_) {}
    return null;
  }

  Future<void> _saveToDiskCache(String key, Uint8List bytes) async {
    try {
      final dir = await _thumbDir();
      final file = File('${dir.path}/$key.jpg');
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  void _addToMemoryCache(String key, Uint8List bytes) {
    final existing = _thumbnailCache[key];
    if (existing != null) {
      _thumbBytes -= existing.length;
      _thumbnailCache.remove(key);
    }
    _thumbnailCache[key] = bytes;
    _thumbBytes += bytes.length;

    while (_thumbnailCache.length > _maxThumbEntries ||
        _thumbBytes > _maxThumbBytes) {
      final firstKey = _thumbnailCache.keys.first;
      final removed = _thumbnailCache.remove(firstKey);
      if (removed != null) _thumbBytes -= removed.length;
    }
  }

  Future<Uint8List?> getPageThumbnail(
    String identifier,
    int page, {
    int scale = 2,
    int maxRetries = 2,
  }) {
    final cacheKey = '${identifier}_page_$page';
    final url = getPageThumbnailUrl(identifier, page, scale: scale);

    final hit = _thumbnailCache[cacheKey];
    if (hit != null) return Future.value(hit);
    if (_failedUrls.contains(url)) return Future.value(null);

    final inflight = _inFlight[cacheKey];
    if (inflight != null) return inflight;

    final future = () async {
      final disk = await _loadFromDiskCache(cacheKey);
      if (disk != null && disk.isNotEmpty) {
        _addToMemoryCache(cacheKey, disk);
        return disk;
      }

      for (int retry = 0; retry < maxRetries; retry++) {
        try {
          final resp = await _client
              .get(
                Uri.parse(url),
                headers: const {
                  'User-Agent': 'Mozilla/5.0 (compatible; ArchiveApp/1.0)',
                },
              )
              .timeout(const Duration(seconds: 10));

          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            final bytes = resp.bodyBytes;
            _addToMemoryCache(cacheKey, bytes);
            unawaited(_saveToDiskCache(cacheKey, bytes));
            return bytes;
          }

          if (resp.statusCode == 404) {
            _failedUrls.add(url);
            return null;
          }
        } catch (_) {
          if (retry == maxRetries - 1) _failedUrls.add(url);
          await Future.delayed(Duration(milliseconds: 350 * (retry + 1)));
        }
      }
      return null;
    }();

    _inFlight[cacheKey] = future;
    future.whenComplete(() => _inFlight.remove(cacheKey));
    return future;
  }

  void clearCache() {
    _thumbnailCache.clear();
    _thumbBytes = 0;
    _failedUrls.clear();
    _inFlight.clear();
  }
}

/// --------------------
/// Utilities
/// --------------------

class DocumentUtils {
  static DocumentType detectDocumentType(String url) {
    final uri = Uri.tryParse(url.toLowerCase());
    if (uri == null) return DocumentType.unknown;

    final path = uri.path;
    if (path.endsWith('.pdf')) return DocumentType.pdf;
    if (path.endsWith('.epub')) return DocumentType.epub;
    if (path.endsWith('.txt')) return DocumentType.txt;

    if (url.contains('archive.org')) {
      if (path.contains('/download/') && path.contains('.pdf')) {
        return DocumentType.pdf;
      }
      if (path.contains('/download/') && path.contains('.epub')) {
        return DocumentType.epub;
      }
      if (path.contains('/download/') && path.contains('.txt')) {
        return DocumentType.txt;
      }
    }
    return DocumentType.unknown;
  }

  static String formatProgress(double progress) {
    return '${(progress * 100).toStringAsFixed(0)}%';
  }

  static String? extractArchiveIdentifier(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.host.contains('archive.org')) return null;
      final segs = uri.pathSegments;

      final detailsIndex = segs.indexOf('details');
      if (detailsIndex != -1 && detailsIndex + 1 < segs.length) {
        return segs[detailsIndex + 1];
      }

      final downloadIndex = segs.indexOf('download');
      if (downloadIndex != -1 && downloadIndex + 1 < segs.length) {
        return segs[downloadIndex + 1];
      }

      final streamIndex = segs.indexOf('stream');
      if (streamIndex != -1 && streamIndex + 1 < segs.length) {
        return segs[streamIndex + 1];
      }
    } catch (_) {}
    return null;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String formatReadingTime(Duration duration) {
    if (duration.isNegative) return 'Just now';

    final seconds = duration.inSeconds;
    if (seconds < 60) return 'Just now';

    final minutes = duration.inMinutes;
    if (minutes < 60) return '${minutes}m ago';

    final hours = duration.inHours;
    if (hours < 24) return '${hours}h ago';

    final days = duration.inDays;
    if (days < 7) return '${days}d ago';
    if (days < 30) return '${(days / 7).floor()}w ago';
    if (days < 365) return '${(days / 30).floor()}mo ago';

    return '${(days / 365).floor()}y ago';
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  static String extractTitleFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return 'Document';

    final lastSegment = uri.pathSegments.last;
    return lastSegment
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[_-]'), ' ')
        .trim();
  }
}

/// Horizontal scrollable tool bar
class HorizontalToolBar extends StatelessWidget {
  final List<ReaderToolItem> tools;
  final Color? backgroundColor;
  final double height;
  final EdgeInsets padding;

  const HorizontalToolBar({
    super.key,
    required this.tools,
    this.backgroundColor,
    this.height = 56,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: backgroundColor ?? Theme.of(context).cardColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: tools
              .map((tool) => _buildToolButton(context, tool))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildToolButton(BuildContext context, ReaderToolItem tool) {
    final isActive = tool.isActive;
    final activeColor = tool.activeColor ?? Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tool.isLoading ? null : tool.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border.all(color: activeColor.withValues(alpha: 0.5))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tool.isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        isActive
                            ? activeColor
                            : Theme.of(context).iconTheme.color,
                      ),
                    ),
                  )
                else
                  Icon(
                    tool.icon,
                    size: 18,
                    color: isActive ? activeColor : null,
                  ),
                const SizedBox(width: 6),
                Text(
                  tool.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? activeColor : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
