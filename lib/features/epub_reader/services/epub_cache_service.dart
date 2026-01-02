import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/safe_async.dart';
import '../../../core/utils/memory_manager.dart';
import '../models/epub_chapter.dart';
import '../models/reading_progress.dart';

/// Cache entry with metadata
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  final int sizeBytes;
  final String? etag;

  CacheEntry({
    required this.data,
    required this.createdAt,
    required this.sizeBytes,
    this.etag,
  }) : lastAccessedAt = createdAt;

  CacheEntry<T> touch() {
    return CacheEntry(
      data: data,
      createdAt: createdAt,
      sizeBytes: sizeBytes,
      etag: etag,
    );
  }

  bool get isExpired =>
      DateTime.now().difference(createdAt) > AppConstants.cacheMaxAge;

  Duration get age => DateTime.now().difference(createdAt);

  Map<String, dynamic> toJson(dynamic Function(T) dataToJson) => {
    'data': dataToJson(data),
    'createdAt': createdAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
    'sizeBytes': sizeBytes,
    'etag': etag,
  };

  factory CacheEntry.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) dataFromJson,
  ) {
    return CacheEntry(
      data: dataFromJson(json['data']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      etag: json['etag'] as String?,
    );
  }
}

/// EPUB Cache Service - Manages caching of EPUB content
class EpubCacheService {
  EpubCacheService._();

  static final EpubCacheService _instance = EpubCacheService._();
  static EpubCacheService get instance => _instance;

  // Memory manager reference
  final MemoryManager _memoryManager = MemoryManager.instance;

  // Hive boxes
  Box<dynamic>? _chapterCacheBox;
  Box<dynamic>? _imageCacheBox;
  Box<dynamic>? _translationCacheBox;
  Box<dynamic>? _metadataBox;

  // Disk cache directories
  String? _imageCacheDir;
  String? _chapterCacheDir;
  String? _coverCacheDir;

  // In-memory caches
  final Map<String, CacheEntry<EpubChapter>> _chapterMemoryCache = {};
  final Map<String, CacheEntry<Uint8List>> _imageMemoryCache = {};
  final Map<String, CacheEntry<TextTranslation>> _translationMemoryCache = {};

  // Image path cache (in-memory for quick access)
  final Map<String, String> _imagePathCache = {};

  // Cache statistics
  int _cacheHits = 0;
  int _cacheMisses = 0;

  // Is initialized
  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;
  int get cacheHits => _cacheHits;
  int get cacheMisses => _cacheMisses;
  double get hitRate => (_cacheHits + _cacheMisses) > 0
      ? _cacheHits / (_cacheHits + _cacheMisses)
      : 0.0;

  /// Initialize cache service
  Future<Result<void>> initialize() async {
    if (_isInitialized) return Result.success(null);

    return SafeAsync.run(() async {
      // Initialize Hive boxes
      _chapterCacheBox = await Hive.openBox('chapter_cache');
      _imageCacheBox = await Hive.openBox('image_cache');
      _translationCacheBox = await Hive.openBox('translation_cache');
      _metadataBox = await Hive.openBox('cache_metadata');

      // Create disk cache directories
      final appDir = await getApplicationDocumentsDirectory();
      final cacheBase = path.join(appDir.path, AppConstants.epubCacheDir);

      _imageCacheDir = path.join(cacheBase, 'images');
      _chapterCacheDir = path.join(cacheBase, 'chapters');
      _coverCacheDir = path.join(cacheBase, 'covers');

      await Directory(_imageCacheDir!).create(recursive: true);
      await Directory(_chapterCacheDir!).create(recursive: true);
      await Directory(_coverCacheDir!).create(recursive: true);

      // Load existing image paths from Hive to memory cache
      await _loadImagePathCache();

      // Setup memory pressure listener
      _memoryManager.addListener(_handleMemoryPressure);

      // Clean up expired entries
      await _cleanupExpiredEntries();

      _isInitialized = true;
      debugPrint('EpubCacheService initialized');
    }, operationName: 'EpubCacheService.initialize');
  }

