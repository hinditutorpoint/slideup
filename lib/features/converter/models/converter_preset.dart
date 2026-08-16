import 'dart:convert';

import 'conversion_settings.dart';

/// A named, reusable set of conversion settings.
///
/// System presets are seeded in code and read-only; custom presets are
/// created/edited/duplicated/renamed/deleted by the user and persisted.
class ConverterPreset {
  ConverterPreset({
    required this.id,
    required this.name,
    required this.isSystem,
    this.isDefault = false,
    required this.settings,
    required this.createdAt,
    this.updatedAt,
    this.description,
  });

  final String id;
  String name;
  final bool isSystem;
  bool isDefault;
  ConversionSettings settings;
  final DateTime createdAt;
  DateTime? updatedAt;
  String? description;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isSystem': isSystem,
      'isDefault': isDefault,
      'settingsJson': jsonEncode(settings.toJson()),
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': (updatedAt ?? createdAt).toIso8601String(),
    };
  }

  factory ConverterPreset.fromJson(Map<String, dynamic> json) {
    final settingsRaw = json['settingsJson'];
    ConversionSettings settings = const ConversionSettings();
    if (settingsRaw is String) {
      try {
        final decoded = jsonDecode(settingsRaw);
        if (decoded is Map) {
          settings = ConversionSettings.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    } else if (settingsRaw is Map) {
      settings = ConversionSettings.fromJson(Map<String, dynamic>.from(settingsRaw));
    }
    return ConverterPreset(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Preset',
      isSystem: json['isSystem'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
      settings: settings,
      description: json['description'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  ConverterPreset copyWith({
    String? name,
    bool? isDefault,
    ConversionSettings? settings,
    String? description,
    DateTime? updatedAt,
  }) {
    return ConverterPreset(
      id: id,
      name: name ?? this.name,
      isSystem: isSystem,
      isDefault: isDefault ?? this.isDefault,
      settings: settings ?? this.settings,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}