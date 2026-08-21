import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/settings/settings_section_header.dart';
import '../models/scene_settings.dart';
import '../providers/scene_settings_provider.dart';

class SceneSettingsSection extends ConsumerStatefulWidget {
  const SceneSettingsSection({super.key});

  @override
  ConsumerState<SceneSettingsSection> createState() => _SceneSettingsSectionState();
}

class _SceneSettingsSectionState extends ConsumerState<SceneSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(sceneSettingsProvider);
    final preset = settings.resolvedPreset;
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SettingsSectionHeader(title: 'SCENE CUT', icon: Icons.movie_filter_rounded),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Platform preset'),
          subtitle: Text(preset.label),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showPlatformDialog,
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Container'),
          subtitle: Text(settings.container.label.toUpperCase()),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showContainerDialog,
        ),
        if (settings.platform == ScenePlatform.custom)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: const Text('Custom resolution'),
            subtitle: Text(
              settings.customWidth != null || settings.customHeight != null
                  ? '${settings.customWidth ?? '?'}×${settings.customHeight ?? '?'}'
                  : 'Original source',
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _showCustomResolutionDialog,
          ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Fit mode'),
          subtitle: Text(settings.fitMode.label),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showFitDialog,
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('FPS'),
          subtitle: Text('${settings.fps} fps'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showFpsDialog,
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Video bitrate'),
          subtitle: Text('${settings.videoBitrateKbps} kbps'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showBitrateDialog,
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Audio'),
          subtitle: Text(settings.audioMode == SceneAudioMode.keep ? 'Keep audio' : 'Remove audio'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showAudioDialog,
        ),
        const Divider(height: 24),
        const SettingsSectionHeader(title: 'OUTPUT', icon: Icons.save_outlined),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Save destination'),
          subtitle: Text(settings.saveDestination.subtitle),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: _showSaveDestinationDialog,
        ),
        if (settings.saveDestination != SceneSaveDestination.galleryOnly)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: const Text('Save location'),
            subtitle: Text(settings.saveLocation),
            trailing: const Icon(Icons.folder_open, size: 20),
            onTap: () async {
              final selected = await FilePicker.platform.getDirectoryPath(
                dialogTitle: 'Choose scene folder',
                initialDirectory: settings.saveLocation,
              );
              if (selected != null && mounted) {
                await ref.read(sceneSettingsProvider.notifier).setSaveLocation(selected);
              }
            },
          )
        else
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: const Text('Save location'),
            subtitle: const Text('Gallery: Movies/SlideUpScenes (no folder needed)'),
            enabled: false,
          ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Faststart (MP4)'),
          subtitle: const Text('Enable +faststart for web streaming'),
          value: settings.faststart,
          activeColor: primary,
          onChanged: (v) => ref.read(sceneSettingsProvider.notifier).setFaststart(v),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'Isolated from Video Editor. Scales/crops per platform preset via own FFmpeg pipeline.',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ],
    );
  }

  void _showPlatformDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Platform preset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ScenePlatform.values.map((p) {
            final preset = scenePresetTable[p]!;
            return ListTile(
              dense: true,
              title: Text(p.label),
              subtitle: Text(preset.label, style: const TextStyle(fontSize: 11)),
              onTap: () async {
                await ref.read(sceneSettingsProvider.notifier).setPlatform(p);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showContainerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Container'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SceneContainer.values.map((c) {
            return ListTile(
              dense: true,
              title: Text(c.extension.toUpperCase()),
              onTap: () async {
                await ref.read(sceneSettingsProvider.notifier).setContainer(c);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fit mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SceneFit.values.map((f) {
            return ListTile(
              dense: true,
              title: Text(f.label),
              onTap: () async {
                await ref.read(sceneSettingsProvider.notifier).setFitMode(f);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFpsDialog() {
    const options = [24, 30, 60];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('FPS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((fps) {
            return ListTile(
              dense: true,
              title: Text('$fps fps'),
              onTap: () async {
                await ref.read(sceneSettingsProvider.notifier).setFps(fps);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showBitrateDialog() {
    int kbps = ref.read(sceneSettingsProvider).videoBitrateKbps;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: const Text('Video bitrate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$kbps kbps', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Slider(
                value: kbps.toDouble().clamp(2000, 20000),
                min: 2000,
                max: 20000,
                divisions: 18,
                label: '$kbps',
                onChanged: (v) => setDialog(() => kbps = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await ref.read(sceneSettingsProvider.notifier).setBitrate(kbps);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Audio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: const Text('Keep audio'),
              onTap: () async {
                await ref.read(sceneSettingsProvider.notifier).setAudioMode(SceneAudioMode.keep);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              dense: true,
              title: const Text('Remove audio'),
              onTap: () async {
                await ref.read(sceneSettingsProvider.notifier).setAudioMode(SceneAudioMode.remove);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomResolutionDialog() {
    final s = ref.read(sceneSettingsProvider);
    final wCtrl = TextEditingController(text: s.customWidth?.toString() ?? '');
    final hCtrl = TextEditingController(text: s.customHeight?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom resolution'),
        content: Row(
          children: [
            Expanded(child: TextField(controller: wCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Width'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: hCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height'))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(sceneSettingsProvider.notifier).clearCustomResolution();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () async {
              final w = int.tryParse(wCtrl.text.trim());
              final h = int.tryParse(hCtrl.text.trim());
              await ref.read(sceneSettingsProvider.notifier).setCustomResolution(w, h);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSaveDestinationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save destination'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SceneSaveDestination.values.map((d) {
            return ListTile(
              dense: true,
              title: Text(d.label),
              subtitle: Text(d.subtitle, style: const TextStyle(fontSize: 11)),
              onTap: () async {
                await ref.read(sceneSettingsProvider.notifier).setSaveDestination(d);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