  /// Load image paths from Hive to memory cache
  Future<void> _loadImagePathCache() async {
    try {
      for (final key in _imageCacheBox?.keys ?? []) {
        final data = _imageCacheBox?.get(key);
        if (data is Map && data['filePath'] is String) {
          final filePath = data['filePath'] as String;
          final file = File(filePath);
          if (await file.exists()) {
            _imagePathCache[key.toString()] = filePath;
          }
        }
      }
      debugPrint('Loaded ${_imagePathCache.length} image paths from cache');
    } catch (e) {
      debugPrint('Failed to load image path cache: $e');
    }
  }

  /// Dispose service
  Future<void> dispose() async {
    try {
      _memoryManager.removeListener(_handleMemoryPressure);

      // Clear memory caches
      _chapterMemoryCache.clear();
      _imageMemoryCache.clear();
      _translationMemoryCache.clear();
      _imagePathCache.clear();

      // Close Hive boxes
      await _chapterCacheBox?.close();
      await _imageCacheBox?.close();
      await _translationCacheBox?.close();
      await _metadataBox?.close();

      _isInitialized = false;
      debugPrint('EpubCacheService disposed');
    } catch (e) {
      debugPrint('EpubCacheService dispose error: $e');
    }
  }

  // ===========================================================================
  // CHAPTER CACHE
  // ===========================================================================

  /// Cache chapter content
  Future<Result<void>> cacheChapter(String key, EpubChapter chapter) async {
    return SafeAsync.run(() async {
      final sizeBytes = _estimateChapterSize(chapter);

      // Store in memory cache
      _chapterMemoryCache[key] = CacheEntry(
        data: chapter,
        createdAt: DateTime.now(),
        sizeBytes: sizeBytes,
      );

      // Also store chapter metadata in Hive (not full content for memory)
      await _chapterCacheBox?.put(key, {
        'id': chapter.id,
        'title': chapter.title,
        'index': chapter.index,
        'href': chapter.href,
        'wordCount': chapter.wordCount,
        'cachedAt': DateTime.now().toIso8601String(),
      });

      // Store full content on disk if large
      if (sizeBytes > 100 * 1024) {
        await _saveChapterToDisk(key, chapter);
      }

      _updateCacheMetadata();
    }, operationName: 'cacheChapter');
  }

  /// Get cached chapter
  Future<EpubChapter?> getChapter(String key) async {
    // Check memory cache first
    final memoryEntry = _chapterMemoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      _cacheHits++;
      _chapterMemoryCache[key] = memoryEntry.touch();
      return memoryEntry.data;
    }

    // Check if we have metadata in Hive
    final metadata = _chapterCacheBox?.get(key);
    if (metadata != null) {
      // Try to load from disk
      final diskChapter = await _loadChapterFromDisk(key);
      if (diskChapter != null) {
        _cacheHits++;
        // Re-add to memory cache
        _chapterMemoryCache[key] = CacheEntry(
          data: diskChapter,
          createdAt: DateTime.now(),
          sizeBytes: _estimateChapterSize(diskChapter),
        );
        return diskChapter;
      }
    }

