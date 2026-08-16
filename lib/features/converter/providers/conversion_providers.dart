import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversion_job.dart';
import '../models/conversion_settings.dart';
import '../models/converter_preferences.dart';
import '../services/conversion_manager.dart';
import '../services/converter_settings_service.dart';
import '../services/ffmpeg_probe_service.dart';

/// Live snapshot of the converter queue + history.
///
/// The notifier starts from whatever the manager already holds and refreshes
/// whenever the manager broadcasts a change.
class ConversionJobsNotifier extends Notifier<List<ConversionJob>> {
  @override
  List<ConversionJob> build() {
    ConversionManager.instance.changes.listen((_) => refresh());
    return ConversionManager.instance.jobs;
  }

  bool get mounted => true;

  void refresh() {
    if (mounted) state = ConversionManager.instance.jobs;
  }
}

final conversionJobsProvider =
    NotifierProvider<ConversionJobsNotifier, List<ConversionJob>>(
      () => ConversionJobsNotifier(),
    );

/// Number of currently processing conversions (feeds the global indicator).
class ActiveConverterCountNotifier extends Notifier<int> {
  @override
  int build() {
    return ConversionManager.instance.activeCount;
  }

  bool get mounted => true;

  void refresh() {
    if (mounted) state = ConversionManager.instance.activeCount;
  }
}

final activeConverterCountProvider =
    NotifierProvider<ActiveConverterCountNotifier, int>(
      () => ActiveConverterCountNotifier(),
    );

/// User preferences for the converter feature, backed by Hive.
class ConverterPreferencesNotifier extends Notifier<ConverterPreferences> {
  @override
  ConverterPreferences build() {
    return ConverterSettingsService.instance.preferences;
  }

  Future<void> save(ConverterPreferences prefs) async {
    state = prefs;
    await ConverterSettingsService.instance.save(prefs);
  }

  bool get mounted => true;

  Future<void> update(
    ConverterPreferences Function(ConverterPreferences current) change,
  ) async {
    final prefs = await ConverterSettingsService.instance.update(change);
    if (mounted) state = prefs;
  }
}

final converterPreferencesProvider =
    NotifierProvider<ConverterPreferencesNotifier, ConverterPreferences>(
      () => ConverterPreferencesNotifier(),
    );

/// Draft conversion options shared between the Convert and Preview tabs.
class ConverterDraftNotifier extends Notifier<ConversionSettings> {
  @override
  ConversionSettings build() => const ConversionSettings();

  void apply(ConversionSettings settings) => state = settings;
}

final converterDraftProvider =
    NotifierProvider<ConverterDraftNotifier, ConversionSettings>(
      () => ConverterDraftNotifier(),
    );

/// A single source file loaded into the Preview tab for inspection before
/// sending it to the conversion queue.
class ConverterPreviewItem {
  const ConverterPreviewItem({
    required this.path,
    required this.name,
    required this.probe,
  });

  final String path;
  final String name;
  final MediaProbeInfo probe;

  bool get hasVideo => probe.hasVideo;
  bool get hasAudio => probe.hasAudio;
}

/// Selection of files picked for preview. Kept in state so the Preview tab
/// can show a player on top and a playable list below.
class ConverterPreviewListNotifier extends Notifier<List<ConverterPreviewItem>> {
  @override
  List<ConverterPreviewItem> build() => const [];

  void add(ConverterPreviewItem item) => state = [...state, item];

  void addAll(List<ConverterPreviewItem> items) => state = [...state, ...items];

  void removeAt(int index) {
    final next = [...state]..removeAt(index);
    state = next;
  }

  void clear() => state = const [];

  void removeWhere(bool Function(ConverterPreviewItem) test) {
    state = state.where((e) => !test(e)).toList();
  }
}

final converterPreviewListProvider =
    NotifierProvider<ConverterPreviewListNotifier, List<ConverterPreviewItem>>(
      () => ConverterPreviewListNotifier(),
    );