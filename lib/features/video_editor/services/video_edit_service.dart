import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';

import '../models/video_edit_settings.dart';
import 'package:slideup/core/utils/safe_async.dart';
import 'package:slideup/core/utils/isolate_helper.dart';

// ═══════════════════════════════════════════════════════
// ✅ VIDEO INFO MODEL
// ═══════════════════════════════════════════════════════

@immutable
class VideoInfo {
  final Duration duration;
  final int width;
  final int height;
  final double fps;
  final int bitrate;
  final String codec;
  final String format;
  final int fileSize;
  final bool hasAudio;
  final String? audioCodec;
  final int? audioBitrate;
  final int? audioSampleRate;

  const VideoInfo({
    required this.duration,
    required this.width,
    required this.height,
    required this.fps,
    required this.bitrate,
    required this.codec,
    required this.format,
    required this.fileSize,
    this.hasAudio = true,
    this.audioCodec,
    this.audioBitrate,
    this.audioSampleRate,
  });

  String get resolution => '${width}x$height';

  String get aspectRatio {
    final gcd = _gcd(width, height);
    if (gcd == 0) return '16:9';
    return '${width ~/ gcd}:${height ~/ gcd}';
  }

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toJson() => {
    'duration': duration.inMilliseconds,
    'width': width,
    'height': height,
    'fps': fps,
    'bitrate': bitrate,
    'codec': codec,
    'format': format,
    'fileSize': fileSize,
    'hasAudio': hasAudio,
    'audioCodec': audioCodec,
    'audioBitrate': audioBitrate,
    'audioSampleRate': audioSampleRate,
  };

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      duration: Duration(milliseconds: json['duration'] as int? ?? 0),
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      fps: (json['fps'] as num?)?.toDouble() ?? 0.0,
      bitrate: json['bitrate'] as int? ?? 0,
      codec: json['codec'] as String? ?? '',
      format: json['format'] as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      hasAudio: json['hasAudio'] as bool? ?? true,
      audioCodec: json['audioCodec'] as String?,
      audioBitrate: json['audioBitrate'] as int?,
      audioSampleRate: json['audioSampleRate'] as int?,
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ VIDEO EDIT ERROR
// ═══════════════════════════════════════════════════════

enum VideoEditErrorType {
  fileNotFound,
  invalidInput,
  processingFailed,
  cancelled,
  timeout,
  insufficientStorage,
  codecNotSupported,
  unknown,
}

class VideoEditError implements Exception {
  final VideoEditErrorType type;
  final String message;
  final String? details;
  final Object? originalError;
  final StackTrace? stackTrace;

