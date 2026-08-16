import 'dart:convert';

import 'conversion_models.dart';
import 'conversion_settings.dart';

/// A persistent conversion job persisted in the app database.
class ConversionJob {
  ConversionJob({
    required this.id,
    required this.sourcePath,
    required this.sourceName,
    this.presetName,
    this.outputPath,
    required this.settings,
    required this.status,
    this.progress = 0,
    this.durationMs,
    this.errorMessage,
    this.ffmpegLog,
    this.notificationId = 0,
    required this.queuedAt,
    this.startedAt,
    this.completedAt,
    this.outputSize,
  });

  final String id;
  final String sourcePath;
  final String sourceName;
  String? presetName;
  String? outputPath;
  ConversionSettings settings;
  ConversionStatus status;
  int progress;
  int? durationMs;
  String? errorMessage;

  /// Bounded FFmpeg log (last N characters) for "View Technical Details".
  String? ffmpegLog;
  int notificationId;
  final DateTime queuedAt;
  DateTime? startedAt;
  DateTime? completedAt;
  int? outputSize;

  bool get isActive => status.isActive;

  ConversionJob copyWith({
    String? presetName,
    String? outputPath,
    ConversionStatus? status,
    int? progress,
    int? durationMs,
    String? errorMessage,
    String? ffmpegLog,
    DateTime? startedAt,
    DateTime? completedAt,
    int? outputSize,
  }) {
    return ConversionJob(
      id: id,
      sourcePath: sourcePath,
      sourceName: sourceName,
      presetName: presetName ?? this.presetName,
      outputPath: outputPath ?? this.outputPath,
      settings: settings,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      durationMs: durationMs ?? this.durationMs,
      errorMessage: errorMessage ?? this.errorMessage,
      ffmpegLog: ffmpegLog ?? this.ffmpegLog,
      notificationId: notificationId,
      queuedAt: queuedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      outputSize: outputSize ?? this.outputSize,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourcePath': sourcePath,
      'sourceName': sourceName,
      'presetName': presetName,
      'outputPath': outputPath,
      'settingsJson': jsonEncode(settings.toJson()),
      'status': status.index,
      'progress': progress,
      'durationMs': durationMs,
      'errorMessage': errorMessage,
      'ffmpegLog': ffmpegLog,
      'notificationId': notificationId,
      'queuedAt': queuedAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'outputSize': outputSize,
    };
  }

  factory ConversionJob.fromJson(Map<String, dynamic> json) {
    final settingsJson = json['settingsJson'];
    final settings = settingsJson is String
        ? _decodeSettings(settingsJson)
        : (settingsJson is Map
              ? ConversionSettings.fromJson(Map<String, dynamic>.from(settingsJson))
              : const ConversionSettings());
    final statusIndex = json['status'] as int?;
    return ConversionJob(
      id: json['id'] as String,
      sourcePath: json['sourcePath'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? '',
      presetName: json['presetName'] as String?,
      outputPath: json['outputPath'] as String?,
      settings: settings,
      status: statusIndex != null && statusIndex >= 0 && statusIndex < ConversionStatus.values.length
          ? ConversionStatus.values[statusIndex]
          : ConversionStatus.pending,
      progress: json['progress'] as int? ?? 0,
      durationMs: json['durationMs'] as int?,
      errorMessage: json['errorMessage'] as String?,
      ffmpegLog: json['ffmpegLog'] as String?,
      notificationId: json['notificationId'] as int? ?? 0,
      queuedAt: DateTime.tryParse(json['queuedAt'] as String? ?? '') ?? DateTime.now(),
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'] as String) : null,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
      outputSize: json['outputSize'] as int?,
    );
  }

  static ConversionSettings _decodeSettings(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return ConversionSettings.fromJson(decoded);
      if (decoded is Map) return ConversionSettings.fromJson(Map<String, dynamic>.from(decoded));
      return const ConversionSettings();
    } catch (_) {
      return const ConversionSettings();
    }
  }
}