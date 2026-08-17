import 'conversion_models.dart';

/// User-level converter preferences, persisted in Hive `settingsBox`.
class ConverterPreferences {
  const ConverterPreferences({
    this.defaultPresetId,
    this.outputLocation = OutputLocation.appFolder,
    this.selectedFolderPath,
    this.maxSimultaneous = 1,
    this.duplicateStrategy = DuplicateStrategy.rename,
    this.keepHistory = true,
    this.autoOpenOutput = false,
    this.notificationsEnabled = true,
    this.backgroundConversion = true,
    this.hardwareMode = HardwareMode.auto,
    this.keepAwake = false,
  });

  final String? defaultPresetId;
  final OutputLocation outputLocation;
  final String? selectedFolderPath;
  final int maxSimultaneous;
  final DuplicateStrategy duplicateStrategy;
  final bool keepHistory;
  final bool autoOpenOutput;
  final bool notificationsEnabled;
  final bool backgroundConversion;
  final HardwareMode hardwareMode;

  /// Prevent the screen from sleeping while converting (default off to
  /// conserve battery).
  final bool keepAwake;

  ConverterPreferences copyWith({
    String? defaultPresetId,
    bool clearDefaultPreset = false,
    OutputLocation? outputLocation,
    String? selectedFolderPath,
    int? maxSimultaneous,
    DuplicateStrategy? duplicateStrategy,
    bool? keepHistory,
    bool? autoOpenOutput,
    bool? notificationsEnabled,
    bool? backgroundConversion,
    HardwareMode? hardwareMode,
    bool? keepAwake,
  }) {
    return ConverterPreferences(
      defaultPresetId: clearDefaultPreset ? null : (defaultPresetId ?? this.defaultPresetId),
      outputLocation: outputLocation ?? this.outputLocation,
      selectedFolderPath:
          selectedFolderPath ?? this.selectedFolderPath,
      maxSimultaneous: maxSimultaneous ?? this.maxSimultaneous,
      duplicateStrategy: duplicateStrategy ?? this.duplicateStrategy,
      keepHistory: keepHistory ?? this.keepHistory,
      autoOpenOutput: autoOpenOutput ?? this.autoOpenOutput,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      backgroundConversion: backgroundConversion ?? this.backgroundConversion,
      hardwareMode: hardwareMode ?? this.hardwareMode,
      keepAwake: keepAwake ?? this.keepAwake,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultPresetId': defaultPresetId,
      'outputLocation': outputLocation.index,
      'selectedFolderPath': selectedFolderPath,
      'maxSimultaneous': maxSimultaneous,
      'duplicateStrategy': duplicateStrategy.index,
      'keepHistory': keepHistory,
      'autoOpenOutput': autoOpenOutput,
      'notificationsEnabled': notificationsEnabled,
      'backgroundConversion': backgroundConversion,
      'hardwareMode': hardwareMode.index,
      'keepAwake': keepAwake,
    };
  }

  factory ConverterPreferences.fromJson(Map<String, dynamic> json) {
    return ConverterPreferences(
      defaultPresetId: json['defaultPresetId'] as String?,
      outputLocation: OutputLocation.values.elementAtOrNull(json['outputLocation'] as int?) ?? OutputLocation.appFolder,
      selectedFolderPath: json['selectedFolderPath'] as String?,
      maxSimultaneous: json['maxSimultaneous'] as int? ?? 1,
      duplicateStrategy: DuplicateStrategy.values.elementAtOrNull(json['duplicateStrategy'] as int?) ?? DuplicateStrategy.rename,
      keepHistory: json['keepHistory'] as bool? ?? true,
      autoOpenOutput: json['autoOpenOutput'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      backgroundConversion: json['backgroundConversion'] as bool? ?? true,
      hardwareMode: HardwareMode.values.elementAtOrNull(json['hardwareMode'] as int?) ?? HardwareMode.auto,
      keepAwake: json['keepAwake'] as bool? ?? false,
    );
  }
}