    _cacheMisses++;
    return null;
  }

  /// Remove chapter from cache
  void removeChapter(String key) {
    _chapterMemoryCache.remove(key);
    _chapterCacheBox?.delete(key);
    _deleteChapterFromDisk(key);
  }

  /// Save chapter to disk
  Future<void> _saveChapterToDisk(String key, EpubChapter chapter) async {
    try {
      final fileName = _hashKey(key);
      final file = File(path.join(_chapterCacheDir!, '$fileName.json'));

      final json = jsonEncode(chapter.toJson());
      await file.writeAsString(json);
    } catch (e) {
      debugPrint('Failed to save chapter to disk: $e');
    }
  }

  /// Load chapter from disk
  Future<EpubChapter?> _loadChapterFromDisk(String key) async {
    try {
      final fileName = _hashKey(key);
      final file = File(path.join(_chapterCacheDir!, '$fileName.json'));

      if (await file.exists()) {
        final json = await file.readAsString();
        return EpubChapter.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Failed to load chapter from disk: $e');
    }
    return null;
  }

  /// Delete chapter from disk
  Future<void> _deleteChapterFromDisk(String key) async {
    try {
      final fileName = _hashKey(key);
      final file = File(path.join(_chapterCacheDir!, '$fileName.json'));

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete chapter from disk: $e');
    }
  }

  // ===========================================================================
  // IMAGE CACHE
  // ===========================================================================

  /// Cache image and return the file path
  /// Returns the file path where the image was saved
  Future<Result<String>> cacheImage(String key, Uint8List imageData) async {
    return SafeAsync.run(() async {
      // Store in memory cache (if not too large)
      if (imageData.length < 1024 * 1024) {
        _imageMemoryCache[key] = CacheEntry(
          data: imageData,
          createdAt: DateTime.now(),
          sizeBytes: imageData.length,
        );
      }

      // Store on disk and get file path
      final filePath = await _saveImageToDisk(key, imageData);

      if (filePath == null) {
        throw Exception('Failed to save image to disk');
      }

      // Verify file was written
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Image file not found after save: $filePath');
      }

      // Store in memory path cache for quick access
      _imagePathCache[key] = filePath;

      // Store metadata in Hive
      await _imageCacheBox?.put(key, {
        'sizeBytes': imageData.length,
        'cachedAt': DateTime.now().toIso8601String(),
        'filePath': filePath,
      });

      // Flush Hive to ensure data is persisted
      await _imageCacheBox?.flush();

      _updateCacheMetadata();

      debugPrint('Image cached: $key -> $filePath');

      return filePath;
    }, operationName: 'cacheImage');
  }

  /// Get cached image file path
  /// Returns the file path if image is cached, null otherwise
  Future<String?> getImagePath(String key) async {
    // First check in-memory path cache
    final cachedPath = _imagePathCache[key];
    if (cachedPath != null) {
      final file = File(cachedPath);
      if (await file.exists()) {
        debugPrint('Image path from memory cache: $cachedPath');
        return cachedPath;
      } else {
        // File was deleted, remove from cache
        _imagePathCache.remove(key);
      }
    }

    // Check Hive metadata
    try {
      final meta = _imageCacheBox?.get(key);
      if (meta is Map && meta['filePath'] is String) {
        final filePath = meta['filePath'] as String;
        final file = File(filePath);
        if (await file.exists()) {
          // Add to memory cache
          _imagePathCache[key] = filePath;
          debugPrint('Image path from Hive: $filePath');
          return filePath;
        }
      }
    } catch (e) {
      debugPrint('Failed to get image path from metadata: $e');
    }

    // Fallback: look for file with known extensions
    try {
      final fileName = _hashKey(key);
      for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg']) {
        final filePath = path.join(_imageCacheDir!, '$fileName.$ext');
        final file = File(filePath);
        if (await file.exists()) {
          // Update caches
          _imagePathCache[key] = filePath;
          await _imageCacheBox?.put(key, {
            'sizeBytes': await file.length(),
            'cachedAt': DateTime.now().toIso8601String(),
            'filePath': filePath,
          });
          debugPrint('Image path from fallback: $filePath');
          return filePath;
        }
      }
    } catch (e) {
      debugPrint('Failed to get image path via fallback: $e');
    }

    debugPrint('Image path not found for key: $key');
    return null;
  }

  /// Get cached image bytes
  Future<Uint8List?> getImage(String key) async {
    // Check memory cache first
    final memoryEntry = _imageMemoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      _cacheHits++;
      _imageMemoryCache[key] = memoryEntry.touch();
      return memoryEntry.data;
    }

    // Check disk cache
    final diskImage = await _loadImageFromDisk(key);
    if (diskImage != null) {
      _cacheHits++;

      // Re-add to memory cache if small enough
      if (diskImage.length < 1024 * 1024) {
        _imageMemoryCache[key] = CacheEntry(
          data: diskImage,
          createdAt: DateTime.now(),
          sizeBytes: diskImage.length,
        );
      }

      return diskImage;
    }

    _cacheMisses++;
    return null;
  }

  /// Remove image from cache
  void removeImage(String key) {
    _imageMemoryCache.remove(key);
    _imagePathCache.remove(key);
    _imageCacheBox?.delete(key);
    _deleteImageFromDisk(key);
  }

  /// Save image to disk
  Future<String?> _saveImageToDisk(String key, Uint8List data) async {
    try {
      final fileName = _hashKey(key);
      final extension = _guessImageExtension(data);
      final filePath = path.join(_imageCacheDir!, '$fileName.$extension');

      final file = File(filePath);
      await file.writeAsBytes(data, flush: true);

      debugPrint('Saved image to disk: $filePath (${data.length} bytes)');

      return filePath;
    } catch (e) {
      debugPrint('Failed to save image to disk: $e');
      return null;
    }
  }

  /// Load image from disk
  Future<Uint8List?> _loadImageFromDisk(String key) async {
    try {
      // First try from path cache
      final cachedPath = _imagePathCache[key];
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }

      // Fallback to searching by hash
      final fileName = _hashKey(key);
      for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg']) {
        final file = File(path.join(_imageCacheDir!, '$fileName.$ext'));
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    } catch (e) {
      debugPrint('Failed to load image from disk: $e');
    }
    return null;
  }

  /// Delete image from disk
  Future<void> _deleteImageFromDisk(String key) async {
    try {
      // Try from path cache first
      final cachedPath = _imagePathCache[key];
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          await file.delete();
          return;
        }
      }

      // Fallback
      final fileName = _hashKey(key);
      for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg']) {
        final file = File(path.join(_imageCacheDir!, '$fileName.$ext'));
        if (await file.exists()) {
          await file.delete();
          break;
        }
      }
    } catch (e) {
      debugPrint('Failed to delete image from disk: $e');
    }
  }

  // ===========================================================================
  // COVER CACHE
  // ===========================================================================

  /// Cache book cover
  Future<Result<String>> cacheCover(String bookId, Uint8List coverData) async {
    return SafeAsync.run(() async {
      final extension = _guessImageExtension(coverData);
      final fileName = '${_hashKey(bookId)}.$extension';
      final filePath = path.join(_coverCacheDir!, fileName);

      final file = File(filePath);
      await file.writeAsBytes(coverData, flush: true);

      return filePath;
    }, operationName: 'cacheCover');
  }

  /// Get cached cover path
  Future<String?> getCoverPath(String bookId) async {
    try {
      final hashedId = _hashKey(bookId);

      for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'webp']) {
        final filePath = path.join(_coverCacheDir!, '$hashedId.$ext');
        final file = File(filePath);
        if (await file.exists()) {
          return filePath;
        }
      }
    } catch (e) {
      debugPrint('Failed to get cover path: $e');
    }
    return null;
  }

  /// Remove cover from cache
  Future<void> removeCover(String bookId) async {
    try {
      final hashedId = _hashKey(bookId);

      for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'webp']) {
        final file = File(path.join(_coverCacheDir!, '$hashedId.$ext'));
        if (await file.exists()) {
          await file.delete();
          break;
        }
      }
    } catch (e) {
      debugPrint('Failed to remove cover: $e');
    }
  }

  // ===========================================================================
  // TRANSLATION CACHE
  // ===========================================================================

  /// Cache translation
  Future<Result<void>> cacheTranslation({
    required String bookId,
    required String originalText,
    required String targetLanguage,
    required TextTranslation translation,
  }) async {
    return SafeAsync.run(() async {
      final key = _buildTranslationKey(bookId, originalText, targetLanguage);
      final sizeBytes = _estimateTranslationSize(translation);

      // Store in memory cache
      _translationMemoryCache[key] = CacheEntry(
        data: translation,
        createdAt: DateTime.now(),
        sizeBytes: sizeBytes,
      );

      // Store in Hive
      await _translationCacheBox?.put(key, translation.toJson());

      _updateCacheMetadata();
    }, operationName: 'cacheTranslation');
  }

  /// Get cached translation
  Future<TextTranslation?> getTranslation({
    required String bookId,
    required String originalText,
    required String targetLanguage,
  }) async {
    final key = _buildTranslationKey(bookId, originalText, targetLanguage);

    // Check memory cache first
    final memoryEntry = _translationMemoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      _cacheHits++;
      _translationMemoryCache[key] = memoryEntry.touch();
      return memoryEntry.data;
    }

    // Check Hive
    try {
      final data = _translationCacheBox?.get(key);
      if (data != null) {
        _cacheHits++;
        final translation = TextTranslation.fromJson(
          Map<String, dynamic>.from(data as Map),
        );

        // Re-add to memory cache
        _translationMemoryCache[key] = CacheEntry(
          data: translation,
          createdAt: DateTime.now(),
          sizeBytes: _estimateTranslationSize(translation),
        );

        return translation;
      }
    } catch (e) {
      debugPrint('Failed to get translation from cache: $e');
    }

    _cacheMisses++;
    return null;
  }

  /// Get all translations for a language
  Future<List<TextTranslation>> getTranslationsForLanguage({
    required String bookId,
    required String targetLanguage,
  }) async {
    final translations = <TextTranslation>[];
    final prefix = '${bookId}_${targetLanguage}_';

    try {
      for (final key in _translationCacheBox?.keys ?? []) {
        if (key.toString().startsWith(prefix)) {
          final data = _translationCacheBox?.get(key);
          if (data != null) {
            translations.add(
              TextTranslation.fromJson(Map<String, dynamic>.from(data as Map)),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to get translations for language: $e');
    }

    return translations;
  }

  /// Remove translation from cache
  void removeTranslation({
    required String bookId,
    required String originalText,
    required String targetLanguage,
  }) {
    final key = _buildTranslationKey(bookId, originalText, targetLanguage);
    _translationMemoryCache.remove(key);
    _translationCacheBox?.delete(key);
  }

  /// Build translation cache key
  String _buildTranslationKey(
    String bookId,
    String originalText,
    String targetLanguage,
  ) {
    final textHash = _hashKey(originalText);
    return '${bookId}_${targetLanguage}_$textHash';
  }

  // ===========================================================================
  // CACHE MANAGEMENT
  // ===========================================================================

  /// Clear all cache for a book
  Future<Result<void>> clearBookCache(String bookId) async {
    return SafeAsync.run(() async {
      // Clear chapters
      final chapterKeysToRemove = <String>[];
      for (final key in _chapterMemoryCache.keys) {
        if (key.startsWith(bookId)) {
          chapterKeysToRemove.add(key);
        }
      }
      for (final key in chapterKeysToRemove) {
        removeChapter(key);
      }

      // Clear images
      final imageKeysToRemove = <String>[];
      for (final key in _imageMemoryCache.keys) {
        if (key.startsWith(bookId)) {
          imageKeysToRemove.add(key);
        }
      }
      for (final key in imageKeysToRemove) {
        removeImage(key);
      }

      // Also clear from path cache
      final pathKeysToRemove = <String>[];
      for (final key in _imagePathCache.keys) {
        if (key.startsWith(bookId)) {
          pathKeysToRemove.add(key);
        }
      }
      for (final key in pathKeysToRemove) {
        _imagePathCache.remove(key);
      }

      // Clear translations
      final translationKeysToRemove = <String>[];
      for (final key in _translationMemoryCache.keys) {
        if (key.startsWith(bookId)) {
          translationKeysToRemove.add(key);
        }
      }
      for (final key in translationKeysToRemove) {
        _translationMemoryCache.remove(key);
        await _translationCacheBox?.delete(key);
      }

      // Clear cover
      await removeCover(bookId);

      _updateCacheMetadata();
    }, operationName: 'clearBookCache');
  }

  /// Clear all cache
  Future<Result<void>> clearAllCache() async {
    return SafeAsync.run(() async {
      // Clear memory caches
      _chapterMemoryCache.clear();
      _imageMemoryCache.clear();
      _translationMemoryCache.clear();
      _imagePathCache.clear();

      // Clear Hive boxes
      await _chapterCacheBox?.clear();
      await _imageCacheBox?.clear();
      await _translationCacheBox?.clear();

      // Clear disk cache
      await _clearDirectory(_chapterCacheDir!);
      await _clearDirectory(_imageCacheDir!);
      await _clearDirectory(_coverCacheDir!);

      // Reset statistics
      _cacheHits = 0;
      _cacheMisses = 0;

      _updateCacheMetadata();
    }, operationName: 'clearAllCache');
  }

  /// Get cache statistics
  CacheStats getCacheStats() {
    int memorySize = 0;
    for (final entry in _chapterMemoryCache.values) {
      memorySize += entry.sizeBytes;
    }
    for (final entry in _imageMemoryCache.values) {
      memorySize += entry.sizeBytes;
    }
    for (final entry in _translationMemoryCache.values) {
      memorySize += entry.sizeBytes;
    }

    return CacheStats(
      chapterCount: _chapterMemoryCache.length,
      imageCount: _imageMemoryCache.length + _imagePathCache.length,
      translationCount: _translationMemoryCache.length,
      memorySizeBytes: memorySize,
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
      hitRate: hitRate,
    );
  }

  /// Get disk cache size
  Future<Result<int>> getDiskCacheSize() async {
    return SafeAsync.run(() async {
      int totalSize = 0;

      totalSize += await _getDirectorySize(_chapterCacheDir!);
      totalSize += await _getDirectorySize(_imageCacheDir!);
      totalSize += await _getDirectorySize(_coverCacheDir!);

      return totalSize;
    }, operationName: 'getDiskCacheSize');
  }

  /// Cleanup expired entries
  Future<void> _cleanupExpiredEntries() async {
    try {
      // Clean memory caches
      _chapterMemoryCache.removeWhere((_, entry) => entry.isExpired);
      _imageMemoryCache.removeWhere((_, entry) => entry.isExpired);
      _translationMemoryCache.removeWhere((_, entry) => entry.isExpired);

      // Clean Hive caches
      final now = DateTime.now();
      final maxAge = AppConstants.cacheMaxAge;

      await _cleanupHiveBox(_chapterCacheBox, now, maxAge, 'cachedAt');
      await _cleanupHiveBox(_imageCacheBox, now, maxAge, 'cachedAt');
      await _cleanupHiveBox(_translationCacheBox, now, maxAge, 'createdAt');

      _updateCacheMetadata();
    } catch (e) {
      debugPrint('Cache cleanup error: $e');
    }
  }

  /// Cleanup expired entries in a Hive box
  Future<void> _cleanupHiveBox(
    Box<dynamic>? box,
    DateTime now,
    Duration maxAge,
    String dateKey,
  ) async {
    if (box == null) return;

    final keysToDelete = <dynamic>[];

    for (final key in box.keys) {
      try {
        final data = box.get(key);
        if (data is Map) {
          final dateStr = data[dateKey] as String?;
          if (dateStr != null) {
            final cachedAt = DateTime.parse(dateStr);
            if (now.difference(cachedAt) > maxAge) {
              keysToDelete.add(key);
            }
          }
        }
      } catch (_) {}
    }

    for (final key in keysToDelete) {
      await box.delete(key);
    }
  }

  /// Handle memory pressure
  void _handleMemoryPressure(MemoryPressure pressure) {
    switch (pressure) {
      case MemoryPressure.moderate:
        _trimCache(_chapterMemoryCache, 0.75);
        _trimCache(_imageMemoryCache, 0.75);
        break;
      case MemoryPressure.high:
        _trimCache(_chapterMemoryCache, 0.50);
        _trimCache(_imageMemoryCache, 0.50);
        break;
      case MemoryPressure.critical:
        _chapterMemoryCache.clear();
        _imageMemoryCache.clear();
        _translationMemoryCache.clear();
        // Keep _imagePathCache as it's lightweight
        break;
      case MemoryPressure.normal:
        break;
    }
  }

  /// Trim cache to percentage
  void _trimCache<T>(Map<String, CacheEntry<T>> cache, double percentage) {
    final targetSize = (cache.length * percentage).round();
    if (cache.length <= targetSize) return;

    final entries = cache.entries.toList()
      ..sort(
        (a, b) => a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt),
      );

    final toRemove = entries.take(cache.length - targetSize);
    for (final entry in toRemove) {
      cache.remove(entry.key);
    }
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  /// Hash a key for file naming
  String _hashKey(String key) {
    final bytes = utf8.encode(key);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Estimate chapter size in bytes
  int _estimateChapterSize(EpubChapter chapter) {
    int size = 0;
    size += (chapter.htmlContent?.length ?? 0) * 2;
    size += (chapter.textContent?.length ?? 0) * 2;
    size += chapter.title.length * 2;
    size += 200;
    return size;
  }

  /// Estimate translation size in bytes
  int _estimateTranslationSize(TextTranslation translation) {
    int size = 0;
    size += translation.originalText.length * 2;
    size += translation.translatedText.length * 2;
    size += (translation.context?.length ?? 0) * 2;
    size += 100;
    return size;
  }

  /// Guess image extension from bytes
  String _guessImageExtension(Uint8List data) {
    if (data.length < 4) return 'bin';

    if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
      return 'jpg';
    }
    if (data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4E &&
        data[3] == 0x47) {
      return 'png';
    }
    if (data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46) {
      return 'gif';
    }
    if (data[0] == 0x52 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x46) {
      return 'webp';
    }
    if (data[0] == 0x3C) {
      return 'svg';
    }

    return 'bin';
  }

  /// Get directory size
  Future<int> _getDirectorySize(String dirPath) async {
    int totalSize = 0;

    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to get directory size: $e');
    }

    return totalSize;
  }

  /// Clear directory contents
  Future<void> _clearDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          await entity.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('Failed to clear directory: $e');
    }
  }

  /// Update cache metadata
  void _updateCacheMetadata() {
    try {
      _metadataBox?.put('lastUpdated', DateTime.now().toIso8601String());
      _metadataBox?.put('stats', getCacheStats().toJson());
    } catch (e) {
      debugPrint('Failed to update cache metadata: $e');
    }
  }
}

