import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/tts_audio_cache.dart';

/// Raw cache entry for controller use
class RawCacheEntry {
  final String id;
  final String textHash;
  final String text;
  final String textPreview;
  final String filePath;
  final String modelId;
  final Duration duration;
  final double speed;
  final int speakerId;
  final String? bookId;
  final int? pageNumber;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final int fileSize;

  RawCacheEntry({
    required this.id,
    required this.textHash,
    required this.text,
    required this.textPreview,
    required this.filePath,
    required this.modelId,
    required this.duration,
    required this.speed,
    required this.speakerId,
    this.bookId,
    this.pageNumber,
    required this.createdAt,
    required this.lastUsedAt,
    required this.fileSize,
  });

  /// Create from TtsAudioCache
  factory RawCacheEntry.fromCache(TtsAudioCache cache) {
    return RawCacheEntry(
      id: cache.id,
      textHash: cache.textHash,
      text: cache.text,
      textPreview: cache.text.length > 100
          ? '${cache.text.substring(0, 100)}...'
          : cache.text,
      filePath: cache.filePath,
      modelId: cache.modelId,
      duration: Duration(milliseconds: cache.durationMs),
      speed: cache.speed,
      speakerId: cache.speakerId,
      bookId: cache.bookId,
      pageNumber: cache.pageNumber,
      createdAt: cache.createdAt,
      lastUsedAt: cache.lastUsedAt,
      fileSize: cache.fileSize,
    );
  }
}

class TtsCacheRepository {
  static const String _boxName = 'tts_audio_cache';
  static const String _cacheDir = 'tts_cache';
  static const int _maxCacheSize = 500 * 1024 * 1024; // 500 MB
  static const int _maxCacheEntries = 1000;

  Box<TtsAudioCache>? _box;
  String? _cachePath;
  bool _isInitialized = false;

  /// Check if repository is initialized
  bool get isInitialized => _isInitialized;

  /// Get cache directory path
  String? get cachePath => _cachePath;

  Future<void> init() async {
    if (_isInitialized) return;

    debugPrint('[TtsCacheRepository] Initializing...');

    // Get cache directory
    final appDir = await getApplicationDocumentsDirectory();
    _cachePath = '${appDir.path}/$_cacheDir';

    final cacheDir = Directory(_cachePath!);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    // Open Hive box
    _box = await Hive.openBox<TtsAudioCache>(_boxName);

    _isInitialized = true;
    debugPrint(
      '[TtsCacheRepository] Initialized with ${_box!.length} cached entries',
    );

    // Cleanup old entries
    await _cleanupIfNeeded();
  }

  /// Generate hash for text + model + speed combination
  String generateHash(
    String text,
    String modelId,
    double speed,
    int speakerId,
  ) {
    final input = '$text|$modelId|$speed|$speakerId';
    return md5.convert(utf8.encode(input)).toString();
  }

  /// Get cached audio for text
  Future<TtsAudioCache?> getCachedAudio({
    required String text,
    required String modelId,
    double speed = 1.0,
    int speakerId = 0,
  }) async {
    await _ensureInitialized();

    final hash = generateHash(text, modelId, speed, speakerId);
    final cache = _box!.get(hash);

    if (cache != null) {
      // Verify file exists
      final file = File(cache.filePath);
      if (await file.exists()) {
        // Update last used time
        final updated = cache.copyWith(lastUsedAt: DateTime.now());
        await _box!.put(hash, updated);
        debugPrint('[TtsCacheRepository] Cache hit for hash: $hash');
        return updated;
      } else {
        // File missing, remove entry
        await _box!.delete(hash);
        debugPrint('[TtsCacheRepository] Cache file missing, removed entry');
      }
    }

    return null;
  }

  /// Get cached audio by book and page
  Future<TtsAudioCache?> getCachedAudioForPage({
    required String bookId,
    required int pageNumber,
    required String modelId,
    double speed = 1.0,
    int speakerId = 0,
  }) async {
    await _ensureInitialized();

    try {
      final cache = _box!.values.firstWhere(
        (c) =>
            c.bookId == bookId &&
            c.pageNumber == pageNumber &&
            c.modelId == modelId &&
            c.speed == speed &&
            c.speakerId == speakerId,
      );

      final file = File(cache.filePath);
      if (await file.exists()) {
        // Update last used time
        final updated = cache.copyWith(lastUsedAt: DateTime.now());
        await _box!.put(cache.textHash, updated);
        return updated;
      }
    } catch (_) {}

    return null;
  }

