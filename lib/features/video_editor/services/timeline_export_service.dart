import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/video_edit_settings.dart';
import 'package:slideup/core/utils/safe_async.dart';

// ═══════════════════════════════════════════════════════
// ✅ TIMELINE EXPORT MODELS
// ═══════════════════════════════════════════════════════

@immutable
class TimelineExportConfig {
  final VideoProject project;
  final ExportPreset preset;
  final bool includeTextOverlays;
  final bool includeImageOverlays;
  final bool includeAudioTracks;
  final bool applyColorGrading;
  final String? outputPath;

  const TimelineExportConfig({
    required this.project,
    required this.preset,
    this.includeTextOverlays = true,
    this.includeImageOverlays = true,
    this.includeAudioTracks = true,
    this.applyColorGrading = true,
    this.outputPath,
  });

  TimelineExportConfig copyWith({
    VideoProject? project,
    ExportPreset? preset,
    bool? includeTextOverlays,
    bool? includeImageOverlays,
    bool? includeAudioTracks,
    bool? applyColorGrading,
    String? outputPath,
  }) {
    return TimelineExportConfig(
      project: project ?? this.project,
      preset: preset ?? this.preset,
      includeTextOverlays: includeTextOverlays ?? this.includeTextOverlays,
      includeImageOverlays: includeImageOverlays ?? this.includeImageOverlays,
      includeAudioTracks: includeAudioTracks ?? this.includeAudioTracks,
      applyColorGrading: applyColorGrading ?? this.applyColorGrading,
      outputPath: outputPath ?? this.outputPath,
    );
  }
}

@immutable
class ExportStage {
  final String name;
  final double progress;
  final String? message;

  const ExportStage({required this.name, required this.progress, this.message});

  static const ExportStage preparing = ExportStage(
    name: 'Preparing',
    progress: 0.0,
    message: 'Analyzing timeline...',
  );

  static const ExportStage processingVideo = ExportStage(
    name: 'Processing Video',
    progress: 0.2,
    message: 'Applying effects...',
  );

  static const ExportStage renderingOverlays = ExportStage(
    name: 'Rendering Overlays',
    progress: 0.5,
    message: 'Adding text and images...',
  );

  static const ExportStage mixingAudio = ExportStage(
    name: 'Mixing Audio',
    progress: 0.7,
    message: 'Processing audio tracks...',
  );

  static const ExportStage encoding = ExportStage(
    name: 'Encoding',
    progress: 0.9,
    message: 'Finalizing export...',
  );

  static const ExportStage completed = ExportStage(
    name: 'Completed',
    progress: 1.0,
    message: 'Export successful',
  );
}

// ═══════════════════════════════════════════════════════
// ✅ TIMELINE EXPORT ERROR
// ═══════════════════════════════════════════════════════

enum TimelineExportErrorType {
  invalidProject,
  missingAssets,
  processingFailed,
  cancelled,
  timeout,
  insufficientStorage,
  unknown,
}

class TimelineExportError implements Exception {
  final TimelineExportErrorType type;
  final String message;
  final String? details;
  final Object? originalError;

  const TimelineExportError({
    required this.type,
    required this.message,
    this.details,
    this.originalError,
  });

  @override
  String toString() =>
      'TimelineExportError($type): $message${details != null ? ' - $details' : ''}';

  factory TimelineExportError.invalidProject(String reason) =>
      TimelineExportError(
        type: TimelineExportErrorType.invalidProject,
        message: 'Invalid project',
        details: reason,
      );

  factory TimelineExportError.missingAssets(List<String> assets) =>
      TimelineExportError(
        type: TimelineExportErrorType.missingAssets,
        message: 'Missing required assets',
        details: assets.join(', '),
      );

  factory TimelineExportError.processingFailed(
    String operation, [
    Object? error,
  ]) => TimelineExportError(
    type: TimelineExportErrorType.processingFailed,
    message: 'Export processing failed',
    details: operation,
    originalError: error,
  );

  factory TimelineExportError.cancelled() => const TimelineExportError(
    type: TimelineExportErrorType.cancelled,
    message: 'Export cancelled',
  );
}

// ═══════════════════════════════════════════════════════
// ✅ TIMELINE EXPORT SERVICE
// ═══════════════════════════════════════════════════════

class TimelineExportService {
  static final TimelineExportService _instance =
      TimelineExportService._internal();
  factory TimelineExportService() => _instance;
  TimelineExportService._internal();

  static const Duration _defaultTimeout = Duration(hours: 2);

  final _uuid = const Uuid();
  FFmpegSession? _currentSession;
  bool _isProcessing = false;
  bool _isCancelled = false;

  final _progressController = StreamController<double>.broadcast();
  final _stageController = StreamController<ExportStage>.broadcast();

