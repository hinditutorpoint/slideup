import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:slideup/core/utils/safe_async.dart';

// ═══════════════════════════════════════════════════════
// ✅ HIVE BOX NAMES
// ═══════════════════════════════════════════════════════

class HiveBoxNames {
  static const String projects = 'video_projects';
  static const String recentProjects = 'recent_projects';
  static const String exportJobs = 'export_jobs';
  static const String settings = 'editor_settings';
  static const String presets = 'custom_presets';
  static const String colorPresets = 'color_presets';
  static const String textPresets = 'text_presets';
  static const String mediaLibrary = 'media_library';

  HiveBoxNames._();
}

// ═══════════════════════════════════════════════════════
// ✅ HIVE SERVICE
// ═══════════════════════════════════════════════════════

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Box instances
  Box<String>? _projectsBox;
  Box<String>? _recentProjectsBox;
  Box<String>? _exportJobsBox;
  Box<String>? _settingsBox;
  Box<String>? _presetsBox;
  Box<String>? _colorPresetsBox;
  Box<String>? _textPresetsBox;
  Box<String>? _mediaLibraryBox;

  // Getters
  Box<String>? get projectsBox => _projectsBox;
  Box<String>? get recentProjectsBox => _recentProjectsBox;
  Box<String>? get exportJobsBox => _exportJobsBox;
  Box<String>? get settingsBox => _settingsBox;
  Box<String>? get presetsBox => _presetsBox;
  Box<String>? get colorPresetsBox => _colorPresetsBox;
  Box<String>? get textPresetsBox => _textPresetsBox;
  Box<String>? get mediaLibraryBox => _mediaLibraryBox;

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> initialize() async {
    if (_isInitialized) return Result.success(null);

    return SafeAsync.run(() async {
      final appDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDir.path);

      // Open all boxes
      _projectsBox = await Hive.openBox<String>(HiveBoxNames.projects);
      _recentProjectsBox = await Hive.openBox<String>(
        HiveBoxNames.recentProjects,
      );
      _exportJobsBox = await Hive.openBox<String>(HiveBoxNames.exportJobs);
      _settingsBox = await Hive.openBox<String>(HiveBoxNames.settings);
      _presetsBox = await Hive.openBox<String>(HiveBoxNames.presets);
      _colorPresetsBox = await Hive.openBox<String>(HiveBoxNames.colorPresets);
      _textPresetsBox = await Hive.openBox<String>(HiveBoxNames.textPresets);
      _mediaLibraryBox = await Hive.openBox<String>(HiveBoxNames.mediaLibrary);

      _isInitialized = true;
      debugPrint('✅ HiveService initialized');
    }, operationName: 'HiveService.initialize');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GENERIC OPERATIONS
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> put(Box<String>? box, String key, String value) async {
    return SafeAsync.run(() async {
      if (box == null) throw Exception('Box not initialized');
      await box.put(key, value);
    }, operationName: 'HiveService.put');
  }

  Future<Result<String?>> get(Box<String>? box, String key) async {
    return SafeAsync.run(() async {
      if (box == null) throw Exception('Box not initialized');
      return box.get(key);
    }, operationName: 'HiveService.get');
  }

  Future<Result<void>> delete(Box<String>? box, String key) async {
    return SafeAsync.run(() async {
      if (box == null) throw Exception('Box not initialized');
      await box.delete(key);
    }, operationName: 'HiveService.delete');
  }

  Future<Result<List<String>>> getAllKeys(Box<String>? box) async {
    return SafeAsync.run(() async {
      if (box == null) throw Exception('Box not initialized');
      return box.keys.cast<String>().toList();
    }, operationName: 'HiveService.getAllKeys');
  }

  Future<Result<Map<String, String>>> getAll(Box<String>? box) async {
    return SafeAsync.run(() async {
      if (box == null) throw Exception('Box not initialized');
      final map = <String, String>{};
      for (final key in box.keys) {
        final value = box.get(key);
        if (value != null) {
          map[key as String] = value;
        }
      }
      return map;
    }, operationName: 'HiveService.getAll');
  }

  Future<Result<void>> clear(Box<String>? box) async {
    return SafeAsync.run(() async {
      if (box == null) throw Exception('Box not initialized');
      await box.clear();
    }, operationName: 'HiveService.clear');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DISPOSE
  // ═══════════════════════════════════════════════════════

  Future<void> dispose() async {
    await _projectsBox?.close();
    await _recentProjectsBox?.close();
    await _exportJobsBox?.close();
    await _settingsBox?.close();
    await _presetsBox?.close();
    await _colorPresetsBox?.close();
    await _textPresetsBox?.close();
    await _mediaLibraryBox?.close();

    _isInitialized = false;
    debugPrint('✅ HiveService disposed');
  }
}
