import 'package:flutter/material.dart';

import '../services/supported_extensions_service.dart';

// ═══════════════════════════════════════════════════════
// ✅ FILE EXTENSIONS CUSTOMIZATION SCREEN
// ═══════════════════════════════════════════════════════

class FileExtensionsScreen extends StatefulWidget {
  const FileExtensionsScreen({super.key});

  @override
  State<FileExtensionsScreen> createState() => _FileExtensionsScreenState();
}

class _FileExtensionsScreenState extends State<FileExtensionsScreen> {
  final SupportedExtensionsService _service = SupportedExtensionsService.instance;

  @override
  void initState() {
    super.initState();
    _service.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _toggleExtension(String ext, bool enabled) async {
    await _service.toggleExtension(ext, enabled);
    if (mounted) setState(() {});
  }

  void _toggleCategory(ExtensionCategory category, bool enabled) async {
    await _service.toggleCategory(category, enabled);
    if (mounted) setState(() {});
  }

  void _showAddCustomDialog() {
    final textController = TextEditingController();
    ExtensionCategory selectedCategory = ExtensionCategory.video;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Text('➕ Add Custom Extension'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter file extension (e.g. .m2ts, .srt, .sub):',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '.ext',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.extension),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Category:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ExtensionCategory>(
                value: selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: ExtensionCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text('${cat.iconEmoji} ${cat.displayName}'),
                  );
                }).toList(),
                onChanged: (cat) {
                  if (cat != null) {
                    setDialogState(() => selectedCategory = cat);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final ext = textController.text.trim();
                if (ext.isEmpty) return;
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final success = await _service.addCustomExtension(
                  ext,
                  selectedCategory,
                );
                navigator.pop();
                if (mounted) {
                  setState(() {});
                  if (success) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Added $ext to ${selectedCategory.displayName}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add Extension'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResetDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Extensions'),
        content: const Text(
          'Reset all supported file extensions to default settings?',
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
              await _service.resetToDefaults();
              navigator.pop();
              if (mounted) {
                setState(() {});
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Reset file extensions to default'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supported File Extensions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset Defaults',
            onPressed: _confirmResetDefaults,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Extension'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Informational Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_special,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Check or uncheck extensions to customize what files the app reads and scans.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Categories
          ...ExtensionCategory.values.map(
            (category) => _buildCategoryCard(category),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(ExtensionCategory category) {
    final exts = _service.getExtensionsForCategory(category);
    final allEnabled = exts.every((e) => _service.isExtensionEnabled(e));
    final someEnabled = exts.any((e) => _service.isExtensionEnabled(e));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Text(category.iconEmoji, style: const TextStyle(fontSize: 24)),
        title: Text(
          '${category.displayName} Files',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${exts.where((e) => _service.isExtensionEnabled(e)).length} of ${exts.length} enabled',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: allEnabled ? true : (someEnabled ? null : false),
              tristate: true,
              onChanged: (val) {
                _toggleCategory(category, val ?? true);
              },
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: exts.map((ext) {
                final isEnabled = _service.isExtensionEnabled(ext);
                final isCustom = _service.customExtensions.containsKey(ext);

                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ext,
                        style: TextStyle(
                          fontWeight: isEnabled
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (isCustom) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                      ],
                    ],
                  ),
                  selected: isEnabled,
                  onSelected: (selected) {
                    _toggleExtension(ext, selected);
                  },
                  onDeleted: isCustom
                      ? () async {
                          await _service.removeCustomExtension(ext);
                          if (mounted) setState(() {});
                        }
                      : null,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
