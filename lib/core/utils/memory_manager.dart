import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

/// Memory pressure level
enum MemoryPressure { normal, moderate, high, critical }

/// Memory manager for handling memory efficiently
class MemoryManager {
  MemoryManager._();

  static final MemoryManager _instance = MemoryManager._();
  static MemoryManager get instance => _instance;

  // Memory monitoring
  Timer? _memoryMonitorTimer;
  MemoryPressure _currentPressure = MemoryPressure.normal;
  final List<void Function(MemoryPressure)> _listeners = [];

  // Cache management
  final LRUCache<String, Uint8List> _imageCache = LRUCache(
    maxSize: AppConstants.maxCachedImages,
    maxSizeBytes: AppConstants.imageCacheSizeMB * 1024 * 1024,
  );

  final LRUCache<String, String> _chapterCache = LRUCache(
    maxSize: AppConstants.maxCachedChapters,
    maxSizeBytes: 50 * 1024 * 1024, // 50MB for chapters
  );

  final Map<String, dynamic> _genericCache = {};

  MemoryPressure get currentPressure => _currentPressure;

  /// Initialize memory manager
  void initialize() {
    _startMemoryMonitoring();
    _setupSystemMemoryListener();
  }

  /// Dispose memory manager
  void dispose() {
    _memoryMonitorTimer?.cancel();
    _listeners.clear();
    clearAllCaches();
  }

