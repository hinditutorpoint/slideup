import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../models/conversion_job.dart';
import '../models/conversion_models.dart';
import '../models/conversion_settings.dart';
import '../models/converter_preset.dart';
import '../providers/conversion_providers.dart';
import '../services/conversion_manager.dart';
import '../services/converter_constants.dart';
import '../services/converter_database_service.dart';
import '../services/ffmpeg_probe_service.dart';
import '../widgets/converter_preview_player.dart';

class ConverterHomeScreen extends ConsumerStatefulWidget {
  const ConverterHomeScreen({super.key});

  @override
  ConsumerState<ConverterHomeScreen> createState() =>
      _ConverterHomeScreenState();
}

class _ConverterHomeScreenState extends ConsumerState<ConverterHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  _HistoryFilter _filter = _HistoryFilter.completed;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Converter'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_to_photos_outlined), text: 'Convert'),
            Tab(icon: Icon(Icons.visibility_outlined), text: 'Preview'),
            Tab(icon: Icon(Icons.playlist_play), text: 'Queue'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.tune), text: 'Presets'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ConvertTab(onDone: () => _tabController.animateTo(2)),
          const _PreviewTab(onDone: null),
          const _QueueTab(),
          _HistoryTab(
            searchController: _searchController,
            filter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
          ),
          const _PresetsTab(),
          const _SettingsTab(),
        ],
      ),
    );
  }
}

enum _HistoryFilter { all, completed, failed, cancelled, interrupted }

// ─────────────────────────────── Convert ───────────────────────────────

class _ConvertTab extends ConsumerStatefulWidget {
  const _ConvertTab({this.onDone});

  final VoidCallback? onDone;

  @override
  ConsumerState<_ConvertTab> createState() => _ConvertTabState();
}

class _ConvertTabState extends ConsumerState<_ConvertTab> {
  bool _picking = false;
  List<ConverterPreset> _presets = [];
  ConverterPreset? _selectedPreset;

  ConversionSettings get _settings => ref.read(converterDraftProvider);

  void _updateSettings(ConversionSettings settings) {
    ref.read(converterDraftProvider.notifier).apply(settings);
  }

  @override
  void initState() {
    super.initState();
    _loadPresets();
    _applyDefaultPresetAsync();
  }

  Future<void> _loadPresets() async {
    final prefs = ref.read(converterPreferencesProvider);
    final all = await ConverterDatabaseService.instance.getAllPresets();
    final ordered = prefs.defaultPresetId == null
        ? all
        : _applyDefaultOrder(all, prefs.defaultPresetId!);
    if (mounted) setState(() => _presets = ordered);
  }

  List<ConverterPreset> _applyDefaultOrder(List<ConverterPreset> all, String id) {
    final def = all.where((p) => p.id == id).toList();
    final rest = all.where((p) => p.id != id).toList();
    return [...def, ...rest];
  }

  Future<void> _applyDefaultPresetAsync() async {
    final prefs = ref.read(converterPreferencesProvider);
    if (prefs.defaultPresetId == null) return;
    final all = await ConverterDatabaseService.instance.getAllPresets();
    for (final p in all) {
      if (p.id == prefs.defaultPresetId) {
        if (mounted) {
          setState(() {
            _selectedPreset = p;
            _updateSettings(p.settings);
          });
        }
        return;
      }
    }
  }

  Future<void> _pickAndEnqueue() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ConverterConstants.supportedInputs,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final paths = <String>[];
      final names = <String>[];
      final probes = <MediaProbeInfo>[];
      for (final f in result.files) {
        final path = f.path;
        if (path == null) continue;
        final probe = await FFprobeService.instance.probe(path);
        if (probe == null) continue;
        paths.add(path);
        names.add(f.name);
        probes.add(probe);
      }

