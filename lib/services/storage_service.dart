import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/storage_info.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  Future<List<StorageInfo>> getAvailableStorageLocations() async {
    final locations = <StorageInfo>[];

    if (Platform.isAndroid) {
      // ── Permission check ───────────────────────────────────────────────
      // On Android 11+ (API 30+) any directory listing throws errno=13
      // unless MANAGE_EXTERNAL_STORAGE is granted.  We ask here so the
      // file browser never blindly calls list() without it.
      final sdkInt = await _androidSdkInt();
      if (sdkInt >= 30) {
        final hasAll = await Permission.manageExternalStorage.status.isGranted;
        if (!hasAll) {
          await Permission.manageExternalStorage.request();
          // Re-check; if still not granted, skip all file-system enumeration
          // to avoid errno=13. Return an empty list so the caller can show
          // a "Grant permission" prompt instead of crashing.
          final granted =
              await Permission.manageExternalStorage.status.isGranted;
          if (!granted) return locations;
        }
      } else if (sdkInt >= 23) {
        // Android 6–10: plain READ_EXTERNAL_STORAGE is enough
        final status = await Permission.storage.status;
        if (status.isDenied) await Permission.storage.request();
        final granted = await Permission.storage.status.isGranted;
        if (!granted) return locations;
      }

      // Internal storage
      await _addStorageLocation(
        locations,
        '/storage/emulated/0',
        'Internal Storage',
        StorageType.internal,
      );

      // External SD card and USB
      await _scanExternalStorage(locations);
    } else if (Platform.isIOS) {
      // iOS app sandbox
      final appDir = await getApplicationDocumentsDirectory();
      await _addStorageLocation(
        locations,
        appDir.path,
        'App Documents',
        StorageType.internal,
      );
    }

    return locations;
  }

  Future<void> _addStorageLocation(
    List<StorageInfo> locations,
    String path,
    String name,
    StorageType type,
  ) async {
    final directory = Directory(path);
    if (!await directory.exists()) return;

    try {
      //final stat = await directory.stat();

      locations.add(
        StorageInfo(
          name: name,
          path: path,
          type: type,
          totalSpace: await _getTotalSpace(path),
          freeSpace: await _getFreeSpace(path),
          isAccessible: true,
        ),
      );
    } catch (e) {
      debugPrint('Error accessing storage location $path: $e');
      locations.add(
        StorageInfo(
          name: name,
          path: path,
          type: type,
          totalSpace: 0,
          freeSpace: 0,
          isAccessible: false,
        ),
      );
    }
  }

  Future<void> _scanExternalStorage(List<StorageInfo> locations) async {
    try {
      final storage = Directory('/storage');
      if (!await storage.exists()) return;

      await for (final entity in storage.list()) {
        if (entity is Directory) {
          final dirName = path.basename(entity.path);

          // Skip emulated and self directories
          if (dirName == 'emulated' || dirName == 'self') continue;

          // Check if it's accessible — wrap in try/catch so errno=13 on
          // an individual volume doesn't crash the whole scan.
          try {
            await entity.list().first;

            // Determine storage type
            StorageType type = StorageType.external;
            String name = 'SD Card';

            if (dirName.toLowerCase().contains('usb') ||
                dirName.toLowerCase().contains('otg')) {
              type = StorageType.usb;
              name = 'USB Storage';
            }

            await _addStorageLocation(locations, entity.path, name, type);
          } on FileSystemException catch (e) {
            // errno=13 = EACCES (Permission denied) — silently skip the volume.
            debugPrint(
              'Skipping inaccessible storage ${entity.path}: ${e.osError}',
            );
          } catch (e) {
            debugPrint('Skipping storage ${entity.path}: $e');
          }
        }
      }
    } on FileSystemException catch (e) {
      debugPrint('Cannot list /storage: ${e.osError}');
    } catch (e) {
      debugPrint('Error scanning external storage: $e');
    }
  }

  Future<int> _getTotalSpace(String path) async {
    try {
      // This is a simplified implementation
      // In production, you might want to use platform channels
      final file = File(path);
      if (await file.exists()) {
        return 1024 * 1024 * 1024; // 1GB placeholder
      }
    } catch (e) {
      debugPrint('Error getting total space: $e');
    }
    return 0;
  }

  Future<int> _getFreeSpace(String path) async {
    try {
      // This is a simplified implementation
      // In production, you might want to use platform channels
      final file = File(path);
      if (await file.exists()) {
        return 512 * 1024 * 1024; // 512MB placeholder
      }
    } catch (e) {
      debugPrint('Error getting free space: $e');
    }
    return 0;
  }

  /// Returns the Android SDK integer (e.g. 33 for Android 13).
  /// Falls back to 0 on non-Android or parse error.
  Future<int> _androidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    try {
      final version = Platform.operatingSystemVersion;
      final match = RegExp(r'(\d+)').firstMatch(version);
      return int.tryParse(match?.group(1) ?? '0') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
