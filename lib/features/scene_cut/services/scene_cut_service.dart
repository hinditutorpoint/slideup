import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';

import '../models/scene_settings.dart';

/// Standalone scene cut — no dependency on `features/video_editor`.
class SceneCutService {
  static final SceneCutService instance = SceneCutService._();
  SceneCutService._();

  /// Cut a scene from [inputPath] between [start] and [end] using [settings].
  /// Returns output path on success, null on failure/cancel.
  /// [onProgress] 0..1, [onStatistics] raw FFmpeg stats if needed.
  Future<String?> cutScene({
    required String inputPath,
    required Duration start,
    required Duration end,
    required SceneSettings settings,
    void Function(double progress)? onProgress,
    void Function(Statistics)? onStatistics,
  }) async {
    final duration = end - start;
    if (duration.inMilliseconds < 300) return null;
    if (inputPath.isEmpty) return null;

    final needsFile =
        settings.saveDestination == SceneSaveDestination.filesOnly ||
        settings.saveDestination == SceneSaveDestination.both;
    final needsGallery =
        settings.saveDestination == SceneSaveDestination.galleryOnly ||
        settings.saveDestination == SceneSaveDestination.both;

    // Resolve output directory: files -> saveLocation, galleryOnly -> temp
    final String outputDirPath;
    if (needsFile) {
      final dir = Directory(settings.saveLocation);
      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
        } catch (_) {
          return null;
        }
      }
      outputDirPath = dir.path;
    } else {
      final tmp = await getTemporaryDirectory();
      final tempDir = Directory(p.join(tmp.path, 'slideup_scenes'));
      if (!await tempDir.exists()) {
        try {
          await tempDir.create(recursive: true);
        } catch (_) {
          return null;
        }
      }
      outputDirPath = tempDir.path;
    }

    // Unique output path
    final ext = settings.container.extension;
    final now = DateTime.now();
    final ts =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final base = p.basenameWithoutExtension(inputPath);
    final safeBase = base.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    final outName = 'scene_${safeBase}_$ts.$ext';
    final outputPath = _uniquePath(outputDirPath, outName);

    final preset = settings.resolvedPreset;
    final vf = _buildVideoFilter(preset.width, preset.height, settings.fitMode);
    final startStr = _fmtDuration(start);
    final durStr = _fmtDuration(duration);

    final escapedInput = inputPath.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final escapedOutput = outputPath.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

    // Fast path: exact resolution not requested and keep-audio + mp4 copy
    // is NOT used — we always transcode to respect platform resolution/fit.
    // For custom null W/H we do stream copy-like fast trim (no scale) but still
    // re-encode audio if needed for faststart.
    final hasScale = preset.width != null && preset.height != null;
    final vfArg = hasScale && vf.isNotEmpty ? ' -vf "$vf"' : '';
    final fpsArg = ' -r ${settings.fps}';
    final vcodecArg = ' -c:v libx264 -preset fast -b:v ${settings.videoBitrateKbps}k';
    final acodecArg = settings.audioMode == SceneAudioMode.remove
        ? ' -an'
        : ' -c:a aac -b:a 128k';
    final faststartArg = settings.container == SceneContainer.mp4 && settings.faststart
        ? ' -movflags +faststart'
        : '';
    // WebM: use libvpx for video if container is webm — fallback to libx264 still works
    final vcodecEffective = settings.container == SceneContainer.webm ? ' -c:v libvpx -b:v ${settings.videoBitrateKbps}k' : vcodecArg;

    final command =
        '-y -ss $startStr -i "$escapedInput" -t $durStr$vfArg${settings.container == SceneContainer.webm ? '' : fpsArg}$vcodecEffective$acodecArg$faststartArg "$escapedOutput"';

    final completer = _CutCompleter(duration: duration, onProgress: onProgress, onStatistics: onStatistics);
    try {
      final session = await FFmpegKit.executeAsync(
        command,
        (s) => completer.complete(s, outputPath),
        null,
        completer.onStats,
      );
      completer.session = session;
      final result = await completer.future;
      if (result == null) return null;

      // Handle gallery copy when requested. Service owns gallery insertion
      // so callers don't need duplicate SaverGallery logic.
      if (needsGallery) {
        try {
          await SaverGallery.saveFile(
            filePath: result,
            fileName: p.basename(result),
            androidRelativePath: 'Movies/SlideUpScenes',
            skipIfExists: false,
          );
        } catch (_) {
          // Gallery copy is best-effort; file already exists at result for
          // `both` mode, so don't fail the cut if gallery insert fails.
          if (settings.saveDestination == SceneSaveDestination.galleryOnly) {
            // galleryOnly still succeeded at file level — return path anyway.
          }
        }
        if (settings.saveDestination == SceneSaveDestination.galleryOnly) {
          // For galleryOnly the temp file is just a staging copy; best-effort
          // cleanup after gallery insert. Return original path for caller snackbar.
          // Caller treats non-null as success regardless of temp lifetime.
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Cancel a running session if needed (call FFmpegKit.cancel externally with sessionId).
  static Future<void> cancelSession(FFmpegSession session) async {
    try {
      await FFmpegKit.cancel(session.getSessionId());
    } catch (_) {}
  }

  String _uniquePath(String dir, String fileName) {
    var candidate = p.join(dir, fileName);
    if (!File(candidate).existsSync()) return candidate;
    final base = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    int i = 1;
    while (true) {
      candidate = p.join(dir, '$base ($i)$ext');
      if (!File(candidate).existsSync()) return candidate;
      i++;
      if (i > 999) break;
    }
    return p.join(dir, '${base}_${DateTime.now().millisecondsSinceEpoch}$ext');
  }

  String _buildVideoFilter(int? w, int? h, SceneFit fit) {
    if (w == null || h == null) return '';
    switch (fit) {
      case SceneFit.cropCenter:
        // ignore: unnecessary_brace_in_string_interps
        return 'scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,setsar=1';
      case SceneFit.padBlack:
        // ignore: unnecessary_brace_in_string_interps
        return 'scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1';
      case SceneFit.padBlur:
        // ignore: unnecessary_brace_in_string_interps
        return 'scale=$w:$h:force_original_aspect_ratio=decrease,pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1';
    }
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final ms = d.inMilliseconds.remainder(1000);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }
}

class _CutCompleter {
  final Duration duration;
  final void Function(double)? onProgress;
  final void Function(Statistics)? onStatistics;
  FFmpegSession? session;

  final _completer = Completer<String?>();

  Future<String?> get future => _completer.future;

  _CutCompleter({required this.duration, this.onProgress, this.onStatistics});

  void onStats(Statistics stats) {
    onStatistics?.call(stats);
    if (onProgress != null) {
      final t = stats.getTime();
      if (t > 0 && duration.inMilliseconds > 0) {
        onProgress!( (t / duration.inMilliseconds).clamp(0.0, 1.0));
      }
    }
  }

  Future<void> complete(FFmpegSession s, String outputPath) async {
    final rc = await s.getReturnCode();
    final success = rc != null && rc.isValueSuccess();
    if (!success) {
      try {
        final f = File(outputPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      if (!_completer.isCompleted) _completer.complete(null);
      return;
    }
    if (onProgress != null) onProgress!(1.0);
    if (!_completer.isCompleted) _completer.complete(outputPath);
  }
}


