import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import '../models/storage_info.dart';

class PermissionService {
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  /// Check if the app has all required permissions including write
  Future<bool> hasAllPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ (API 33+)
        return await _checkMultiplePermissions([
              Permission.videos,
              Permission.audio,
              Permission.photos,
              Permission.notification,
            ]) &&
            await hasManageExternalStoragePermission();
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11-12 (API 30-32)
        return await hasManageExternalStoragePermission();
      } else {
        // Android 10 and below (API 29-)
        // accessMediaLocation only exists on Android 10 (API 29)+
        return await _checkMultiplePermissions([
          Permission.storage,
          if (androidInfo.version.sdkInt >= 29) Permission.accessMediaLocation,
        ]);
      }
    } else if (Platform.isIOS) {
      return await _checkMultiplePermissions([
        Permission.photos,
        Permission.mediaLibrary,
      ]);
    }
    return false;
  }

  /// Check if app has manage external storage permission (for write access)
  Future<bool> hasManageExternalStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 30) {
        // Android 11+ requires MANAGE_EXTERNAL_STORAGE for full write access
        return await Permission.manageExternalStorage.status.isGranted;
      } else {
        // Android 10 and below use regular storage permission
        return await Permission.storage.status.isGranted;
      }
    }
    return true; // iOS handles this differently
  }

  /// Check if a path is blocked by Android scoped storage (Android 11+).
  /// On Android 11+ the OS blocks direct access to other apps' Android/data
  /// and Android/obb folders even with MANAGE_EXTERNAL_STORAGE granted.
  Future<bool> isProtectedPathUnderScopedStorage(String dirPath) async {
    if (!Platform.isAndroid) return false;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt < 30) return false;
    final lower = dirPath.toLowerCase();
    return lower.contains('/android/data') || lower.contains('/android/obb');
  }

  /// Check if we have write permission for a specific path
  Future<bool> hasWritePermissionForPath(String dirPath) async {
    try {
      // First check general permissions
      if (!await hasWritePermission()) {
        return false;
      }

      // Test actual write capability
      return await _testWriteCapability(dirPath);
    } catch (e) {
      debugPrint('❌ Error checking write permission for path: $e');
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidVersion();

        if (androidInfo >= 33) {
          final status = await Permission.notification.status;
          if (status.isDenied) {
            final result = await Permission.notification.request();
            return result.isGranted;
          }
          return status.isGranted;
        }
        return true;
      } else if (Platform.isIOS) {
        final status = await Permission.notification.status;
        if (status.isDenied) {
          final result = await Permission.notification.request();
          return result.isGranted;
        }
        return status.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
      return false;
    }
  }

  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;

    try {
      final version = Platform.operatingSystemVersion;
      final regex = RegExp(r'(\d+)');
      final match = regex.firstMatch(version);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '0') ?? 0;
      }
    } catch (e) {
      debugPrint('Failed to get Android version: $e');
    }
    return 0;
  }

  Future<bool> requestAllDownloadPermissions() async {
    final storageGranted = await hasManageExternalStoragePermission();
    final notificationGranted = await requestNotificationPermission();
    return storageGranted && notificationGranted;
  }

  /// Test if we can actually write to a directory
  Future<bool> _testWriteCapability(String dirPath) async {
    try {
      final directory = Directory(dirPath);
      if (!await directory.exists()) {
        return false;
      }

      // Try to create a temporary file
      final testFile = File(
        path.join(
          dirPath,
          '.write_test_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );

      try {
        await testFile.writeAsString('test');
        final canRead = await testFile.readAsString() == 'test';
        await testFile.delete(); // Clean up
        return canRead;
      } catch (e) {
        // Clean up in case of error
        try {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        } catch (_) {}
        return false;
      }
    } catch (e) {
      debugPrint('❌ Write test failed: $e');
      return false;
    }
  }

  /// Check if we have basic write permissions
  Future<bool> hasWritePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 30) {
        // Android 11+ - Check MANAGE_EXTERNAL_STORAGE
        return await Permission.manageExternalStorage.status.isGranted;
      } else {
        // Android 10 and below - Check regular storage permission
        return await Permission.storage.status.isGranted;
      }
    }
    return true; // iOS handles this through document picker
  }

  /// Request all necessary permissions including write
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ (API 33+)
        debugPrint('📱 Requesting Android 13+ permissions...');

        // First request media permissions
        final mediaPermissions = [
          Permission.videos,
          Permission.audio,
          Permission.photos,
        ];

        final mediaStatuses = await mediaPermissions.request();
        final mediaGranted = mediaStatuses.values.every(
          (status) => status.isGranted,
        );

        // Then request manage external storage if needed
        final manageStorageGranted = await _requestManageExternalStorage();

        return mediaGranted && manageStorageGranted;
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11-12 (API 30-32)
        debugPrint('📱 Requesting Android 11-12 permissions...');
        return await _requestManageExternalStorage();
      } else {
        // Android 10 and below (API 29-)
        debugPrint('📱 Requesting Android 10 and below permissions...');
        return await _requestMultiplePermissions([
          Permission.storage,
          if (androidInfo.version.sdkInt >= 29) Permission.accessMediaLocation,
        ]);
      }
    } else if (Platform.isIOS) {
      try {
        debugPrint('📱 Requesting iOS permissions...');
        return await _requestMultiplePermissions([
          Permission.photos,
          Permission.mediaLibrary,
        ]);
      } catch (e) {
        debugPrint('❌ Error requesting iOS permissions: $e');
        return false;
      }
    }

    return false;
  }

  /// Request MANAGE_EXTERNAL_STORAGE permission specifically
  Future<bool> _requestManageExternalStorage() async {
    try {
      final status = await Permission.manageExternalStorage.request();

      if (status.isGranted) {
        debugPrint('✅ MANAGE_EXTERNAL_STORAGE granted');
        return true;
      } else if (status.isPermanentlyDenied) {
        debugPrint('❌ MANAGE_EXTERNAL_STORAGE permanently denied');
        return false;
      } else {
        debugPrint('⚠️ MANAGE_EXTERNAL_STORAGE denied, trying fallback');
        // Fallback to regular storage permission
        final fallbackStatus = await Permission.storage.request();
        return fallbackStatus.isGranted;
      }
    } catch (e) {
      debugPrint('❌ Error requesting MANAGE_EXTERNAL_STORAGE: $e');
      // Fallback to regular storage permission
      try {
        final fallbackStatus = await Permission.storage.request();
        return fallbackStatus.isGranted;
      } catch (e2) {
        debugPrint('❌ Fallback permission request failed: $e2');
        return false;
      }
    }
  }

  /// Check if a path is writable (different storage types)
  Future<bool> isPathWritable(String dirPath) async {
    try {
      // Check if path exists
      final directory = Directory(dirPath);
      if (!await directory.exists()) {
        return false;
      }

      // Check if it's a protected system directory
      if (_isProtectedSystemPath(dirPath)) {
        return false;
      }

      // Check permissions based on storage type
      final storageType = _getStorageType(dirPath);

      switch (storageType) {
        case StorageType.internal:
          return await _checkInternalStorageWrite(dirPath);
        case StorageType.external:
          return await _checkExternalStorageWrite(dirPath);
        case StorageType.usb:
          return await _checkUSBStorageWrite(dirPath);
        default:
          return await hasWritePermissionForPath(dirPath);
      }
    } catch (e) {
      debugPrint('❌ Error checking if path is writable: $e');
      return false;
    }
  }

  /// Check if path is a protected system directory
  bool _isProtectedSystemPath(String dirPath) {
    final protectedPaths = [
      '/system',
      '/proc',
      '/dev',
      '/root',
      '/sys',
      '/vendor',
      '/data/data',
      'Android/data',
      'Android/obb',
    ];

    return protectedPaths.any((protected) => dirPath.contains(protected));
  }

  /// Determine storage type from path
  StorageType _getStorageType(String dirPath) {
    if (dirPath.startsWith('/storage/emulated/0') ||
        dirPath.startsWith('/sdcard')) {
      return StorageType.internal;
    } else if (dirPath.startsWith('/storage/') &&
        !dirPath.contains('emulated') &&
        !dirPath.contains('usb')) {
      return StorageType.external;
    } else if (dirPath.toLowerCase().contains('usb') ||
        dirPath.toLowerCase().contains('otg')) {
      return StorageType.usb;
    }
    return StorageType.internal;
  }

  /// Check internal storage write capability
  Future<bool> _checkInternalStorageWrite(String dirPath) async {
    try {
      // Internal storage should be writable with proper permissions
      return await hasWritePermission() && await _testWriteCapability(dirPath);
    } catch (e) {
      debugPrint('❌ Internal storage write check failed: $e');
      return false;
    }
  }

  /// Check external storage (SD card) write capability
  Future<bool> _checkExternalStorageWrite(String dirPath) async {
    try {
      // External storage requires special permissions
      final hasPermission = await hasManageExternalStoragePermission();
      if (!hasPermission) {
        return false;
      }

      return await _testWriteCapability(dirPath);
    } catch (e) {
      debugPrint('❌ External storage write check failed: $e');
      return false;
    }
  }

  /// Check USB storage write capability
  Future<bool> _checkUSBStorageWrite(String dirPath) async {
    try {
      // USB storage write capability depends on the device and Android version
      final hasPermission = await hasManageExternalStoragePermission();
      if (!hasPermission) {
        return false;
      }

      // USB drives might be read-only or require special handling
      return await _testWriteCapability(dirPath);
    } catch (e) {
      debugPrint('❌ USB storage write check failed: $e');
      return false;
    }
  }

  /// Get writable directories for the current permissions
  Future<List<String>> getWritableDirectories() async {
    final writableDirs = <String>[];

    try {
      // Always add app's internal directories
      writableDirs.addAll([
        '/data/data/${await _getPackageName()}/files',
        '/data/data/${await _getPackageName()}/cache',
      ]);

      // Check common writable directories
      final candidateDirs = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/DCIM',
        '/sdcard/Download',
        '/sdcard/Documents',
      ];

      for (final dir in candidateDirs) {
        if (await isPathWritable(dir)) {
          writableDirs.add(dir);
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting writable directories: $e');
    }

    return writableDirs.toSet().toList(); // Remove duplicates
  }

  /// Get package name for app-specific directories
  Future<String> _getPackageName() async {
    // This is a placeholder - in a real app you'd get this from platform channels
    return 'com.slideup.mediaplayer';
  }

  /// Request multiple permissions
  Future<bool> _requestMultiplePermissions(List<Permission> permissions) async {
    try {
      final statuses = await permissions.request();
      return statuses.values.every((status) => status.isGranted);
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  /// Check a single permission
  /* Future<bool> _checkSinglePermission(Permission permission) async {
    try {
      final status = await permission.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  } */

  /// Check multiple permissions
  Future<bool> _checkMultiplePermissions(List<Permission> permissions) async {
    try {
      final statuses = await Future.wait(permissions.map((p) => p.status));
      return statuses.every((status) => status.isGranted);
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }

  /// Open app settings for the user to manually grant permissions
  Future<bool> openAppSettings() async {
    try {
      return await permission_handler.openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  /// Get a user-friendly permission denied message
  String getPermissionDeniedMessage() {
    if (Platform.isAndroid) {
      return 'Storage access permission is required to create, modify, and delete files. '
          'Please grant "All files access" or "Manage external storage" permission in app settings.';
    } else if (Platform.isIOS) {
      return 'Photo Library access is required to manage your media files. '
          'Please grant the permission in app settings.';
    }

    return 'File access permission denied. Please enable it in app settings.';
  }

  /// Get write permission denied message
  String getWritePermissionDeniedMessage() {
    if (Platform.isAndroid) {
      return 'Write access permission is required to create, modify, and delete files. '
          'Please grant "All files access" permission in Android settings:\n\n'
          '1. Go to Settings > Apps > SlideUp\n'
          '2. Tap on "Permissions"\n'
          '3. Enable "All files access"';
    }
    return 'Write permission denied. Please check app permissions.';
  }
}