  /// Save audio to cache
  Future<TtsAudioCache> saveToCache({
    required String text,
    required String modelId,
    required Uint8List audioData,
    required Duration duration,
    double speed = 1.0,
    int speakerId = 0,
    String? bookId,
    int? pageNumber,
  }) async {
    await _ensureInitialized();

    final hash = generateHash(text, modelId, speed, speakerId);
    final fileName = '$hash.wav';
    final filePath = '$_cachePath/$fileName';

    // Save audio file
    final file = File(filePath);
    await file.writeAsBytes(audioData);

    final cache = TtsAudioCache(
      id: hash,
      textHash: hash,
      text: text,
      modelId: modelId,
      filePath: filePath,
      durationMs: duration.inMilliseconds,
      speed: speed,
      speakerId: speakerId,
      fileSize: audioData.length,
      bookId: bookId,
      pageNumber: pageNumber,
    );

    await _box!.put(hash, cache);
    debugPrint(
      '[TtsCacheRepository] Saved cache: $hash (${audioData.length} bytes)',
    );

    // Cleanup if needed
    await _cleanupIfNeeded();

    return cache;
  }

  /// Delete cached audio by hash
  Future<void> deleteCache(String hash) async {
    await _ensureInitialized();

    final cache = _box!.get(hash);
    if (cache != null) {
      try {
        final file = File(cache.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      await _box!.delete(hash);
    }
  }

  /// Delete cache entry by ID (alias for deleteCache)
  Future<void> deleteCacheEntry(String id) async {
    await deleteCache(id);
  }

  /// Delete all cache for a book
  Future<void> deleteCacheForBook(String bookId) async {
    await _ensureInitialized();

    final toDelete = _box!.values
        .where((c) => c.bookId == bookId)
        .map((c) => c.textHash)
        .toList();

    for (final hash in toDelete) {
      await deleteCache(hash);
    }

    debugPrint(
      '[TtsCacheRepository] Deleted ${toDelete.length} entries for book: $bookId',
    );
  }

  /// Get all cached entries for a book
  Future<List<TtsAudioCache>> getCacheForBook(String bookId) async {
    await _ensureInitialized();

    return _box!.values.where((c) => c.bookId == bookId).toList()
      ..sort((a, b) => (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0));
  }

  // ==================== NEW METHODS FOR CONTROLLER ====================

  /// Get all cached entries with optional filters
  /// Returns RawCacheEntry list for controller use
  Future<List<RawCacheEntry>> getAllCachedEntries({
    String? bookId,
    String? modelId,
    double? speed,
    int? speakerId,
  }) async {
    await _ensureInitialized();

    final allEntries = _box!.values.toList();

    final filtered = allEntries.where((entry) {
      if (bookId != null && entry.bookId != bookId) return false;
      if (modelId != null && entry.modelId != modelId) return false;
      if (speed != null && (entry.speed - speed).abs() > 0.01) return false;
      if (speakerId != null && entry.speakerId != speakerId) return false;
      return true;
    }).toList();

    return filtered.map((cache) => RawCacheEntry.fromCache(cache)).toList();
  }

  /// Get all cached entries as TtsAudioCache list
  Future<List<TtsAudioCache>> getAllCachedEntriesRaw({
    String? bookId,
    String? modelId,
    double? speed,
    int? speakerId,
  }) async {
    await _ensureInitialized();

    final allEntries = _box!.values.toList();

    return allEntries.where((entry) {
      if (bookId != null && entry.bookId != bookId) return false;
      if (modelId != null && entry.modelId != modelId) return false;
      if (speed != null && (entry.speed - speed).abs() > 0.01) return false;
      if (speakerId != null && entry.speakerId != speakerId) return false;
      return true;
    }).toList();
  }

  /// Get unique book IDs that have cached audio
  Future<List<String>> getBookIdsWithCache() async {
    await _ensureInitialized();

    final bookIds = <String>{};
    for (final entry in _box!.values) {
      if (entry.bookId != null && entry.bookId!.isNotEmpty) {
        bookIds.add(entry.bookId!);
      }
    }
    return bookIds.toList();
  }

  /// Get cache entry count
  Future<int> getCacheEntryCount({String? bookId, String? modelId}) async {
    await _ensureInitialized();

    if (bookId == null && modelId == null) {
      return _box!.length;
    }

    return _box!.values.where((entry) {
      if (bookId != null && entry.bookId != bookId) return false;
      if (modelId != null && entry.modelId != modelId) return false;
      return true;
    }).length;
  }

  /// Get cache by hash directly
  Future<TtsAudioCache?> getCacheByHash(String hash) async {
    await _ensureInitialized();
    return _box!.get(hash);
  }

  /// Check if cache exists for hash
  Future<bool> hasCacheForHash(String hash) async {
    await _ensureInitialized();
    final cache = _box!.get(hash);
    if (cache == null) return false;

    final file = File(cache.filePath);
    return file.existsSync();
  }

  /// Get cache entries created within date range
  Future<List<RawCacheEntry>> getCacheEntriesInDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _ensureInitialized();

    return _box!.values
        .where(
          (entry) =>
              entry.createdAt.isAfter(startDate) &&
              entry.createdAt.isBefore(endDate),
        )
        .map((cache) => RawCacheEntry.fromCache(cache))
        .toList();
  }

  /// Get most recently used cache entries
  Future<List<RawCacheEntry>> getRecentlyUsedEntries({int limit = 20}) async {
    await _ensureInitialized();

    final entries = _box!.values.toList()
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));

