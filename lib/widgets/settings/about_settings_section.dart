import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../screens/privacy_policy_screen.dart';
import '../../screens/terms_of_service_screen.dart';
import '../settings/settings_section_header.dart';

/// About category.
class AboutSettingsSection extends ConsumerStatefulWidget {
  const AboutSettingsSection({super.key});

  @override
  ConsumerState<AboutSettingsSection> createState() =>
      _AboutSettingsSectionState();
}

class _AboutSettingsSectionState extends ConsumerState<AboutSettingsSection> {
  String _appVersion = '';
  String _appVersionLabel = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
        _appVersionLabel = '${info.version}+${info.buildNumber} (Release)';
      });
    } catch (e) {
      debugPrint('Version load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SettingsSectionHeader(title: 'ABOUT', icon: Icons.info_outline),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.info_outline, size: 22),
          title: const Text('Version'),
          subtitle: Text(
            _appVersionLabel.isEmpty ? 'Loading...' : _appVersionLabel,
          ),
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.gavel_outlined, size: 22),
          title: const Text('Open Source Licenses & Credits'),
          subtitle: const Text(
            'View licenses for all 3rd-party packages (FFmpeg, MediaKit, Flutter, etc.)',
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'SlideUp Media Player',
              applicationVersion: _appVersion.isEmpty ? '1.0.0+1' : _appVersion,
              applicationIcon: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              applicationLegalese:
                  '© 2026 SlideUp Project. All rights reserved.',
            );
          },
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.privacy_tip_outlined, size: 22),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
          ),
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.description_outlined, size: 22),
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
          ),
        ),
      ],
    );
  }
}