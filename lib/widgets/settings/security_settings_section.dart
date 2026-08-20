import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../screens/auth_screen.dart';
import '../../screens/locked_files_screen.dart';
import '../../services/security_service.dart';
import '../settings/settings_section_header.dart';
import '../../features/private_browser/browser_settings_screen.dart';

/// Security + Browser settings category.
class SecuritySettingsSection extends ConsumerStatefulWidget {
  const SecuritySettingsSection({super.key});

  @override
  ConsumerState<SecuritySettingsSection> createState() =>
      _SecuritySettingsSectionState();
}

class _SecuritySettingsSectionState
    extends ConsumerState<SecuritySettingsSection> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SettingsSectionHeader(title: 'SECURITY', icon: Icons.lock_outline),
        FutureBuilder<bool>(
          future: SecurityService.instance.hasAppLock(),
          builder: (context, snapshot) {
            final hasLock = snapshot.data ?? false;

            return Column(
              children: [
                SwitchListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: const Text('App Lock'),
                  subtitle: Text(
                    hasLock
                        ? 'App security lock is enabled'
                        : 'Require authentication to open app',
                  ),
                  value: hasLock,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (value) async {
                    if (value) {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AuthScreen(isSetup: true),
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
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: const Text('Lock Type'),
                        subtitle: Text(lockType.displayName),
                        trailing: const Icon(Icons.chevron_right, size: 20),
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
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: const Text('Security Question'),
                        subtitle: Text(
                          hasQuestion
                              ? 'Configured for lock recovery'
                              : 'Set up security question for recovery',
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
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
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: const Text('Biometric Authentication'),
                  subtitle: const Text('Use fingerprint or face unlock'),
                  value: isEnabled,
                  activeColor: Theme.of(context).colorScheme.primary,
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
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Locked Files'),
          subtitle: const Text('Manage file locks'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LockedFilesScreen(),
              ),
            );
          },
        ),
        const Divider(height: 24),
        const SettingsSectionHeader(title: 'BROWSER', icon: Icons.shield_outlined),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.shield_outlined, color: Colors.teal, size: 22),
          title: const Text('Browser Settings'),
          subtitle: const Text('HTTPS-only, trackers, JavaScript'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BrowserSettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showRemoveLockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove App Lock'),
        content: const Text(
          'Are you sure you want to remove the app security lock?',
        ),
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
}