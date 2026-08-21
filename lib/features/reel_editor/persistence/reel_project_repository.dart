import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/errors/reel_exceptions.dart';
import '../models/reel_project.dart';

/// Persistence md:559-575 scoped storage, md:516-526 debounced autosave
class ReelProjectRepository {
  static const _boxName = 'reel_projects';
  static const _recentKey = 'reel_recent_ids';
  static const _autosaveKeyPrefix = 'autosave_';

  Box<String>? _box;

  Future<void> init() async {
    try {
      _box = await Hive.openBox<String>(_boxName);
    } catch (e) {
      throw StorageException('hive_open_failed', 'Failed to open reel_projects box', e);
    }
  }

  Box<String> get _b {
    final b = _box;
    if (b == null || !b.isOpen) throw const StorageException('not_initialized', 'Repository not initialized');
    return b;
  }

  Future<void> save(ReelProject p) async {
    try {
      await _b.put(p.id, jsonEncode(p.toJson()));
      await _touchRecent(p.id);
    } catch (e) {
      throw StorageException('save_failed', 'Failed to save project ${p.id}', e);
    }
  }

  Future<void> autosave(ReelProject p) async {
    try {
      await _b.put('$_autosaveKeyPrefix${p.id}', jsonEncode(p.toJson()));
    } catch (e) {
      debugPrint('autosave failed: $e');
    }
  }

  ReelProject? load(String id) {
    try {
      final raw = _b.get(id);
      if (raw == null) return null;
      return ReelProject.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('load failed $id: $e');
      return null;
    }
  }

  ReelProject? loadAutosave(String id) {
    final raw = _b.get('$_autosaveKeyPrefix$id');
    if (raw == null) return null;
    try { return ReelProject.fromJson(jsonDecode(raw) as Map<String, dynamic>); } catch (_) { return null; }
  }

  List<ReelProject> loadAll() {
    final out = <ReelProject>[];
    for (final k in _b.keys) {
      if (k.toString().startsWith(_autosaveKeyPrefix) || k == _recentKey) continue;
      final p = load(k.toString());
      if (p != null) out.add(p);
    }
    out.sort((a,b)=> b.modifiedAt.compareTo(a.modifiedAt));
    return out;
  }

  Future<void> delete(String id) async {
    await _b.delete(id);
    await _b.delete('$_autosaveKeyPrefix$id');
    final rec = recentIds()..remove(id);
    await _b.put(_recentKey, jsonEncode(rec));
  }

  List<String> recentIds() {
    try {
      final raw = _b.get(_recentKey);
      if (raw == null) return [];
      final l = jsonDecode(raw) as List;
      return l.map((e)=> e.toString()).toList();
    } catch (_) { return []; }
  }

  Future<void> _touchRecent(String id) async {
    final r = recentIds()..remove(id);
    r.insert(0, id);
    if (r.length > 20) r.removeRange(20, r.length);
    await _b.put(_recentKey, jsonEncode(r));
  }

  Future<void> clearAutosave(String id) async => _b.delete('$_autosaveKeyPrefix$id');
}
