import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../screens/file_extensions_screen.dart';
import '../../services/settings_service.dart';
import '../settings/settings_section_header.dart';

/// File Management category.
class FilesSettingsSection extends ConsumerStatefulWidget {
  const FilesSettingsSection({super.key});

  @override
  ConsumerState<FilesSettingsSection> createState() =>
      _FilesSettingsSectionState();
}

class _FilesSettingsSectionState extends ConsumerState<FilesSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SettingsSectionHeader(
          title: 'FILE MANAGEMENT',
          icon: Icons.folder_open_outlined,
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.extension_outlined, size: 22),
          title: const Text('Supported File Extensions'),
          subtitle: const Text(
            'Customize extensions, check/uncheck & add custom formats',
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
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
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('File Browser View Mode'),
              subtitle: const Text('Grid or List view for file browser'),
              value: isGrid,
              activeColor: primary,
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
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('Show Hidden Files'),
              subtitle: const Text('Display files starting with .'),
              value: showHidden,
              activeColor: primary,
              onChanged: (value) async {
                await SettingsService.instance.setShowHiddenFiles(value);
                setState(() {});
              },
            );
          },
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Sort Files By'),
          subtitle: FutureBuilder<SortBy>(
            future: SettingsService.instance.getSortBy(),
            builder: (context, snapshot) {
              final sortBy = snapshot.data ?? SortBy.name;
              return Text(sortBy.name.toUpperCase());
            },
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showSortByDialog,
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Sort Order'),
          subtitle: FutureBuilder<SortOrder>(
            future: SettingsService.instance.getSortOrder(),
            builder: (context, snapshot) {
              final sortOrder = snapshot.data ?? SortOrder.ascending;
              return Text(sortOrder.name.toUpperCase());
            },
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showSortOrderDialog,
        ),
      ],
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
      dense: true,
      visualDensity: VisualDensity.compact,
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
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(order.name.toUpperCase()),
      onTap: () async {
        await SettingsService.instance.setSortOrder(order);
        if (!mounted) return;
        Navigator.pop(context);
        setState(() {});
      },
    );
  }
}