      if (paths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No supported media files were found to convert.'),
            ),
          );
        }
        return;
      }

      final prefs = ref.read(converterPreferencesProvider);
      var settings = _resolveSettings(probes);
      settings = settings.copyWith(
        outputLocation: prefs.outputLocation,
        duplicateStrategy: prefs.duplicateStrategy,
        hardwareMode: _selectedPreset?.settings.hardwareMode ??
            settings.hardwareMode,
      );

      await ConversionManager.instance.enqueue(
        sourcePaths: paths,
        sourceNames: names,
        probes: probes,
        settings: settings,
      );
      widget.onDone?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick files: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  ConversionSettings _resolveSettings(List<MediaProbeInfo> probes) {
    final hasVideo = probes.any((p) => p.hasVideo);
    return _settings.copyWith(
      videoMute: _settings.videoMute || !hasVideo,
      audioMute: _settings.audioMute || !probes.any((p) => p.hasAudio),
    );
  }

  void _applyPreset(ConverterPreset? preset) {
    setState(() {
      _selectedPreset = preset;
      _updateSettings(preset?.settings ?? const ConversionSettings());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(converterDraftProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _picking ? null : _pickAndEnqueue,
          icon: _picking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.video_library_outlined),
          label: Text(_picking ? 'Scanning files…' : 'Choose media files'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 24),
        Text('Preset', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<ConverterPreset>(
          value: _selectedPreset,
          isExpanded: true,
          hint: const Text('Custom settings'),
          items: _presets
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(
                    '${p.isDefault ? '★ ' : ''}${p.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _applyPreset,
        ),
        const SizedBox(height: 24),
        Text('Output settings', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._buildOutputSettings(context),
        const SizedBox(height: 8),
        ExpansionTile(
          title: const Text('Advanced options'),
          initiallyExpanded: true,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: _buildAdvancedControls(context),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _picking ? null : _pickAndEnqueue,
          icon: const Icon(Icons.autorenew),
          label: const Text('Convert'),
        ),
      ],
    );
  }

  List<Widget> _buildOutputSettings(BuildContext context) {
    final s = _settings;
    return [
      DropdownButtonFormField<ContainerFormat>(
        value: s.format,
        decoration: const InputDecoration(labelText: 'Output format'),
        items: ContainerFormat.values
            .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
            .toList(),
        onChanged: (v) => setState(() {
          _selectedPreset = null;
          _updateSettings(s.copyWith(format: v ?? s.format));
        }),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<OutputLocation>(
        value: s.outputLocation,
        decoration: const InputDecoration(labelText: 'Output location'),
        items: OutputLocation.values
            .map((o) => DropdownMenuItem(value: o, child: Text(_locationLabel(o))))
            .toList(),
        onChanged: (v) => setState(() {
          _selectedPreset = null;
          _updateSettings(s.copyWith(outputLocation: v ?? s.outputLocation));
        }),
      ),
      if (s.outputLocation == OutputLocation.selectedFolder) ...[
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_open),
          title: Text(s.selectedFolderPath ?? 'Choose a folder…'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final dir = await FilePicker.platform.getDirectoryPath();
            if (dir != null) {
              setState(() {
                _updateSettings(s.copyWith(selectedFolderPath: dir));
              });
            }
          },
        ),
      ],
      const SizedBox(height: 12),
      DropdownButtonFormField<DuplicateStrategy>(
        value: s.duplicateStrategy,
        decoration: const InputDecoration(labelText: 'If output exists'),
        items: DuplicateStrategy.values
            .map((d) => DropdownMenuItem(value: d, child: Text(_duplicateLabel(d))))
            .toList(),
        onChanged: (v) => setState(() {
          _selectedPreset = null;
          _updateSettings(s.copyWith(duplicateStrategy: v ?? s.duplicateStrategy));
        }),
      ),
    ];
  }

  List<Widget> _buildAdvancedControls(BuildContext context) {
    final s = _settings;
    final isAudio = s.format.isAudioContainer;
    return [
      DropdownButtonFormField<VideoCodec>(
        value: s.videoCodec,
        decoration: const InputDecoration(labelText: 'Video codec'),
        items: VideoCodec.values
            .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
            .toList(),
        onChanged: isAudio
            ? null
            : (v) => setState(
                  () => _updateSettings(s.copyWith(videoCodec: v ?? s.videoCodec)),
                ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<AudioCodec>(
        value: s.audioCodec,
        decoration: const InputDecoration(labelText: 'Audio codec'),
        items: AudioCodec.values
            .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
            .toList(),
        onChanged: (v) =>
            setState(() => _updateSettings(s.copyWith(audioCodec: v ?? s.audioCodec))),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: s.width?.toString() ?? '',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Width'),
              onChanged: (v) =>
                  setState(() => _updateSettings(s.copyWith(width: int.tryParse(v)))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: s.height?.toString() ?? '',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Height'),
              onChanged: (v) =>
                  setState(() => _updateSettings(s.copyWith(height: int.tryParse(v)))),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<VideoFrameRate>(
        value: s.frameRate,
        decoration: const InputDecoration(labelText: 'Frame rate'),
        items: VideoFrameRate.values
            .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
            .toList(),
        onChanged: isAudio
            ? null
            : (v) => setState(
                  () => _updateSettings(s.copyWith(frameRate: v ?? s.frameRate)),
                ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<VideoProfile>(
        value: s.profile,
        decoration: const InputDecoration(labelText: 'Profile'),
        items: VideoProfile.values
            .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
            .toList(),
        onChanged: isAudio
            ? null
            : (v) => setState(
                  () => _updateSettings(s.copyWith(profile: v ?? s.profile)),
                ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<AudioSampleRate>(
        value: s.audioSampleRate,
        decoration: const InputDecoration(labelText: 'Sample rate'),
        items: AudioSampleRate.values
            .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
            .toList(),
        onChanged: (v) => setState(
          () => _updateSettings(s.copyWith(audioSampleRate: v ?? s.audioSampleRate)),
        ),
      ),
      _sliderField(
        context,
        label: 'Audio quality',
        value: (s.audioQuality ?? kDefaultAudioQuality).toDouble(),
        min: 0,
        max: 9,
        divisions: 9,
        onChanged: (v) =>
            setState(() => _updateSettings(s.copyWith(audioQuality: v.round()))),
      ),
      _sliderField(
        context,
        label: 'Audio volume',
        value: s.volume,
        min: 0.0,
        max: 2.0,
        divisions: 20,
        onChanged: (v) => setState(() => _updateSettings(s.copyWith(volume: v))),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Start playback ready (faststart)'),
        value: s.faststart,
        onChanged: isAudio
            ? null
            : (v) => setState(() => _updateSettings(s.copyWith(faststart: v))),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Keep metadata'),
        value: s.keepMetadata,
        onChanged: (v) => setState(() => _updateSettings(s.copyWith(keepMetadata: v))),
      ),
    ];
  }

  Widget _sliderField(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    final rounded = value == value.roundToDouble() ? value.round() : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $rounded'),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

String _locationLabel(OutputLocation o) {
  switch (o) {
    case OutputLocation.sameFolder:
      return 'Same folder as source';
    case OutputLocation.appFolder:
      return 'App output folder';
    case OutputLocation.selectedFolder:
      return 'Choose folder…';
  }
}

String _duplicateLabel(DuplicateStrategy d) {
  switch (d) {
    case DuplicateStrategy.ask:
      return 'Ask me';
    case DuplicateStrategy.replace:
      return 'Replace existing';
    case DuplicateStrategy.rename:
      return 'Rename new file';
    case DuplicateStrategy.skip:
      return 'Skip';
  }
}

// ─────────────────────────────── Preview ───────────────────────────────

class _PreviewTab extends ConsumerStatefulWidget {
  const _PreviewTab({this.onDone});

  final VoidCallback? onDone;

  @override
  ConsumerState<_PreviewTab> createState() => _PreviewTabState();
}

class _PreviewTabState extends ConsumerState<_PreviewTab> {
  int _selectedIndex = 0;
  bool _picking = false;

  Future<void> _pickFiles() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ConverterConstants.supportedInputs,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final items = <ConverterPreviewItem>[];
      for (final f in result.files) {
        final path = f.path;
        if (path == null) continue;
        final probe = await FFprobeService.instance.probe(path);
        if (probe == null) continue;
        items.add(
          ConverterPreviewItem(path: path, name: f.name, probe: probe),
        );
      }
      if (items.isEmpty) return;

      ref.read(converterPreviewListProvider.notifier).addAll(items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load preview: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _sendToQueue() async {
    final items = ref.read(converterPreviewListProvider);
    if (items.isEmpty) return;

    final settings = ref.read(converterDraftProvider);
    final prefs = ref.read(converterPreferencesProvider);
    final hasVideo = items.any((i) => i.hasVideo);
    final hasAudio = items.any((i) => i.hasAudio);
    final resolved = settings.copyWith(
      videoMute: settings.videoMute || !hasVideo,
      audioMute: settings.audioMute || !hasAudio,
      outputLocation: prefs.outputLocation,
      duplicateStrategy: prefs.duplicateStrategy,
      hardwareMode: settings.hardwareMode,
    );

    await ConversionManager.instance.enqueue(
      sourcePaths: items.map((i) => i.path).toList(),
      sourceNames: items.map((i) => i.name).toList(),
      probes: items.map((i) => i.probe).toList(),
      settings: resolved,
    );
    ref.read(converterPreviewListProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${items.length} file(s) added to the queue.'),
        ),
      );
    }
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(converterPreviewListProvider);
    if (_selectedIndex >= items.length && items.isNotEmpty) {
      _selectedIndex = items.length - 1;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _picking ? null : _pickFiles,
                  icon: _picking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(_picking ? 'Loading…' : 'Add files to preview'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove all',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: items.isEmpty
                    ? null
                    : () => ref
                        .read(converterPreviewListProvider.notifier)
                        .clear(),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const _EmptyState(
                  icon: Icons.visibility_outlined,
                  message: 'Add media files to preview them before converting.',
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ConverterPreviewPlayer(
                          key: ValueKey(items[_selectedIndex].path),
                          path: items[_selectedIndex].path,
                          title: items[_selectedIndex].name,
                          hasVideo: items[_selectedIndex].hasVideo,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final selected = i == _selectedIndex;
                          return ListTile(
                            selected: selected,
                            selectedTileColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.4),
                            leading: Icon(
                              item.hasVideo
                                  ? Icons.movie_outlined
                                  : Icons.audiotrack,
                            ),
                            title: Text(
                              item.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item.hasVideo
                                  ? 'Video'
                                  : item.hasAudio
                                      ? 'Audio'
                                      : 'Media',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Play',
                                  icon: Icon(
                                    selected
                                        ? Icons.volume_up
                                        : Icons.play_arrow,
                                  ),
                                  onPressed: () => setState(
                                    () => _selectedIndex = i,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    ref
                                        .read(
                                          converterPreviewListProvider.notifier,
                                        )
                                        .removeAt(i);
                                    if (_selectedIndex >=
                                        items.length - 1) {
                                      _selectedIndex = (items.length - 2)
                                          .clamp(0, items.length - 1);
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () => setState(() => _selectedIndex = i),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: items.isEmpty ? null : _sendToQueue,
              icon: const Icon(Icons.autorenew),
              label: Text(
                'Send ${items.length} to queue',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Queue ───────────────────────────────

class _QueueTab extends ConsumerWidget {
  const _QueueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs =
        ref.watch(conversionJobsProvider).where((j) => j.status.isActive).toList();
    if (jobs.isEmpty) {
      return const _EmptyState(
        icon: Icons.playlist_play,
        message: 'No conversions running.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: jobs.length,
      itemBuilder: (context, i) => _ActiveJobTile(
        job: jobs[i],
        key: ValueKey(jobs[i].id),
      ),
    );
  }
}

class _ActiveJobTile extends ConsumerStatefulWidget {
  const _ActiveJobTile({super.key, required this.job});

  final ConversionJob job;

  @override
  ConsumerState<_ActiveJobTile> createState() => _ActiveJobTileState();
}

class _ActiveJobTileState extends ConsumerState<_ActiveJobTile> {
  StreamSubscription<ConversionProgress>? _sub;
  double _fraction = 0;
  double _speed = 0;

  @override
  void initState() {
    super.initState();
    _fraction = widget.job.progress / 100.0;
    _sub = ConversionManager.instance.progress
        .where((p) => p.jobId == widget.job.id)
        .listen((p) {
      if (mounted) {
        setState(() {
          _fraction = p.fraction;
          _speed = p.speed;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final colorScheme = Theme.of(context).colorScheme;
    final percent = (_fraction * 100).round().clamp(0, 100);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            job.settings.format.isVideoContainer
                ? Icons.movie_outlined
                : Icons.audiotrack,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(job.sourceName, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            LinearProgressIndicator(value: _fraction),
            const SizedBox(height: 4),
            Text(
              '${job.settings.format.label} · $percent%'
              '${_speed > 0 ? ' · ${_speed.toStringAsFixed(1)}x' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: job.status == ConversionStatus.processing
            ? IconButton(
                tooltip: 'Cancel',
                icon: const Icon(Icons.close),
                onPressed: () => ConversionManager.instance.cancelJob(job.id),
              )
            : const Chip(
                label: Text('Pending'),
                visualDensity: VisualDensity.compact,
              ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => JobDetailsScreen(jobId: job.id)),
        ),
      ),
    );
  }
}

// ─────────────────────────────── History ───────────────────────────────

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab({
    required this.searchController,
    required this.filter,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final _HistoryFilter filter;
  final ValueChanged<_HistoryFilter> onFilterChanged;

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  @override
  Widget build(BuildContext context) {
    final all = ref.watch(conversionJobsProvider);
    final query = widget.searchController.text.trim().toLowerCase();

    Iterable<ConversionJob> jobs = all.where((j) {
      switch (widget.filter) {
        case _HistoryFilter.completed:
          return j.status == ConversionStatus.completed;
        case _HistoryFilter.failed:
          return j.status == ConversionStatus.failed;
        case _HistoryFilter.cancelled:
          return j.status == ConversionStatus.cancelled;
        case _HistoryFilter.interrupted:
          return j.status == ConversionStatus.interrupted;
        case _HistoryFilter.all:
          return j.status.isTerminal;
      }
    });
    if (query.isNotEmpty) {
      jobs = jobs.where((j) => j.sourceName.toLowerCase().contains(query));
    }
    final list = jobs.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: widget.searchController,
            onChanged: (_) => widget.onFilterChanged(widget.filter),
            decoration: const InputDecoration(
              hintText: 'Search by file name…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: _HistoryFilter.values
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filterLabel(f)),
                      selected: widget.filter == f,
                      onSelected: (_) => widget.onFilterChanged(f),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const _EmptyState(
                  icon: Icons.history,
                  message: 'No past conversions yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  itemBuilder: (context, i) => HistoryTile(
                    job: list[i],
                    key: ValueKey(list[i].id),
                  ),
                ),
        ),
      ],
    );
  }
}

String _filterLabel(_HistoryFilter f) {
  switch (f) {
    case _HistoryFilter.completed:
      return 'Completed';
    case _HistoryFilter.failed:
      return 'Failed';
    case _HistoryFilter.cancelled:
      return 'Cancelled';
    case _HistoryFilter.interrupted:
      return 'Interrupted';
    case _HistoryFilter.all:
      return 'All';
  }
}

class HistoryTile extends ConsumerWidget {
  const HistoryTile({super.key, required this.job});

  final ConversionJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final IconData icon;
    final Color color;
    switch (job.status) {
      case ConversionStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
      case ConversionStatus.failed:
        icon = Icons.error;
        color = colorScheme.error;
      case ConversionStatus.cancelled:
        icon = Icons.cancel;
        color = colorScheme.outline;
      case ConversionStatus.interrupted:
        icon = Icons.power_off;
        color = colorScheme.tertiary;
      default:
        icon = Icons.history;
        color = colorScheme.outline;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(job.sourceName, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${job.settings.format.label} · ${job.progress}%'
          '${job.completedAt != null ? ' · ${_fmtTime(job.completedAt!)}' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (context) => [
            if (job.status.isRetryable)
              const PopupMenuItem(value: 'retry', child: Text('Retry')),
            const PopupMenuItem(value: 'reconvert', child: Text('Reconvert')),
            if (job.outputPath != null)
              const PopupMenuItem(value: 'open', child: Text('Open output')),
            if (job.outputPath != null)
              const PopupMenuItem(value: 'delete', child: Text('Delete output')),
            const PopupMenuItem(value: 'details', child: Text('Details')),
            const PopupMenuItem(value: 'remove', child: Text('Remove from list')),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => JobDetailsScreen(jobId: job.id)),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    final manager = ConversionManager.instance;
    switch (action) {
      case 'retry':
        manager.retryJob(job.id);
      case 'reconvert':
        _reconvert(context);
      case 'open':
        if (job.outputPath != null) {
          OpenFilex.open(job.outputPath!);
        }
      case 'delete':
        _deleteOutput(context);
      case 'details':
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => JobDetailsScreen(jobId: job.id),
        );
      case 'remove':
        manager.deleteJobs([job.id]);
    }
  }

  Future<void> _reconvert(BuildContext context) async {
    final probe = await FFprobeService.instance.probe(job.sourcePath);
    if (probe == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source file is no longer available.')),
        );
      }
      return;
    }
    await ConversionManager.instance.enqueue(
      sourcePaths: [job.sourcePath],
      sourceNames: [job.sourceName],
      probes: [probe],
      settings: job.settings,
    );
  }

  Future<void> _deleteOutput(BuildContext context) async {
    final path = job.outputPath;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Output deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete output: $e')),
        );
      }
    }
  }
}

String _fmtTime(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// ─────────────────────────────── Presets ───────────────────────────────

class _PresetsTab extends ConsumerWidget {
  const _PresetsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ConverterPreset>>(
      future: ConverterDatabaseService.instance.getAllPresets(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final presets = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: presets.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: FilledButton.tonalIcon(
                  onPressed: () => _showCreateDialog(ref, context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create preset from current settings'),
                ),
              );
            }
            final preset = presets[i - 1];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: Icon(
                  preset.isSystem ? Icons.auto_awesome : Icons.tune,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text('${preset.isDefault ? '★ ' : ''}${preset.name}'),
                subtitle: Text(
                  '${preset.settings.format.label} · '
                  '${preset.settings.videoCodec.label} / '
                  '${preset.settings.audioCodec.label}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (a) => _handlePresetAction(ref, context, preset, a),
                  itemBuilder: (context) => [
                    if (!preset.isSystem)
                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    if (!preset.isSystem)
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    if (!preset.isDefault)
                      const PopupMenuItem(
                        value: 'default',
                        child: Text('Set as default'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handlePresetAction(
    WidgetRef ref,
    BuildContext context,
    ConverterPreset preset,
    String action,
  ) async {
    final db = ConverterDatabaseService.instance;
    switch (action) {
      case 'rename':
        _showNameDialog(context, preset);
      case 'duplicate':
        final copy = ConverterPreset(
          id: 'user_${DateTime.now().microsecondsSinceEpoch}',
          name: '${preset.name} Copy',
          isSystem: false,
          isDefault: false,
          settings: preset.settings,
          createdAt: DateTime.now(),
        );
        await db.upsertPreset(copy);
      case 'delete':
        if (!preset.isSystem) {
          await db.deletePreset(preset.id);
        }
      case 'default':
        await _setDefault(ref, db, preset);
    }
  }

  Future<void> _setDefault(
    WidgetRef ref,
    ConverterDatabaseService db,
    ConverterPreset preset,
  ) async {
    final all = await db.getAllPresets();
    for (final p in all) {
      if (p.isDefault && p.id != preset.id) {
        await db.upsertPreset(p.copyWith(isDefault: false));
      }
    }
    await db.upsertPreset(preset.copyWith(isDefault: true));
    final prefs = ref.read(converterPreferencesProvider);
    await ref.read(converterPreferencesProvider.notifier).save(
          prefs.copyWith(defaultPresetId: preset.id),
        );
  }

  void _showNameDialog(BuildContext context, ConverterPreset preset) {
    final controller = TextEditingController(text: preset.name);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename preset'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await ConverterDatabaseService.instance.upsertPreset(
                  preset.copyWith(name: name),
                );
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(WidgetRef ref, BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create preset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Preset name'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Presets store the options from the Convert tab. Configure '
                'your desired options there first.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final now = DateTime.now();
              await ConverterDatabaseService.instance.upsertPreset(
                ConverterPreset(
                  id: 'user_${now.microsecondsSinceEpoch}',
                  name: name,
                  isSystem: false,
                  isDefault: false,
                  settings: const ConversionSettings(),
                  createdAt: now,
                ),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Settings ───────────────────────────────

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(converterPreferencesProvider);
    final notifier = ref.read(converterPreferencesProvider.notifier);
    return FutureBuilder<List<ConverterPreset>>(
      future: ConverterDatabaseService.instance.getAllPresets(),
      builder: (context, snapshot) {
        final presets = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: prefs.defaultPresetId ?? '',
              decoration: const InputDecoration(labelText: 'Default preset'),
              items: [
                const DropdownMenuItem(value: '', child: Text('None (system default)')),
                ...presets.map(
                  (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                ),
              ],
              onChanged: (v) => notifier
                  .update((c) => c.copyWith(defaultPresetId: (v ?? '').isEmpty ? null : v)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<OutputLocation>(
              value: prefs.outputLocation,
              decoration: const InputDecoration(
                labelText: 'Default output location',
              ),
              items: OutputLocation.values
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(_locationLabel(o)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => notifier
                  .update((c) => c.copyWith(outputLocation: v ?? c.outputLocation)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DuplicateStrategy>(
              value: prefs.duplicateStrategy,
              decoration: const InputDecoration(labelText: 'If output exists'),
              items: DuplicateStrategy.values
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text(_duplicateLabel(d)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => notifier.update(
                (c) => c.copyWith(duplicateStrategy: v ?? c.duplicateStrategy),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<HardwareMode>(
              value: prefs.hardwareMode,
              decoration: const InputDecoration(labelText: 'Hardware acceleration'),
              items: HardwareMode.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(_hwLabel(m)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => notifier
                  .update((c) => c.copyWith(hardwareMode: v ?? c.hardwareMode)),
            ),
            const SizedBox(height: 16),
            Text('Concurrent conversions: ${prefs.maxSimultaneous}'),
            Slider(
              value: prefs.maxSimultaneous.toDouble(),
              min: 1,
              max: 3,
              divisions: 2,
              label: '${prefs.maxSimultaneous}',
              onChanged: (v) => notifier
                  .update((c) => c.copyWith(maxSimultaneous: v.round())),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep history'),
              value: prefs.keepHistory,
              onChanged: (v) => notifier.update((c) => c.copyWith(keepHistory: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Open output when done'),
              value: prefs.autoOpenOutput,
              onChanged: (v) => notifier.update((c) => c.copyWith(autoOpenOutput: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Progress notifications'),
              value: prefs.notificationsEnabled,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(notificationsEnabled: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Background conversion'),
              subtitle: const Text('Keeps running when the app is closed'),
              value: prefs.backgroundConversion,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(backgroundConversion: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep screen awake'),
              value: prefs.keepAwake,
              onChanged: (v) => notifier.update((c) => c.copyWith(keepAwake: v)),
            ),
          ],
        );
      },
    );
  }
}

String _hwLabel(HardwareMode m) {
  switch (m) {
    case HardwareMode.auto:
      return 'Auto';
    case HardwareMode.cpu:
      return 'CPU only';
    case HardwareMode.hardware:
      return 'Hardware acceleration';
  }
}

// ─────────────────────────────── Details ───────────────────────────────

class JobDetailsScreen extends ConsumerWidget {
  const JobDetailsScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(conversionJobsProvider);
    ConversionJob? job;
    for (final j in jobs) {
      if (j.id == jobId) {
        job = j;
        break;
      }
    }
    if (job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job details')),
        body: const Center(child: Text('Job not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _detailRow('Source', job.sourceName),
          if (job.outputPath != null) _detailRow('Output', job.outputPath!),
          _detailRow('Status', _statusName(job.status)),
          _detailRow('Format', job.settings.format.label),
          _detailRow('Progress', '${job.progress}%'),
          if (job.durationMs != null)
            _detailRow('Duration', '${(job.durationMs! / 1000).toStringAsFixed(1)} s'),
          if (job.outputSize != null) _detailRow('Output size', _bytes(job.outputSize!)),
          if (job.completedAt != null)
            _detailRow('Completed', job.completedAt!.toIso8601String()),
          if (job.errorMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  job.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
          if (job.ffmpegLog != null) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Technical details'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    job.ffmpegLog!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

String _statusName(ConversionStatus s) {
  switch (s) {
    case ConversionStatus.pending:
      return 'Pending';
    case ConversionStatus.queued:
      return 'Queued';
    case ConversionStatus.processing:
      return 'Processing';
    case ConversionStatus.completed:
      return 'Completed';
    case ConversionStatus.failed:
      return 'Failed';
    case ConversionStatus.cancelled:
      return 'Cancelled';
    case ConversionStatus.interrupted:
      return 'Interrupted';
  }
}

String _bytes(int b) {
  if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '$b B';
}

// ─────────────────────────────── Shared ───────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}