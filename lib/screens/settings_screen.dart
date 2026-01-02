import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slideup/screens/multi_backup_restore_screen.dart';
import '../services/security_service.dart';
import '../services/settings_service.dart';
import '../providers/settings_provider.dart';
import '../helpers/image_helper.dart';
import '../services/database_service.dart';
import '../services/multi_database_backup_service.dart';
import 'auth_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import '../models/database_config.dart';
import '/features/speaker_player/screens/models_screen.dart';
import '../features/speaker_player/tts_controller.dart';

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
            future: SecurityService.instance.hasAppPassword(),
            builder: (context, snapshot) {
              final hasPassword = snapshot.data ?? false;

              return SwitchListTile(
                title: const Text('App Lock'),
                subtitle: const Text('Require password to open app'),
                value: hasPassword,
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
                    _showRemovePasswordDialog();
                  }
                },
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
              // TODO: Navigate to locked files screen
            },
          ),

          const Divider(),
          _buildSectionHeader('Player Settings'),

          SwitchListTile(
            title: const Text('Video Popup Playback'),
            subtitle: const Text('Play videos in floating window'),
            value: settings.videoPopupEnabled,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setVideoPopupEnabled(value);
            },
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
            onTap: () {
              // TODO: Show folder picker
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

          ListTile(title: const Text('Version'), subtitle: const Text('1.0.0')),

          ListTile(
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),

          ListTile(
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
            ),
          ),

          const SizedBox(height: 20),
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

  void _showRemovePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Password'),
        content: const Text('Are you sure you want to remove app password?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await SecurityService.instance.removeAppPassword();
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
        Navigator.pop(context);
        setState(() {});
      },
    );
  }

  void _showClearCacheDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will delete all cached thumbnails and temporary files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseService.instance.database;
              try {
                final cleaned = await ImageHelper.cleanupDatabaseOrphans();
                if (cleaned > 0) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared')),
                  );
                }
              } catch (e) {
                print('Error during cleanup: $e');
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