    return entries
        .take(limit)
        .map((cache) => RawCacheEntry.fromCache(cache))
        .toList();
  }

  /// Get oldest cache entries (for cleanup preview)
  Future<List<RawCacheEntry>> getOldestEntries({int limit = 20}) async {
    await _ensureInitialized();

    final entries = _box!.values.toList()
      ..sort((a, b) => a.lastUsedAt.compareTo(b.lastUsedAt));

    return entries
        .take(limit)
        .map((cache) => RawCacheEntry.fromCache(cache))
        .toList();
  }

  /// Get largest cache entries
  Future<List<RawCacheEntry>> getLargestEntries({int limit = 20}) async {
    await _ensureInitialized();

    final entries = _box!.values.toList()
      ..sort((a, b) => b.fileSize.compareTo(a.fileSize));

    return entries
        .take(limit)
        .map((cache) => RawCacheEntry.fromCache(cache))
        .toList();
  }

  /// Delete multiple cache entries by IDs
  Future<int> deleteCacheEntries(List<String> ids) async {
    await _ensureInitialized();

    int deleted = 0;
    for (final id in ids) {
      try {
        await deleteCache(id);
        deleted++;
      } catch (_) {}
    }
    return deleted;
  }

  /// Delete cache entries older than specified duration
  Future<int> deleteEntriesOlderThan(Duration age) async {
    await _ensureInitialized();

    final cutoff = DateTime.now().subtract(age);
    final toDelete = _box!.values
        .where((entry) => entry.lastUsedAt.isBefore(cutoff))
        .map((e) => e.textHash)
        .toList();

    for (final hash in toDelete) {
      await deleteCache(hash);
    }

    debugPrint(
      '[TtsCacheRepository] Deleted ${toDelete.length} entries older than $age',
    );
    return toDelete.length;
  }

  /// Delete cache entries to free up space
  Future<int> deleteEntriesToFreeSpace(int bytesToFree) async {
    await _ensureInitialized();

    final entries = _box!.values.toList()
      ..sort((a, b) => a.lastUsedAt.compareTo(b.lastUsedAt));

    int freedBytes = 0;
    int deletedCount = 0;

    for (final entry in entries) {
      if (freedBytes >= bytesToFree) break;

      await deleteCache(entry.textHash);
      freedBytes += entry.fileSize;
      deletedCount++;
    }

    debugPrint(
      '[TtsCacheRepository] Deleted $deletedCount entries, freed ${_formatBytes(freedBytes)}',
    );
    return deletedCount;
  }

  // ==================== EXISTING METHODS ====================

  /// Get total cache size
  Future<int> getTotalCacheSize() async {
    await _ensureInitialized();

    int totalSize = 0;
    for (final cache in _box!.values) {
      totalSize += cache.fileSize;
    }
    return totalSize;
  }

  /// Get total cache size for a specific book
  Future<int> getCacheSizeForBook(String bookId) async {
    await _ensureInitialized();

    int totalSize = 0;
    for (final cache in _box!.values) {
      if (cache.bookId == bookId) {
        totalSize += cache.fileSize;
      }
    }
    return totalSize;
  }

  /// Get total cache duration
  Future<Duration> getTotalCacheDuration() async {
    await _ensureInitialized();

    int totalMs = 0;
    for (final cache in _box!.values) {
      totalMs += cache.durationMs;
    }
    return Duration(milliseconds: totalMs);
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    await _ensureInitialized();

    final entries = _box!.values.toList();
    int totalSize = 0;
    int totalDuration = 0;
    DateTime? oldestEntry;
    DateTime? newestEntry;

    for (final cache in entries) {
      totalSize += cache.fileSize;
      totalDuration += cache.durationMs;

      if (oldestEntry == null || cache.createdAt.isBefore(oldestEntry)) {
        oldestEntry = cache.createdAt;
      }
      if (newestEntry == null || cache.createdAt.isAfter(newestEntry)) {
        newestEntry = cache.createdAt;
      }
    }

    // Count unique books
    final uniqueBooks = <String>{};
    for (final cache in entries) {
      if (cache.bookId != null) {
        uniqueBooks.add(cache.bookId!);
      }
    }

    return {
      'entries': entries.length,
      'totalSize': totalSize,
      'totalSizeBytes': totalSize,
      'totalDuration': Duration(milliseconds: totalDuration),
      'totalDurationMs': totalDuration,
      'formattedSize': _formatBytes(totalSize),
      'formattedDuration': _formatDuration(
        Duration(milliseconds: totalDuration),
      ),
      'oldestEntry': oldestEntry,
      'newestEntry': newestEntry,
      'uniqueBooks': uniqueBooks.length,
      'bookIds': uniqueBooks.toList(),
      'maxCacheSize': _maxCacheSize,
      'maxCacheEntries': _maxCacheEntries,
      'usagePercent': (totalSize / _maxCacheSize * 100).toStringAsFixed(1),
    };
  }

  /// Get detailed cache statistics by book
  Future<Map<String, Map<String, dynamic>>> getCacheStatsByBook() async {
    await _ensureInitialized();

    final bookStats = <String, Map<String, dynamic>>{};

    for (final cache in _box!.values) {
      final bookId = cache.bookId ?? 'unknown';

      if (!bookStats.containsKey(bookId)) {
        bookStats[bookId] = {
          'entries': 0,
          'totalSize': 0,
          'totalDuration': 0,
          'pages': <int>[],
          'oldestEntry': cache.createdAt,
          'newestEntry': cache.createdAt,
        };
      }

      final stats = bookStats[bookId]!;
      stats['entries'] = (stats['entries'] as int) + 1;
      stats['totalSize'] = (stats['totalSize'] as int) + cache.fileSize;
      stats['totalDuration'] =
          (stats['totalDuration'] as int) + cache.durationMs;

      if (cache.pageNumber != null) {
        (stats['pages'] as List<int>).add(cache.pageNumber!);
      }

      if (cache.createdAt.isBefore(stats['oldestEntry'] as DateTime)) {
        stats['oldestEntry'] = cache.createdAt;
      }
      if (cache.createdAt.isAfter(stats['newestEntry'] as DateTime)) {
        stats['newestEntry'] = cache.createdAt;
      }
    }

    // Add formatted values
    for (final bookId in bookStats.keys) {
      final stats = bookStats[bookId]!;
      stats['formattedSize'] = _formatBytes(stats['totalSize'] as int);
      stats['formattedDuration'] = _formatDuration(
        Duration(milliseconds: stats['totalDuration'] as int),
      );
      (stats['pages'] as List<int>).sort();
    }

    return bookStats;
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    await _ensureInitialized();

    // Delete all files
    final cacheDir = Directory(_cachePath!);
    if (await cacheDir.exists()) {
      await for (final file in cacheDir.list()) {
        if (file is File) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    }

    await _box!.clear();
    debugPrint('[TtsCacheRepository] All cache cleared');
  }

  /// Verify cache integrity (remove entries with missing files)
  Future<int> verifyCacheIntegrity() async {
    await _ensureInitialized();

    final toDelete = <String>[];

    for (final cache in _box!.values) {
      final file = File(cache.filePath);
      if (!await file.exists()) {
        toDelete.add(cache.textHash);
      }
    }

    for (final hash in toDelete) {
      await _box!.delete(hash);
    }

    if (toDelete.isNotEmpty) {
      debugPrint(
        '[TtsCacheRepository] Removed ${toDelete.length} orphaned cache entries',
      );
    }

    return toDelete.length;
  }

  /// Cleanup old entries if cache is too large
  Future<void> _cleanupIfNeeded() async {
    final totalSize = await getTotalCacheSize();
    final entries = _box!.values.toList();

    if (totalSize > _maxCacheSize || entries.length > _maxCacheEntries) {
      debugPrint(
        '[TtsCacheRepository] Cleanup needed: $totalSize bytes, ${entries.length} entries',
      );

      // Sort by last used (oldest first)
      entries.sort((a, b) => a.lastUsedAt.compareTo(b.lastUsedAt));

      int currentSize = totalSize;
      int currentEntries = entries.length;

      for (final cache in entries) {
        if (currentSize <= _maxCacheSize * 0.8 &&
            currentEntries <= _maxCacheEntries * 0.8) {
          break;
        }

        await deleteCache(cache.textHash);
        currentSize -= cache.fileSize;
        currentEntries--;
      }

      debugPrint(
        '[TtsCacheRepository] Cleanup complete: $currentSize bytes, $currentEntries entries',
      );
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> close() async {
    if (_isInitialized && _box != null) {
      await _box!.close();
      _isInitialized = false;
    }
  }
}
