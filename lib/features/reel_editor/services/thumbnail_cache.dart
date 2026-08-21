import 'dart:collection';
import 'dart:typed_data';
import '../core/validation/numeric_guard.dart';

/// Thumbnail cache md:27 — keyed sourceId+timestamp+resolution+cacheVersion, lazy, visible-only
class ThumbnailCache {
  static const int _cacheVersion = 2;
  static const int _maxEntries = 80;
  final LinkedHashMap<String, Uint8List> _mem = LinkedHashMap();
  final Set<String> _pending = {};

  String key(String sourceId, Duration ts, int resW) {
    final sec = NumericGuard.sanitizeDouble(ts.inMilliseconds/1000, 0, 86400, 0).toStringAsFixed(2);
    return '$sourceId|$sec|${resW}w|v$_cacheVersion';
  }

  Uint8List? get(String k) => _mem[k];

  void put(String k, Uint8List bytes) {
    if (_mem.length >= _maxEntries) _mem.remove(_mem.keys.first);
    _mem[k] = bytes;
  }

  bool isPending(String k) => _pending.contains(k);
  void markPending(String k) => _pending.add(k);
  void unmark(String k) => _pending.remove(k);

  // creative: LRU eviction + visible window prefetch helper
  List<String> visibleKeys(String sourceId, List<Duration> visibleTs, int resW) =>
      visibleTs.map((t) => key(sourceId, t, resW)).toList();

  void clear() { _mem.clear(); _pending.clear(); }
  int get size => _mem.length;
}
