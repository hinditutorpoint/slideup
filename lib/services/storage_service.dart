import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import '../models/storage_info.dart';
import 'permission_service.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  Future<List<StorageInfo>> getAvailableStorageLocations() async {
    final locations = <StorageInfo>[];
    final addedPaths = <String>{};

    if (Platform.isAndroid) {
      // 1. Check/Request permissions if needed
      final hasPermission =
          await PermissionService.instance.hasAllPermissions();
      if (!hasPermission) {
        await PermissionService.instance.requestPermissions();
      }

      // 2. Primary Internal Storage (/storage/emulated/0)
      const primaryPath = '/storage/emulated/0';
      if (await Directory(primaryPath).exists()) {
        await _addStorageLocation(
          locations,
          addedPaths,
          primaryPath,
          'Internal Storage',
          StorageType.internal,
        );
      } else {
        const altPrimary = '/sdcard';
        if (await Directory(altPrimary).exists()) {
          await _addStorageLocation(
            locations,
            addedPaths,
            altPrimary,
            'Internal Storage',
            StorageType.internal,
          );
        }
      }

      // 3. Scan external SD cards and USB drives via getExternalStorageDirectories
      try {
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null) {
          for (final dir in extDirs) {
            final parts = path.split(dir.path);
            final storageIdx = parts.indexOf('storage');
            if (storageIdx != -1 && storageIdx + 1 < parts.length) {
              final volumeName = parts[storageIdx + 1];
              if (volumeName != 'emulated' && volumeName != 'self') {
                final volumePath = '/storage/$volumeName';
                if (!addedPaths.contains(volumePath) &&
                    await Directory(volumePath).exists()) {
                  final isUsb = volumeName.toLowerCase().contains('usb') ||
                      volumeName.toLowerCase().contains('otg');
                  await _addStorageLocation(
                    locations,
                    addedPaths,
                    volumePath,
                    isUsb ? 'USB Storage' : 'SD Card ($volumeName)',
                    isUsb ? StorageType.usb : StorageType.external,
                  );
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting external storage directories: $e');
      }

      // 4. Scan /storage directory directly for any additional mounted volumes
      await _scanExternalStorage(locations, addedPaths);
    } else if (Platform.isIOS) {
      final appDir = await getApplicationDocumentsDirectory();
      await _addStorageLocation(
        locations,
        addedPaths,
        appDir.path,
        'App Documents',
        StorageType.internal,
      );
    } else if (Platform.isWindows) {
      for (final letter in ['C', 'D', 'E', 'F', 'G', 'H']) {
        final drivePath = '$letter:\\';
        if (await Directory(drivePath).exists()) {
          await _addStorageLocation(
            locations,
            addedPaths,
            drivePath,
            'Drive ($letter:)',
            letter == 'C' ? StorageType.internal : StorageType.external,
          );
        }
      }
      try {
        final docs = await getApplicationDocumentsDirectory();
        if (!addedPaths.contains(docs.path) && await docs.exists()) {
          await _addStorageLocation(
            locations,
            addedPaths,
            docs.path,
            'Documents',
            StorageType.internal,
          );
        }
      } catch (_) {}
    } else if (Platform.isLinux || Platform.isMacOS) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        await _addStorageLocation(
          locations,
          addedPaths,
          appDir.path,
          'Documents',
          StorageType.internal,
        );
      } catch (_) {}
    }

    // Safety fallback: if no locations found at all, try getApplicationDocumentsDirectory
    if (locations.isEmpty) {
      try {
        final fallbackDir = await getApplicationDocumentsDirectory();
        if (await fallbackDir.exists()) {
          await _addStorageLocation(
            locations,
            addedPaths,
            fallbackDir.path,
            'Storage',
            StorageType.internal,
          );
        }
      } catch (_) {}
    }

    return locations;
  }

  Future<void> _addStorageLocation(
    List<StorageInfo> locations,
    Set<String> addedPaths,
    String dirPath,
    String name,
    StorageType type,
  ) async {
    if (addedPaths.contains(dirPath)) return;
    final directory = Directory(dirPath);
    if (!await directory.exists()) return;

    addedPaths.add(dirPath);

    int totalSpace = 0;
    int freeSpace = 0;
    bool isAccessible = true;

    try {
      final diskSpacePlus = DiskSpacePlus();
      final freeMb = await diskSpacePlus.getFreeDiskSpaceForPath(dirPath) ??
          await diskSpacePlus.getFreeDiskSpace;
      final totalMb = await diskSpacePlus.getTotalDiskSpace;

      if (totalMb != null && totalMb > 0) {
        totalSpace = (totalMb * 1024 * 1024).round();
      }
      if (freeMb != null && freeMb > 0) {
        freeSpace = (freeMb * 1024 * 1024).round();
      }
    } catch (e) {
      debugPrint('Error getting disk space for $dirPath: $e');
    }

    // Test directory readability safely
    try {
      await directory.list().take(1).drain();
    } catch (e) {
      debugPrint('Directory $dirPath may have limited access: $e');
    }

    locations.add(
      StorageInfo(
        name: name,
        path: dirPath,
        type: type,
        totalSpace: totalSpace,
        freeSpace: freeSpace,
        isAccessible: isAccessible,
      ),
    );
  }

  Future<void> _scanExternalStorage(
    List<StorageInfo> locations,
    Set<String> addedPaths,
  ) async {
    try {
      final storage = Directory('/storage');
      if (!await storage.exists()) return;

      await for (final entity in storage.list()) {
        if (entity is Directory) {
          final dirName = path.basename(entity.path);

          // Skip emulated, self, and system directories
          if (dirName == 'emulated' ||
              dirName == 'self' ||
              dirName == 'knox' ||
              dirName.startsWith('.')) {
            continue;
          }

          if (addedPaths.contains(entity.path)) continue;

          StorageType type = StorageType.external;
          String name = 'SD Card ($dirName)';

          if (dirName.toLowerCase().contains('usb') ||
              dirName.toLowerCase().contains('otg')) {
            type = StorageType.usb;
            name = 'USB Storage ($dirName)';
          }

          await _addStorageLocation(
            locations,
            addedPaths,
            entity.path,
            name,
            type,
          );
        }
      }
    } catch (e) {
      debugPrint('Error scanning /storage: $e');
    }
  }
}
