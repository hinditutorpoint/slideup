import 'package:hive_flutter/hive_flutter.dart';
import '../models/scene_settings.dart';

class SceneSettingsService {
  static final SceneSettingsService instance = SceneSettingsService._();
  SceneSettingsService._();

  static const _boxName = 'settingsBox';
  static const _key = 'scene_settings';

  Box get _box {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    throw StateError('Hive box $_boxName not open — ensure Hive.openBox in main()');
  }

  SceneSettings load() {
    try {
      final raw = _box.get(_key);
      if (raw is Map) {
        return SceneSettings.fromJson(Map<String, dynamic>.from(raw));
      }
      if (raw is Map<String, dynamic>) {
        return SceneSettings.fromJson(raw);
      }
    } catch (_) {}
    return const SceneSettings();
  }

  Future<void> save(SceneSettings settings) async {
    final box = Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);
    await box.put(_key, settings.toJson());
  }
}
