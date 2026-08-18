import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Manages User Agreement & Privacy Policy consent state, required by OPPO
/// App Market guidelines (Doc #id=15) and international privacy laws.
class PrivacyPolicyManager {
  PrivacyPolicyManager._();

  static const String _kBoxName = 'settingsBox';
  static const String _kConsentKey = 'user_agreement_agreed';

  /// Returns true if the user has already accepted the privacy policy.
  static bool hasUserAgreed() {
    try {
      final box = Hive.box(_kBoxName);
      return box.get(_kConsentKey, defaultValue: false) as bool;
    } catch (_) {
      return false;
    }
  }

  /// Sets the user consent state.
  static Future<void> setUserAgreed(bool agreed) async {
    try {
      final box = Hive.box(_kBoxName);
      await box.put(_kConsentKey, agreed);
    } catch (e) {
      debugPrint('Error saving privacy agreement: $e');
    }
  }

  /// Shows the first-launch Privacy Policy & User Agreement modal if not yet agreed.
  /// Returns `true` if agreed, `false` if user declined.
  static Future<bool> ensurePrivacyAgreed(BuildContext context) async {
    if (hasUserAgreed()) return true;

    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PrivacyPolicyAgreementModal(),
    );

    if (agreed == true) {
      await setUserAgreed(true);
      return true;
    }

    return false;
  }
}

/// The mandatory first-launch modal dialog explaining data usage and permissions
/// before any runtime permission requests are invoked.
class _PrivacyPolicyAgreementModal extends StatelessWidget {
  const _PrivacyPolicyAgreementModal();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: dark ? const Color(0xFF1E1E2E) : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Shield Icon
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: Color(0xFF6C63FF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Terms & Privacy',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Welcome to SlideUp Media Player',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Scrollable summary of data practices
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thank you for using SlideUp. Please read our User Agreement and Privacy Policy carefully before starting:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPoint(
                        icon: Icons.folder_open_outlined,
                        title: 'Device Storage Access',
                        description:
                            'Used strictly to scan, organize, and play your local videos, audio, and documents (PDF, EPUB, TXT). We do not upload your personal files.',
                      ),
                      const SizedBox(height: 10),
                      _buildPoint(
                        icon: Icons.cloud_outlined,
                        title: 'Network & Streaming',
                        description:
                            'Used when you stream videos, IPTV channels, or search public web media. No tracking or selling of personal data.',
                      ),
                      const SizedBox(height: 10),
                      _buildPoint(
                        icon: Icons.notifications_none_outlined,
                        title: 'Notifications & Background Playback',
                        description:
                            'Used to display media controls in the status bar while playing audio or processing video conversions in background.',
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FullPrivacyPolicyScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Read Full Privacy Policy & Terms',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons: Agree & Continue / Disagree
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      onPressed: () => _showDisagreeConfirmation(context),
                      child: Text(
                        'Disagree',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'Agree & Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPoint({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDisagreeConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Privacy Consent Required'),
        content: const Text(
          'SlideUp requires your agreement to terms and privacy practices in order to manage and play local media on your device.\n\nAre you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Review Again'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              SystemNavigator.pop();
            },
            child: const Text('Exit App'),
          ),
        ],
      ),
    );
  }
}

/// Full screen Privacy Policy document accessible from settings and first-launch dialog.
class FullPrivacyPolicyScreen extends StatelessWidget {
  const FullPrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy & Terms'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SlideUp Privacy Policy',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Last Updated: August 2026',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildSection(
                '1. Overview',
                'SlideUp is a high-performance multimedia player and document viewer designed to play local files and network streams. We respect your privacy and are committed to protecting your personal information.',
              ),
              _buildSection(
                '2. Information We Access & Collect',
                '• Storage & Media Files: We access your local storage solely to scan, index, and playback your videos, audio, images, and documents (PDF, EPUB, TXT). Your personal media files remain on your device and are NEVER uploaded to any remote server.\n'
                '• Network Data: When you access IPTV streams, Archive.org search, or web media, network requests are made directly to the respective hosts to fetch the streams and metadata.\n'
                '• Local Settings: App preferences (volume, brightness, theme, bookmarks, playlists) are stored locally on your device.',
              ),
              _buildSection(
                '3. Permissions Explanation',
                '• Storage / All Files Access: Required to read video/audio/document files across internal and external storage.\n'
                '• Foreground Service & Media Playback: Required to keep audio and live streams playing seamlessly when the screen is locked or app is in background.\n'
                '• Notifications: Used to provide media playback controls in the status bar.\n'
                '• Internet: Required for IPTV live streaming, online document search, and private browsing.',
              ),
              _buildSection(
                '4. Third-Party Sharing & Tracking',
                'SlideUp does not sell, rent, or trade your personal data. We do not use intrusive advertising networks or unauthorized device fingerprinting.',
              ),
              _buildSection(
                '5. User Rights & Data Deletion',
                'You can clear your local cache, playback history, and saved playlists at any time in the app settings. Uninstalling the application completely removes all locally stored app configuration.',
              ),
              _buildSection(
                '6. Contact Us & Grievance Officer',
                'If you have any questions, concerns, or grievances regarding our privacy practices or your personal data, please contact our Grievance Officer at:\n\n'
                'Grievance Officer Email: hinditutorpoint@gmail.com\n\n'
                'We will review and respond to your grievance as soon as possible.',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
