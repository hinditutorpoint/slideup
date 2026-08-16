import 'dart:async';
import 'dart:io';

import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics_callback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../services/notification_service.dart';
import '../../../services/permission_service.dart';
import '../models/conversion_job.dart';
import '../models/conversion_models.dart';
import '../models/conversion_settings.dart';
import '../models/converter_preset.dart';
import 'converter_background_worker.dart';
import 'converter_constants.dart';
import 'converter_database_service.dart';
import 'converter_notifications.dart';
import 'converter_settings_service.dart';
import 'ffmpeg_command_builder.dart';
import 'ffmpeg_probe_service.dart';
import 'format_compatibility.dart';
import 'output_naming.dart';

/// The UI-independent conversion engine.
///
/// Owns the persistent queue and runs conversions on the main isolate using
/// asynchronous FFmpeg sessions with per-session statistics/log callbacks.
/// Progress shown to the user always comes from real FFmpeg statistics —
/// this class never fabricates percentages.
class ConversionManager {
  ConversionManager._() {
    FlutterForegroundTask.addTaskDataCallback(_onForegroundAction);
    NotificationService.registerConversionActionListener(_onNotificationAction);
  }

  static final ConversionManager instance = ConversionManager._();

  final ConverterDatabaseService _db = ConverterDatabaseService.instance;
  final ConverterSettingsService _settings = ConverterSettingsService.instance;
  final ConverterNotificationService _notifier =
      ConverterNotificationService.instance;

  List<ConversionJob> _jobs = [];
  final Map<String, FFmpegSession> _sessions = {};

  final StreamController<void> _changes = StreamController<void>.broadcast();
  final StreamController<ConversionProgress> _progress =
      StreamController<ConversionProgress>.broadcast();

  bool _initialized = false;
  final Uuid _uuid = const Uuid();
  int _nextNotificationId = 6000;
  String? _appOutputDir;
  final Set<String> _pausedIds = {};

  // ─────────────────────────── Public state ───────────────────────────

  List<ConversionJob> get jobs => List.unmodifiable(_jobs);

  Stream<void> get changes => _changes.stream;

  Stream<ConversionProgress> get progress => _progress.stream;

  int get activeCount =>
      _jobs.where((j) => j.status == ConversionStatus.processing).length;