  /// Start periodic memory monitoring
  void _startMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkMemory(),
    );
  }

  /// Setup system memory pressure listener
  void _setupSystemMemoryListener() {
    SystemChannels.lifecycle.setMessageHandler((message) async {
      if (message == 'AppLifecycleState.paused') {
        // Reduce memory usage when app is paused
        await _reduceMemoryUsage(aggressive: false);
      } else if (message == 'AppLifecycleState.detached') {
        // Aggressive cleanup when app is being terminated
        await _reduceMemoryUsage(aggressive: true);
      }
      return null;
    });
  }

  /// Check current memory usage
  Future<void> _checkMemory() async {
    try {
      final pressure = await _calculateMemoryPressure();
      if (pressure != _currentPressure) {
        _currentPressure = pressure;
        _notifyListeners(pressure);

        // Take action based on pressure level
        switch (pressure) {
          case MemoryPressure.moderate:
            await _reduceMemoryUsage(aggressive: false);
            break;
          case MemoryPressure.high:
            await _reduceMemoryUsage(aggressive: true);
            break;
          case MemoryPressure.critical:
            await _emergencyCleanup();
            break;
          case MemoryPressure.normal:
            break;
        }
      }
    } catch (e) {
      debugPrint('Memory check error: $e');
    }
  }

  /// Calculate memory pressure level
  Future<MemoryPressure> _calculateMemoryPressure() async {
    try {
      final totalCacheSize =
          _imageCache.currentSizeBytes +
          _chapterCache.currentSizeBytes +
          _estimateGenericCacheSize();

      final totalCacheSizeMB = totalCacheSize / (1024 * 1024);

      if (totalCacheSizeMB > AppConstants.maxMemoryUsageMB) {
        return MemoryPressure.critical;
      } else if (totalCacheSizeMB > AppConstants.maxMemoryUsageMB * 0.8) {
        return MemoryPressure.high;
      } else if (totalCacheSizeMB > AppConstants.maxMemoryUsageMB * 0.6) {
        return MemoryPressure.moderate;
      }

      return MemoryPressure.normal;
    } catch (e) {
      return MemoryPressure.normal;
    }
  }

  int _estimateGenericCacheSize() {
    int size = 0;
    for (final value in _genericCache.values) {
      if (value is String) {
        size += value.length * 2;
      } else if (value is List) {
        size += value.length * 8;
      } else if (value is Uint8List) {
        size += value.length;
      } else {
        size += 100; // Estimate for other types
      }
    }
    return size;
  }

  /// Reduce memory usage
  Future<void> _reduceMemoryUsage({required bool aggressive}) async {
    try {
      if (aggressive) {
        // Remove 50% of caches
        _imageCache.trimToSize(_imageCache.size ~/ 2);
        _chapterCache.trimToSize(_chapterCache.size ~/ 2);
      } else {
        // Remove 25% of caches
        _imageCache.trimToSize((_imageCache.size * 3) ~/ 4);
        _chapterCache.trimToSize((_chapterCache.size * 3) ~/ 4);
      }

      // Force garbage collection hint
      await Future.delayed(Duration.zero);
    } catch (e) {
      debugPrint('Memory reduction error: $e');
    }
  }

  /// Emergency cleanup when memory is critical
  Future<void> _emergencyCleanup() async {
    try {
      debugPrint('🚨 Emergency memory cleanup triggered');
      clearAllCaches();
      // Force garbage collection hint
      await Future.delayed(Duration.zero);
    } catch (e) {
      debugPrint('Emergency cleanup error: $e');
    }
  }

  // ==========================================================================
  // IMAGE CACHE
  // ==========================================================================

  /// Cache an image
  void cacheImage(String key, Uint8List data) {
    try {
      _imageCache.put(key, data, data.length);
    } catch (e) {
      debugPrint('Image cache error: $e');
    }
  }

  /// Get cached image
  Uint8List? getCachedImage(String key) {
    try {
      return _imageCache.get(key);
    } catch (e) {
      debugPrint('Get cached image error: $e');
      return null;
    }
  }

  /// Remove cached image
  void removeCachedImage(String key) {
    _imageCache.remove(key);
  }

  /// Check if image is cached
  bool isImageCached(String key) {
    return _imageCache.containsKey(key);
  }

  // ==========================================================================
  // CHAPTER CACHE
  // ==========================================================================

  /// Cache chapter content
  void cacheChapter(String key, String content) {
    try {
      _chapterCache.put(key, content, content.length * 2);
    } catch (e) {
      debugPrint('Chapter cache error: $e');
    }
  }

  /// Get cached chapter
  String? getCachedChapter(String key) {
    try {
      return _chapterCache.get(key);
    } catch (e) {
      debugPrint('Get cached chapter error: $e');
      return null;
    }
  }

  /// Remove cached chapter
  void removeCachedChapter(String key) {
    _chapterCache.remove(key);
  }

  // ==========================================================================
  // GENERIC CACHE
  // ==========================================================================

  /// Cache generic data
  void cache<T>(String key, T value) {
    _genericCache[key] = value;
  }

  /// Get cached data
  T? getCache<T>(String key) {
    final value = _genericCache[key];
    return value is T ? value : null;
  }

  /// Remove cached data
  void removeCache(String key) {
    _genericCache.remove(key);
  }

  /// Check if key exists
  bool hasCache(String key) {
    return _genericCache.containsKey(key);
  }

  // ==========================================================================
  // CACHE MANAGEMENT
  // ==========================================================================

  /// Clear all caches
  void clearAllCaches() {
    _imageCache.clear();
    _chapterCache.clear();
    _genericCache.clear();
    debugPrint('All caches cleared');
  }

  /// Clear image cache
  void clearImageCache() {
    _imageCache.clear();
  }

  /// Clear chapter cache
  void clearChapterCache() {
    _chapterCache.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'imageCache': {
        'size': _imageCache.size,
        'sizeBytes': _imageCache.currentSizeBytes,
        'maxSize': _imageCache.maxSize,
        'maxSizeBytes': _imageCache.maxSizeBytes,
      },
      'chapterCache': {
        'size': _chapterCache.size,
        'sizeBytes': _chapterCache.currentSizeBytes,
        'maxSize': _chapterCache.maxSize,
        'maxSizeBytes': _chapterCache.maxSizeBytes,
      },
      'genericCache': {
        'size': _genericCache.length,
        'estimatedSizeBytes': _estimateGenericCacheSize(),
      },
      'memoryPressure': _currentPressure.name,
    };
  }

  // ==========================================================================
  // LISTENERS
  // ==========================================================================

  /// Add memory pressure listener
  void addListener(void Function(MemoryPressure) listener) {
    _listeners.add(listener);
  }

  /// Remove memory pressure listener
  void removeListener(void Function(MemoryPressure) listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners
  void _notifyListeners(MemoryPressure pressure) {
    for (final listener in _listeners) {
      try {
        listener(pressure);
      } catch (e) {
        debugPrint('Memory listener error: $e');
      }
    }
  }

  /// Force memory cleanup
  Future<void> forceCleanup() async {
    await _reduceMemoryUsage(aggressive: true);
  }

  /// Get memory usage report
  String getMemoryReport() {
    final stats = getCacheStats();
    return '''
╔══════════════════════════════════════════════════════════════════════════════
║ MEMORY REPORT
╠══════════════════════════════════════════════════════════════════════════════
║ Image Cache: ${stats['imageCache']['size']} items, ${(stats['imageCache']['sizeBytes'] / (1024 * 1024)).toStringAsFixed(2)} MB
║ Chapter Cache: ${stats['chapterCache']['size']} items, ${(stats['chapterCache']['sizeBytes'] / (1024 * 1024)).toStringAsFixed(2)} MB
║ Generic Cache: ${stats['genericCache']['size']} items, ${(stats['genericCache']['estimatedSizeBytes'] / (1024 * 1024)).toStringAsFixed(2)} MB
║ Memory Pressure: ${stats['memoryPressure']}
╚══════════════════════════════════════════════════════════════════════════════
''';
  }
}

