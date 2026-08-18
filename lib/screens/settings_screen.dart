import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slideup/screens/multi_backup_restore_screen.dart';
import '../services/security_service.dart';
import '../services/settings_service.dart';
import '../services/permission_service.dart';
import '../providers/settings_provider.dart';
import '../helpers/image_helper.dart';
import '../services/multi_database_backup_service.dart';
import 'auth_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import '../models/database_config.dart';
import '/features/speaker_player/screens/models_screen.dart';
import '../features/speaker_player/tts_controller.dart';
import '../features/private_browser/browser_settings_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/thumbnail_service.dart';
import 'locked_files_screen.dart';
import 'file_extensions_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// Import enums from settings service
export '../services/settings_service.dart' show SortBy, SortOrder;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    const databases = [
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

    // Initialize the multi-database backup service
    final backupService = MultiDatabaseBackupService(
      databases: databases,
      backupFolderName: 'MyAppBackups',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSectionHeader('Security'),
          FutureBuilder<bool>(
            future: SecurityService.instance.hasAppLock(),
            builder: (context, snapshot) {
              final hasLock = snapshot.data ?? false;

              return Column(
                children: [
                  SwitchListTile(
                    title: const Text('App Lock'),
                    subtitle: Text(
                      hasLock
                          ? 'App security lock is enabled'
                          : 'Require authentication to open app',
                    ),
                    value: hasLock,
                    onChanged: (value) async {
                      if (value) {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AuthScreen(isSetup: true),
                            fullscreenDialog: true,
                          ),
                        );

                        if (result == true) {
                          setState(() {});
                        }
                      } else {
                        _showRemoveLockDialog();
                      }
                    },
                  ),
                  if (hasLock) ...[
                    FutureBuilder<AppLockType>(
                      future: SecurityService.instance.getAppLockType(),
                      builder: (context, lockTypeSnapshot) {
                        final lockType =
                            lockTypeSnapshot.data ?? AppLockType.password;

                        return ListTile(
                          title: const Text('Lock Type'),
                          subtitle: Text(lockType.displayName),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AuthScreen(
                                  isSetup: true,
                                  initialLockType: lockType,
                                ),
                                fullscreenDialog: true,
                              ),
                            );
                            if (result == true) {
                              setState(() {});
                            }
                          },
                        );
                      },
                    ),
                    FutureBuilder<bool>(
                      future: SecurityService.instance.hasSecurityQuestion(),
                      builder: (context, sqSnapshot) {
                        final hasQuestion = sqSnapshot.data ?? false;
                        return ListTile(
                          title: const Text('Security Question'),
                          subtitle: Text(
                            hasQuestion
                                ? 'Configured for lock recovery'
                                : 'Set up security question for recovery',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showSetSecurityQuestionDialog,
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
          FutureBuilder<bool>(
            future: SecurityService.instance.canUseBiometric(),
            builder: (context, canUseSnapshot) {
              if (canUseSnapshot.data != true) {
                return const SizedBox.shrink();
              }

              return FutureBuilder<bool>(
                future: SecurityService.instance.isBiometricEnabled(),
                builder: (context, isEnabledSnapshot) {
                  final isEnabled = isEnabledSnapshot.data ?? false;

                  return SwitchListTile(
                    title: const Text('Biometric Authentication'),
                    subtitle: const Text('Use fingerprint or face unlock'),
                    value: isEnabled,
                    onChanged: (value) async {
                      await SecurityService.instance.setBiometricEnabled(value);
                      setState(() {});
                    },
                  );
                },
              );
            },
          ),
          ListTile(
            title: const Text('Locked Files'),
            subtitle: const Text('Manage file locks'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LockedFilesScreen(),
                ),
              );
            },
          ),

          const Divider(),
          _buildSectionHeader('Browser'),
          ListTile(
            leading: const Icon(Icons.shield_outlined, color: Colors.teal),
            title: const Text('Browser Settings'),
            subtitle: const Text('HTTPS-only, trackers, JavaScript'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BrowserSettingsScreen(),
                ),
              );
            },
          ),
          _buildSectionHeader('Player Settings'),

          SwitchListTile(
            title: const Text('Video Popup Playback'),
            subtitle: const Text('Play videos in floating window'),
            value: settings.videoPopupEnabled,
            onChanged: (value) => _handleVideoPopupToggle(value),
          ),

          SwitchListTile(
            title: const Text('Background Audio Playback'),
            subtitle: const Text(
              'Continue playing audio when app is in background',
            ),
            value: settings.backgroundAudioEnabled,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setBackgroundAudioEnabled(value);
            },
          ),

          SwitchListTile(
            title: const Text('Auto-play Next'),
            subtitle: const Text('Automatically play next file in playlist'),
            value: settings.autoPlayNext,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setAutoPlayNext(value);
            },
          ),

          SwitchListTile(
            title: const Text('Ask to Resume Last Position'),
            subtitle: const Text(
              'Prompt before resuming playback from last saved position',
            ),
            value: settings.askResumeLastPosition,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setAskResumeLastPosition(value);
            },
          ),

          SwitchListTile(
            title: const Text('Recent History'),
            subtitle: const Text(
              'Save videos to recent history when playback ends',
            ),
            value: settings.recentHistoryEnabled,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setRecentHistoryEnabled(value);
            },
          ),

          SwitchListTile(
            title: const Text('Up Next Button'),
            subtitle: const Text(
              'Show upcoming video button in the last 10 seconds',
            ),
            value: settings.showUpNextButton,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setShowUpNextButton(value);
            },
          ),

          ListTile(
            title: const Text('Up Next Lead Time'),
            subtitle: Text(
              'Show the button ${settings.upNextLeadSeconds}s before the video ends',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showUpNextLeadDialog,
          ),

          SwitchListTile(
            title: const Text('Swipe to Switch Video'),
            subtitle: const Text(
              'Swipe up/down in the middle to switch videos',
            ),
            value: settings.swipeToSwitchEnabled,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setSwipeToSwitchEnabled(value);
            },
          ),

          SwitchListTile(
            title: const Text('Error Debugging'),
            subtitle: const Text('Show detailed error information'),
            value: settings.errorDebuggingEnabled ?? false,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setErrorDebuggingEnabled(value);
            },
          ),

          ListTile(
            title: const Text('Default Video Quality'),
            subtitle: Text(settings.defaultVideoQuality),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showVideoQualityDialog,
          ),

          const Divider(),
          _buildSectionHeader('Storage'),

          ListTile(
            title: const Text('Download Location'),
            subtitle: Text(settings.downloadLocation),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final selected =
                  await FilePicker.platform.getDirectoryPath(
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
            future:
                PermissionService.instance.hasManageExternalStoragePermission(),
            builder: (context, snapshot) {
              final granted = snapshot.data ?? false;
              return ListTile(
                title: const Text('Storage Write Permission'),
                subtitle: Text(
                  granted
                      ? 'Write enabled - USB/SD storage grants access on first use'
                      : 'Full file access needed to create, modify & delete files',
                ),
                trailing: Icon(
                  granted ? Icons.check_circle : Icons.chevron_right,
                  color: granted ? Colors.green : null,
                ),
                onTap: () => _handleStoragePermissionTap(granted),
              );
            },
          ),

          const Divider(),
          _buildSectionHeader('File Management'),

          ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: const Text('Supported File Extensions'),
            subtitle: const Text(
              'Customize extensions, check/uncheck & add custom formats',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FileExtensionsScreen(),
                ),
              );
            },
          ),

          FutureBuilder<bool>(
            future: SettingsService.instance.getIsGridView(),
            builder: (context, snapshot) {
              final isGrid = snapshot.data ?? true;
              return SwitchListTile(
                title: const Text('File Browser View Mode'),
                subtitle: const Text('Grid or List view for file browser'),
                value: isGrid,
                onChanged: (value) async {
                  await SettingsService.instance.setIsGridView(value);
                  setState(() {});
                },
              );
            },
          ),

          FutureBuilder<bool>(
            future: SettingsService.instance.getShowHiddenFiles(),
            builder: (context, snapshot) {
              final showHidden = snapshot.data ?? false;
              return SwitchListTile(
                title: const Text('Show Hidden Files'),
                subtitle: const Text('Display files starting with .'),
                value: showHidden,
                onChanged: (value) async {
                  await SettingsService.instance.setShowHiddenFiles(value);
                  setState(() {});
                },
              );
            },
          ),

          ListTile(
            title: const Text('Sort Files By'),
            subtitle: FutureBuilder<SortBy>(
              future: SettingsService.instance.getSortBy(),
              builder: (context, snapshot) {
                final sortBy = snapshot.data ?? SortBy.name;
                return Text(sortBy.name.toUpperCase());
              },
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showSortByDialog,
          ),

          ListTile(
            title: const Text('Sort Order'),
            subtitle: FutureBuilder<SortOrder>(
              future: SettingsService.instance.getSortOrder(),
              builder: (context, snapshot) {
                final sortOrder = snapshot.data ?? SortOrder.ascending;
                return Text(sortOrder.name.toUpperCase());
              },
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showSortOrderDialog,
          ),

          ListTile(
            title: const Text('Backup Service'),
            subtitle: Text(settings.downloadLocation),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MultiBackupRestoreScreen(backupService: backupService),
              ),
            ),
          ),

          ListTile(
            title: const Text('Clear Cache'),
            subtitle: const Text('Free up storage space'),
            trailing: const Icon(Icons.delete_outline),
            onTap: _showClearCacheDialog,
          ),

          const Divider(),

          FutureBuilder<bool>(
            future: SettingsService.instance.getShowHiddenFiles(),
            builder: (context, snapshot) {
              final modelName =
                  TtsController.instance.currentModelName ?? 'No model';
              return ListTile(
                title: const Text('Speech Service'),
                subtitle: Text(modelName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ModelsScreen()),
                ),
              );
            },
          ),

          const Divider(),
          _buildSectionHeader('Default App'),

          SwitchListTile(
            title: const Text('Set as Default Media Player'),
            subtitle: const Text('Open media files with this app by default'),
            value: settings.isDefaultMediaPlayer,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setAsDefaultPlayer(value);
              const platform = MethodChannel(
                'com.slideup.mediaplayer/settings',
              );
              platform.invokeMethod('openDefaultApps', {'isDefault': value});
            },
          ),

          const Divider(),
          _buildSectionHeader('About'),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0+1 (Release)'),
          ),

          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Open Source Licenses & Credits'),
            subtitle: const Text('View licenses for all 3rd-party packages (FFmpeg, MediaKit, Flutter, etc.)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'SlideUp Media Player',
                applicationVersion: '1.0.0+1',
                applicationIcon: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.slideshow, color: Colors.white, size: 28),
                ),
                applicationLegalese: '© 2026 SlideUp Project. All rights reserved.',
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  void _showRemoveLockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove App Lock'),
        content: const Text('Are you sure you want to remove the app security lock?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await SecurityService.instance.removeAppLock();
              if (!context.mounted) return;
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showSetSecurityQuestionDialog() async {
    final currentQuestion =
        await SecurityService.instance.getSecurityQuestion();
    if (!mounted) return;

    final questionController = TextEditingController(
      text: currentQuestion ?? 'What was the name of your first pet?',
    );
    final answerController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Security Recovery Question'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a question and answer to reset your app lock if forgotten:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: questionController,
              decoration: const InputDecoration(
                labelText: 'Security Question',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerController,
              decoration: const InputDecoration(
                labelText: 'Answer (Case-insensitive)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final q = questionController.text.trim();
              final a = answerController.text.trim();
              if (q.isNotEmpty && a.isNotEmpty) {
                await SecurityService.instance.setSecurityQuestion(q, a);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Security question saved')),
                );
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUpNextLeadDialog() {
    final settings = ref.read(settingsProvider);
    var seconds = settings.upNextLeadSeconds;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Up Next Lead Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Show the Up Next button this many seconds before the video ends:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                '$seconds seconds',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                value: seconds.toDouble().clamp(5.0, 30.0),
                min: 5,
                max: 30,
                divisions: 5,
                label: '$seconds s',
                onChanged: (value) =>
                    setDialogState(() => seconds = value.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(settingsProvider.notifier)
                    .setUpNextLeadSeconds(seconds);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoQualityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Video Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQualityOption('Auto'),
            _buildQualityOption('1080p'),
            _buildQualityOption('720p'),
            _buildQualityOption('480p'),
            _buildQualityOption('360p'),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(String quality) {
    return ListTile(
      title: Text(quality),
      onTap: () {
        ref.read(settingsProvider.notifier).setVideoQuality(quality);
        Navigator.pop(context);
      },
    );
  }

  void _showSortByDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Files By'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortByOption(SortBy.name),
            _buildSortByOption(SortBy.size),
            _buildSortByOption(SortBy.date),
            _buildSortByOption(SortBy.type),
          ],
        ),
      ),
    );
  }

  Widget _buildSortByOption(SortBy sortBy) {
    return ListTile(
      title: Text(sortBy.name.toUpperCase()),
      onTap: () async {
        await SettingsService.instance.setSortBy(sortBy);
        if (!mounted) return;
        Navigator.pop(context);
        setState(() {});
      },
    );
  }

  void _showSortOrderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOrderOption(SortOrder.ascending),
            _buildSortOrderOption(SortOrder.descending),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOrderOption(SortOrder order) {
    return ListTile(
      title: Text(order.name.toUpperCase()),
      onTap: () async {
        await SettingsService.instance.setSortOrder(order);
        if (!mounted) return;
        Navigator.pop(context);
        setState(() {});
      },
    );
  }

  void _showClearCacheDialog() async {
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
                  final mbFreed = (bytesFreed / (1024 * 1024)).toStringAsFixed(1);
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

  Future<void> _handleVideoPopupToggle(bool value) async {
    if (value) {
      if (Platform.isAndroid) {
        final status = await Permission.systemAlertWindow.status;
        if (!status.isGranted) {
          final reqStatus = await Permission.systemAlertWindow.request();
          if (!reqStatus.isGranted) {
            if (!mounted) return;
            _showOverlayPermissionDialog();
            return;
          }
        }
      }
      await ref.read(settingsProvider.notifier).setVideoPopupEnabled(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video Popup Playback enabled'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await ref.read(settingsProvider.notifier).setVideoPopupEnabled(false);
    }
  }

  void _showOverlayPermissionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.picture_in_picture_alt, color: Color(0xFF6C63FF)),
            SizedBox(width: 10),
            Text('Permission Required'),
          ],
        ),
        content: const Text(
          '"Display over other apps" (Floating Window / Popup) permission is required to play videos in popup mode over other apps.\n\nPlease enable the permission in Settings.',
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
}
