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
      debugPrint('⚠️ Error cancelling operation: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TRIM/CLIP VIDEO
  // ═══════════════════════════════════════════════════════

  Future<String?> trimVideo({
    required String inputPath,
    required Duration startTime,
    required Duration endTime,
    String? outputPath,
    Function(double progress)? onProgress,
  }) async {
    if (_isProcessing) {
      debugPrint('⚠️ Another operation is in progress');
      return null;
    }

    // Validate input
    if (!await _validateInputFile(inputPath)) {
      return null;
    }

    if (startTime >= endTime) {
      debugPrint('❌ Invalid time range: start >= end');
      return null;
    }

    _isProcessing = true;
    _isCancelled = false;

    try {
      final output = await _getOutputPath(outputPath, 'trimmed', 'mp4');
      if (output == null) return null;

      final startString = _formatDuration(startTime);
      final duration = endTime - startTime;
      final durationString = _formatDuration(duration);

      // Use stream copy for fast trimming, re-encode if needed
      final command =
          '-y -ss $startString -i "$inputPath" -t $durationString -c copy -avoid_negative_ts make_zero "$output"';

      debugPrint('📹 Trimming video: $command');

      final totalDuration = duration;

      _setupProgressCallback(totalDuration, onProgress);

      _currentSession = await FFmpegKit.execute(command);
      final returnCode = await _currentSession?.getReturnCode();

      _clearProgressCallback();

      if (_isCancelled) {
        await _cleanupFile(output);
        return null;
      }

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('✅ Video trimmed: $output');
        return output;
      } else {
        final logs = await _currentSession?.getAllLogsAsString();
        debugPrint(
          '❌ Trim failed: ${logs?.substring(0, (logs.length).clamp(0, 500))}',
        );
        await _cleanupFile(output);
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Trim error: $e');
      debugPrint('Stack: $stackTrace');
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
    String format = 'mp3',
    int bitrate = 192,
    String? outputPath,
    Function(double progress)? onProgress,
  }) async {
    if (_isProcessing) {
      debugPrint('⚠️ Another operation is in progress');
      return null;
    }

    if (!await _validateInputFile(inputPath)) {
      return null;
    }

    // Validate format
    final validFormats = ['mp3', 'aac', 'wav', 'flac', 'm4a', 'ogg'];
    if (!validFormats.contains(format.toLowerCase())) {
      debugPrint('❌ Invalid audio format: $format');
      return null;
    }

    _isProcessing = true;
    _isCancelled = false;

    try {
      final output = await _getOutputPath(outputPath, 'audio', format);
      if (output == null) return null;

      final codec = _getAudioCodec(format, bitrate);
      final command = '-y -i "$inputPath" -vn $codec "$output"';

      debugPrint('🎵 Extracting audio: $command');

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
        debugPrint('✅ Audio extracted: $output');
        return output;
      } else {
        final logs = await _currentSession?.getAllLogsAsString();
        debugPrint(
          '❌ Audio extraction failed: ${logs?.substring(0, (logs.length).clamp(0, 500))}',
        );
        await _cleanupFile(output);
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Audio extraction error: $e');
      debugPrint('Stack: $stackTrace');
      return null;
    } finally {
      _isProcessing = false;
      _currentSession = null;
    }
  }

  String _getAudioCodec(String format, int bitrate) {
    switch (format.toLowerCase()) {
      case 'aac':
      case 'm4a':
        return '-c:a aac -b:a ${bitrate}k';
      case 'wav':
        return '-c:a pcm_s16le';
      case 'flac':
        return '-c:a flac';
      case 'ogg':
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
    Function(double progress)? onProgress,
  }) async {
    if (_isProcessing) {
      debugPrint('⚠️ Another operation is in progress');
      return null;
    }

    if (!await _validateInputFile(inputPath)) {
      return null;
    }

    // Skip if default settings
    if (settings.isDefault) {
      debugPrint('ℹ️ Default color settings, no processing needed');
      return inputPath;
    }

    _isProcessing = true;
    _isCancelled = false;

    try {
      final output = await _getOutputPath(outputPath, 'graded', 'mp4');
      if (output == null) return null;

      final filters = _buildColorFilters(settings);

      if (filters.isEmpty) {
        debugPrint('ℹ️ No filters to apply');
        return inputPath;
      }

      final command = '-y -i "$inputPath" -vf "$filters" -c:a copy "$output"';

      debugPrint('🎨 Applying color grading: $command');

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
        debugPrint('✅ Color grading applied: $output');
        return output;
      } else {
        final logs = await _currentSession?.getAllLogsAsString();
        debugPrint(
          '❌ Color grading failed: ${logs?.substring(0, (logs.length).clamp(0, 500))}',
        );
        await _cleanupFile(output);
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Color grading error: $e');
      debugPrint('Stack: $stackTrace');
      return null;
    } finally {
      _isProcessing = false;
      _currentSession = null;
    }
  }

  String _buildColorFilters(ColorGradeSettings settings) {
    final filters = <String>[];

    // Brightness and contrast using eq filter
    if (settings.brightness != 0.0 || settings.contrast != 1.0) {
      final brightness = settings.brightness.clamp(-1.0, 1.0);
      final contrast = settings.contrast.clamp(0.0, 4.0);
      filters.add('eq=brightness=$brightness:contrast=$contrast');
    }

    // Saturation
    if (settings.saturation != 1.0) {
      final saturation = settings.saturation.clamp(0.0, 3.0);
      filters.add('eq=saturation=$saturation');
    }

    // Hue
    if (settings.hue != 0.0) {
      final hue = settings.hue.clamp(-180.0, 180.0);
      filters.add('hue=h=$hue');
    }

    // RGB channels using colorbalance
    if (settings.red != 1.0 || settings.green != 1.0 || settings.blue != 1.0) {
      final rs = (settings.red - 1.0).clamp(-1.0, 1.0);
      final gs = (settings.green - 1.0).clamp(-1.0, 1.0);
      final bs = (settings.blue - 1.0).clamp(-1.0, 1.0);
      filters.add(
        'colorbalance=rs=$rs:gs=$gs:bs=$bs:rm=$rs:gm=$gs:bm=$bs:rh=$rs:gh=$gs:bh=$bs',
      );
    }

    // Temperature (warm/cool)
    if (settings.temperature != 0.0) {
      final temp = settings.temperature / 100;
      final r = temp > 0 ? temp : 0.0;
      final b = temp < 0 ? -temp : 0.0;
      filters.add('colorbalance=rs=$r:bs=$b:rm=$r:bm=$b:rh=$r:bh=$b');
    }

    // Shadows and highlights using curves
    if (settings.shadows != 0.0 || settings.highlights != 0.0) {
      // Simplified curves
      final shadowPoint = (0.25 + settings.shadows * 0.1).clamp(0.0, 0.5);
      final highlightPoint = (0.75 + settings.highlights * 0.1).clamp(0.5, 1.0);
      filters.add(
        'curves=m=0/0 $shadowPoint/$shadowPoint $highlightPoint/$highlightPoint 1/1',
      );
    }

    return filters.join(',');
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
    int maxFrames = 100,
    Function(double progress)? onProgress,
  }) async {
    final frames = <Uint8List>[];

    if (!await _validateInputFile(inputPath)) {
      return frames;
    }

    Directory? tempDir;

    try {
      // Create temp directory
      final baseTempDir = await getExternalStorageDirectory();
      tempDir = Directory(
        p.join(
          baseTempDir!.path,
          'frames_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      await tempDir.create(recursive: true);

      // Build command
      final commandParts = <String>['-y'];

      if (startTime != null) {
        commandParts.add('-ss ${_formatDuration(startTime)}');
      }

      commandParts.add('-i "$inputPath"');

      if (endTime != null && startTime != null) {
        final duration = endTime - startTime;
        commandParts.add('-t ${_formatDuration(duration)}');
      }

      commandParts.add('-vf "fps=$fps,scale=$width:$height"');
      commandParts.add('-vframes $maxFrames');
      commandParts.add('"${tempDir.path}/frame_%04d.jpg"');

      final command = commandParts.join(' ');
      debugPrint('🎞️ Extracting frames: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // Read frames
        final files = await tempDir.list().toList();
        files.sort((a, b) => a.path.compareTo(b.path));

        final total = files.length;
        for (int i = 0; i < files.length; i++) {
          try {
            final file = files[i];
            if (file is File && file.path.endsWith('.jpg')) {
              final bytes = await file.readAsBytes();
              frames.add(bytes);
            }
            onProgress?.call((i + 1) / total);
          } catch (e) {
            debugPrint('⚠️ Error reading frame: $e');
          }
        }

        debugPrint('✅ Extracted ${frames.length} frames');
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint(
          '❌ Frame extraction failed: ${logs?.substring(0, (logs.length).clamp(0, 500))}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Frame extraction error: $e');
      debugPrint('Stack: $stackTrace');
    } finally {
      // Cleanup temp directory
      try {
        if (tempDir != null && await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('⚠️ Cleanup error: $e');
      }
    }

    return frames;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CREATE CLIP WITH MARKER
  // ═══════════════════════════════════════════════════════

  Future<String?> createClipFromMarker({
    required String inputPath,
    required ClipMarker marker,
    String? outputPath,
    Function(double progress)? onProgress,
  }) async {
    if (marker.startTime >= marker.endTime) {
      debugPrint('❌ Invalid marker: start >= end');
      return null;
    }

    String? trimmedPath;

    try {
      // First trim
      trimmedPath = await trimVideo(
        inputPath: inputPath,
        startTime: marker.startTime,
        endTime: marker.endTime,
        onProgress: (p) => onProgress?.call(p * 0.5),
      );

      if (trimmedPath == null) return null;

      // Apply color grading if set
      if (marker.colorGrade != null && !marker.colorGrade!.isDefault) {
        final gradedPath = await applyColorGrading(
          inputPath: trimmedPath,
          settings: marker.colorGrade!,
          outputPath: outputPath,
          onProgress: (p) => onProgress?.call(0.5 + p * 0.5),
        );

        // Cleanup trimmed file if grading succeeded
        if (gradedPath != null && gradedPath != trimmedPath) {
          await _cleanupFile(trimmedPath);
        }

        return gradedPath;
      }

      // Move to final location if needed
      if (outputPath != null && trimmedPath != outputPath) {
        final trimmedFile = File(trimmedPath);
        await trimmedFile.rename(outputPath);
        return outputPath;
      }

      return trimmedPath;
    } catch (e, stackTrace) {
      debugPrint('❌ Create clip error: $e');
      debugPrint('Stack: $stackTrace');

      // Cleanup on error
      if (trimmedPath != null) {
        await _cleanupFile(trimmedPath);
      }

      return null;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GENERATE PREVIEW (For color grading preview)
  // ═══════════════════════════════════════════════════════

  Future<Uint8List?> generateColorPreview({
    required String inputPath,
    required ColorGradeSettings settings,
    Duration? atPosition,
    int width = 640,
    int height = 360,
  }) async {
    if (!await _validateInputFile(inputPath)) {
      return null;
    }

    Directory? tempDir;

    try {
      tempDir = await getExternalStorageDirectory();
      final outputPath = p.join(
        tempDir!.path,
        'preview_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final position = atPosition ?? Duration.zero;
      final filters = settings.isDefault
          ? ''
          : ',${_buildColorFilters(settings)}';

      final command =
          '-y -ss ${_formatDuration(position)} -i "$inputPath" -vframes 1 -vf "scale=$width:$height$filters" -q:v 2 "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await file.delete();
          return bytes;
        }
      }
    } catch (e) {
      debugPrint('❌ Preview generation error: $e');
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VIDEO INFORMATION
  // ═══════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getVideoInfo(String inputPath) async {
    if (!await _validateInputFile(inputPath)) {
      return null;
    }

    try {
      final session = await FFprobeKit.getMediaInformation(inputPath);
      final info = session.getMediaInformation();

      if (info == null) return null;

      final streams = info.getStreams();
      Map<String, dynamic>? videoStream;
      Map<String, dynamic>? audioStream;

      for (final stream in streams) {
        final type = stream.getType();
        final props = stream.getAllProperties();

        if (props == null) continue;

        final castedProps = Map<String, dynamic>.from(props);

        if (type == 'video' && videoStream == null) {
          videoStream = castedProps;
        } else if (type == 'audio' && audioStream == null) {
          audioStream = castedProps;
        }
      }

      return {
        'duration': info.getDuration(),
        'size': info.getSize(),
        'bitrate': info.getBitrate(),
        'format': info.getFormat(),
        'video': videoStream,
        'audio': audioStream,
      };
    } catch (e) {
      debugPrint('❌ Get video info error: $e');
      return null;
    }
  }

  Future<Duration?> _getVideoDuration(String inputPath) async {
    try {
      final info = await getVideoInfo(inputPath);
      if (info != null && info['duration'] != null) {
        final durationStr = info['duration'] as String;
        final seconds = double.tryParse(durationStr);
        if (seconds != null) {
          return Duration(milliseconds: (seconds * 1000).toInt());
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not get duration: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPER METHODS
  // ═══════════════════════════════════════════════════════

  Future<bool> _validateInputFile(String inputPath) async {
    try {
      final file = File(inputPath);
      if (!await file.exists()) {
        debugPrint('❌ Input file does not exist: $inputPath');
        return false;
      }

      final stat = await file.stat();
      if (stat.size == 0) {
        debugPrint('❌ Input file is empty: $inputPath');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ File validation error: $e');
      return false;
    }
  }

  Future<String?> _getOutputPath(
    String? providedPath,
    String prefix,
    String extension,
  ) async {
    try {
      if (providedPath != null) {
        final dir = Directory(p.dirname(providedPath));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return providedPath;
      }

      final outputDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory(p.join(outputDir.path, 'processed_videos'));
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      return p.join(videosDir.path, '${prefix}_${_uuid.v4()}.$extension');
    } catch (e) {
      debugPrint('❌ Could not create output path: $e');
      return null;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }

  void _setupProgressCallback(
    Duration? duration,
    Function(double)? onProgress,
  ) {
    if (duration == null || onProgress == null) return;

    try {
      FFmpegKitConfig.enableStatisticsCallback((statistics) {
        try {
          final time = statistics.getTime();
          if (time > 0 && duration.inMilliseconds > 0) {
            final progress = (time / duration.inMilliseconds).clamp(0.0, 1.0);
            onProgress(progress);
            if (!_progressController.isClosed) {
              _progressController.add(progress);
            }
          }
        } catch (e) {
          // Ignore statistics errors
        }
      });
    } catch (e) {
      debugPrint('⚠️ Could not setup progress callback: $e');
    }
  }

  void _clearProgressCallback() {
    try {
      FFmpegKitConfig.enableStatisticsCallback(null);
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _cleanupFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🧹 Cleaned up: $path');
      }
    } catch (e) {
      debugPrint('⚠️ Cleanup error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DISPOSE
  // ═══════════════════════════════════════════════════════

  void dispose() {
    cancelCurrentOperation();
    if (!_progressController.isClosed) {
      _progressController.close();
    }
  }
}
