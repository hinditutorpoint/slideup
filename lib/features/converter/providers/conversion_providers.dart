import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversion_job.dart';
import '../models/converter_preferences.dart';
import '../services/conversion_manager.dart';
import '../services/converter_settings_service.dart';

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