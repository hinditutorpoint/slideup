import 'package:hive_flutter/hive_flutter.dart';

import '../models/converter_preferences.dart';

/// Persists [ConverterPreferences] in the shared Hive `settingsBox`.
class ConverterSettingsService {
  ConverterSettingsService._();

  static final ConverterSettingsService instance = ConverterSettingsService._();

  static const String _key = 'converter_preferences';

  Box get _box => Hive.box('settingsBox');

  ConverterPreferences get preferences {
    try {
      final raw = _box.get(_key);
      if (raw is Map) {
        return ConverterPreferences.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {}
    return const ConverterPreferences();
  }

  Future<void> save(ConverterPreferences prefs) async {
    await _box.put(_key, prefs.toJson());
  }

  Future<ConverterPreferences> update(
    ConverterPreferences Function(ConverterPreferences current) change,
  ) async {
    final prefs = change(preferences);
    await save(prefs);
    return prefs;
  }
}