import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saf/saf.dart';

import '../../helpers/image_helper.dart';
import '../../models/database_config.dart';
import '../../providers/settings_provider.dart';
import '../../screens/multi_backup_restore_screen.dart';
import '../../services/multi_database_backup_service.dart';
import '../../services/permission_service.dart';
import '../../services/saf_service.dart';
import '../../services/settings_service.dart';
import '../../services/thumbnail_service.dart';
import '../../features/speaker_player/screens/models_screen.dart';
import '../../features/speaker_player/tts_controller.dart';
import '../settings/settings_section_header.dart';

/// Storage + backup + maintenance category.
class StorageSettingsSection extends ConsumerStatefulWidget {
  const StorageSettingsSection({super.key});

  @override
  ConsumerState<StorageSettingsSection> createState() =>
      _StorageSettingsSectionState();
}

class _StorageSettingsSectionState extends ConsumerState<StorageSettingsSection> {
  final _databases = const [
    DatabaseConfig(
      name: 'media',
      displayName: 'Media Database',
      fileName: 'slideup_media.db',
      isRequired: true,
    ),
    DatabaseConfig(
      name: 'archive',
      displayName: 'Archive Database',
      fileName: 'slideup_archive_app.db',
      isRequired: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final backupService = MultiDatabaseBackupService(
      databases: _databases,
      backupFolderName: 'MyAppBackups',
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SettingsSectionHeader(
          title: 'STORAGE',
          icon: Icons.storage_outlined,
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Download Location'),
          subtitle: Text(settings.downloadLocation),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () async {
            final selected = await FilePicker.platform.getDirectoryPath(
              dialogTitle: 'Choose download folder',
              initialDirectory: settings.downloadLocation,
            );
            if (selected != null && mounted) {
              await ref
                  .read(settingsProvider.notifier)
                  .setDownloadLocation(selected);
            }
          },
        ),
        FutureBuilder<bool>(
          future: PermissionService.instance.hasManageExternalStoragePermission(),
          builder: (context, snapshot) {
            final granted = snapshot.data ?? false;
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('Storage Write Permission'),
              subtitle: Text(
                granted
                    ? 'Write enabled - USB/SD storage grants access on first use'
                    : 'Full file access needed to create, modify & delete files',
              ),
              trailing: Icon(
                granted ? Icons.check_circle : Icons.chevron_right,
                color: granted ? Colors.green : null,
                size: 20,
              ),
              onTap: () => _handleStoragePermissionTap(granted),
            );
          },
        ),
        FutureBuilder<List<SafPersistedPermission>>(
          future: _getPersistedSafPermissions(),
          builder: (context, snapshot) {
            final grants = snapshot.data ?? const <SafPersistedPermission>[];
            final granted = grants.isNotEmpty;
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('Removable Storage Access'),
              subtitle: Text(
                granted
                    ? 'USB/SD granted - file operations work on removable drives'
                    : 'Grant access to USB/SD drives for delete, move & modify',
              ),
              trailing: Icon(
                granted ? Icons.check_circle : Icons.chevron_right,
                color: granted ? Colors.green : null,
                size: 20,
              ),
              onTap: () => _handleRemovableStorageAccessTap(granted),
            );
          },
        ),
        const Divider(height: 24),
        const SettingsSectionHeader(
          title: 'BACKUP & MAINTENANCE',
          icon: Icons.settings_backup_restore_outlined,
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Backup Service'),
          subtitle: Text(settings.downloadLocation),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MultiBackupRestoreScreen(backupService: backupService),
            ),
          ),
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Clear Cache'),
          subtitle: const Text('Free up storage space'),
          trailing: const Icon(Icons.delete_outline, size: 20),
          onTap: _showClearCacheDialog,
        ),
        FutureBuilder<bool>(
          future: SettingsService.instance.getShowHiddenFiles(),
          builder: (context, snapshot) {
            final modelName =
                TtsController.instance.currentModelName ?? 'No model';
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('Speech Service'),
              subtitle: Text(modelName),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ModelsScreen()),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _handleStoragePermissionTap(bool currentlyGranted) async {
    if (currentlyGranted) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Storage Write Permission'),
          content: const Text(
            'Storage write access is already granted. You can manage or revoke '
            '"All files access" from the Android system settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await openAppSettings();
                if (mounted) setState(() {});
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return;
    }

    final granted = await PermissionService.instance.requestPermissions();
    if (!mounted) return;

    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage write permission granted'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_off_outlined, color: Color(0xFF6C63FF)),
            SizedBox(width: 10),
            Text('Permission Required'),
          ],
        ),
        content: Text(
          PermissionService.instance.getWritePermissionDeniedMessage(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await openAppSettings();
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<List<SafPersistedPermission>> _getPersistedSafPermissions() async {
    if (!Platform.isAndroid) return const [];
    try {
      return await Saf().persistedPermissions();
    } catch (e) {
      debugPrint('Error loading persisted SAF permissions: $e');
      return const [];
    }
  }

  Future<void> _handleRemovableStorageAccessTap(bool currentlyGranted) async {
    if (!Platform.isAndroid) {
      _showSnack('Removable storage access is only available on Android');
      return;
    }

    if (currentlyGranted) {
      _showRemovableStorageGrantedDialog();
      return;
    }

    try {
      final dir = await Saf().pickDirectory();
      if (dir == null || !mounted) {
        _showSnack('Removable storage access not granted');
        return;
      }

      // Bridge the grant into the native registry so deletes/moves work too.
      final rootId = await SafService.instance.storeTree(dir.uri);
      if (!mounted) return;
      setState(() {});
      _showSnack(
        rootId != null
            ? 'USB/SD storage access granted'
            : 'Folder access granted',
      );
    } catch (e) {
      debugPrint('❌ Removable storage access error: $e');
      if (!mounted) return;
      _showSnack('Failed to grant removable storage access');
    }
  }

  void _showRemovableStorageGrantedDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Removable Storage Access'),
        content: const Text(
          'USB/SD storage access is already granted. File operations on '
          'removable drives now work.\n\n'
          'You can manage or revoke grants from the Android system settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await openAppSettings();
              if (mounted) setState(() {});
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Color(0xFF6C63FF)),
            SizedBox(width: 8),
            Text('Clear Cache'),
          ],
        ),
        content: const Text(
          'This will delete all cached thumbnails, temporary export files, and database orphans to free up storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              try {
                int bytesFreed = 0;

                // 1. Clear Thumbnail Service Cache
                try {
                  final cacheSize = await ThumbnailService.instance.getCacheSize();
                  await ThumbnailService.instance.clearCache();
                  bytesFreed += cacheSize;
                } catch (e) {
                  debugPrint('Error clearing thumbnail cache: $e');
                }

                // 2. Clear Database Orphans
                try {
                  await ImageHelper.cleanupDatabaseOrphans();
                } catch (e) {
                  debugPrint('Error cleaning database orphans: $e');
                }

                // 3. Clear Temporary Directory Files
                try {
                  final tempDir = await getTemporaryDirectory();
                  if (await tempDir.exists()) {
                    final entities = tempDir.listSync(recursive: true);
                    for (final entity in entities) {
                      try {
                        if (entity is File) {
                          final size = await entity.length();
                          await entity.delete();
                          bytesFreed += size;
                        }
                      } catch (_) {}
                    }
                  }
                } catch (e) {
                  debugPrint('Error clearing temp directory: $e');
                }

                navigator.pop();
                if (mounted) {
                  final mbFreed =
                      (bytesFreed / (1024 * 1024)).toStringAsFixed(1);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        bytesFreed > 0
                            ? 'Cache cleared successfully ($mbFreed MB freed)'
                            : 'Cache cleared successfully',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error in clearCache: $e');
                navigator.pop();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear cache: $e'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Now'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}