  Stream<double> get progressStream => _progressController.stream;
  Stream<ExportStage> get stageStream => _stageController.stream;
  bool get isProcessing => _isProcessing;

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> initialize() async {
    return SafeAsync.run(() async {
      debugPrint('✅ TimelineExportService initialized');
    }, operationName: 'TimelineExportService.initialize');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CANCEL OPERATION
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> cancelCurrentOperation() async {
    return SafeAsync.run(() async {
      _isCancelled = true;
      if (_currentSession != null) {
        await FFmpegKit.cancel(_currentSession!.getSessionId());
        _currentSession = null;
      }
      _isProcessing = false;
      debugPrint('✅ Timeline export cancelled');
    }, operationName: 'TimelineExportService.cancel');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXPORT TIMELINE (Main Method)
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> exportTimeline({
    required TimelineExportConfig config,
    void Function(double)? onProgress,
    void Function(ExportStage)? onStageChange,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        TimelineExportError.invalidProject('Another export in progress'),
      );
    }

    // Validate project
    final validationResult = await _validateProject(config.project);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    _startProcessing();

    Directory? tempDir;

    return SafeAsync.run(
      () async {
        _emitStage(ExportStage.preparing, onStageChange);
        onProgress?.call(0.0);

        // Create temp directory
        tempDir = await _createTempDir('timeline_export');

        // Get output path first
        final outputPath =
            config.outputPath ??
            await _getDefaultOutputPath(config.preset.extension);

        // Build FFmpeg command
        // Route to the Hybrid Magnetic Timeline xfade pipeline when the
        // project has primaryVideoClips; otherwise use legacy single-clip path.
        Result<String> commandResult;
        if (config.project.isMagneticMode) {
          commandResult = await _buildMagneticTrackCommand(
            config: config,
            tempDir: tempDir!,
            outputPath: outputPath,
            onProgress: onProgress,
            onStageChange: onStageChange,
          );
        } else {
          commandResult = await _buildTimelineCommand(
            config: config,
            tempDir: tempDir!,
            outputPath: outputPath,
            onProgress: onProgress,
            onStageChange: onStageChange,
          );
        }

        if (commandResult.isFailure) {
          throw commandResult.error!;
        }

        final command = commandResult.requireData;

        debugPrint('🎬 FFmpeg Command: $command');
        debugPrint('📁 Output Path: $outputPath');

        _emitStage(ExportStage.encoding, onStageChange);

        // Execute FFmpeg with better error handling
        final execResult = await _executeFFmpegCommand(
          command: command,
          outputPath: outputPath,
          duration: config.project.effectiveDuration,
          onProgress: onProgress,
        );

        if (execResult.isFailure) {
          throw execResult.error!;
        }

        _emitStage(ExportStage.completed, onStageChange);
        onProgress?.call(1.0);

        debugPrint('✅ Timeline exported: $outputPath');
        return outputPath;
      },
      operationName: 'exportTimeline',
      timeout: _defaultTimeout,
    ).whenComplete(() async {
      _stopProcessing();
      if (tempDir != null && await tempDir!.exists()) {
        await SafeAsync.run(
          () => tempDir!.delete(recursive: true),
          operationName: 'cleanup_timeline_export_temp',
        );
      }
    });
  }

  // New method for executing FFmpeg with better error handling
  Future<Result<void>> _executeFFmpegCommand({
    required String command,
    required String outputPath,
    required Duration duration,
    void Function(double)? onProgress,
  }) async {
    return SafeAsync.run(() async {
      final completer = Completer<bool>();

      // Setup progress callback
      _setupProgressCallback(duration, onProgress);

      // Execute FFmpeg
      _currentSession = await FFmpegKit.executeAsync(
        command,
        (session) async {
          var success = false;
          try {
            final returnCode = await session.getReturnCode();
            success = ReturnCode.isSuccess(returnCode);

            if (!success) {
              // Get detailed error logs
              final logs = await session.getAllLogsAsString();
              final output = await session.getOutput();

              debugPrint('❌ FFmpeg failed with return code: $returnCode');
              debugPrint('📋 FFmpeg Output: $output');
              if (logs != null && logs.isNotEmpty) {
                debugPrint(
                  '📋 FFmpeg Logs: ${logs.length > 500 ? logs.substring(0, 500) : logs}',
                );
              }
            }
          } catch (e, stackTrace) {
            debugPrint('❌ FFmpeg session callback error: $e');
            debugPrint('Stack: $stackTrace');
          }

          if (!completer.isCompleted) {
            completer.complete(success);
          }
        },
        (log) {
          // Log FFmpeg messages for debugging
          final message = log.getMessage();
          if (message.contains('error') || message.contains('Error')) {
            debugPrint('❌ FFmpeg Error: $message');
          }
        },
      );

      // Wait for completion
      final success = await completer.future.timeout(
        const Duration(minutes: 30),
        onTimeout: () {
          debugPrint('⚠️ FFmpeg session callback timed out after 30 minutes');
          if (_isCancelled) {
            completer.complete(false);
            return false;
          }
          completer.complete(false);
          return false;
        },
      );

      // Clear callbacks
      _clearProgressCallback();

      if (_isCancelled) {
        throw TimelineExportError.cancelled();
      }

      if (!success) {
        final logs = await _currentSession?.getAllLogsAsString();
        final errorMsg = _extractErrorFromLogs(logs);
        throw TimelineExportError.processingFailed(
          'FFmpeg execution failed',
          errorMsg,
        );
      }

      // Verify output file exists
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw TimelineExportError.processingFailed(
          'Output file not created',
          'FFmpeg completed but output file is missing',
        );
      }

      final fileSize = await outputFile.length();
      if (fileSize == 0) {
        throw TimelineExportError.processingFailed(
          'Output file is empty',
          'FFmpeg created an empty file',
        );
      }

      debugPrint('✅ Output file created: ${fileSize ~/ 1024} KB');
    }, operationName: '_executeFFmpegCommand');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HYBRID MAGNETIC TIMELINE – XFADE EXPORT PIPELINE
  // ═══════════════════════════════════════════════════════

  /// Builds the FFmpeg command for Hybrid Magnetic Timeline mode.
  ///
  /// Strategy:
  /// - If all clips are "Cut" (no transitions) → fast `concat` demuxer path.
  /// - Otherwise → `xfade` filter_complex pipeline with overlay compositing.
  Future<Result<String>> _buildMagneticTrackCommand({
    required TimelineExportConfig config,
    required Directory tempDir,
    required String outputPath,
    void Function(double)? onProgress,
    void Function(ExportStage)? onStageChange,
  }) async {
    return SafeAsync.run(() async {
      final project = config.project;
      final preset = config.preset;
      final clips = project.primaryVideoClips;

      _emitStage(ExportStage.processingVideo, onStageChange);
      onProgress?.call(0.1);

      // Fast path: no transitions, use concat demuxer
      final allCuts = clips.every(
        (c) => c.transitionOut.type == TransitionType.none,
      );

      if (allCuts) {
        return _buildConcatDemuxerCommand(
          clips: clips,
          project: project,
          preset: preset,
          tempDir: tempDir,
          outputPath: outputPath,
          config: config,
          onProgress: onProgress,
          onStageChange: onStageChange,
        );
      }

      // xfade path: build -filter_complex with xfade between clips
      final inputs = <String>[];
      int inputIndex = 0;

      for (final clip in clips) {
        final path = _escapePath(clip.videoPath);
        final startSec = clip.trimStart.inMilliseconds / 1000.0;
        final endSec = clip.trimEnd.inMilliseconds / 1000.0;
        inputs.add('-ss $startSec -to $endSec -i $path');
        inputIndex++;
      }

      // Audio/image overlay inputs
      final audioItems = config.includeAudioTracks
          ? project.audioItems
          : <AudioTimelineItem>[];
      final imageItems = config.includeImageOverlays
          ? project.imageItems
          : <ImageTimelineItem>[];

      final audioInputIndices = <String, int>{};
      for (final item in audioItems) {
        if (item.audioPath.isNotEmpty && File(item.audioPath).existsSync()) {
          inputs.add('-i ${_escapePath(item.audioPath)}');
          audioInputIndices[item.id] = inputIndex++;
        }
      }

      final imageInputIndices = <String, int>{};
      for (final item in imageItems) {
        if (item.imagePath.isNotEmpty && File(item.imagePath).existsSync()) {
          inputs.add('-loop 1 -t 1 -i ${_escapePath(item.imagePath)}');
          imageInputIndices[item.id] = inputIndex++;
        }
      }

      _emitStage(ExportStage.renderingOverlays, onStageChange);
      onProgress?.call(0.4);

      final filters = <String>[];
      final targetWidth = preset.width ?? 1920;
      final targetHeight = preset.height ?? 1080;

      // Scale each clip to target resolution
      for (int i = 0; i < clips.length; i++) {
        filters.add(
          '[$i:v]scale=$targetWidth:$targetHeight:'
          'force_original_aspect_ratio=decrease,'
          'pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2,'
          'setsar=1,format=yuv420p[v${i}s]',
        );
      }

      // Chain xfade filters
      String videoStream = '[v0s]';
      Duration offset = clips[0].effectiveDuration;

      for (int i = 0; i < clips.length - 1; i++) {
        final transition = clips[i].transitionOut;
        final nextStream = '[v${i + 1}s]';
        final outLabel = i == clips.length - 2 ? '[vmain]' : '[xf$i]';
        final offsetSec = offset.inMilliseconds / 1000.0;

        if (transition.hasTransition) {
          final xfadeName = transition.type.ffmpegName ?? 'fade';
          final durationSec = transition.duration.inMilliseconds / 1000.0;
          filters.add(
            '$videoStream${nextStream}xfade='
            'transition=$xfadeName:'
            'duration=$durationSec:'
            'offset=${(offsetSec - durationSec).clamp(0.0, double.infinity)}'
            '$outLabel',
          );
          offset += clips[i + 1].effectiveDuration - transition.duration;
        } else {
          // Simple concat for this boundary
          filters.add('$videoStream${nextStream}concat=n=2:v=1:a=0$outLabel');
          offset += clips[i + 1].effectiveDuration;
        }
        videoStream = outLabel;
      }

      // Color grading on final combined stream
      if (config.applyColorGrading && !project.colorGrade.isDefault) {
        final colorFilter = _buildColorGradeFilter(project.colorGrade);
        if (colorFilter.isNotEmpty) {
          filters.add('$videoStream$colorFilter[graded]');
          videoStream = '[graded]';
        }
      }

      // Image overlays
      if (imageItems.isNotEmpty && config.includeImageOverlays) {
        videoStream = _buildImageOverlaysSimplified(
          baseStream: videoStream,
          imageItems: imageItems,
          imageInputIndices: imageInputIndices,
          filters: filters,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );
      }

      // Text overlays
      if (project.textItems.isNotEmpty && config.includeTextOverlays) {
        videoStream = _buildTextOverlaysSimplified(
          baseStream: videoStream,
          textItems: project.textItems,
          filters: filters,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );
      }

      filters.add('${videoStream}format=yuv420p[vout]');

      _emitStage(ExportStage.mixingAudio, onStageChange);
      onProgress?.call(0.7);

      // Audio: mix original audio from all clips + overlay audio tracks
      final audioFilters = <String>[];
      for (int i = 0; i < clips.length; i++) {
        audioFilters.add('[$i:a]');
      }
      final audioMixCount = clips.length + audioItems.length;
      for (final entry in audioInputIndices.entries) {
        final item = audioItems.firstWhere((a) => a.id == entry.key);
        final delaySec = item.startTime.inMilliseconds;
        audioFilters.add('[${entry.value}:a]adelay=$delaySec|$delaySec');
      }
      if (audioMixCount > 1) {
        filters.add(
          '${audioFilters.join('')}amix=inputs=$audioMixCount:duration=first'
          ':normalize=0[aout]',
        );
      }

      // Assemble command
      final commandParts = ['-y'];
      commandParts.addAll(inputs);
      commandParts.add('-filter_complex "${filters.join(';')}"');
      commandParts.add('-map "[vout]"');
      if (!preset.removeAudio) {
        commandParts.add(
          audioMixCount > 1 ? '-map "[aout]"' : '-map 0:a?',
        );
      }
      commandParts.add('-c:v libx264 -preset medium -crf 23');
      if (preset.bitrate != null) {
        commandParts
          ..add('-maxrate ${preset.bitrate}k')
          ..add('-bufsize ${preset.bitrate! * 2}k');
      }
      if (preset.fps != null) {
        commandParts.add('-r ${preset.fps}');
      }
      if (!preset.removeAudio) {
        commandParts.add(
          '-c:a aac -b:a ${preset.audioBitrate ?? 128}k',
        );
      }
      commandParts.add('-movflags +faststart');
      commandParts.add(_escapePath(outputPath));
      return commandParts.join(' ');
    }, operationName: '_buildMagneticTrackCommand');
  }

  /// Fast-path export using FFmpeg concat demuxer (no re-encode when
  /// all clips share the same codec/resolution as the output preset).
  Future<String> _buildConcatDemuxerCommand({
    required List<PrimaryVideoClip> clips,
    required VideoProject project,
    required ExportPreset preset,
    required Directory tempDir,
    required String outputPath,
    required TimelineExportConfig config,
    void Function(double)? onProgress,
    void Function(ExportStage)? onStageChange,
  }) async {
    // Write concat list file
    final listFile = File(p.join(tempDir.path, 'concat_list.txt'));
    final buffer = StringBuffer();
    for (final clip in clips) {
      buffer.writeln("file '${clip.videoPath.replaceAll("'", "'\\''")}'");
      final startSec = clip.trimStart.inMilliseconds / 1000.0;
      buffer.writeln('inpoint $startSec');
      final endSec = clip.trimEnd.inMilliseconds / 1000.0;
      buffer.writeln('outpoint $endSec');
    }
    await listFile.writeAsString(buffer.toString());

    _emitStage(ExportStage.renderingOverlays, onStageChange);
    onProgress?.call(0.5);

    final overlayFilters = <String>[];
    int inputIndex = 1; // 0 = concat output
    final imageItems = config.includeImageOverlays
        ? project.imageItems
        : <ImageTimelineItem>[];
    final audioItems = config.includeAudioTracks
        ? project.audioItems
        : <AudioTimelineItem>[];
    final imageInputIndices = <String, int>{};
    final audioInputIndices = <String, int>{};

    final extraInputs = <String>[];
    for (final item in imageItems) {
      if (item.imagePath.isNotEmpty && File(item.imagePath).existsSync()) {
        extraInputs.add('-loop 1 -t 1 -i ${_escapePath(item.imagePath)}');
        imageInputIndices[item.id] = inputIndex++;
      }
    }
    for (final item in audioItems) {
      if (item.audioPath.isNotEmpty && File(item.audioPath).existsSync()) {
        extraInputs.add('-i ${_escapePath(item.audioPath)}');
        audioInputIndices[item.id] = inputIndex++;
      }
    }

    final targetWidth = preset.width ?? 1920;
    final targetHeight = preset.height ?? 1080;

    String videoStream = '[v0concat]';
    overlayFilters.add(
      '[0:v]scale=$targetWidth:$targetHeight:'
      'force_original_aspect_ratio=decrease,'
      'pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2[v0concat]',
    );

    if (imageItems.isNotEmpty && config.includeImageOverlays) {
      videoStream = _buildImageOverlaysSimplified(
        baseStream: videoStream,
        imageItems: imageItems,
        imageInputIndices: imageInputIndices,
        filters: overlayFilters,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
    }
    if (project.textItems.isNotEmpty && config.includeTextOverlays) {
      videoStream = _buildTextOverlaysSimplified(
        baseStream: videoStream,
        textItems: project.textItems,
        filters: overlayFilters,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
    }
    overlayFilters.add('${videoStream}format=yuv420p[vout]');

    String? audioStream;
    if (!preset.removeAudio) {
      audioStream = _buildAudioMixSimplified(
        mainVideoIndex: 0,
        audioItems: audioItems,
        audioInputIndices: audioInputIndices,
        filters: overlayFilters,
        project: project,
      );
    }

    final commandParts = [
      '-y',
      '-f concat -safe 0 -i ${_escapePath(listFile.path)}',
      ...extraInputs,
    ];

    if (overlayFilters.isNotEmpty) {
      commandParts.add('-filter_complex "${overlayFilters.join(';')}"');
      commandParts.add('-map "[vout]"');
      if (audioStream != null && !preset.removeAudio) {
        final isRawInputRef =
            RegExp(r'^\[\d+:[a-zA-Z]+\]$').hasMatch(audioStream);
        commandParts.add(
          isRawInputRef
              ? '-map ${audioStream.substring(1, audioStream.length - 1)}'
              : '-map "$audioStream"',
        );
      }
    } else {
      commandParts.add('-map 0:v -map 0:a?');
    }

    commandParts.add('-c:v libx264 -preset medium -crf 23');
    if (preset.bitrate != null) {
      commandParts
        ..add('-maxrate ${preset.bitrate}k')
        ..add('-bufsize ${preset.bitrate! * 2}k');
    }
    if (preset.fps != null) commandParts.add('-r ${preset.fps}');
    if (!preset.removeAudio) {
      commandParts.add('-c:a aac -b:a ${preset.audioBitrate ?? 128}k');
    }
    commandParts.add('-movflags +faststart');
    commandParts.add(_escapePath(outputPath));

    debugPrint('⚡ Concat demuxer command: ${commandParts.join(' ')}');
    return commandParts.join(' ');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BUILD TIMELINE COMMAND
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> _buildTimelineCommand({
    required TimelineExportConfig config,
    required Directory tempDir,
    required String outputPath,
    void Function(double)? onProgress,
    void Function(ExportStage)? onStageChange,
  }) async {
    return SafeAsync.run(() async {
      final project = config.project;
      final preset = config.preset;

      // Build command parts
      final inputs = <String>[];
      final filters = <String>[];
      int inputIndex = 0;

      // Main video input
      final videoPath = _escapePath(project.videoPath);
      inputs.add('-i $videoPath');
      final mainVideoIndex = inputIndex++;

      // Collect and add image inputs
      final imageItems = config.includeImageOverlays
          ? project.imageItems
          : <ImageTimelineItem>[];

      final imageInputIndices = <String, int>{};
      for (final item in imageItems) {
        if (item.imagePath.isNotEmpty && File(item.imagePath).existsSync()) {
          inputs.add('-loop 1 -t 1 -i ${_escapePath(item.imagePath)}');
          imageInputIndices[item.id] = inputIndex++;
        }
      }

      // Collect and add audio inputs
      final audioItems = config.includeAudioTracks
          ? project.audioItems
          : <AudioTimelineItem>[];

      final audioInputIndices = <String, int>{};
      for (final item in audioItems) {
        if (item.audioPath.isNotEmpty && File(item.audioPath).existsSync()) {
          inputs.add('-i ${_escapePath(item.audioPath)}');
          audioInputIndices[item.id] = inputIndex++;
        }
      }

      _emitStage(ExportStage.processingVideo, onStageChange);
      onProgress?.call(0.2);

      // Start building filter chain
      String videoStream = '[$mainVideoIndex:v]';

      // Apply trim
      if (project.trimStart > Duration.zero ||
          project.trimEnd < project.videoDuration) {
        final startSec = project.trimStart.inMilliseconds / 1000.0;
        final endSec = project.trimEnd.inMilliseconds / 1000.0;

        filters.add(
          '${videoStream}trim=start=$startSec:end=$endSec,setpts=PTS-STARTPTS[vtrimmed]',
        );
        videoStream = '[vtrimmed]';
      }

      // Apply color grading
      if (config.applyColorGrading && !project.colorGrade.isDefault) {
        final colorFilter = _buildColorGradeFilter(project.colorGrade);
        if (colorFilter.isNotEmpty) {
          filters.add('$videoStream$colorFilter[graded]');
          videoStream = '[graded]';
        }
      }

      // Apply resolution scaling
      final targetWidth = preset.width ?? 1920;
      final targetHeight = preset.height ?? 1080;

      filters.add(
        '${videoStream}scale=$targetWidth:$targetHeight:'
        'force_original_aspect_ratio=decrease,'
        'pad=$targetWidth:$targetHeight:(ow-iw)/2:(oh-ih)/2[scaled]',
      );
      videoStream = '[scaled]';

      _emitStage(ExportStage.renderingOverlays, onStageChange);
      onProgress?.call(0.5);

      // Apply image overlays
      if (imageItems.isNotEmpty && config.includeImageOverlays) {
        videoStream = _buildImageOverlaysSimplified(
          baseStream: videoStream,
          imageItems: imageItems,
          imageInputIndices: imageInputIndices,
          filters: filters,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );
      }

      // Apply text overlays
      if (project.textItems.isNotEmpty && config.includeTextOverlays) {
        videoStream = _buildTextOverlaysSimplified(
          baseStream: videoStream,
          textItems: project.textItems,
          filters: filters,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );
      }

      // Format final video
      filters.add('${videoStream}format=yuv420p[vout]');

      _emitStage(ExportStage.mixingAudio, onStageChange);
      onProgress?.call(0.7);

      // Build audio filter chain
      String? audioStream;
      if (!preset.removeAudio) {
        audioStream = _buildAudioMixSimplified(
          mainVideoIndex: mainVideoIndex,
          audioItems: audioItems,
          audioInputIndices: audioInputIndices,
          filters: filters,
          project: project,
        );
      }

      // Construct final FFmpeg command
      final commandParts = <String>['-y'];

      // Add all inputs
      commandParts.addAll(inputs);

      // Add filter complex
      if (filters.isNotEmpty) {
        final filterComplex = filters.join(';');
        commandParts.add('-filter_complex "$filterComplex"');
        commandParts.add('-map "[vout]"');

        if (audioStream != null && !preset.removeAudio) {
          // Raw input refs like [0:a] must be mapped WITHOUT brackets
          // (FFmpeg only treats bracketed names as filter graph output
          // labels). Filter outputs like [aout] keep their brackets.
          final isRawInputRef =
              RegExp(r'^\[\d+:[a-zA-Z]+\]$').hasMatch(audioStream);
          commandParts.add(
            isRawInputRef
                ? '-map ${audioStream.substring(1, audioStream.length - 1)}'
                : '-map "$audioStream"',
          );
        }
      } else {
        commandParts.add('-map 0:v');
        if (!preset.removeAudio) {
          commandParts.add('-map 0:a?');
        }
      }

      // Video codec settings
      commandParts.add('-c:v libx264');
      commandParts.add('-preset medium');
      commandParts.add('-crf 23');

      if (preset.bitrate != null) {
        commandParts.add('-maxrate ${preset.bitrate}k');
        commandParts.add('-bufsize ${preset.bitrate! * 2}k');
      }

      if (preset.fps != null) {
        commandParts.add('-r ${preset.fps}');
      }

      // Audio codec settings
      if (!preset.removeAudio) {
        commandParts.add('-c:a aac');
        commandParts.add('-b:a ${preset.audioBitrate ?? 128}k');
      }

      // Output settings
      commandParts.add('-movflags +faststart');
      commandParts.add('-pix_fmt yuv420p');

      // Add output path
      commandParts.add(_escapePath(outputPath));

      final command = commandParts.join(' ');
      debugPrint('📹 Full FFmpeg Command: $command');

      return command;
    }, operationName: '_buildTimelineCommand');
  }

  // Simplified image overlay builder
  String _buildImageOverlaysSimplified({
    required String baseStream,
    required List<ImageTimelineItem> imageItems,
    required Map<String, int> imageInputIndices,
    required List<String> filters,
    required int targetWidth,
    required int targetHeight,
  }) {
    String currentStream = baseStream;

    // Sort by layer
    final sortedItems = List<ImageTimelineItem>.from(imageItems)
      ..sort((a, b) => a.layer.compareTo(b.layer));

    for (int i = 0; i < sortedItems.length; i++) {
      final item = sortedItems[i];
      final inputIdx = imageInputIndices[item.id];
      if (inputIdx == null) continue;

      // Calculate position and size
      final itemWidth = (targetWidth * item.scale).round();
      final itemHeight = (itemWidth / item.aspectRatio).round();
      final x = ((item.x * targetWidth) - (itemWidth / 2)).round();
      final y = ((item.y * targetHeight) - (itemHeight / 2)).round();

      // Prepare overlay with scale
      final overlayLabel = 'img$i';
      filters.add('[$inputIdx:v]scale=$itemWidth:$itemHeight[$overlayLabel]');

      // Calculate time range
      final startSec = item.startTime.inMilliseconds / 1000.0;
      final endSec = item.endTime.inMilliseconds / 1000.0;

      // Apply overlay with time enable
      final outputStream = '[overlay$i]';
      filters.add(
        '$currentStream[$overlayLabel]overlay=$x:$y:'
        'enable=\'between(t,$startSec,$endSec)\'$outputStream',
      );

      currentStream = outputStream;
    }

    return currentStream;
  }

  // Simplified text overlay builder
  String _buildTextOverlaysSimplified({
    required String baseStream,
    required List<TextTimelineItem> textItems,
    required List<String> filters,
    required int targetWidth,
    required int targetHeight,
  }) {
    String currentStream = baseStream;

    // Sort by layer
    final sortedItems = List<TextTimelineItem>.from(textItems)
      ..sort((a, b) => a.layer.compareTo(b.layer));

    for (int i = 0; i < sortedItems.length; i++) {
      final item = sortedItems[i];

      // Calculate position
      final x = (item.x * targetWidth).round();
      final y = (item.y * targetHeight).round();

      // Convert color to hex
      final color = item.style.color;
      final r = (color >> 16) & 0xFF;
      final g = (color >> 8) & 0xFF;
      final b = color & 0xFF;
      final colorHex =
          '0x${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}';

      // Calculate time range
      final startSec = item.startTime.inMilliseconds / 1000.0;
      final endSec = item.endTime.inMilliseconds / 1000.0;

      // Escape text for FFmpeg
      final escapedText = item.text
          .replaceAll('\\', '\\\\')
          .replaceAll(':', '\\:')
          .replaceAll("'", "\\'")
          .replaceAll('"', '\\"')
          .replaceAll('[', '\\[')
          .replaceAll(']', '\\]')
          .replaceAll(',', '\\,')
          .replaceAll(';', '\\;');

      // Build drawtext filter
      final outputStream = i == sortedItems.length - 1
          ? currentStream
          : '[text$i]';

      String drawtextFilter =
          '$currentStream'
          'drawtext='
          'text=\'$escapedText\':'
          'fontsize=${item.style.fontSize.round()}:'
          'fontcolor=$colorHex:'
          'x=$x:y=$y:'
          'enable=\'between(t,$startSec,$endSec)\'';

      // Add shadow if needed
      if (item.style.shadowBlur > 0) {
        final shadowColor = item.style.shadowColor;
        final sr = (shadowColor >> 16) & 0xFF;
        final sg = (shadowColor >> 8) & 0xFF;
        final sb = shadowColor & 0xFF;
        final shadowHex =
            '0x${sr.toRadixString(16).padLeft(2, '0')}'
            '${sg.toRadixString(16).padLeft(2, '0')}'
            '${sb.toRadixString(16).padLeft(2, '0')}';

        drawtextFilter += ':shadowcolor=$shadowHex:shadowx=2:shadowy=2';
      }

      if (i < sortedItems.length - 1) {
        drawtextFilter += outputStream;
      }

      filters.add(drawtextFilter);

      if (i < sortedItems.length - 1) {
        currentStream = outputStream;
      }
    }

    return currentStream;
  }

  // Simplified audio mix builder
  String _buildAudioMixSimplified({
    required int mainVideoIndex,
    required List<AudioTimelineItem> audioItems,
    required Map<String, int> audioInputIndices,
    required List<String> filters,
    required VideoProject project,
  }) {
    if (audioItems.isEmpty) {
      // Apply trim to main audio if needed
      if (project.trimStart > Duration.zero ||
          project.trimEnd < project.videoDuration) {
        final startSec = project.trimStart.inMilliseconds / 1000.0;
        final endSec = project.trimEnd.inMilliseconds / 1000.0;

        filters.add(
          '[$mainVideoIndex:a]atrim=start=$startSec:end=$endSec,'
          'asetpts=PTS-STARTPTS[aout]',
        );
        return '[aout]';
      }
      return '[$mainVideoIndex:a]';
    }

    // Mix audio tracks
    final audioStreams = <String>[];

    // Add main video audio
    audioStreams.add('[$mainVideoIndex:a]');

    // Process additional audio tracks
    for (int i = 0; i < audioItems.length; i++) {
      final item = audioItems[i];
      final inputIdx = audioInputIndices[item.id];
      if (inputIdx == null) continue;

      String audioStream = '[$inputIdx:a]';

      // Apply volume
      if (item.effectiveVolume != 1.0) {
        filters.add(
          '${audioStream}volume=${item.effectiveVolume}[audio${i}_vol]',
        );
        audioStream = '[audio${i}_vol]';
      }

      // Apply delay for start time
      final delayMs = item.startTime.inMilliseconds;
      if (delayMs > 0) {
        filters.add(
          '${audioStream}adelay=$delayMs|$delayMs[audio${i}_delayed]',
        );
        audioStream = '[audio${i}_delayed]';
      }

      audioStreams.add(audioStream);
    }

    // Mix all audio streams
    if (audioStreams.length > 1) {
      filters.add(
        '${audioStreams.join('')}amix=inputs=${audioStreams.length}:'
        'duration=first:dropout_transition=2[aout]',
      );
      return '[aout]';
    }

    return audioStreams[0];
  }

  // Simplified color grade filter
  String _buildColorGradeFilter(ColorGradeSettings settings) {
    final filters = <String>[];

    // Basic color adjustments
    if (settings.brightness != 0.0 ||
        settings.contrast != 1.0 ||
        settings.saturation != 1.0) {
      filters.add(
        'eq=brightness=${settings.brightness}:'
        'contrast=${settings.contrast}:'
        'saturation=${settings.saturation}',
      );
    }

    // Hue adjustment
    if (settings.hue != 0.0) {
      filters.add('hue=h=${settings.hue}');
    }

    return filters.isEmpty ? '' : filters.join(',');
  }

  // Helper to properly escape paths for FFmpeg
  String _escapePath(String path) {
    // For Windows
    if (Platform.isWindows) {
      return '"${path.replaceAll('"', '\\"')}"';
    }
    // For Unix-like systems (Android, iOS, macOS, Linux)
    return "'${path.replaceAll("'", "'\\''")}'";
  }

  // Extract meaningful error from FFmpeg logs
  String _extractErrorFromLogs(String? logs) {
    if (logs == null || logs.isEmpty) return 'Unknown error';

    final lines = logs.split('\n');

    // Look for error lines
    for (final line in lines.reversed) {
      final lowerLine = line.toLowerCase();
      if (lowerLine.contains('error') ||
          lowerLine.contains('invalid') ||
          lowerLine.contains('failed') ||
          lowerLine.contains('unable') ||
          lowerLine.contains('no such file') ||
          lowerLine.contains('permission denied')) {
        return line.length > 200 ? '${line.substring(0, 200)}...' : line;
      }
    }

    // Return last few lines if no specific error found
    final lastLines = lines.where((l) => l.trim().isNotEmpty).toList();
    if (lastLines.length > 3) {
      return lastLines.sublist(lastLines.length - 3).join(' | ');
    }

    return 'Export failed - check video file and settings';
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VALIDATE PROJECT
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> _validateProject(VideoProject project) async {
    return SafeAsync.run(() async {
      final missingAssets = <String>[];

      // Check main video
      if (!await File(project.videoPath).exists()) {
        missingAssets.add('Main video: ${project.videoPath}');
      }

      // Check image assets
      for (final item in project.imageItems) {
        if (!await File(item.imagePath).exists()) {
          missingAssets.add('Image: ${item.imagePath}');
        }
      }

      // Check audio assets
      for (final item in project.audioItems) {
        if (!await File(item.audioPath).exists()) {
          missingAssets.add('Audio: ${item.audioPath}');
        }
      }

      if (missingAssets.isNotEmpty) {
        throw TimelineExportError.missingAssets(missingAssets);
      }

      if (project.videoDuration == Duration.zero) {
        throw TimelineExportError.invalidProject('Video duration is zero');
      }
    }, operationName: '_validateProject');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════

  Future<String> _getDefaultOutputPath(String ext) async {
    final outputDir = await getExternalStorageDirectory();
    final videosDir = Directory(p.join(outputDir!.path, 'exported_videos'));

    if (!await videosDir.exists()) {
      await videosDir.create(recursive: true);
    }

    return p.join(videosDir.path, 'export_${_uuid.v4()}.$ext');
  }

  Future<Directory> _createTempDir(String prefix) async {
    final tempDir = await getExternalStorageDirectory();
    final dir = Directory(
      p.join(
        '${tempDir!.path}/temp_timeline_export',
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await dir.create(recursive: true);
    return dir;
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

  void _emitStage(
    ExportStage stage,
    void Function(ExportStage)? onStageChange,
  ) {
    if (!_stageController.isClosed) {
      _stageController.add(stage);
    }
    onStageChange?.call(stage);
  }

  void _startProcessing() {
    _isProcessing = true;
    _isCancelled = false;
  }

  void _stopProcessing() {
    _isProcessing = false;
    _currentSession = null;
  }

  void dispose() {
    cancelCurrentOperation();
    if (!_progressController.isClosed) {
      _progressController.close();
    }
    if (!_stageController.isClosed) {
      _stageController.close();
    }
  }
}

  // ═══════════════════════════════════════════════════════
  // ✅ VALIDATE PROJECT
  // ═══════════════════════════════════════════════════════
