import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/video_settings.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  static const _boxName = 'settingsBox';

  static const String _settingsKey = 'video_settings';
  static const String _volumeKey = 'user_volume';
  static const String _brightnessKey = 'user_brightness';
  static const String _keyViewMode = 'file_browser_view_mode';
  static const String _keyLastLocation = 'file_browser_last_location';
  static const String _keyShowHiddenFiles = 'show_hidden_files';
  static const String _keySortBy = 'sort_by';
  static const String _keySortOrder = 'sort_order';

  Box get _box => Hive.box(_boxName);

  // ---------------- Video settings ----------------

  Future<VideoSettings> loadSettings() async {
    try {
      final jsonString = _box.get(_settingsKey);
      if (jsonString != null) {
        return VideoSettings.fromJson(jsonDecode(jsonString as String));
      }
      return const VideoSettings();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return const VideoSettings();
    }
  }

  Future<bool> saveSettings(VideoSettings settings) async {
    try {
      await _box.put(_settingsKey, jsonEncode(settings.toJson()));
      return true;
    } catch (e) {
      debugPrint('Error saving settings: $e');
      return false;
    }
  }

  // ---------------- Volume ----------------

  Future<bool> saveVolume(double volume) async {
    try {
      await _box.put(_volumeKey, volume);
      return true;
    } catch (e) {
      debugPrint('Error saving volume: $e');
      return false;
    }
  }

  Future<double?> loadVolume() async {
    try {
      return _box.get(_volumeKey) as double?;
    } catch (e) {
      debugPrint('Error loading volume: $e');
      return null;
    }
  }

  // ---------------- Brightness ----------------

  Future<bool> saveBrightness(double brightness) async {
    try {
      await _box.put(_brightnessKey, brightness);
      return true;
    } catch (e) {
      debugPrint('Error saving brightness: $e');
      return false;
    }
  }

  Future<double?> loadBrightness() async {
    try {
      return _box.get(_brightnessKey) as double?;
    } catch (e) {
      debugPrint('Error loading brightness: $e');
      return null;
    }
  }

  // ---------------- View mode ----------------

  bool get isGridView {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        return _box.get(_keyViewMode, defaultValue: 'grid') == 'grid';
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> getIsGridView() async {
    return isGridView;
  }

  Future<void> setIsGridView(bool isGrid) async {
    try {
      await _box.put(_keyViewMode, isGrid ? 'grid' : 'list');
    } catch (e) {
      debugPrint('Error saving view mode: $e');
    }
  }

  // ---------------- Last location ----------------

  Future<String?> getLastLocation() async {
    try {
      return _box.get(_keyLastLocation) as String?;
    } catch (e) {
      debugPrint('Error loading last location: $e');
      return null;
    }
  }

  Future<void> setLastLocation(String path) async {
    try {
      await _box.put(_keyLastLocation, path);
    } catch (e) {
      debugPrint('Error saving last location: $e');
    }
  }

  // ---------------- Hidden files ----------------

  Future<bool> getShowHiddenFiles() async {
    try {
      return _box.get(_keyShowHiddenFiles, defaultValue: false) as bool;
    } catch (e) {
      debugPrint('Error loading show hidden files: $e');
      return false;
    }
  }

  Future<void> setShowHiddenFiles(bool show) async {
    try {
      await _box.put(_keyShowHiddenFiles, show);
    } catch (e) {
      debugPrint('Error saving show hidden files: $e');
    }
  }

  // ---------------- Sorting ----------------

  Future<SortBy> getSortBy() async {
    try {
      final value = _box.get(_keySortBy, defaultValue: SortBy.name.name);
      return SortBy.values.firstWhere((e) => e.name == value);
    } catch (e) {
      debugPrint('Error loading sort by: $e');
      return SortBy.name;
    }
  }

  Future<void> setSortBy(SortBy sortBy) async {
    try {
      await _box.put(_keySortBy, sortBy.name);
    } catch (e) {
      debugPrint('Error saving sort by: $e');
    }
  }

  Future<SortOrder> getSortOrder() async {
    try {
      final value = _box.get(
        _keySortOrder,
        defaultValue: SortOrder.ascending.name,
      );
      return SortOrder.values.firstWhere((e) => e.name == value);
    } catch (e) {
      debugPrint('Error loading sort order: $e');
      return SortOrder.ascending;
    }
  }

  Future<void> setSortOrder(SortOrder order) async {
    try {
      await _box.put(_keySortOrder, order.name);
    } catch (e) {
      debugPrint('Error saving sort order: $e');
    }
  }
}

enum SortBy { name, size, date, type }

enum SortOrder { ascending, descending }