  const VideoEditError({
    required this.type,
    required this.message,
    this.details,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() =>
      'VideoEditError($type): $message${details != null ? ' - $details' : ''}';

  factory VideoEditError.fileNotFound(String path) => VideoEditError(
    type: VideoEditErrorType.fileNotFound,
    message: 'File not found',
    details: path,
  );

  factory VideoEditError.invalidInput(String reason) => VideoEditError(
    type: VideoEditErrorType.invalidInput,
    message: 'Invalid input',
    details: reason,
  );

  factory VideoEditError.processingFailed(String operation, [Object? error]) =>
      VideoEditError(
        type: VideoEditErrorType.processingFailed,
        message: 'Processing failed',
        details: operation,
        originalError: error,
      );

  factory VideoEditError.cancelled() => const VideoEditError(
    type: VideoEditErrorType.cancelled,
    message: 'Operation cancelled',
  );

  factory VideoEditError.timeout(Duration duration) => VideoEditError(
    type: VideoEditErrorType.timeout,
    message: 'Operation timed out',
    details: '${duration.inSeconds}s',
  );
}

// ═══════════════════════════════════════════════════════
// ✅ VIDEO EDIT SERVICE
// ═══════════════════════════════════════════════════════

class VideoEditService {
  static final VideoEditService _instance = VideoEditService._internal();
  factory VideoEditService() => _instance;
  VideoEditService._internal();

  static const Duration _defaultTimeout = Duration(minutes: 30);
  static const int _maxRetries = 2;

  final _uuid = const Uuid();
  FFmpegSession? _currentSession;
  CancellableOperation<String>? _currentOperation;

  bool _isProcessing = false;
  bool _isCancelled = false;
  bool _isInitialized = false;

  final _progressController = StreamController<double>.broadcast();
  final _errorController = StreamController<VideoEditError>.broadcast();

  Stream<double> get progressStream => _progressController.stream;
  Stream<VideoEditError> get errorStream => _errorController.stream;
  bool get isProcessing => _isProcessing;
  bool get isInitialized => _isInitialized;

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> initialize() async {
    if (_isInitialized) return Result.success(null);

    return SafeAsync.run(() async {
      await IsolateHelper.instance.initialize(poolSize: 2);
      _isInitialized = true;
      debugPrint('✅ VideoEditService initialized');
    }, operationName: 'VideoEditService.initialize');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CANCEL OPERATION
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> cancelCurrentOperation() async {
    return SafeAsync.run(() async {
      _isCancelled = true;
      _currentOperation?.cancel();

      if (_currentSession != null) {
        await FFmpegKit.cancel(_currentSession!.getSessionId());
        _currentSession = null;
      }

      _isProcessing = false;
      debugPrint('✅ Operation cancelled');
    }, operationName: 'VideoEditService.cancel');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TRIM VIDEO
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> trimVideo({
    required String inputPath,
    required Duration startTime,
    required Duration endTime,
    String? outputPath,
    ExportPreset? preset,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        VideoEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    if (startTime >= endTime) {
      return Result.failure(
        VideoEditError.invalidInput('Start time must be before end time'),
      );
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        final ext = preset?.extension ?? 'mp4';
        final outputResult = await _getOutputPath('trimmed', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

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
          throw VideoEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Trimmed: $output');
          return output;
        }

        await _cleanupFile(output);
        throw VideoEditError.processingFailed('Trim operation failed');
      },
      operationName: 'trimVideo',
      timeout: _defaultTimeout,
      retryCount: _maxRetries,
      shouldRetry: (error) => _shouldRetryError(error),
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXPORT WITH PRESET
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> exportWithPreset({
    required String inputPath,
    required ExportPreset preset,
    Duration? trimStart,
    Duration? trimEnd,
    ColorGradeSettings? colorGrade,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        VideoEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        final outputResult = await _getOutputPath('export', preset.extension);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        final command = await _buildExportCommand(
          inputPath: inputPath,
          output: output,
          preset: preset,
          trimStart: trimStart,
          trimEnd: trimEnd,
          colorGrade: colorGrade,
        );

        debugPrint('📤 Export: $command');

        final durationResult = await _getVideoDuration(inputPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw VideoEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Exported: $output');
          return output;
        }

        await _cleanupFile(output);
        throw VideoEditError.processingFailed('Export failed');
      },
      operationName: 'exportWithPreset',
      timeout: _defaultTimeout,
      retryCount: 1,
    ).whenComplete(() => _stopProcessing());
  }

  Future<String> _buildExportCommand({
    required String inputPath,
    required String output,
    required ExportPreset preset,
    Duration? trimStart,
    Duration? trimEnd,
    ColorGradeSettings? colorGrade,
  }) async {
    final commandParts = <String>['-y'];

    if (trimStart != null) {
      commandParts.add('-ss ${_formatDuration(trimStart)}');
    }

    commandParts.add('-i "$inputPath"');

    if (trimEnd != null && trimStart != null) {
      final duration = trimEnd - trimStart;
      commandParts.add('-t ${_formatDuration(duration)}');
    }

    // Build filters in isolate for complex operations
    final filtersResult = await IsolateHelper.instance.compute(
      _buildFiltersIsolate,
      _FilterParams(preset: preset, colorGrade: colorGrade),
    );

    final filters = filtersResult.getOrElse(<String>[]);
    if (filters.isNotEmpty) {
      commandParts.add('-vf "${filters.join(',')}"');
    }

    if (preset.quality != VideoQuality.original) {
      commandParts.add('-c:v libx264 -preset medium');
      if (preset.bitrate != null) {
        commandParts.add('-b:v ${preset.bitrate}k');
      }
    } else {
      commandParts.add('-c:v copy');
    }

    if (preset.removeAudio) {
      commandParts.add('-an');
    } else {
      commandParts.add('-c:a aac -b:a ${preset.audioBitrate ?? 128}k');
    }

    commandParts.add('"$output"');

    return commandParts.join(' ');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MERGE VIDEOS
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> mergeVideos({
    required List<MergeItem> items,
    ExportPreset? preset,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        VideoEditError.invalidInput('Another operation in progress'),
      );
    }

    if (items.isEmpty) {
      return Result.failure(VideoEditError.invalidInput('No items to merge'));
    }

    _startProcessing();

    Directory? tempDir;

    return SafeAsync.run(
      () async {
        final outputResult = await _getOutputPath(
          'merged',
          preset?.extension ?? 'mp4',
        );
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        tempDir = await _createTempDir('merge');
        final listFile = File(p.join(tempDir!.path, 'list.txt'));
        final processedFiles = <String>[];

        for (int i = 0; i < items.length; i++) {
          if (_isCancelled) throw VideoEditError.cancelled();

          final item = items[i];
          onProgress?.call(i / items.length * 0.8);

          if (item.type == MediaType.video) {
            final processedPath = await _processVideoForMerge(
              item,
              tempDir!.path,
              i,
            );
            if (processedPath != null) {
              processedFiles.add(processedPath);
            }
          } else if (item.type == MediaType.image) {
            final imageVideo = await _imageToVideo(
              item.path,
              item.duration ?? const Duration(seconds: 3),
              tempDir!.path,
              i,
            );
            if (imageVideo.isSuccess) {
              processedFiles.add(imageVideo.requireData);
            }
          }
        }

        if (processedFiles.isEmpty) {
          throw VideoEditError.processingFailed('No files processed for merge');
        }

        final listContent = processedFiles.map((f) => "file '$f'").join('\n');
        await listFile.writeAsString(listContent);

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

        throw VideoEditError.processingFailed('Merge failed');
      },
      operationName: 'mergeVideos',
      timeout: const Duration(hours: 1),
    ).whenComplete(() async {
      _stopProcessing();
      if (tempDir != null) {
        await SafeAsync.run(
          () => tempDir!.delete(recursive: true),
          operationName: 'cleanup_merge_temp',
        );
      }
    });
  }

  Future<String?> _processVideoForMerge(
    MergeItem item,
    String tempPath,
    int index,
  ) async {
    if (item.trimStart != null || item.trimEnd != null) {
      final result = await _trimForMerge(
        item.path,
        item.trimStart ?? Duration.zero,
        item.trimEnd ?? item.duration ?? Duration.zero,
        tempPath,
        index,
      );
      return result.getOrNull();
    }
    return item.path;
  }

  Future<Result<String>> _trimForMerge(
    String input,
    Duration start,
    Duration end,
    String tempPath,
    int index,
  ) async {
    return SafeAsync.run(() async {
      final output = p.join(tempPath, 'segment_$index.mp4');
      final startStr = _formatDuration(start);
      final durationStr = _formatDuration(end - start);

      final command =
          '-y -ss $startStr -i "$input" -t $durationStr -c copy "$output"';
      final session = await FFmpegKit.execute(command);

      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        return output;
      }
      throw VideoEditError.processingFailed('Trim for merge failed');
    }, operationName: 'trimForMerge');
  }

  Future<Result<String>> _imageToVideo(
    String imagePath,
    Duration duration,
    String tempPath,
    int index,
  ) async {
    return SafeAsync.run(() async {
      final output = p.join(tempPath, 'image_$index.mp4');
      final durationSec = duration.inMilliseconds / 1000;

      final command =
          '-y -loop 1 -i "$imagePath" -c:v libx264 -t $durationSec -pix_fmt yuv420p '
          '-vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" "$output"';

      final session = await FFmpegKit.execute(command);

      if (ReturnCode.isSuccess(await session.getReturnCode())) {
        return output;
      }
      throw VideoEditError.processingFailed('Image to video conversion failed');
    }, operationName: 'imageToVideo');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ADD AUDIO TO VIDEO
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> addAudioToVideo({
    required String videoPath,
    required String audioPath,
    bool replaceOriginal = false,
    double audioVolume = 1.0,
    double originalVolume = 1.0,
    Duration? audioStart,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        VideoEditError.invalidInput('Another operation in progress'),
      );
    }

    final videoValidation = await _validateInputFile(videoPath);
    if (videoValidation.isFailure) {
      return Result.failure(videoValidation.error!);
    }

    final audioValidation = await _validateInputFile(audioPath);
    if (audioValidation.isFailure) {
      return Result.failure(audioValidation.error!);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        final outputResult = await _getOutputPath('audio_added', 'mp4');
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        String command;

        if (replaceOriginal) {
          command =
              '-y -i "$videoPath" -i "$audioPath" -c:v copy -map 0:v:0 -map 1:a:0 -shortest "$output"';
        } else {
          final audioStartSec = (audioStart?.inMilliseconds ?? 0) / 1000;
          command =
              '-y -i "$videoPath" -i "$audioPath" -filter_complex '
              '"[0:a]volume=$originalVolume[a0];[1:a]adelay=${(audioStartSec * 1000).toInt()}|${(audioStartSec * 1000).toInt()},volume=$audioVolume[a1];[a0][a1]amix=inputs=2:duration=first[aout]" '
              '-map 0:v -map "[aout]" -c:v copy "$output"';
        }

        debugPrint('🎵 Add audio: $command');

        final durationResult = await _getVideoDuration(videoPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw VideoEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Audio added: $output');
          return output;
        }

        await _cleanupFile(output);
        throw VideoEditError.processingFailed('Add audio failed');
      },
      operationName: 'addAudioToVideo',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXTRACT AUDIO
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> extractAudio({
    required String inputPath,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        VideoEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        final ext = _getAudioExtension(format);
        final outputResult = await _getOutputPath('audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        final codec = _getAudioCodec(format, bitrate);
        final command = '-y -i "$inputPath" -vn $codec "$output"';

        debugPrint('🎵 Extract audio: $command');

        final durationResult = await _getVideoDuration(inputPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw VideoEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Audio extracted: $output');
          return output;
        }

        await _cleanupFile(output);
        throw VideoEditError.processingFailed('Extract audio failed');
      },
      operationName: 'extractAudio',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  String _getAudioExtension(AudioFormat format) {
    switch (format) {
      case AudioFormat.mp3:
        return 'mp3';
      case AudioFormat.aac:
        return 'aac';
      case AudioFormat.wav:
        return 'wav';
      case AudioFormat.flac:
        return 'flac';
      case AudioFormat.ogg:
        return 'ogg';
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
      case AudioFormat.mp3:
        return '-c:a libmp3lame -b:a ${bitrate}k';
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ COLOR GRADING
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> applyColorGrading({
    required String inputPath,
    required ColorGradeSettings settings,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        VideoEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    if (settings.isDefault) {
      return Result.success(inputPath);
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        final outputResult = await _getOutputPath('graded', 'mp4');
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        final filtersResult = await IsolateHelper.instance.compute(
          _buildColorFiltersIsolate,
          settings,
        );
        final filters = filtersResult.getOrElse('null');

        final command = '-y -i "$inputPath" -vf "$filters" -c:a copy "$output"';

        debugPrint('🎨 Color grade: $command');

        final durationResult = await _getVideoDuration(inputPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw VideoEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Color grading applied: $output');
          return output;
        }

        await _cleanupFile(output);
        throw VideoEditError.processingFailed('Color grading failed');
      },
      operationName: 'applyColorGrading',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXTRACT FRAMES
  // ═══════════════════════════════════════════════════════

  Future<Result<List<Uint8List>>> extractFrames({
    required String inputPath,
    Duration? startTime,
    Duration? endTime,
    int fps = 1,
    int width = 320,
    int height = 180,
    int maxFrames = 50,
    void Function(double)? onProgress,
  }) async {
    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    Directory? tempDir;

    return SafeAsync.run(
      () async {
        tempDir = await _createTempDir('frames');

        final cmdParts = <String>['-y'];
        if (startTime != null) {
          cmdParts.add('-ss ${_formatDuration(startTime)}');
        }
        cmdParts.add('-i "$inputPath"');
        if (endTime != null && startTime != null) {
          cmdParts.add('-t ${_formatDuration(endTime - startTime)}');
        }
        cmdParts.add('-vf "fps=$fps,scale=$width:$height"');
        cmdParts.add('-vframes $maxFrames');
        cmdParts.add('"${tempDir!.path}/frame_%04d.jpg"');

        final session = await FFmpegKit.execute(cmdParts.join(' '));

        if (!ReturnCode.isSuccess(await session.getReturnCode())) {
          throw VideoEditError.processingFailed('Frame extraction failed');
        }

        final files = await tempDir!.list().toList();
        files.sort((a, b) => a.path.compareTo(b.path));

        final frames = <Uint8List>[];

        for (int i = 0; i < files.length; i++) {
          if (files[i] is File && files[i].path.endsWith('.jpg')) {
            final bytes = await (files[i] as File).readAsBytes();
            frames.add(bytes);
          }
          onProgress?.call((i + 1) / files.length);
        }

        return frames;
      },
      operationName: 'extractFrames',
      timeout: const Duration(minutes: 10),
    ).whenComplete(() async {
      if (tempDir != null) {
        await SafeAsync.run(
          () => tempDir!.delete(recursive: true),
          operationName: 'cleanup_frames_temp',
        );
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CREATE CLIP FROM MARKER
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> createClipFromMarker({
    required String inputPath,
    required ClipMarker marker,
    ExportPreset? preset,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    String? trimmedPath;

    return SafeAsync.run(
      () async {
        final trimResult = await trimVideo(
          inputPath: inputPath,
          startTime: marker.startTime,
          endTime: marker.endTime,
          preset: preset,
          onProgress: (p) => onProgress?.call(p * 0.5),
        );

        if (trimResult.isFailure) {
          throw trimResult.error!;
        }

        trimmedPath = trimResult.requireData;

        if (marker.colorGrade != null && !marker.colorGrade!.isDefault) {
          final gradedResult = await applyColorGrading(
            inputPath: trimmedPath!,
            settings: marker.colorGrade!,
            outputPath: outputPath,
            onProgress: (p) => onProgress?.call(0.5 + p * 0.5),
          );

          if (gradedResult.isSuccess) {
            final gradedPath = gradedResult.requireData;
            if (gradedPath != trimmedPath) {
              await _cleanupFile(trimmedPath!);
            }
            return gradedPath;
          }
        }

        return trimmedPath!;
      },
      operationName: 'createClipFromMarker',
      timeout: _defaultTimeout,
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ FILE OPERATIONS
  // ═══════════════════════════════════════════════════════

  Future<Result<bool>> deleteFile(String path) async {
    return SafeAsync.run(() async {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    }, operationName: 'deleteFile');
  }

  Future<Result<String>> renameFile(String path, String newName) async {
    return SafeAsync.run(() async {
      final file = File(path);
      if (!await file.exists()) {
        throw VideoEditError.fileNotFound(path);
      }

      final dir = p.dirname(path);
      final ext = p.extension(path);
      final newPath = p.join(dir, '$newName$ext');
      await file.rename(newPath);
      return newPath;
    }, operationName: 'renameFile');
  }

  Future<Result<void>> shareFile(String path) async {
    return SafeAsync.run(() async {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out this file!',
          subject: 'Shared File',
          files: [XFile(path)],
        ),
      );
    }, operationName: 'shareFile');
  }

  Future<Result<List<MediaItem>>> getLibraryItems() async {
    return SafeAsync.run(() async {
      final items = <MediaItem>[];

      final outputDir = await getExternalStorageDirectory();
      if (outputDir == null) {
        return items;
      }

      final videosDir = Directory(p.join(outputDir.path, 'processed_videos'));

      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
        return items;
      }

      await for (final entity in videosDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final ext = p.extension(entity.path).toLowerCase();

          MediaType? type;
          if (['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext)) {
            type = MediaType.video;
          } else if (['.mp3', '.aac', '.wav', '.flac', '.ogg'].contains(ext)) {
            type = MediaType.audio;
          } else if (['.jpg', '.jpeg', '.png', '.gif'].contains(ext)) {
            type = MediaType.image;
          }

          if (type != null) {
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
      }

      // Sort in isolate for large lists
      if (items.length > 100) {
        final sortedResult = await IsolateHelper.instance.compute(
          (List<MediaItem> list) =>
              list..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          items,
        );
        return sortedResult.getOrElse(items);
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    }, operationName: 'getLibraryItems');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VIDEO INFO
  // ═══════════════════════════════════════════════════════

  Future<Result<VideoInfo>> getVideoInfo(String inputPath) async {
    return SafeAsync.run(() async {
      final session = await FFprobeKit.getMediaInformation(inputPath);
      final info = session.getMediaInformation();

      if (info == null) {
        throw VideoEditError.processingFailed('Could not get video info');
      }

      return _parseMediaInformation(info, inputPath);
    }, operationName: 'getVideoInfo');
  }

  Future<VideoInfo> _parseMediaInformation(
    MediaInformation info,
    String path,
  ) async {
    final durationStr = info.getDuration();
    final duration = durationStr != null
        ? Duration(milliseconds: (double.parse(durationStr) * 1000).toInt())
        : Duration.zero;

    int width = 0;
    int height = 0;
    double fps = 0;
    String codec = '';
    bool hasAudio = false;
    String? audioCodec;

    final streams = info.getStreams();
    for (final stream in streams) {
      final type = stream.getType();
      if (type == 'video' && width == 0) {
        width = stream.getWidth() ?? 0;
        height = stream.getHeight() ?? 0;
        codec = stream.getCodec() ?? '';

        final fpsStr = stream.getRealFrameRate();
        if (fpsStr != null && fpsStr.contains('/')) {
          final parts = fpsStr.split('/');
          if (parts.length == 2) {
            final num = int.tryParse(parts[0]) ?? 0;
            final den = int.tryParse(parts[1]) ?? 1;
            fps = den != 0 ? num / den : 0;
          }
        }
      } else if (type == 'audio') {
        hasAudio = true;
        audioCodec = stream.getCodec();
      }
    }

    final bitrateStr = info.getBitrate();
    final bitrate = bitrateStr != null ? int.tryParse(bitrateStr) ?? 0 : 0;

    final file = File(path);
    final fileSize = await file.length();

    return VideoInfo(
      duration: duration,
      width: width,
      height: height,
      fps: fps,
      bitrate: bitrate ~/ 1000,
      codec: codec,
      format: info.getFormat() ?? '',
      fileSize: fileSize,
      hasAudio: hasAudio,
      audioCodec: audioCodec,
    );
  }

  Future<Result<Duration>> _getVideoDuration(String inputPath) async {
    return SafeAsync.run(() async {
      final infoResult = await getVideoInfo(inputPath);
      if (infoResult.isSuccess) {
        return infoResult.requireData.duration;
      }
      return Duration.zero;
    }, operationName: '_getVideoDuration');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> _validateInputFile(String path) async {
    return SafeAsync.run(() async {
      final file = File(path);
      if (!await file.exists()) {
        throw VideoEditError.fileNotFound(path);
      }
      final stat = await file.stat();
      if (stat.size == 0) {
        throw VideoEditError.invalidInput('File is empty');
      }
    }, operationName: '_validateInputFile');
  }

  Future<Result<String>> _getOutputPath(String prefix, String ext) async {
    return SafeAsync.run(() async {
      final outputDir = await getExternalStorageDirectory();
      if (outputDir == null) {
        throw VideoEditError.processingFailed('Cannot access storage');
      }

      final videosDir = Directory(p.join(outputDir.path, 'processed_videos'));
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      return p.join(videosDir.path, '${prefix}_${_uuid.v4()}.$ext');
    }, operationName: '_getOutputPath');
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
    void Function(double)? onProgress,
  ) {
    if (duration == null || onProgress == null) return;

    try {
      FFmpegKitConfig.enableStatisticsCallback((stats) {
        final time = stats.getTime();
        if (time > 0 && duration.inMilliseconds > 0) {
          final progress = (time / duration.inMilliseconds).clamp(0.0, 1.0);
          onProgress(progress);
          if (!_progressController.isClosed) {
            _progressController.add(progress);
          }
        }
      });
    } catch (e) {
      debugPrint('⚠️ Progress callback setup error: $e');
    }
  }

  void _clearProgressCallback() {
    try {
      FFmpegKitConfig.enableStatisticsCallback(null);
    } catch (_) {}
  }

  Future<void> _cleanupFile(String path) async {
    await SafeAsync.run(() async {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }, operationName: '_cleanupFile');
  }

  void _startProcessing() {
    _isProcessing = true;
    _isCancelled = false;
  }

  void _stopProcessing() {
    _isProcessing = false;
    _currentSession = null;
  }

  /* void _emitError(VideoEditError error) {
    if (!_errorController.isClosed) {
      _errorController.add(error);
    }
    debugPrint('❌ VideoEditService Error: $error');
  } */

  bool _shouldRetryError(Object error) {
    if (error is VideoEditError) {
      switch (error.type) {
        case VideoEditErrorType.cancelled:
        case VideoEditErrorType.invalidInput:
        case VideoEditErrorType.fileNotFound:
          return false;
        default:
          return true;
      }
    }
    return false;
  }

  void dispose() {
    cancelCurrentOperation();
    if (!_progressController.isClosed) {
      _progressController.close();
    }
    if (!_errorController.isClosed) {
      _errorController.close();
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ ISOLATE-SAFE FUNCTIONS (Top-level)
// ═══════════════════════════════════════════════════════

class _FilterParams {
  final ExportPreset preset;
  final ColorGradeSettings? colorGrade;

  const _FilterParams({required this.preset, this.colorGrade});
}

List<String> _buildFiltersIsolate(_FilterParams params) {
  final filters = <String>[];
  final preset = params.preset;
  final colorGrade = params.colorGrade;

  if (preset.width != null && preset.height != null) {
    filters.add(
      'scale=${preset.width}:${preset.height}:force_original_aspect_ratio=decrease,pad=${preset.width}:${preset.height}:(ow-iw)/2:(oh-ih)/2',
    );
  }

  if (preset.fps != null) {
    filters.add('fps=${preset.fps}');
  }

  if (colorGrade != null && !colorGrade.isDefault) {
    filters.add(_buildColorFiltersIsolate(colorGrade));
  }

  return filters;
}

String _buildColorFiltersIsolate(ColorGradeSettings s) {
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

  if (s.highlights != 0.0 || s.shadows != 0.0) {
    final shadowVal = (1.0 + s.shadows).clamp(0.5, 1.5);
    final highlightVal = (1.0 - s.highlights).clamp(0.5, 1.5);
    filters.add(
      'curves=m=0/0 0.25/${0.25 * shadowVal} 0.75/${0.75 * highlightVal} 1/1',
    );
  }

  if (s.chromaKeyEnabled) {
    filters.add('chromakey=color=0x${_rgbHexIsolate(s.chromaKeyColor)}:similarity=${s.chromaKeySimilarity}');
  }

  return filters.isEmpty ? 'null' : filters.join(',');
}

String _rgbHexIsolate(int argb) {
  final rgb = argb & 0xFFFFFF;
  return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
}