  Future<void> initializeAndRecover() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _jobs = await _db.getAllJobs();
      await _ensureSystemPresets();
      await _recoverInterrupted();
      await _cleanupOrphanTemp();
      _nextNotificationId = 6000 + _jobs.length;
      _notify();
    } catch (e) {
      debugPrint('⚠️ Converter init error: $e');
    }
  }

  Future<void> _ensureSystemPresets() async {
    final presets = await _db.getAllPresets();
    if (presets.any((p2) => p2.isSystem)) return;
    for (final preset in ConverterConstants.createSystemPresets()) {
      await _db.upsertPreset(preset);
    }
  }

  /// Jobs left "processing" by a killed process must never be stuck: they
  /// become [ConversionStatus.interrupted] and the user gets a retry.
  Future<void> _recoverInterrupted() async {
    final dirty = _jobs.where((job) => job.status.isActive).toList();
    for (final job in dirty) {
      job.status = ConversionStatus.interrupted;
      job.errorMessage =
          'Interrupted — the app or system closed during conversion. '
          'You can retry.';
      await _db.upsertJob(job);
      _notifier.dismiss(job);
    }
  }

  Future<void> _cleanupOrphanTemp() async {
    try {
      final dir = await _tempDir();
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        try {
          if (entity is File) await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ─────────────────────────────── Queue ──────────────────────────────

  Future<List<ConversionJob>> enqueue({
    required List<String> sourcePaths,
    required List<String> sourceNames,
    required List<MediaProbeInfo> probes,
    required ConversionSettings settings,
    String? presetName,
  }) async {
    final created = <ConversionJob>[];
    for (var i = 0; i < sourcePaths.length; i++) {
      final probe = i < probes.length ? probes[i] : null;
      if (probe == null) continue;

      final job = ConversionJob(
        id: _uuid.v4().replaceAll('-', ''),
        sourcePath: sourcePaths[i],
        sourceName: sourceNames[i],
        presetName: presetName,
        settings: settings,
        status: ConversionStatus.queued,
        notificationId: _nextNotificationId++,
        queuedAt: DateTime.now(),
      );
      _jobs.insert(0, job);
      await _db.upsertJob(job);
      created.add(job);
      _notify();
    }
    return created;
  }

  Future<void> retryJob(String id) async {
    final job = _jobs.firstWhereOrNull((j) => j.id == id);
    if (job == null || job.status.isActive) return;

    final fresh = ConversionJob(
      id: _uuid.v4().replaceAll('-', ''),
      sourcePath: job.sourcePath,
      sourceName: job.sourceName,
      settings: job.settings,
      status: ConversionStatus.queued,
      notificationId: _nextNotificationId++,
      queuedAt: DateTime.now(),
    );
    _jobs.insert(0, fresh);
    await _db.upsertJob(fresh);
    _notify();
  }

  /// Manually starts a queued/pending job (respecting max simultaneous).
  Future<void> startJob(String id) async {
    final job = _jobs.firstWhereOrNull((j) => j.id == id);
    if (job == null) return;
    if (job.status != ConversionStatus.queued &&
        job.status != ConversionStatus.pending) {
      return;
    }
    final prefs = _settings.preferences;
    final maxConcurrent = prefs.maxSimultaneous <= 0
        ? ConverterConstants.defaultMaxSimultaneous
        : prefs.maxSimultaneous;
    final running = _jobs
        .where((j) => j.status == ConversionStatus.processing)
        .length;
    if (running >= maxConcurrent) return;
    unawaited(_startJob(job));
  }

  /// Applies a preset (its settings + name) to a specific queued/pending job.
  Future<void> applyPresetToJob(String id, ConverterPreset preset) async {
    final job = _jobs.firstWhereOrNull((j) => j.id == id);
    if (job == null) return;
    if (job.status != ConversionStatus.queued &&
        job.status != ConversionStatus.pending) {
      return;
    }
    job.settings = preset.settings;
    job.presetName = preset.name;
    await _db.updateJob(job);
    _notify();
  }

  /// Stops the running FFmpeg process and returns the job to the queue so it
  /// can be started again later (pause = real stop + requeue; no fake state).
  Future<void> pauseJob(String id) async {
    final job = _jobs.firstWhereOrNull((j) => j.id == id);
    if (job == null || job.status != ConversionStatus.processing) return;
    final session = _sessions[id];
    if (session == null) return;
    _pausedIds.add(id);
    job.progress = 0;
    await _db.updateJob(job);
    await FFmpegKit.cancel(session.getSessionId());
  }

  Future<void> cancelJob(String id) async {
    final job = _jobs.firstWhereOrNull((j) => j.id == id);
    if (job == null) return;

    if (job.status == ConversionStatus.processing) {
      // Actually stop FFmpeg — the session complete callback settles state.
      final session = _sessions[id];
      if (session != null) {
        await FFmpegKit.cancel(session.getSessionId());
        return;
      }
      job.status = ConversionStatus.cancelled;
      job.errorMessage = 'Cancelled';
    } else if (job.status == ConversionStatus.queued ||
        job.status == ConversionStatus.pending) {
      job.status = ConversionStatus.cancelled;
      job.errorMessage = 'Cancelled before start';
    } else {
      return;
    }
    job.completedAt = DateTime.now();
    await _db.upsertJob(job);
    await _notifier.dismiss(job);
    _notify();
  }

  Future<void> deleteJobs(List<String> ids) async {
    final set = ids.toSet();
    _jobs.removeWhere((j) => set.contains(j.id));
    await _db.deleteJobs(ids);
    _notify();
  }

  Future<void> clearHistory() async {
    final keep = _jobs.where((j) => j.status.isActive).toList();
    _jobs = keep;
    await _db.clearJobs();
    for (final job in keep) {
      await _db.upsertJob(job);
    }
    _notify();
  }

  // ────────────────────────────── Worker ──────────────────────────────

  Future<void> _startJob(ConversionJob job) async {
    job.status = ConversionStatus.processing;
    job.startedAt = DateTime.now();
    await _db.upsertJob(job);
    _notify();

    final prefs = _settings.preferences;
    if (prefs.keepAwake && !kIsWeb) await WakelockPlus.enable();
    if (prefs.backgroundConversion) {
      await _notifier.startForeground(job: job, fraction: 0);
    }

    try {
      final probe = await FFprobeService.instance.probe(job.sourcePath);
      if (probe == null) {
        await _fail(job, _friendlyError('Could not read the source file.'));
        return;
      }
      job.durationMs = probe.durationMs;
      await _db.updateJob(job);

      final outPath = await _resolveOutputPath(job);
      if (outPath == null) return; // marked skipped/terminal
      job.outputPath = outPath;
      await _db.updateJob(job);

      if (!await _checkDiskSpace(job)) return;

      final problems = FormatCompatibility.validate(job.settings);
      if (problems.isNotEmpty) {
        await _fail(job, problems.join('\n'));
        return;
      }

      final args = FFmpegCommandBuilder.instance.build(
        sourcePath: job.sourcePath,
        outputPath: outPath,
        probe: probe,
        settings: job.settings,
      );

      final session = await FFmpegKit.executeWithArgumentsAsync(
        args,
        (completed) async {
          await _onSessionComplete(job, completed, outPath);
        },
        (log) {
          _onSessionLog(job, log);
        },
        _onSessionStats(job, probe.durationMs),
      );
      _sessions[job.id] = session;
      if (job.status != ConversionStatus.processing) {
        await FFmpegKit.cancel(session.getSessionId());
      }
    } catch (e) {
      await _fail(job, 'Unexpected error: $e');
    }
  }

  void _onSessionLog(ConversionJob job, Log log) {
    try {
      final message = log.getMessage();
      if (message.isEmpty) return;
      final combined = '${job.ffmpegLog ?? ''}$message';
      if (combined.length > ConverterConstants.maxLogLength) {
        job.ffmpegLog = combined.substring(combined.length - ConverterConstants.maxLogLength);
      } else {
        job.ffmpegLog = combined;
      }
    } catch (_) {}
  }

  StatisticsCallback _onSessionStats(ConversionJob job, int? durationMs) {
    return (stats) {
      final timeMs = stats.getTime();
      final speed = stats.getSpeed();
      double fraction = 0;
      if (durationMs != null && durationMs > 0) {
        fraction = (timeMs / durationMs).clamp(0.0, 1.0);
      }
      final percent = (fraction * 100).round();
      if (percent != job.progress) {
        job.progress = percent;
        _progress.add(
          ConversionProgress(
            jobId: job.id,
            fraction: fraction,
            timeMs: timeMs,
            speed: speed,
            sizeBytes: stats.getSize(),
          ),
        );
        _notify();
      }
      if (job.status == ConversionStatus.processing) {
        unawaited(_updateNotification(job, fraction));
      }
    };
  }

  Future<void> _updateNotification(ConversionJob job, double fraction) async {
    final prefs = _settings.preferences;
    if (!prefs.notificationsEnabled) return;
    try {
      if (prefs.backgroundConversion) {
        await _notifier.updateForeground(job: job, fraction: fraction);
      } else {
        await _notifier.showProgress(job: job, fraction: fraction);
      }
      await _db.updateJob(job); // throttled enough by percent gate
    } catch (_) {}
  }

  Future<void> _onSessionComplete(
    ConversionJob job,
    FFmpegSession session,
    String outPath,
  ) async {
    _sessions.remove(job.id);
    final rc = await session.getReturnCode();
    final prefs = _settings.preferences;

    if (ReturnCode.isSuccess(rc)) {
      final file = File(outPath);
      job.outputSize = file.existsSync() ? file.lengthSync() : null;
      job.status = ConversionStatus.completed;
      job.completedAt = DateTime.now();
      await _db.updateJob(job);
      await _notifier.dismiss(job);
      if (prefs.notificationsEnabled) {
        await _notifier.showResult(job: job, success: true);
      }
      if (prefs.autoOpenOutput && file.existsSync()) {
        unawaited(_openOutput(outPath));
      }
      await _afterJobEnds(job);
    } else if (ReturnCode.isCancel(rc)) {
      if (_pausedIds.remove(job.id)) {
        // Paused: return to queue, ready to be started again.
        await _cleanupPartial(outPath);
        job.status = ConversionStatus.queued;
        job.errorMessage = 'Paused — press Start to resume.';
        await _db.updateJob(job);
        await _notifier.dismiss(job);
        _notify();
        await _afterJobEnds(job);
        return;
      }
      await _cleanupPartial(outPath);
      job.status = ConversionStatus.cancelled;
      job.errorMessage = 'Cancelled';
      job.completedAt = DateTime.now();
      await _db.updateJob(job);
      await _notifier.dismiss(job);
      await _afterJobEnds(job);
    } else {
      final output = await session.getOutput();
      final details =
          (job.ffmpegLog?.trim().isNotEmpty ?? false)
              ? job.ffmpegLog!
              : (output != null && output.trim().isNotEmpty
                    ? output
                    : 'Unknown FFmpeg error (code ${rc?.getValue()})');
      await _cleanupPartial(outPath);
      await _fail(job, _friendlyError(details));
    }
  }

  Future<void> _fail(ConversionJob job, String message) async {
    job.status = ConversionStatus.failed;
    job.errorMessage = message;
    job.completedAt = DateTime.now();
    await _db.updateJob(job);
    final prefs = _settings.preferences;
    if (prefs.notificationsEnabled) {
      await _notifier.showResult(job: job, success: false);
    } else {
      await _notifier.dismiss(job);
    }
    await _afterJobEnds(job);
  }

  Future<void> _afterJobEnds(ConversionJob job) async {
    _notify();
    if (!_jobs.any((j) => j.status == ConversionStatus.processing)) {
      if (!kIsWeb) await WakelockPlus.disable();
      await _notifier.stopForeground();
    }
  }

  static String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('no such file') || lower.contains('cannot open')) {
      return 'The source file could not be opened. It may have moved or is '
          'no longer readable.';
    }
    if (lower.contains('not recognized') || lower.contains('unknown format')) {
      return 'The source format is not recognized by FFmpeg.';
    }
    if (lower.contains('out of memory') || lower.contains('cannot allocate')) {
      return 'Not enough memory was available. Close other apps or lower the '
          'output resolution.';
    }
    if (lower.contains('invalid data')) {
      return 'The source file appears corrupt or truncated.';
    }
    if (lower.contains('permission denied')) {
      return 'Permission denied writing the output. Try choosing the app '
          'output folder.';
    }
    if (lower.contains('already exists')) {
      return 'The output file already exists and could not be overwritten.';
    }
    if (raw.length > 300) return '${raw.substring(0, 300)}…';
    return raw;
  }

  // ─────────────────────────── Output handling ──────────────────────────

  /// Returns the final output path, or `null` when the job was already
  /// settled by duplicate handling (e.g. "skip").
  Future<String?> _resolveOutputPath(ConversionJob job) async {
    final settings = job.settings;
    final fileName = OutputNaming.outputFileName(
      job.sourceName,
      settings.format,
    );

    String dir;
    switch (settings.outputLocation) {
      case OutputLocation.sameFolder:
        dir = p.dirname(job.sourcePath);
        if (!await _ensureWritableDir(dir)) dir = await _appFolder();
      case OutputLocation.appFolder:
        dir = await _appFolder();
      case OutputLocation.selectedFolder:
        final selected = settings.selectedFolderPath;
        if (selected != null && await _ensureWritableDir(selected)) {
          dir = selected;
        } else {
          dir = await _appFolder();
        }
    }

    if (!await _ensureWritableDir(dir)) {
      // Last resort: app-private documents directory (always writable).
      dir =
          '${(await getApplicationDocumentsDirectory()).path}'
          '${Platform.pathSeparator}SlideUpConvert';
      await _ensureWritableDir(dir);
    }

    var finalPath = '$dir${Platform.pathSeparator}$fileName';

    // Never silently overwrite the source file itself.
    if (OutputNaming.wouldOverwriteSource(job.sourcePath, finalPath)) {
      return OutputNaming.uniqueFilePath(dir, fileName);
    }

    switch (settings.duplicateStrategy) {
      case DuplicateStrategy.replace:
        break; // -y overwrites
      case DuplicateStrategy.rename:
        finalPath = OutputNaming.uniqueFilePath(dir, fileName);
      case DuplicateStrategy.ask:
        finalPath = OutputNaming.uniqueFilePath(dir, fileName);
      case DuplicateStrategy.skip:
        if (File(finalPath).existsSync()) {
          job.status = ConversionStatus.cancelled;
          job.errorMessage = 'Skipped — output already exists';
          job.completedAt = DateTime.now();
          await _db.updateJob(job);
          await _notifier.dismiss(job);
          await _afterJobEnds(job);
          return null;
        }
    }
    return finalPath;
  }

  Future<bool> _checkDiskSpace(ConversionJob job) async {
    try {
      final free = (await DiskSpacePlus().getFreeDiskSpace ?? 0).round();
      final sourceSize = await File(job.sourcePath).length();
      final estimate =
          (sourceSize * ConverterConstants.outputSizeEstimateFactor).ceil();
      if (free > 0 && estimate > free) {
        await _fail(
          job,
          'Not enough free disk space. Need ~${_humanBytes(estimate)} but '
          'only ${_humanBytes(free)} is available.',
        );
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Creates the directory (if needed) and verifies it is actually writable.
/// Returns `false` (without throwing) when the path is read-only — e.g.
/// some removable SD cards — so callers can fall back to the app folder.
Future<bool> _ensureWritableDir(String dir) async {
  try {
    final directory = Directory(dir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return await PermissionService.instance.isPathWritable(dir);
  } catch (e) {
    debugPrint('⚠️ Output dir not writable ($dir): $e');
    return false;
  }
}

  Future<String> _appFolder() async {
    if (_appOutputDir != null) return _appOutputDir!;
    final base = await getExternalStorageDirectory();
    final dir = base != null
        ? '$base${Platform.pathSeparator}SlideUpConvert'
        : '${(await getApplicationDocumentsDirectory()).path}'
              '${Platform.pathSeparator}SlideUpConvert';
    _appOutputDir = dir;
    return dir;
  }

  Future<Directory> _tempDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}${Platform.pathSeparator}converter_tmp');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _cleanupPartial(String outPath) async {
    try {
      final f = File(outPath);
      if (await f.exists() && await f.length() == 0) {
        await f.delete();
      }
    } catch (_) {}
  }

  static String _humanBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  Future<void> _openOutput(String path) async {
    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        debugPrint('⚠️ Could not open output: $path');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to open output: $e');
    }
  }

  // ──────────────────────────── Action bridge ──────────────────────────

  void _onForegroundAction(Object data) {
    if (data is Map && data['action'] is String) {
      _handleAction(data['action'] as String);
    }
  }

  void _onNotificationAction(String actionId, String? payload) {
    switch (actionId) {
      case 'conv_cancel':
        _handleAction(FgsAction.cancel);
      case 'conv_open':
        ConverterNotificationService.openConverterScreen();
    }
  }

  void _handleAction(String actionId) {
    switch (actionId) {
      case FgsAction.cancel:
        final running = _jobs.firstWhereOrNull(
          (j) => j.status == ConversionStatus.processing,
        );
        if (running != null) unawaited(cancelJob(running.id));
      case FgsAction.open:
        ConverterNotificationService.openConverterScreen();
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
}

extension FirstWhereOrNullExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}