import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/private_browser/private_browser_screen.dart';
import '../../../../core/constants/legal_content.dart';
import 'open_source_licenses_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        children: [
          // App Info Header
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // App Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.archive,
                    size: 50,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  LegalContent.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),

          const Divider(),

          // App Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Access millions of free books, videos, and audio files from the Internet Archive.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),

          const Divider(),

          // Legal Section
          _SectionHeader(title: 'Legal'),

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

          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source Licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OpenSourceLicensesScreen(),
              ),
            ),
          ),

          const Divider(),

          // Links Section
          _SectionHeader(title: 'Links'),

          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Internet Archive'),
            subtitle: const Text('archive.org'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl(context, 'https://archive.org'),
          ),

          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Pixabay'),
            subtitle: const Text('pixabay.com'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl(context, 'https://pixabay.com'),
          ),

          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Contact Support'),
            subtitle: Text(LegalContent.companyEmail),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl(context, 'mailto:${LegalContent.companyEmail}'),
          ),

          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate This App'),
            subtitle: const Text('Share your feedback'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl(
              context,
              'https://play.google.com/store/apps/details?id=com.slideup.mediaplayer',
            ),
          ),

          const Divider(),

          // Credits
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Made with ❤️',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                ),
                const SizedBox(height: 8),
                Text(
                  '© ${DateTime.now().year} ${LegalContent.companyName}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
                const SizedBox(height: 4),
                Text(
                  'All rights reserved',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme == 'mailto') {
        await Clipboard.setData(ClipboardData(text: uri.path));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email address copied to clipboard')),
        );
        return;
      }
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrivateBrowserScreen(initialUrl: url),
        ),
      );
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
