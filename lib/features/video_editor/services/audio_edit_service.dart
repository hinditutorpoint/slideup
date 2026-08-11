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

import '../models/video_edit_settings.dart';
import 'package:slideup/core/utils/safe_async.dart';

// ═══════════════════════════════════════════════════════
// ✅ AUDIO INFO MODEL
// ═══════════════════════════════════════════════════════

@immutable
class AudioInfo {
  final Duration duration;
  final int bitrate;
  final int sampleRate;
  final int channels;
  final String codec;
  final String format;
  final int fileSize;

  const AudioInfo({
    required this.duration,
    required this.bitrate,
    required this.sampleRate,
    required this.channels,
    required this.codec,
    required this.format,
    required this.fileSize,
  });

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
    'bitrate': bitrate,
    'sampleRate': sampleRate,
    'channels': channels,
    'codec': codec,
    'format': format,
    'fileSize': fileSize,
  };

  factory AudioInfo.fromJson(Map<String, dynamic> json) {
    return AudioInfo(
      duration: Duration(milliseconds: json.safeGet<int>('duration', 0)!),
      bitrate: json.safeGet<int>('bitrate', 0)!,
      sampleRate: json.safeGet<int>('sampleRate', 0)!,
      channels: json.safeGet<int>('channels', 0)!,
      codec: json.safeGet<String>('codec', '')!,
      format: json.safeGet<String>('format', '')!,
      fileSize: json.safeGet<int>('fileSize', 0)!,
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ AUDIO EFFECT TYPES
// ═══════════════════════════════════════════════════════

enum AudioEffectType {
  echo,
  reverb,
  compressor,
  vocalEnhancer,
  noiseRemoval,
  vocalRemoval,
  bassBoost,
  trebleBoost,
  equalizer,
}

@immutable
class AudioEffect {
  final AudioEffectType type;
  final Map<String, dynamic> parameters;

  const AudioEffect({required this.type, this.parameters = const {}});

  // Preset effects
  static const AudioEffect echo = AudioEffect(
    type: AudioEffectType.echo,
    parameters: {'delay': 0.5, 'decay': 0.5},
  );

  static const AudioEffect reverb = AudioEffect(
    type: AudioEffectType.reverb,
    parameters: {'roomSize': 0.5, 'damping': 0.5},
  );

  static const AudioEffect compressor = AudioEffect(
    type: AudioEffectType.compressor,
    parameters: {'threshold': -20, 'ratio': 4, 'attack': 5, 'release': 50},
  );

  static const AudioEffect vocalEnhancer = AudioEffect(
    type: AudioEffectType.vocalEnhancer,
    parameters: {'frequency': 3000, 'gain': 3},
  );

  static const AudioEffect noiseRemoval = AudioEffect(
    type: AudioEffectType.noiseRemoval,
    parameters: {'amount': 0.5},
  );

  static const AudioEffect vocalRemoval = AudioEffect(
    type: AudioEffectType.vocalRemoval,
    parameters: {},
  );

  static const AudioEffect bassBoost = AudioEffect(
    type: AudioEffectType.bassBoost,
    parameters: {'frequency': 100, 'gain': 5},
  );

  static const AudioEffect trebleBoost = AudioEffect(
    type: AudioEffectType.trebleBoost,
    parameters: {'frequency': 10000, 'gain': 5},
  );
}

// ═══════════════════════════════════════════════════════
// ✅ AUDIO EDIT ERROR
// ═══════════════════════════════════════════════════════

enum AudioEditErrorType {
  fileNotFound,
  invalidInput,
  processingFailed,
  cancelled,
  timeout,
  codecNotSupported,
  unknown,
}

class AudioEditError implements Exception {
  final AudioEditErrorType type;
  final String message;
  final String? details;
  final Object? originalError;

  const AudioEditError({
    required this.type,
    required this.message,
    this.details,
    this.originalError,
  });

  @override
  String toString() =>
      'AudioEditError($type): $message${details != null ? ' - $details' : ''}';

  factory AudioEditError.fileNotFound(String path) => AudioEditError(
    type: AudioEditErrorType.fileNotFound,
    message: 'Audio file not found',
    details: path,
  );

  factory AudioEditError.invalidInput(String reason) => AudioEditError(
    type: AudioEditErrorType.invalidInput,
    message: 'Invalid input',
    details: reason,
  );

  factory AudioEditError.processingFailed(String operation, [Object? error]) =>
      AudioEditError(
        type: AudioEditErrorType.processingFailed,
        message: 'Audio processing failed',
        details: operation,
        originalError: error,
      );

  factory AudioEditError.cancelled() => const AudioEditError(
    type: AudioEditErrorType.cancelled,
    message: 'Operation cancelled',
  );
}

// ═══════════════════════════════════════════════════════
// ✅ AUDIO EDIT SERVICE
// ═══════════════════════════════════════════════════════

class AudioEditService {
  static final AudioEditService _instance = AudioEditService._internal();
  factory AudioEditService() => _instance;
  AudioEditService._internal();

  static const Duration _defaultTimeout = Duration(minutes: 10);

  final _uuid = const Uuid();
  FFmpegSession? _currentSession;
  bool _isProcessing = false;
  bool _isCancelled = false;

  final _progressController = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;
  bool get isProcessing => _isProcessing;

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> initialize() async {
    return SafeAsync.run(() async {
      debugPrint('✅ AudioEditService initialized');
    }, operationName: 'AudioEditService.initialize');
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
      debugPrint('✅ Audio operation cancelled');
    }, operationName: 'AudioEditService.cancel');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TRIM AUDIO
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> trimAudio({
    required String inputPath,
    required Duration startTime,
    required Duration endTime,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        AudioEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    if (startTime >= endTime) {
      return Result.failure(
        AudioEditError.invalidInput('Start time must be before end time'),
      );
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        final ext = _getAudioExtension(format);
        final outputResult = await _getOutputPath('trimmed_audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        final startStr = _formatDuration(startTime);
        final duration = endTime - startTime;
        final durationStr = _formatDuration(duration);

        final codec = _getAudioCodec(format, bitrate);
        final command =
            '-y -ss $startStr -i "$inputPath" -t $durationStr $codec "$output"';

        debugPrint('🎵 Trim audio: $command');
        _setupProgressCallback(duration, onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw AudioEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Audio trimmed: $output');
          return output;
        }

        await _cleanupFile(output);
        throw AudioEditError.processingFailed('Trim audio failed');
      },
      operationName: 'trimAudio',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MERGE AUDIO FILES
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> mergeAudio({
    required List<String> inputPaths,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        AudioEditError.invalidInput('Another operation in progress'),
      );
    }

    if (inputPaths.isEmpty) {
      return Result.failure(
        AudioEditError.invalidInput('No audio files to merge'),
      );
    }

    // Validate all input files
    for (final path in inputPaths) {
      final validationResult = await _validateInputFile(path);
      if (validationResult.isFailure) {
        return Result.failure(validationResult.error!);
      }
    }

    _startProcessing();

    Directory? tempDir;

    return SafeAsync.run(
      () async {
        final ext = _getAudioExtension(format);
        final outputResult = await _getOutputPath('merged_audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        tempDir = await _createTempDir('audio_merge');
        final listFile = File(p.join(tempDir!.path, 'list.txt'));

        // Create concat list
        final listContent = inputPaths.map((path) => "file '$path'").join('\n');
        await listFile.writeAsString(listContent);

        final codec = _getAudioCodec(format, bitrate);
        final command =
            '-y -f concat -safe 0 -i "${listFile.path}" $codec "$output"';

        debugPrint('🔗 Merge audio: $command');

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();

        onProgress?.call(1.0);

        if (_isCancelled) {
          await _cleanupFile(output);
          throw AudioEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Audio merged: $output');
          return output;
        }

        await _cleanupFile(output);
        throw AudioEditError.processingFailed('Merge audio failed');
      },
      operationName: 'mergeAudio',
      timeout: _defaultTimeout,
    ).whenComplete(() async {
      _stopProcessing();
      if (tempDir != null) {
        await SafeAsync.run(
          () => tempDir!.delete(recursive: true),
          operationName: 'cleanup_audio_merge_temp',
        );
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  // ✅ APPLY ECHO EFFECT
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> applyEcho({
    required String inputPath,
    double delay = 0.5,
    double decay = 0.5,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        AudioEditError.invalidInput('Another operation in progress'),
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
        final outputResult = await _getOutputPath('echo_audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        // FFmpeg echo filter: aecho=in_gain:out_gain:delays:decays
        final delayMs = (delay * 1000).toInt();
        final command =
            '-y -i "$inputPath" '
            '-af "aecho=1.0:0.7:$delayMs:$decay" '
            '${_getAudioCodec(format, bitrate)} "$output"';

        debugPrint('🔊 Apply echo: $command');

        final durationResult = await _getAudioDuration(inputPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw AudioEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Echo applied: $output');
          return output;
        }

        await _cleanupFile(output);
        throw AudioEditError.processingFailed('Apply echo failed');
      },
      operationName: 'applyEcho',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ APPLY COMPRESSOR
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> applyCompressor({
    required String inputPath,
    double threshold = -20.0,
    double ratio = 4.0,
    double attack = 5.0,
    double release = 50.0,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        AudioEditError.invalidInput('Another operation in progress'),
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
        final outputResult = await _getOutputPath('compressed_audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        // FFmpeg compressor filter
        final command =
            '-y -i "$inputPath" '
            '-af "acompressor=threshold=${threshold}dB:ratio=$ratio:attack=$attack:release=$release" '
            '${_getAudioCodec(format, bitrate)} "$output"';

        debugPrint('🎛️ Apply compressor: $command');

        final durationResult = await _getAudioDuration(inputPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw AudioEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Compressor applied: $output');
          return output;
        }

        await _cleanupFile(output);
        throw AudioEditError.processingFailed('Apply compressor failed');
      },
      operationName: 'applyCompressor',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VOCAL ENHANCER
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> enhanceVocals({
    required String inputPath,
    double frequency = 3000.0,
    double gain = 3.0,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        AudioEditError.invalidInput('Another operation in progress'),
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
        final outputResult = await _getOutputPath('enhanced_audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        // EQ boost for vocal frequencies (typically 2kHz-4kHz)
        final command =
            '-y -i "$inputPath" '
            '-af "equalizer=f=$frequency:width_type=o:width=2:g=$gain" '
            '${_getAudioCodec(format, bitrate)} "$output"';

        debugPrint('🎤 Enhance vocals: $command');

        final durationResult = await _getAudioDuration(inputPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw AudioEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Vocals enhanced: $output');
          return output;
        }

        await _cleanupFile(output);
        throw AudioEditError.processingFailed('Enhance vocals failed');
      },
      operationName: 'enhanceVocals',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ NOISE REMOVAL
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> removeNoise({
    required String inputPath,
    double amount = 0.5,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        AudioEditError.invalidInput('Another operation in progress'),
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
        final outputResult = await _getOutputPath('denoised_audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        // FFmpeg highpass and lowpass filters for noise reduction
        final command =
            '-y -i "$inputPath" '
            '-af "highpass=f=200,lowpass=f=3000,afftdn=nf=${(amount * 20).toInt()}" '
            '${_getAudioCodec(format, bitrate)} "$output"';

        debugPrint('🔇 Remove noise: $command');

        final durationResult = await _getAudioDuration(inputPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw AudioEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Noise removed: $output');
          return output;
        }

        await _cleanupFile(output);
        throw AudioEditError.processingFailed('Remove noise failed');
      },
      operationName: 'removeNoise',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VOCAL REMOVAL (Karaoke Effect)
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> removeVocals({
    required String inputPath,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        AudioEditError.invalidInput('Another operation in progress'),
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
        final outputResult = await _getOutputPath('karaoke_audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        // FFmpeg vocal removal using stereo pan technique
        final command =
            '-y -i "$inputPath" '
            '-af "stereotools=mlev=0.015625" '
            '${_getAudioCodec(format, bitrate)} "$output"';

        debugPrint('🎤❌ Remove vocals: $command');

        final durationResult = await _getAudioDuration(inputPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw AudioEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Vocals removed: $output');
          return output;
        }

        await _cleanupFile(output);
        throw AudioEditError.processingFailed('Remove vocals failed');
      },
      operationName: 'removeVocals',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BASS BOOST
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> applyBassBoost({
    required String inputPath,
    double gain = 5.0,
    double frequency = 100,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        AudioEditError.invalidInput('Another operation in progress'),
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
        final outputResult = await _getOutputPath('bass_boosted_audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        final command =
            '-y -i "$inputPath" '
            '-af "bass=g=$gain:f=$frequency" '
            '${_getAudioCodec(format, bitrate)} "$output"';

        debugPrint('🔊 Bass boost: $command');

        final durationResult = await _getAudioDuration(inputPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw AudioEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Bass boosted: $output');
          return output;
        }

        await _cleanupFile(output);
        throw AudioEditError.processingFailed('Bass boost failed');
      },
      operationName: 'applyBassBoost',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TREBLE BOOST
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> applyTrebleBoost({
    required String inputPath,
    double gain = 5.0,
    double frequency = 10000,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        AudioEditError.invalidInput('Another operation in progress'),
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
        final outputResult = await _getOutputPath('treble_boosted_audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        final command =
            '-y -i "$inputPath" '
            '-af "treble=g=$gain:f=$frequency" '
            '${_getAudioCodec(format, bitrate)} "$output"';

        debugPrint('🔊 Treble boost: $command');

        final durationResult = await _getAudioDuration(inputPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw AudioEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Treble boosted: $output');
          return output;
        }

        await _cleanupFile(output);
        throw AudioEditError.processingFailed('Treble boost failed');
      },
      operationName: 'applyTrebleBoost',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ADJUST VOLUME
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> adjustVolume({
    required String inputPath,
    double volumeMultiplier = 1.0,
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        AudioEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    if (volumeMultiplier <= 0) {
      return Result.failure(
        AudioEditError.invalidInput('Volume must be greater than 0'),
      );
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        final ext = _getAudioExtension(format);
        final outputResult = await _getOutputPath('volume_adjusted_audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        final command =
            '-y -i "$inputPath" '
            '-af "volume=$volumeMultiplier" '
            '${_getAudioCodec(format, bitrate)} "$output"';

        debugPrint('🔊 Adjust volume: $command');

        final durationResult = await _getAudioDuration(inputPath);
        _setupProgressCallback(durationResult.getOrNull(), onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw AudioEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Volume adjusted: $output');
          return output;
        }

        await _cleanupFile(output);
        throw AudioEditError.processingFailed('Adjust volume failed');
      },
      operationName: 'adjustVolume',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ APPLY FADE IN/OUT
  // ═══════════════════════════════════════════════════════

  Future<Result<String>> applyFade({
    required String inputPath,
    bool fadeIn = false,
    bool fadeOut = false,
    Duration fadeDuration = const Duration(seconds: 2),
    AudioFormat format = AudioFormat.mp3,
    int bitrate = 192,
    String? outputPath,
    void Function(double)? onProgress,
  }) async {
    if (_isProcessing) {
      return Result.failure(
        AudioEditError.invalidInput('Another operation in progress'),
      );
    }

    final validationResult = await _validateInputFile(inputPath);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.error!);
    }

    if (!fadeIn && !fadeOut) {
      return Result.failure(
        AudioEditError.invalidInput('No fade type selected'),
      );
    }

    _startProcessing();

    return SafeAsync.run(
      () async {
        final ext = _getAudioExtension(format);
        final outputResult = await _getOutputPath('faded_audio', ext);
        if (outputResult.isFailure) {
          throw outputResult.error!;
        }
        final output = outputPath ?? outputResult.requireData;

        final durationResult = await _getAudioDuration(inputPath);
        final audioDuration = durationResult.getOrElse(Duration.zero);

        final filters = <String>[];

        if (fadeIn) {
          final fadeInDur = fadeDuration.inMilliseconds / 1000;
          filters.add('afade=t=in:st=0:d=$fadeInDur');
        }

        if (fadeOut) {
          final fadeOutStart =
              (audioDuration - fadeDuration).inMilliseconds / 1000;
          final fadeOutDur = fadeDuration.inMilliseconds / 1000;
          if (fadeOutStart > 0) {
            filters.add('afade=t=out:st=$fadeOutStart:d=$fadeOutDur');
          }
        }

        final filterStr = filters.join(',');

        final command =
            '-y -i "$inputPath" '
            '-af "$filterStr" '
            '${_getAudioCodec(format, bitrate)} "$output"';

        debugPrint('🎚️ Apply fade: $command');

        _setupProgressCallback(audioDuration, onProgress);

        _currentSession = await FFmpegKit.execute(command);
        final returnCode = await _currentSession?.getReturnCode();
        _clearProgressCallback();

        if (_isCancelled) {
          await _cleanupFile(output);
          throw AudioEditError.cancelled();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('✅ Fade applied: $output');
          return output;
        }

        await _cleanupFile(output);
        throw AudioEditError.processingFailed('Apply fade failed');
      },
      operationName: 'applyFade',
      timeout: _defaultTimeout,
    ).whenComplete(() => _stopProcessing());
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GET AUDIO INFO
  // ═══════════════════════════════════════════════════════

  Future<Result<AudioInfo>> getAudioInfo(String inputPath) async {
    return SafeAsync.run(() async {
      final session = await FFprobeKit.getMediaInformation(inputPath);
      final info = session.getMediaInformation();

      if (info == null) {
        throw AudioEditError.processingFailed('Could not get audio info');
      }

      return _parseAudioInformation(info, inputPath);
    }, operationName: 'getAudioInfo');
  }

  Future<AudioInfo> _parseAudioInformation(
    MediaInformation info,
    String path,
  ) async {
    final durationStr = info.getDuration();
    final duration = durationStr != null
        ? Duration(milliseconds: (double.parse(durationStr) * 1000).toInt())
        : Duration.zero;

    int sampleRate = 0;
    int channels = 0;
    String codec = '';

    final streams = info.getStreams();
    for (final stream in streams) {
      final type = stream.getType();
      if (type == 'audio') {
        sampleRate = int.tryParse(stream.getSampleRate() ?? '0') ?? 0;
        channels = int.tryParse(stream.getChannelLayout() ?? '0') ?? 2;
        codec = stream.getCodec() ?? '';
        break;
      }
    }

    final bitrateStr = info.getBitrate();
    final bitrate = bitrateStr != null ? int.tryParse(bitrateStr) ?? 0 : 0;

    final file = File(path);
    final fileSize = await file.length();

    return AudioInfo(
      duration: duration,
      bitrate: bitrate ~/ 1000,
      sampleRate: sampleRate,
      channels: channels,
      codec: codec,
      format: info.getFormat() ?? '',
      fileSize: fileSize,
    );
  }

  Future<Result<Duration>> _getAudioDuration(String inputPath) async {
    return SafeAsync.run(() async {
      final infoResult = await getAudioInfo(inputPath);
      if (infoResult.isSuccess) {
        return infoResult.requireData.duration;
      }
      return Duration.zero;
    }, operationName: '_getAudioDuration');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════

  Future<Result<void>> _validateInputFile(String path) async {
    return SafeAsync.run(() async {
      final file = File(path);
      if (!await file.exists()) {
        throw AudioEditError.fileNotFound(path);
      }
      final stat = await file.stat();
      if (stat.size == 0) {
        throw AudioEditError.invalidInput('File is empty');
      }
    }, operationName: '_validateInputFile');
  }

  Future<Result<String>> _getOutputPath(String prefix, String ext) async {
    return SafeAsync.run(() async {
      final outputDir = await getExternalStorageDirectory();
      if (outputDir == null) {
        throw AudioEditError.processingFailed('Cannot access storage');
      }

      final audioDir = Directory(p.join(outputDir.path, 'processed_audio'));
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      return p.join(audioDir.path, '${prefix}_${_uuid.v4()}.$ext');
    }, operationName: '_getOutputPath');
  }

  Future<Directory> _createTempDir(String prefix) async {
    final tempDir = await getExternalStorageDirectory();
    final dir = Directory(
      p.join(
        '${tempDir!.path}/temp_audio_editing',
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

  void dispose() {
    cancelCurrentOperation();
    if (!_progressController.isClosed) {
      _progressController.close();
    }
  }
}
