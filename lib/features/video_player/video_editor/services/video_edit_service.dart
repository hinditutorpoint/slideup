import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';

import '../models/video_edit_settings.dart';

class VideoEditService {
  static final VideoEditService _instance = VideoEditService._internal();
  factory VideoEditService() => _instance;
  VideoEditService._internal();

  final _uuid = const Uuid();
  FFmpegSession? _currentSession;
  bool _isProcessing = false;
  bool _isCancelled = false;

  final _progressController = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;
  bool get isProcessing => _isProcessing;

  // ═══════════════════════════════════════════════════════
  // ✅ CANCEL OPERATION
  // ═══════════════════════════════════════════════════════

  Future<void> cancelCurrentOperation() async {
    try {
      _isCancelled = true;
      if (_currentSession != null) {
        await FFmpegKit.cancel(_currentSession!.getSessionId());
        _currentSession = null;
      }
      _isProcessing = false;
    } catch (e) {
      debugPrint('⚠️ Error cancelling: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TRIM VIDEO
  // ═══════════════════════════════════════════════════════

  Future<String?> trimVideo({
    required String inputPath,
    required Duration startTime,
    required Duration endTime,
    String? outputPath,
    ExportPreset? preset,
    Function(double)? onProgress,
  }) async {
    if (_isProcessing) return null;
    if (!await _validateInputFile(inputPath)) return null;
    if (startTime >= endTime) return null;

    _isProcessing = true;
    _isCancelled = false;

    try {
      final ext = preset?.extension ?? 'mp4';
      final output = outputPath ?? await _getOutputPath('trimmed', ext);
      if (output == null) return null;

      final startStr = _formatDuration(startTime);
      final duration = endTime - startTime;
      final durationStr = _formatDuration(duration);

      String command;
      if (preset != null && preset.quality != VideoQuality.original) {
        final videoFilters = _buildVideoFilters(preset);
        final audioSettings = _buildAudioSettings(preset);
        command =
            '-y -ss $startStr -i "$inputPath" -t $durationStr $videoFilters $audioSettings "$output"';
      } else {
        command =
            '-y -ss $startStr -i "$inputPath" -t $durationStr -c copy -avoid_negative_ts make_zero "$output"';
      }

      debugPrint('📹 Trim: $command');
      _setupProgressCallback(duration, onProgress);

      _currentSession = await FFmpegKit.execute(command);
      final returnCode = await _currentSession?.getReturnCode();
      _clearProgressCallback();

      if (_isCancelled) {
        await _cleanupFile(output);
        return null;
      }

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('✅ Trimmed: $output');
        return output;
      }

      await _cleanupFile(output);
      return null;
    } catch (e) {
      debugPrint('❌ Trim error: $e');
      return null;
    } finally {
      _isProcessing = false;
      _currentSession = null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXPORT WITH PRESET
  // ═══════════════════════════════════════════════════════

  Future<String?> exportWithPreset({
    required String inputPath,
    required ExportPreset preset,
    Duration? trimStart,
    Duration? trimEnd,
    ColorGradeSettings? colorGrade,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    if (_isProcessing) return null;
    if (!await _validateInputFile(inputPath)) return null;

    _isProcessing = true;
    _isCancelled = false;

    try {
      final output =
          outputPath ?? await _getOutputPath('export', preset.extension);
      if (output == null) return null;

      final commandParts = <String>['-y'];

      // Trim settings
      if (trimStart != null) {
        commandParts.add('-ss ${_formatDuration(trimStart)}');
      }

      commandParts.add('-i "$inputPath"');

      if (trimEnd != null && trimStart != null) {
        final duration = trimEnd - trimStart;
        commandParts.add('-t ${_formatDuration(duration)}');
      }

      // Video filters
      final filters = <String>[];

      // Resolution
      if (preset.width != null && preset.height != null) {
        filters.add(
          'scale=${preset.width}:${preset.height}:force_original_aspect_ratio=decrease,pad=${preset.width}:${preset.height}:(ow-iw)/2:(oh-ih)/2',
        );
      }

      // FPS
      if (preset.fps != null) {
        filters.add('fps=${preset.fps}');
      }

      // Color grading
      if (colorGrade != null && !colorGrade.isDefault) {
        filters.add(_buildColorFilters(colorGrade));
      }

      if (filters.isNotEmpty) {
        commandParts.add('-vf "${filters.join(',')}"');
      }

      // Video codec & bitrate
      if (preset.quality != VideoQuality.original) {
        commandParts.add('-c:v libx264 -preset medium');
        if (preset.bitrate != null) {
          commandParts.add('-b:v ${preset.bitrate}k');
        }
      } else {
        commandParts.add('-c:v copy');
      }

      // Audio
      if (preset.removeAudio) {
        commandParts.add('-an');
      } else {
        commandParts.add('-c:a aac -b:a ${preset.audioBitrate ?? 128}k');
      }

      commandParts.add('"$output"');

      final command = commandParts.join(' ');
      debugPrint('📤 Export: $command');

      final duration = await _getVideoDuration(inputPath);
      _setupProgressCallback(duration, onProgress);

      _currentSession = await FFmpegKit.execute(command);
      final returnCode = await _currentSession?.getReturnCode();
      _clearProgressCallback();

      if (_isCancelled) {
        await _cleanupFile(output);
        return null;
      }

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('✅ Exported: $output');
        return output;
      }

      await _cleanupFile(output);
      return null;
    } catch (e) {
      debugPrint('❌ Export error: $e');
      return null;
    } finally {
      _isProcessing = false;
      _currentSession = null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MERGE VIDEOS
  // ═══════════════════════════════════════════════════════

  Future<String?> mergeVideos({
    required List<MergeItem> items,
    ExportPreset? preset,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    if (_isProcessing) return null;
    if (items.isEmpty) return null;

    _isProcessing = true;
    _isCancelled = false;

    Directory? tempDir;

    try {
      final output =
          outputPath ??
          await _getOutputPath('merged', preset?.extension ?? 'mp4');
      if (output == null) return null;

      tempDir = await _createTempDir('merge');
      final listFile = File(p.join(tempDir.path, 'list.txt'));
      final processedFiles = <String>[];

      // Process each item
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        onProgress?.call(i / items.length * 0.8);

        if (item.type == MediaType.video) {
          String processedPath;

          // Trim if needed
          if (item.trimStart != null || item.trimEnd != null) {
            final trimmed = await _trimForMerge(
              item.path,
              item.trimStart ?? Duration.zero,
              item.trimEnd ?? item.duration ?? Duration.zero,
              tempDir.path,
              i,
            );
            if (trimmed == null) continue;
            processedPath = trimmed;
          } else {
            processedPath = item.path;
          }

          processedFiles.add(processedPath);
        } else if (item.type == MediaType.image) {
          // Convert image to video
          final imageVideo = await _imageToVideo(
            item.path,
            item.duration ?? const Duration(seconds: 3),
            tempDir.path,
            i,
          );
          if (imageVideo != null) {
            processedFiles.add(imageVideo);
          }
        }
      }

      if (processedFiles.isEmpty) {
        return null;
      }

      // Create concat list
      final listContent = processedFiles.map((f) => "file '$f'").join('\n');
      await listFile.writeAsString(listContent);

      // Merge command
      String command;
      if (preset != null && preset.quality != VideoQuality.original) {
        final videoFilters = _buildVideoFilters(preset);
        command =
            '-y -f concat -safe 0 -i "${listFile.path}" $videoFilters -c:a aac "$output"';
      } else {
        command =
            '-y -f concat -safe 0 -i "${listFile.path}" -c copy "$output"';
      }

      debugPrint('🔗 Merge: $command');

      _currentSession = await FFmpegKit.execute(command);
      final returnCode = await _currentSession?.getReturnCode();

      onProgress?.call(1.0);

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('✅ Merged: $output');
        return output;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Merge error: $e');
      return null;
    } finally {
      _isProcessing = false;
      _currentSession = null;
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<String?> _trimForMerge(
    String input,
    Duration start,
    Duration end,
    String tempPath,
    int index,
  ) async {
    final output = p.join(tempPath, 'segment_$index.mp4');
    final startStr = _formatDuration(start);
    final durationStr = _formatDuration(end - start);

    final command =
        '-y -ss $startStr -i "$input" -t $durationStr -c copy "$output"';
    final session = await FFmpegKit.execute(command);

    if (ReturnCode.isSuccess(await session.getReturnCode())) {
      return output;
    }
    return null;
  }

  Future<String?> _imageToVideo(
    String imagePath,
    Duration duration,
    String tempPath,
    int index,
  ) async {
    final output = p.join(tempPath, 'image_$index.mp4');
    final durationSec = duration.inMilliseconds / 1000;

    final command =
        '-y -loop 1 -i "$imagePath" -c:v libx264 -t $durationSec -pix_fmt yuv420p -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" "$output"';
    final session = await FFmpegKit.execute(command);

    if (ReturnCode.isSuccess(await session.getReturnCode())) {
      return output;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ADD AUDIO TO VIDEO
  // ═══════════════════════════════════════════════════════

  Future<String?> addAudioToVideo({
    required String videoPath,
    required String audioPath,
    bool replaceOriginal = false,
    double audioVolume = 1.0,
    double originalVolume = 1.0,
    Duration? audioStart,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    if (_isProcessing) return null;
    if (!await _validateInputFile(videoPath)) return null;
    if (!await _validateInputFile(audioPath)) return null;

    _isProcessing = true;
    _isCancelled = false;

    try {
      final output = outputPath ?? await _getOutputPath('audio_added', 'mp4');
      if (output == null) return null;

      String command;

      if (replaceOriginal) {
        // Replace audio completely
        command =
            '-y -i "$videoPath" -i "$audioPath" -c:v copy -map 0:v:0 -map 1:a:0 -shortest "$output"';
      } else {
        // Mix audio
        final audioStartSec = (audioStart?.inMilliseconds ?? 0) / 1000;
        command =
            '-y -i "$videoPath" -i "$audioPath" -filter_complex '
            '"[0:a]volume=$originalVolume[a0];[1:a]adelay=${(audioStartSec * 1000).toInt()}|${(audioStartSec * 1000).toInt()},volume=$audioVolume[a1];[a0][a1]amix=inputs=2:duration=first[aout]" '
            '-map 0:v -map "[aout]" -c:v copy "$output"';
      }

      debugPrint('🎵 Add audio: $command');

      final duration = await _getVideoDuration(videoPath);
      _setupProgressCallback(duration, onProgress);

      _currentSession = await FFmpegKit.execute(command);
      final returnCode = await _currentSession?.getReturnCode();
      _clearProgressCallback();

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('✅ Audio added: $output');
        return output;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Add audio error: $e');
      return null;
    } finally {
      _isProcessing = false;
      _currentSession = null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXTRACT AUDIO
  // ═══════════════════════════════════════════════════════

  Future<String?> extractAudio({
    required String inputPath,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    if (_isProcessing) return null;
    if (!await _validateInputFile(inputPath)) return null;

    _isProcessing = true;
    _isCancelled = false;

    try {
      final ext = format.name;
      final output = outputPath ?? await _getOutputPath('audio', ext);
      if (output == null) return null;

      final codec = _getAudioCodec(format, bitrate);
      final command = '-y -i "$inputPath" -vn $codec "$output"';

      debugPrint('🎵 Extract audio: $command');

      final duration = await _getVideoDuration(inputPath);
      _setupProgressCallback(duration, onProgress);

      _currentSession = await FFmpegKit.execute(command);
      final returnCode = await _currentSession?.getReturnCode();
      _clearProgressCallback();

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('✅ Audio extracted: $output');
        return output;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Extract audio error: $e');
      return null;
    } finally {
      _isProcessing = false;
      _currentSession = null;
    }
  }

  String _getAudioCodec(AudioFormat format, int bitrate) {
    switch (format) {
      case AudioFormat.aac:
        return '-c:a aac -b:a ${bitrate}k';
      case AudioFormat.wav:
        return '-c:a pcm_s16le';
      case AudioFormat.flac:
        return '-c:a flac';
      case AudioFormat.ogg:
        return '-c:a libvorbis -b:a ${bitrate}k';
      default:
        return '-c:a libmp3lame -b:a ${bitrate}k';
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ COLOR GRADING
  // ═══════════════════════════════════════════════════════

  Future<String?> applyColorGrading({
    required String inputPath,
    required ColorGradeSettings settings,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    if (_isProcessing) return null;
    if (!await _validateInputFile(inputPath)) return null;
    if (settings.isDefault) return inputPath;

    _isProcessing = true;
    _isCancelled = false;

    try {
      final output = outputPath ?? await _getOutputPath('graded', 'mp4');
      if (output == null) return null;

      final filters = _buildColorFilters(settings);
      final command = '-y -i "$inputPath" -vf "$filters" -c:a copy "$output"';

      debugPrint('🎨 Color grade: $command');

      final duration = await _getVideoDuration(inputPath);
      _setupProgressCallback(duration, onProgress);

      _currentSession = await FFmpegKit.execute(command);
      final returnCode = await _currentSession?.getReturnCode();
      _clearProgressCallback();

      if (ReturnCode.isSuccess(returnCode)) {
        return output;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Color grade error: $e');
      return null;
    } finally {
      _isProcessing = false;
      _currentSession = null;
    }
  }

  String _buildColorFilters(ColorGradeSettings s) {
    final filters = <String>[];

    if (s.brightness != 0.0 || s.contrast != 1.0 || s.saturation != 1.0) {
      filters.add(
        'eq=brightness=${s.brightness}:contrast=${s.contrast}:saturation=${s.saturation}',
      );
    }

    if (s.hue != 0.0) {
      filters.add('hue=h=${s.hue}');
    }

    if (s.red != 1.0 || s.green != 1.0 || s.blue != 1.0) {
      final rs = (s.red - 1.0).clamp(-1.0, 1.0);
      final gs = (s.green - 1.0).clamp(-1.0, 1.0);
      final bs = (s.blue - 1.0).clamp(-1.0, 1.0);
      filters.add('colorbalance=rs=$rs:gs=$gs:bs=$bs:rm=$rs:gm=$gs:bm=$bs');
    }

    if (s.temperature != 0.0) {
      final temp = s.temperature / 100;
      final r = temp > 0 ? temp : 0.0;
      final b = temp < 0 ? -temp : 0.0;
      filters.add('colorbalance=rs=$r:bs=$b');
    }

    return filters.isEmpty ? 'null' : filters.join(',');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXTRACT FRAMES
  // ═══════════════════════════════════════════════════════

  Future<List<Uint8List>> extractFrames({
    required String inputPath,
    Duration? startTime,
    Duration? endTime,
    int fps = 1,
    int width = 320,
    int height = 180,
    int maxFrames = 50,
    Function(double)? onProgress,
  }) async {
    final frames = <Uint8List>[];
    if (!await _validateInputFile(inputPath)) return frames;

    Directory? tempDir;

    try {
      tempDir = await _createTempDir('frames');

      final cmdParts = <String>['-y'];
      if (startTime != null) cmdParts.add('-ss ${_formatDuration(startTime)}');
      cmdParts.add('-i "$inputPath"');
      if (endTime != null && startTime != null) {
        cmdParts.add('-t ${_formatDuration(endTime - startTime)}');
      }
      cmdParts.add('-vf "fps=$fps,scale=$width:$height"');
      cmdParts.add('-vframes $maxFrames');
      cmdParts.add('"${tempDir.path}/frame_%04d.jpg"');

      final session = await FFmpegKit.execute(cmdParts.join(' '));

      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        final files = await tempDir.list().toList();
        files.sort((a, b) => a.path.compareTo(b.path));

        for (int i = 0; i < files.length; i++) {
          if (files[i] is File && files[i].path.endsWith('.jpg')) {
            frames.add(await (files[i] as File).readAsBytes());
          }
          onProgress?.call((i + 1) / files.length);
        }
      }
    } catch (e) {
      debugPrint('❌ Extract frames error: $e');
    } finally {
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }

    return frames;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CREATE CLIP FROM MARKER
  // ═══════════════════════════════════════════════════════

  Future<String?> createClipFromMarker({
    required String inputPath,
    required ClipMarker marker,
    ExportPreset? preset,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    String? trimmedPath;

    try {
      trimmedPath = await trimVideo(
        inputPath: inputPath,
        startTime: marker.startTime,
        endTime: marker.endTime,
        preset: preset,
        onProgress: (p) => onProgress?.call(p * 0.5),
      );

      if (trimmedPath == null) return null;

      if (marker.colorGrade != null && !marker.colorGrade!.isDefault) {
        final gradedPath = await applyColorGrading(
          inputPath: trimmedPath,
          settings: marker.colorGrade!,
          outputPath: outputPath,
          onProgress: (p) => onProgress?.call(0.5 + p * 0.5),
        );

        if (gradedPath != null && gradedPath != trimmedPath) {
          await _cleanupFile(trimmedPath);
        }

        return gradedPath;
      }

      return trimmedPath;
    } catch (e) {
      debugPrint('❌ Create clip error: $e');
      if (trimmedPath != null) await _cleanupFile(trimmedPath);
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ FILE OPERATIONS
  // ═══════════════════════════════════════════════════════

  Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('❌ Delete error: $e');
    }
    return false;
  }

  Future<bool> renameFile(String path, String newName) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final dir = p.dirname(path);
        final ext = p.extension(path);
        final newPath = p.join(dir, '$newName$ext');
        await file.rename(newPath);
        return true;
      }
    } catch (e) {
      debugPrint('❌ Rename error: $e');
    }
    return false;
  }

  Future<void> shareFile(String path) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out this file!',
          subject: 'Shared File',
          files: [XFile(path)],
        ),
      );
    } catch (e) {
      debugPrint('❌ Share error: $e');
    }
  }

  Future<List<MediaItem>> getLibraryItems() async {
    final items = <MediaItem>[];

    try {
      final outputDir = await getExternalStorageDirectory();
      final videosDir = Directory(p.join(outputDir!.path, 'processed_videos'));

      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
        return items;
      }

      await for (final entity in videosDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final ext = p.extension(entity.path).toLowerCase();

          MediaType type;
          if (['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext)) {
            type = MediaType.video;
          } else if (['.mp3', '.aac', '.wav', '.flac', '.ogg'].contains(ext)) {
            type = MediaType.audio;
          } else if (['.jpg', '.jpeg', '.png', '.gif'].contains(ext)) {
            type = MediaType.image;
          } else {
            continue;
          }

          items.add(
            MediaItem(
              id: entity.path.hashCode.toString(),
              name: p.basenameWithoutExtension(entity.path),
              path: entity.path,
              type: type,
              createdAt: stat.modified,
              fileSize: stat.size,
            ),
          );
        }
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('❌ Get library error: $e');
    }

    return items;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VIDEO INFO
  // ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getVideoInfo(String inputPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(inputPath);
      final info = session.getMediaInformation();
      if (info == null) return null;

      return {
        'duration': info.getDuration(),
        'size': info.getSize(),
        'bitrate': info.getBitrate(),
        'format': info.getFormat(),
      };
    } catch (e) {
      debugPrint('❌ Get info error: $e');
      return null;
    }
  }

  Future<Duration?> _getVideoDuration(String inputPath) async {
    try {
      final info = await getVideoInfo(inputPath);
      if (info?['duration'] != null) {
        final seconds = double.tryParse(info!['duration'] as String);
        if (seconds != null) {
          return Duration(milliseconds: (seconds * 1000).toInt());
        }
      }
    } catch (_) {}
    return null;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  Future<bool> _validateInputFile(String path) async {
    try {
      final file = File(path);
      return await file.exists() && (await file.stat()).size > 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _getOutputPath(String prefix, String ext) async {
    try {
      final outputDir = await getExternalStorageDirectory();
      final videosDir = Directory(p.join(outputDir!.path, 'processed_videos'));
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }
      return p.join(videosDir.path, '${prefix}_${_uuid.v4()}.$ext');
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _createTempDir(String prefix) async {
    final tempDir = await getExternalStorageDirectory();
    final dir = Directory(
      p.join(
        '${tempDir!.path}/temp_video_editing',
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await dir.create(recursive: true);
    return dir;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String _buildVideoFilters(ExportPreset preset) {
    final filters = <String>[];

    if (preset.width != null && preset.height != null) {
      filters.add(
        '-vf "scale=${preset.width}:${preset.height}:force_original_aspect_ratio=decrease"',
      );
    }

    final parts = <String>['-c:v libx264 -preset medium'];
    if (preset.bitrate != null) {
      parts.add('-b:v ${preset.bitrate}k');
    }
    if (preset.fps != null) {
      parts.add('-r ${preset.fps}');
    }

    return [...filters, ...parts].join(' ');
  }

  String _buildAudioSettings(ExportPreset preset) {
    if (preset.removeAudio) return '-an';
    return '-c:a aac -b:a ${preset.audioBitrate ?? 128}k';
  }

  void _setupProgressCallback(
    Duration? duration,
    Function(double)? onProgress,
  ) {
    if (duration == null || onProgress == null) return;
    try {
      FFmpegKitConfig.enableStatisticsCallback((stats) {
        final time = stats.getTime();
        if (time > 0 && duration.inMilliseconds > 0) {
          onProgress((time / duration.inMilliseconds).clamp(0.0, 1.0));
        }
      });
    } catch (_) {}
  }

  void _clearProgressCallback() {
    try {
      FFmpegKitConfig.enableStatisticsCallback(null);
    } catch (_) {}
  }

  Future<void> _cleanupFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void dispose() {
    cancelCurrentOperation();
    if (!_progressController.isClosed) {
      _progressController.close();
    }
  }
}
