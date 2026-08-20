import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/settings_provider.dart';
import '../settings/settings_section_header.dart';

/// Player Settings + Default App category.
class PlayerSettingsSection extends ConsumerStatefulWidget {
  const PlayerSettingsSection({super.key});

  @override
  ConsumerState<PlayerSettingsSection> createState() =>
      _PlayerSettingsSectionState();
}

class _PlayerSettingsSectionState extends ConsumerState<PlayerSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SettingsSectionHeader(
          title: 'PLAYER SETTINGS',
          icon: Icons.play_circle_outline,
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Video Popup Playback'),
          subtitle: const Text('Play videos in floating window'),
          value: settings.videoPopupEnabled,
          activeColor: primary,
          onChanged: (value) => _handleVideoPopupToggle(value),
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Background Audio Playback'),
          subtitle: const Text('Continue playing audio when app is in background'),
          value: settings.backgroundAudioEnabled,
          activeColor: primary,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setBackgroundAudioEnabled(value);
          },
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Auto-play Next'),
          subtitle: const Text('Automatically play next file in playlist'),
          value: settings.autoPlayNext,
          activeColor: primary,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setAutoPlayNext(value);
          },
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Ask to Resume Last Position'),
          subtitle: const Text(
            'Prompt before resuming playback from last saved position',
          ),
          value: settings.askResumeLastPosition,
          activeColor: primary,
          onChanged: (value) {
            ref
                .read(settingsProvider.notifier)
                .setAskResumeLastPosition(value);
          },
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Recent History'),
          subtitle: const Text('Save videos to recent history when playback ends'),
          value: settings.recentHistoryEnabled,
          activeColor: primary,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setRecentHistoryEnabled(value);
          },
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Skip Intro Video'),
          subtitle: const Text('Automatically skip the intro of a video'),
          value: settings.skipIntroVideo,
          activeColor: primary,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setSkipIntroVideo(value);
          },
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Skip Intro Lead Time'),
          subtitle: Text(
            'Skip ${settings.skipIntroLeadSeconds}s before the intro ends',
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showSkipIntroLeadDialog,
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Skip Intro Interaction Required'),
          subtitle: const Text('Require a tap before the intro is skipped'),
          value: settings.skipIntroInteractionRequired,
          activeColor: primary,
          onChanged: (value) {
            ref
                .read(settingsProvider.notifier)
                .setSkipIntroInteractionRequired(value);
          },
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Up Next Button'),
          subtitle: const Text('Show upcoming video button in the last 10 seconds'),
          value: settings.showUpNextButton,
          activeColor: primary,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setShowUpNextButton(value);
          },
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Up Next Lead Time'),
          subtitle: Text(
            'Show the button ${settings.upNextLeadSeconds}s before the video ends',
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showUpNextLeadDialog,
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Swipe to Switch Video'),
          subtitle: const Text('Swipe up/down in the middle to switch videos'),
          value: settings.swipeToSwitchEnabled,
          activeColor: primary,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setSwipeToSwitchEnabled(value);
          },
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Double-tap to Seek'),
          subtitle: const Text('Double-tap left/right sides to seek forward/backward'),
          value: settings.enableDoubleTapSeek,
          activeColor: primary,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setEnableDoubleTapSeek(value);
          },
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Seek Preview'),
          subtitle: const Text('Show thumbnail preview when seeking'),
          value: settings.enableSeekPreview,
          activeColor: primary,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setEnableSeekPreview(value);
          },
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Accumulate Double-tap Seek'),
          subtitle: const Text('Second double-tap adds more seek time (like YouTube)'),
          value: settings.enableDoubleTapAccumulator,
          activeColor: primary,
          onChanged: (value) {
            ref
                .read(settingsProvider.notifier)
                .setEnableDoubleTapAccumulator(value);
          },
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Error Debugging'),
          subtitle: const Text('Show detailed error information'),
          value: settings.errorDebuggingEnabled ?? false,
          activeColor: primary,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setErrorDebuggingEnabled(value);
          },
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Default Video Quality'),
          subtitle: Text(settings.defaultVideoQuality),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showVideoQualityDialog,
        ),
        const Divider(height: 24),
        const SettingsSectionHeader(
          title: 'DEFAULT APP',
          icon: Icons.phone_android_outlined,
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Set as Default Media Player'),
          subtitle: const Text('Open media files with this app by default'),
          value: settings.isDefaultMediaPlayer,
          activeColor: primary,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setAsDefaultPlayer(value);
            const platform = MethodChannel('com.slideup.mediaplayer/settings');
            platform.invokeMethod('openDefaultApps', {'isDefault': value});
          },
        ),
      ],
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: seconds.toDouble().clamp(5.0, 30.0),
                min: 5,
                max: 30,
                divisions: 5,
                label: '$seconds s',
                onChanged: (value) => setDialogState(() => seconds = value.round()),
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

  void _showSkipIntroLeadDialog() {
    final settings = ref.read(settingsProvider);
    var seconds = settings.skipIntroLeadSeconds;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Skip Intro Lead Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Skip the video intro this many seconds before it ends:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                '$seconds s',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: seconds.toDouble().clamp(30.0, 120.0),
                min: 30,
                max: 120,
                divisions: 9,
                label: '$seconds s',
                onChanged: (value) => setDialogState(() => seconds = value.round()),
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
                    .setSkipIntroLeadSeconds(seconds);
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
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(quality),
      onTap: () {
        ref.read(settingsProvider.notifier).setVideoQuality(quality);
        Navigator.pop(context);
      },
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