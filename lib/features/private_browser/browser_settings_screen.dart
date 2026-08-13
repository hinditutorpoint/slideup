import 'package:flutter/material.dart';

import 'browser_settings.dart';

/// Full-screen control panel for the privacy browser.
///
/// Every toggle is persisted through secure storage so your choices stay
/// between browser sessions and apply to every webview that opens.
class BrowserSettingsScreen extends StatefulWidget {
  const BrowserSettingsScreen({super.key});

  @override
  State<BrowserSettingsScreen> createState() => _BrowserSettingsScreenState();
}

class _BrowserSettingsScreenState extends State<BrowserSettingsScreen> {
  bool _loaded = false;
  late bool _httpsOnly;
  late TrackerBlockMode _trackerMode;
  late bool _javaScriptEnabled;
  late bool _blockPopups;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await BrowserSettings.instance.load();
    if (!mounted) return;
    setState(() {
      _httpsOnly = BrowserSettings.instance.httpsOnly;
      _trackerMode = BrowserSettings.instance.trackerMode;
      _javaScriptEnabled = BrowserSettings.instance.javaScriptEnabled;
      _blockPopups = BrowserSettings.instance.blockPopups;
      _loaded = true;
    });
  }

  void _setHttpsOnly(bool value) {
    setState(() => _httpsOnly = value);
    BrowserSettings.instance.setHttpsOnly(value);
  }

  void _setTrackerMode(TrackerBlockMode mode) {
    setState(() => _trackerMode = mode);
    BrowserSettings.instance.setTrackerMode(mode);
  }

  void _showTrackerModePicker() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Block trackers & ads',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            for (final mode in TrackerBlockMode.values)
              RadioListTile<TrackerBlockMode>(
                value: mode,
                groupValue: _trackerMode,
                activeColor: Colors.teal,
                title: Text(mode.label),
                subtitle: Text(mode.description),
                onChanged: (selected) {
                  Navigator.of(sheetContext).pop();
                  if (selected != null) _setTrackerMode(selected);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _setJavaScript(bool value) {
    setState(() => _javaScriptEnabled = value);
    BrowserSettings.instance.setJavaScriptEnabled(value);
  }

  void _setBlockPopups(bool value) {
    setState(() => _blockPopups = value);
    BrowserSettings.instance.setBlockPopups(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Browser Settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Private browser controls',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'These preferences are stored on this device '
                              'and apply to every browser session.',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline, size: 22),
                  title: const Text('HTTPS-only'),
                  subtitle: const Text('Block non-encrypted http:// pages'),
                  value: _httpsOnly,
                  activeColor: Colors.teal,
                  onChanged: _setHttpsOnly,
                ),
                ListTile(
                  leading: const Icon(Icons.block_outlined, size: 22),
                  title: const Text('Block trackers & ads'),
                  subtitle: Text('Level: ${_trackerMode.label.toLowerCase()}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showTrackerModePicker,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.code_outlined, size: 22),
                  title: const Text('JavaScript'),
                  subtitle: const Text('Disable for maximum privacy'),
                  value: _javaScriptEnabled,
                  activeColor: Colors.teal,
                  onChanged: _setJavaScript,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.open_in_new_outlined, size: 22),
                  title: const Text('Block pop-ups'),
                  subtitle: const Text(
                    'Prevent sites from opening new windows',
                  ),
                  value: _blockPopups,
                  activeColor: Colors.teal,
                  onChanged: _setBlockPopups,
                ),
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.info_outline, size: 20),
                  title: const Text(
                    'Private session data handling',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: const Text(
                    'In private session mode (incognito), the platform WebView '
                    'minimises disk persistence of cookies, cache and browsing '
                    'data. History is always in-memory only and cleared on exit. '
                    '"Clear session" globally wipes all WebView data on this '
                    'device when triggered manually.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.tune_outlined, size: 20),
                  title: const Text(
                    'Quick-access toggles',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: const Text(
                    'The browser home page also has switches that change the '
                    'same stored preferences.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}
