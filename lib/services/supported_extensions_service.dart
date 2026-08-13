import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ═══════════════════════════════════════════════════════
// ✅ SUPPORTED FILE EXTENSIONS SERVICE
// ═══════════════════════════════════════════════════════

enum ExtensionCategory { video, audio, image, document }

extension ExtensionCategoryExt on ExtensionCategory {
  String get displayName {
    switch (this) {
      case ExtensionCategory.video:
        return 'Video';
      case ExtensionCategory.audio:
        return 'Audio';
      case ExtensionCategory.image:
        return 'Image';
      case ExtensionCategory.document:
        return 'Document';
    }
  }

  String get iconEmoji {
    switch (this) {
      case ExtensionCategory.video:
        return '🎬';
      case ExtensionCategory.audio:
        return '🎵';
      case ExtensionCategory.image:
        return '🖼️';
      case ExtensionCategory.document:
        return '📄';
    }
  }
}

class SupportedExtensionsService {
  static final SupportedExtensionsService instance =
      SupportedExtensionsService._();
  SupportedExtensionsService._();

  static const String _boxName = 'settingsBox';
  static const String _enabledExtsKey = 'enabled_file_extensions';
  static const String _customExtsKey = 'custom_file_extensions';

  // Default extensions per category
  static const Map<ExtensionCategory, List<String>> defaultCategoryExtensions =
      {
        ExtensionCategory.video: [
          '.mp4',
          '.mkv',
          '.avi',
          '.mov',
          '.wmv',
          '.flv',
          '.webm',
          '.ts',
          '.3gp',
          '.mpeg',
          '.m4v',
        ],
        ExtensionCategory.audio: [
          '.mp3',
          '.wav',
          '.flac',
          '.aac',
          '.m4a',
          '.ogg',
          '.wma',
          '.opus',
          '.amr',
          '.mp2',
        ],
        ExtensionCategory.image: [
          '.jpg',
          '.jpeg',
          '.png',
          '.gif',
          '.webp',
          '.bmp',
          '.heic',
          '.svg',
        ],
        ExtensionCategory.document: [
          '.pdf',
          '.txt',
          '.html',
          '.htm',
          '.xml',
          '.json',
          '.doc',
          '.docx',
          '.epub',
        ],
      };

  Box get _box => Hive.box(_boxName);

  /// Set of currently enabled extensions (lowercase, e.g. '.mp4')
  Set<String> _enabledExtensions = {};

  /// Custom user-added extensions mapped to their assigned category
  Map<String, ExtensionCategory> _customExtensions = {};

  Set<String> get enabledExtensions => Set.unmodifiable(_enabledExtensions);
  Map<String, ExtensionCategory> get customExtensions =>
      Map.unmodifiable(_customExtensions);

  /// Initialize and load saved extension preferences from Hive
  Future<void> initialize() async {
    try {
      // Initialize defaults
      final allDefaults = defaultCategoryExtensions.values
          .expand((e) => e)
          .toSet();

      // Load custom extensions
      final customJson = _box.get(_customExtsKey);
      if (customJson != null && customJson is String) {
        final decoded = jsonDecode(customJson) as Map<String, dynamic>;
        _customExtensions = decoded.map((key, value) {
          final catIdx = (value as num).toInt();
          return MapEntry(
            key,
            ExtensionCategory.values.elementAt(
              catIdx.clamp(0, ExtensionCategory.values.length - 1),
            ),
          );
        });
      }

      // Load enabled extensions
      final enabledList = _box.get(_enabledExtsKey);
      if (enabledList != null && enabledList is List) {
        _enabledExtensions = enabledList.cast<String>().toSet();
      } else {
        // Default: all default & custom extensions enabled
        _enabledExtensions = {...allDefaults, ..._customExtensions.keys};
      }

      debugPrint(
        '✅ SupportedExtensionsService initialized (${_enabledExtensions.length} enabled)',
      );
    } catch (e) {
      debugPrint('❌ Error initializing SupportedExtensionsService: $e');
      _enabledExtensions = defaultCategoryExtensions.values
          .expand((e) => e)
          .toSet();
    }
  }

