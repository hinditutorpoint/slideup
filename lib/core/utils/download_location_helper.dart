import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';

/// Resolves the user-configured download location from the Settings screen.
///
/// The setting is persisted in the Hive box `settings` under the key
/// `downloadLocation`. When unset, empty or not writable, callers fall back
/// to their own default directory logic.
class DownloadLocationHelper {
  DownloadLocationHelper._();

  static const String _settingsBoxName = 'settings';
  static const String _downloadLocationKey = 'downloadLocation';

  /// Returns the configured download directory if one was chosen and is
  /// usable (exists / can be created / writable), otherwise `null`.
  static Future<Directory?> configuredDirectory() async {
    String? location;
    try {
      final Box box = Hive.isBoxOpen(_settingsBoxName)
          ? Hive.box(_settingsBoxName)
          : await Hive.openBox(_settingsBoxName);
      location = box.get(_downloadLocationKey) as String?;
    } catch (_) {
      return null;
    }

    if (location == null || location.trim().isEmpty) return null;

    final dir = Directory(location.trim());
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probe = File('${dir.path}/.slideup_write_probe');
      await probe.writeAsString('ok');
      await probe.delete();
      return dir;
    } catch (_) {
      return null;
    }
  }
}