/// Cache statistics
class CacheStats {
  final int chapterCount;
  final int imageCount;
  final int translationCount;
  final int memorySizeBytes;
  final int cacheHits;
  final int cacheMisses;
  final double hitRate;

  const CacheStats({
    required this.chapterCount,
    required this.imageCount,
    required this.translationCount,
    required this.memorySizeBytes,
    required this.cacheHits,
    required this.cacheMisses,
    required this.hitRate,
  });

  int get totalEntries => chapterCount + imageCount + translationCount;

  String get formattedMemorySize {
    if (memorySizeBytes < 1024) return '$memorySizeBytes B';
    if (memorySizeBytes < 1024 * 1024) {
      return '${(memorySizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(memorySizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedHitRate => '${(hitRate * 100).toStringAsFixed(1)}%';

  Map<String, dynamic> toJson() => {
    'chapterCount': chapterCount,
    'imageCount': imageCount,
    'translationCount': translationCount,
    'memorySizeBytes': memorySizeBytes,
    'cacheHits': cacheHits,
    'cacheMisses': cacheMisses,
    'hitRate': hitRate,
  };

  factory CacheStats.fromJson(Map<String, dynamic> json) {
    return CacheStats(
      chapterCount: json['chapterCount'] as int? ?? 0,
      imageCount: json['imageCount'] as int? ?? 0,
      translationCount: json['translationCount'] as int? ?? 0,
      memorySizeBytes: json['memorySizeBytes'] as int? ?? 0,
      cacheHits: json['cacheHits'] as int? ?? 0,
      cacheMisses: json['cacheMisses'] as int? ?? 0,
      hitRate: (json['hitRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() {
    return '''
CacheStats(
  chapters: $chapterCount,
  images: $imageCount,
  translations: $translationCount,
  memory: $formattedMemorySize,
  hitRate: $formattedHitRate
)''';
  }
}