/// LRU Cache implementation with size limits
class LRUCache<K, V> {
  final int maxSize;
  final int maxSizeBytes;
  final LinkedHashMap<K, _CacheEntry<V>> _cache = LinkedHashMap();

  int _currentSizeBytes = 0;

  int get size => _cache.length;
  int get currentSizeBytes => _currentSizeBytes;

  LRUCache({required this.maxSize, required this.maxSizeBytes});

  V? get(K key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      // Move to end (most recently used)
      _cache[key] = entry;
      return entry.value;
    }
    return null;
  }

  void put(K key, V value, int sizeBytes) {
    // Remove existing entry if present
    final existing = _cache.remove(key);
    if (existing != null) {
      _currentSizeBytes -= existing.sizeBytes;
    }

    // Evict entries if necessary
    while (_cache.length >= maxSize ||
        _currentSizeBytes + sizeBytes > maxSizeBytes) {
      if (_cache.isEmpty) break;
      final oldestKey = _cache.keys.first;
      final oldest = _cache.remove(oldestKey);
      if (oldest != null) {
        _currentSizeBytes -= oldest.sizeBytes;
      }
    }

    // Add new entry
    _cache[key] = _CacheEntry(value, sizeBytes);
    _currentSizeBytes += sizeBytes;
  }

  void remove(K key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _currentSizeBytes -= entry.sizeBytes;
    }
  }

  bool containsKey(K key) => _cache.containsKey(key);

  void clear() {
    _cache.clear();
    _currentSizeBytes = 0;
  }

  void trimToSize(int targetSize) {
    while (_cache.length > targetSize && _cache.isNotEmpty) {
      final oldestKey = _cache.keys.first;
      final oldest = _cache.remove(oldestKey);
      if (oldest != null) {
        _currentSizeBytes -= oldest.sizeBytes;
      }
    }
  }
}

class _CacheEntry<V> {
  final V value;
  final int sizeBytes;

  _CacheEntry(this.value, this.sizeBytes);
}

/// Disposable resource mixin
mixin DisposableResource {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  void markDisposed() {
    _isDisposed = true;
  }

  void checkDisposed() {
    if (_isDisposed) {
      throw StateError('Resource has been disposed');
    }
  }
}

/// Resource pool for managing expensive resources
class ResourcePool<T> {
  final int maxSize;
  final Future<T> Function() factory;
  final Future<void> Function(T)? onDispose;
  final bool Function(T)? validator;

  final Queue<T> _available = Queue();
  final Set<T> _inUse = {};
  bool _isDisposed = false;

  ResourcePool({
    required this.maxSize,
    required this.factory,
    this.onDispose,
    this.validator,
  });

  int get availableCount => _available.length;
  int get inUseCount => _inUse.length;
  int get totalCount => availableCount + inUseCount;

  Future<T> acquire() async {
    if (_isDisposed) {
      throw StateError('Pool has been disposed');
    }

    // Try to get from available pool
    while (_available.isNotEmpty) {
      final resource = _available.removeFirst();
      if (validator == null || validator!(resource)) {
        _inUse.add(resource);
        return resource;
      } else {
        // Resource is invalid, dispose it
        await onDispose?.call(resource);
      }
    }

    // Create new if under limit
    if (totalCount < maxSize) {
      final resource = await factory();
      _inUse.add(resource);
      return resource;
    }

    // Wait for a resource to become available
    while (_available.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_isDisposed) {
        throw StateError('Pool has been disposed');
      }
    }

    return acquire();
  }

  void release(T resource) {
    if (_inUse.remove(resource)) {
      if (!_isDisposed) {
        _available.add(resource);
      } else {
        onDispose?.call(resource);
      }
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;

    // Dispose all available resources
    while (_available.isNotEmpty) {
      final resource = _available.removeFirst();
      await onDispose?.call(resource);
    }

    // Dispose all in-use resources
    for (final resource in _inUse) {
      await onDispose?.call(resource);
    }
    _inUse.clear();
  }
}
