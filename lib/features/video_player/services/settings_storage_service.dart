import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/player_settings.dart';
import '../models/video_edit_settings.dart';

class SettingsStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _playerSettingsKey = 'player_settings';
  static const String _colorPresetsKey = 'color_presets';
  static const String _playbackPositionsKey = 'playback_positions';
  static const String _recentFilesKey = 'recent_files';

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYER SETTINGS
  // ═══════════════════════════════════════════════════════

  static Future<PlayerSettings> loadPlayerSettings() async {
    try {
      final data = await _storage.read(key: _playerSettingsKey);
      if (data != null) {
        final json = jsonDecode(data) as Map<String, dynamic>;
        return PlayerSettings.fromJson(json);
      }
    } catch (e) {
      debugPrint('❌ Error loading player settings: $e');
    }
    return const PlayerSettings();
  }

  static Future<void> savePlayerSettings(PlayerSettings settings) async {
    try {
      final json = jsonEncode(settings.toJson());
      await _storage.write(key: _playerSettingsKey, value: json);
      debugPrint('✅ Player settings saved');
    } catch (e) {
      debugPrint('❌ Error saving player settings: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYBACK POSITIONS (Resume)
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, int>> loadPlaybackPositions() async {
    try {
      final data = await _storage.read(key: _playbackPositionsKey);
      if (data != null) {
        final json = jsonDecode(data) as Map<String, dynamic>;
        return json.map((key, value) => MapEntry(key, value as int));
      }
    } catch (e) {
      debugPrint('❌ Error loading playback positions: $e');
    }
    return {};
  }

  static Future<void> savePlaybackPosition(
    String fileId,
    Duration position,
  ) async {
    try {
      final positions = await loadPlaybackPositions();
      positions[fileId] = position.inMilliseconds;

      // Keep only last 100 positions
      if (positions.length > 100) {
        final entries = positions.entries.toList();
        entries.removeRange(0, positions.length - 100);
        positions.clear();
        positions.addAll(Map.fromEntries(entries));
      }

      final json = jsonEncode(positions);
      await _storage.write(key: _playbackPositionsKey, value: json);
    } catch (e) {
      debugPrint('❌ Error saving playback position: $e');
    }
  }

  static Future<Duration?> getPlaybackPosition(String fileId) async {
    try {
      final positions = await loadPlaybackPositions();
      final ms = positions[fileId];
      if (ms != null) {
        return Duration(milliseconds: ms);
      }
    } catch (e) {
      debugPrint('❌ Error getting playback position: $e');
    }
    return null;
  }

  static Future<void> clearPlaybackPosition(String fileId) async {
    try {
      final positions = await loadPlaybackPositions();
      positions.remove(fileId);
      final json = jsonEncode(positions);
      await _storage.write(key: _playbackPositionsKey, value: json);
    } catch (e) {
      debugPrint('❌ Error clearing playback position: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ COLOR PRESETS
  // ═══════════════════════════════════════════════════════

  static Future<List<ColorPreset>> loadCustomColorPresets() async {
    try {
      final data = await _storage.read(key: _colorPresetsKey);
      if (data != null) {
        final json = jsonDecode(data) as List;
        return json
            .map((e) => ColorPreset.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Error loading color presets: $e');
    }
    return [];
  }

  static Future<void> saveCustomColorPreset(ColorPreset preset) async {
    try {
      final presets = await loadCustomColorPresets();

      // Remove if exists
      presets.removeWhere((p) => p.id == preset.id);
      presets.add(preset);

      final json = jsonEncode(presets.map((p) => p.toJson()).toList());
      await _storage.write(key: _colorPresetsKey, value: json);
      debugPrint('✅ Color preset saved: ${preset.name}');
    } catch (e) {
      debugPrint('❌ Error saving color preset: $e');
    }
  }

  static Future<void> deleteCustomColorPreset(String presetId) async {
    try {
      final presets = await loadCustomColorPresets();
      presets.removeWhere((p) => p.id == presetId);
      final json = jsonEncode(presets.map((p) => p.toJson()).toList());
      await _storage.write(key: _colorPresetsKey, value: json);
    } catch (e) {
      debugPrint('❌ Error deleting color preset: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ RECENT FILES
  // ═══════════════════════════════════════════════════════

  static Future<List<String>> loadRecentFiles() async {
    try {
      final data = await _storage.read(key: _recentFilesKey);
      if (data != null) {
        final json = jsonDecode(data) as List;
        return json.cast<String>();
      }
    } catch (e) {
      debugPrint('❌ Error loading recent files: $e');
    }
    return [];
  }

  static Future<void> addRecentFile(String filePath) async {
    try {
      final files = await loadRecentFiles();

      // Remove if exists and add to front
      files.remove(filePath);
      files.insert(0, filePath);

      // Keep only last 50
      if (files.length > 50) {
        files.removeRange(50, files.length);
      }

      final json = jsonEncode(files);
      await _storage.write(key: _recentFilesKey, value: json);
    } catch (e) {
      debugPrint('❌ Error adding recent file: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CLEAR ALL
  // ═══════════════════════════════════════════════════════

  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('✅ All settings cleared');
    } catch (e) {
      debugPrint('❌ Error clearing settings: $e');
    }
  }
}