  /// Get all extensions (default + custom) for a category
  List<String> getExtensionsForCategory(ExtensionCategory category) {
    final defaults = defaultCategoryExtensions[category] ?? [];
    final customs = _customExtensions.entries
        .where((e) => e.value == category)
        .map((e) => e.key);
    return {...defaults, ...customs}.toList();
  }

  /// Check if a specific extension string (e.g., '.mp4') is enabled
  bool isExtensionEnabled(String extension) {
    final ext = extension.toLowerCase().trim();
    final formattedExt = ext.startsWith('.') ? ext : '.$ext';
    return _enabledExtensions.contains(formattedExt);
  }

  /// Check if a file path has an enabled extension
  bool isFileSupported(String filePath) {
    if (filePath.isEmpty) return false;
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.slock')) return true;
    final dotIndex = filePath.lastIndexOf('.');
    if (dotIndex < 0) return false;
    final ext = filePath.substring(dotIndex).toLowerCase();
    return _enabledExtensions.contains(ext);
  }

  /// Toggle enabled state for an extension
  Future<void> toggleExtension(String extension, bool enabled) async {
    try {
      final ext = extension.toLowerCase().trim();
      final formattedExt = ext.startsWith('.') ? ext : '.$ext';

      if (enabled) {
        _enabledExtensions.add(formattedExt);
      } else {
        _enabledExtensions.remove(formattedExt);
      }

      await _saveEnabledState();
    } catch (e) {
      debugPrint('❌ Error toggling extension: $e');
    }
  }

  /// Toggle all extensions in a category
  Future<void> toggleCategory(ExtensionCategory category, bool enabled) async {
    try {
      final exts = getExtensionsForCategory(category);
      if (enabled) {
        _enabledExtensions.addAll(exts);
      } else {
        _enabledExtensions.removeAll(exts);
      }
      await _saveEnabledState();
    } catch (e) {
      debugPrint('❌ Error toggling category: $e');
    }
  }

  /// Add a custom user file extension
  Future<bool> addCustomExtension(
    String extension,
    ExtensionCategory category,
  ) async {
    try {
      var ext = extension.toLowerCase().trim();
      if (ext.isEmpty) return false;
      if (!ext.startsWith('.')) ext = '.$ext';

      _customExtensions[ext] = category;
      _enabledExtensions.add(ext);

      await _saveCustomState();
      await _saveEnabledState();
      return true;
    } catch (e) {
      debugPrint('❌ Error adding custom extension: $e');
      return false;
    }
  }

  /// Delete a custom extension
  Future<void> removeCustomExtension(String extension) async {
    try {
      var ext = extension.toLowerCase().trim();
      if (!ext.startsWith('.')) ext = '.$ext';

      _customExtensions.remove(ext);
      _enabledExtensions.remove(ext);

      await _saveCustomState();
      await _saveEnabledState();
    } catch (e) {
      debugPrint('❌ Error removing custom extension: $e');
    }
  }

  /// Reset all extension preferences back to factory defaults
  Future<void> resetToDefaults() async {
    try {
      _customExtensions.clear();
      _enabledExtensions = defaultCategoryExtensions.values
          .expand((e) => e)
          .toSet();

      await _box.delete(_customExtsKey);
      await _saveEnabledState();
    } catch (e) {
      debugPrint('❌ Error resetting extensions to defaults: $e');
    }
  }

  Future<void> _saveEnabledState() async {
    await _box.put(_enabledExtsKey, _enabledExtensions.toList());
  }

  Future<void> _saveCustomState() async {
    final mapToSave = _customExtensions.map(
      (k, v) => MapEntry(k, v.index),
    );
    await _box.put(_customExtsKey, jsonEncode(mapToSave));
  }
}
