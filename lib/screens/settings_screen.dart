import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/settings/security_settings_section.dart';
import '../widgets/settings/player_settings_section.dart';
import '../widgets/settings/storage_settings_section.dart';
import '../widgets/settings/files_settings_section.dart';
import '../widgets/settings/about_settings_section.dart';

// Import enums from settings service
export '../services/settings_service.dart' show SortBy, SortOrder;

/// Categorized settings screen with compact category tabs.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    const tabStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: tabStyle,
            indicatorSize: TabBarIndicatorSize.label,
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Security', icon: Icon(Icons.lock_outline, size: 16)),
              Tab(text: 'Player', icon: Icon(Icons.play_circle_outline, size: 16)),
              Tab(text: 'Storage', icon: Icon(Icons.storage_outlined, size: 16)),
              Tab(text: 'Files', icon: Icon(Icons.folder_open_outlined, size: 16)),
              Tab(text: 'About', icon: Icon(Icons.info_outline, size: 16)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SecuritySettingsSection(),
            PlayerSettingsSection(),
            StorageSettingsSection(),
            FilesSettingsSection(),
            AboutSettingsSection(),
          ],
        ),
      ),
    );
  }
}