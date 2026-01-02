import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import '../models/tts_request.dart';

class TtsService {
  static TtsService? _instance;
  static TtsService get instance => _instance ??= TtsService._();

  TtsService._();

  // Cache of initialized TTS engines by model path
  final Map<String, sherpa.OfflineTts> _ttsEngines = {};
  String? _defaultModelPath;
  String? _defaultModelName;

  bool _sherpaInitialized = false;
  Completer<void>? _sherpaInitCompleter;

  // Track if generation is in progress
  bool _isGenerating = false;
  bool _cancelRequested = false;

  final _stateController = StreamController<TtsPlaybackState>.broadcast();
  Stream<TtsPlaybackState> get stateStream => _stateController.stream;

  bool get isInitialized => _defaultModelPath != null && _sherpaInitialized;
  bool get isSherpaInitialized => _sherpaInitialized;
  String? get defaultModelPath => _defaultModelPath;
  String? get defaultModelName => _defaultModelName;
  bool get isGenerating => _isGenerating;

  /// Cancel ongoing generation
  void cancelGeneration() {
    _cancelRequested = true;
  }

  Future<void> _ensureSherpaInitialized() async {
    if (_sherpaInitialized) return;

    if (_sherpaInitCompleter != null) {
      return _sherpaInitCompleter!.future;
    }

    _sherpaInitCompleter = Completer<void>();

    try {
      debugPrint('[TtsService] Initializing Sherpa bindings...');
      _stateController.add(TtsPlaybackState.loading);

      await _initSherpaBindingsWithTimeout();

      _sherpaInitialized = true;
      _sherpaInitCompleter!.complete();

      debugPrint('[TtsService] Sherpa bindings initialized successfully');
      _stateController.add(TtsPlaybackState.idle);
    } catch (e, st) {
      debugPrint('[TtsService] Failed to initialize Sherpa bindings: $e');
      debugPrint('[TtsService] Stack: $st');
      _sherpaInitCompleter!.completeError(e);
      _sherpaInitCompleter = null;
      _stateController.add(TtsPlaybackState.error);
      throw Exception('Failed to initialize Sherpa bindings: $e');
    }
  }

  Future<void> _initSherpaBindingsWithTimeout() async {
    final completer = Completer<void>();
    Timer? timeoutTimer;

    timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Sherpa initialization timed out after 30 seconds'),
        );
      }
    });

    try {
      sherpa.initBindings();
      timeoutTimer.cancel();
      if (!completer.isCompleted) {
        completer.complete();
      }
    } catch (e) {
      timeoutTimer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  /// Set default model
  Future<bool> setDefaultModel({
    required String modelPath,
    String? modelName,
  }) async {
    final success = await _initializeEngine(modelPath);
    if (success) {
      _defaultModelPath = modelPath;
      _defaultModelName = modelName;
      debugPrint('[TtsService] Default model set: $modelPath');
    }
    return success;
  }

  /// Initialize TTS engine for a model path
  Future<bool> _initializeEngine(String modelPath) async {
    if (_ttsEngines.containsKey(modelPath)) {
      debugPrint('[TtsService] Engine already initialized for: $modelPath');
      return true;
    }

    try {
      await _ensureSherpaInitialized();

      debugPrint('[TtsService] Initializing engine for: $modelPath');
      _stateController.add(TtsPlaybackState.loading);

      final modelDir = Directory(modelPath);
      String? onnxModel;
      String? tokens;
      String? dataDir;

      if (await modelDir.exists()) {
        await for (final entity in modelDir.list(recursive: true)) {
          if (entity is File) {
            final name = entity.path.split('/').last.toLowerCase();
            final ext = name.split('.').last;

            if ((ext == 'onnx' || name.startsWith('onnx_')) &&
                onnxModel == null) {
              onnxModel = entity.path;
            } else if ((name.contains('tokens') ||
                    name.contains('token') ||
                    ext == 'txt') &&
                tokens == null) {
              tokens = entity.path;
            }
          } else if (entity is Directory) {
            final name = entity.path.split('/').last.toLowerCase();
            if (name.contains('espeak') ||
                name.contains('data') ||
                name.contains('lexicon')) {
              dataDir = entity.path;
            }
          }
        }
      } else if (modelPath.endsWith('.onnx')) {
        onnxModel = modelPath;
      }

      if (onnxModel == null) {
        debugPrint('[TtsService] No ONNX model found in: $modelPath');
        if (await modelDir.exists()) {
          debugPrint('[TtsService] Available files:');
          await for (final entity in modelDir.list(recursive: true)) {
            debugPrint('  ${entity.path}');
          }
        }
        return false;
      }

      debugPrint('[TtsService] ONNX: $onnxModel');
      debugPrint('[TtsService] Tokens: $tokens');
      debugPrint('[TtsService] Data: $dataDir');

      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: onnxModel,
            tokens: tokens ?? '',
            dataDir: dataDir ?? '',
          ),
          numThreads: 2,
          debug: false,
        ),
      );

      final tts = sherpa.OfflineTts(config);
      _ttsEngines[modelPath] = tts;

      debugPrint('[TtsService] Engine initialized successfully');
      _stateController.add(TtsPlaybackState.idle);
      return true;
    } catch (e, st) {
      debugPrint('[TtsService] Initialization error: $e');
      debugPrint('[TtsService] Stack: $st');
      _stateController.add(TtsPlaybackState.error);
      return false;
    }
  }

  /// Get TTS engine for model path (or default)
  Future<sherpa.OfflineTts?> _getEngine(String? modelPath) async {
    final path = modelPath ?? _defaultModelPath;

    if (path == null) {
      debugPrint('[TtsService] No model path provided and no default set');
      return null;
    }

    await _ensureSherpaInitialized();

    if (!_ttsEngines.containsKey(path)) {
      final success = await _initializeEngine(path);
      if (!success) return null;
    }

    return _ttsEngines[path];
  }

  /// Generate audio from text - WITH CHUNKING TO PREVENT UI FREEZE
  Future<TtsGenerationResult?> generateAudio({
    required String text,
    String? modelPath,
    double speed = 1.0,
    int speakerId = 0,
    void Function(double progress)? onProgress,
  }) async {
    final engine = await _getEngine(modelPath);
    if (engine == null) {
      debugPrint('[TtsService] No engine available');
      return null;
    }

    try {
      debugPrint(
        '[TtsService] Generating: "${text.substring(0, text.length.clamp(0, 30))}..."',
      );
      _stateController.add(TtsPlaybackState.generating);

      // Split into chunks for UI responsiveness
      final chunks = _splitTextIntoChunks(text, maxChunkLength: 120);
      debugPrint('[TtsService] Split into ${chunks.length} chunks');

      final allSamples = <double>[];
      int sampleRate = 22050;

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i].trim();
        if (chunk.isEmpty) continue;

        // Yield to UI before generation
        await Future.delayed(const Duration(milliseconds: 150));

        try {
          final audio = engine.generate(
            text: chunk,
            sid: speakerId,
            speed: speed,
          );
          allSamples.addAll(audio.samples);
          sampleRate = audio.sampleRate;

          onProgress?.call((i + 1) / chunks.length);

          // Yield to UI after generation
          await Future.delayed(const Duration(milliseconds: 150));
        } catch (e) {
          debugPrint('[TtsService] Chunk $i error: $e');
          continue;
        }
      }

      if (allSamples.isEmpty) {
        debugPrint('[TtsService] ✗ No samples generated');
        _stateController.add(TtsPlaybackState.error);
        return null;
      }

      debugPrint(
        '[TtsService] Generated ${allSamples.length} samples at ${sampleRate}Hz',
      );

      // ✅ FIX: Yield before WAV creation
      await Future.delayed(const Duration(milliseconds: 50));

      // Create WAV file
      final wavBytes = _createWavFile(
        Float32List.fromList(allSamples),
        sampleRate,
      );

      debugPrint('[TtsService] Created WAV: ${wavBytes.length} bytes');

      // ✅ FIX: Save to temp file with better error handling
      String? filePath;
      try {
        filePath = await _getDefaultOutputPath();
        debugPrint('[TtsService] Saving to: $filePath');

        final file = File(filePath);

        // Ensure parent directory exists
        await file.parent.create(recursive: true);

        // Write file
        await file.writeAsBytes(wavBytes);

        // ✅ FIX: Verify file was written
        if (!await file.exists()) {
          debugPrint('[TtsService] ✗ File not found after write');
          filePath = null;
        } else {
          final fileSize = await file.length();
          debugPrint('[TtsService] ✓ File saved: $fileSize bytes');
        }
      } catch (e) {
        debugPrint('[TtsService] ✗ File save error: $e');
        filePath = null;
      }

      _stateController.add(TtsPlaybackState.idle);

      return TtsGenerationResult(
        audioData: wavBytes,
        filePath: filePath,
        sampleRate: sampleRate,
        duration: Duration(
          milliseconds: (allSamples.length / sampleRate * 1000).round(),
        ),
      );
    } catch (e, st) {
      debugPrint('[TtsService] ✗ Error: $e\n$st');
      _stateController.add(TtsPlaybackState.error);
      return null;
    }
  }

  /// Generate audio with proper chunking and UI yields (NEW METHOD)
  Future<TtsGenerationResult?> generateAudioWithChunks({
    required String text,
    required String modelPath,
    double speed = 1.0,
    int speakerId = 0,
    void Function(double progress)? onProgress,
  }) async {
    final engine = await _getEngine(modelPath);
    if (engine == null) {
      debugPrint('[TtsService] No TTS engine available');
      return null;
    }

    try {
      debugPrint(
        '[TtsService] Generating with chunking: "${text.substring(0, text.length.clamp(0, 50))}..."',
      );
      _stateController.add(TtsPlaybackState.generating);

      // ✅ Split into smaller chunks (120 chars per chunk for UI responsiveness)
      final chunks = _splitTextIntoChunks(text, maxChunkLength: 120);
      debugPrint('[TtsService] Split into ${chunks.length} chunks');

      final allSamples = <double>[];
      int sampleRate = 22050;

      for (int i = 0; i < chunks.length; i++) {
        if (_cancelRequested) {
          debugPrint('[TtsService] Generation cancelled');
          _stateController.add(TtsPlaybackState.idle);
          return null;
        }

        final chunk = chunks[i];
        if (chunk.trim().isEmpty) continue;

        // ✅ CRITICAL: Yield to UI BEFORE heavy work
        await Future.delayed(const Duration(milliseconds: 100));

        debugPrint('[TtsService] Generating chunk ${i + 1}/${chunks.length}');

        try {
          // Generate this chunk
          final audio = engine.generate(
            text: chunk,
            sid: speakerId,
            speed: speed,
          );

          allSamples.addAll(audio.samples);
          sampleRate = audio.sampleRate;

          // Report progress
          final progress = (i + 1) / chunks.length;
          onProgress?.call(progress);

          // ✅ CRITICAL: Yield to UI AFTER heavy work
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('[TtsService] Chunk ${i + 1} generation error: $e');
          // Continue with other chunks instead of failing completely
          continue;
        }
      }

      if (allSamples.isEmpty) {
        debugPrint('[TtsService] No audio generated');
        _stateController.add(TtsPlaybackState.error);
        return null;
      }

      debugPrint('[TtsService] Total samples generated: ${allSamples.length}');

      // ✅ Yield before WAV creation
      await Future.delayed(const Duration(milliseconds: 50));

      final wavBytes = _createWavFile(
        Float32List.fromList(allSamples),
        sampleRate,
      );

      // Save to file
      final filePath = await _getDefaultOutputPath();
      final file = File(filePath);
      await file.writeAsBytes(wavBytes);

      debugPrint('[TtsService] Audio saved to: $filePath');

      _stateController.add(TtsPlaybackState.idle);

      return TtsGenerationResult(
        audioData: wavBytes,
        filePath: filePath,
        sampleRate: sampleRate,
        duration: Duration(
          milliseconds: (allSamples.length / sampleRate * 1000).round(),
        ),
      );
    } catch (e, st) {
      debugPrint('[TtsService] Generation error: $e\n$st');
      _stateController.add(TtsPlaybackState.error);
      return null;
    }
  }

  List<String> _splitTextIntoChunks(String text, {int maxChunkLength = 120}) {
    // ✅ CHANGE: Smaller chunks for less UI blocking
    final chunks = <String>[];
    final sentences = text.split(RegExp(r'(?<=[.!?।॥])\s+'));

    var currentChunk = StringBuffer();

    for (final sentence in sentences) {
      if (currentChunk.length + sentence.length > maxChunkLength) {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.toString().trim());
          currentChunk.clear();
        }

        if (sentence.length > maxChunkLength) {
          // ✅ FIX: Split long sentences more aggressively
          final words = sentence.split(' ');
          for (final word in words) {
            if (currentChunk.length + word.length + 1 > maxChunkLength) {
              if (currentChunk.isNotEmpty) {
                chunks.add(currentChunk.toString().trim());
                currentChunk.clear();
              }
            }
            currentChunk.write('$word ');
          }
        } else {
          currentChunk.write('$sentence ');
        }
      } else {
        currentChunk.write('$sentence ');
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString().trim());
    }

    return chunks.where((c) => c.trim().isNotEmpty).toList();
  }

  Uint8List _createWavFile(Float32List samples, int sampleRate) {
    try {
      final numChannels = 1;
      final bitsPerSample = 16;
      final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
      final blockAlign = numChannels * bitsPerSample ~/ 8;
      final dataSize = samples.length * 2;
      final fileSize = 36 + dataSize;

      final buffer = ByteData(44 + dataSize);
      var offset = 0;

      // RIFF header
      buffer.setUint8(offset++, 0x52); // R
      buffer.setUint8(offset++, 0x49); // I
      buffer.setUint8(offset++, 0x46); // F
      buffer.setUint8(offset++, 0x46); // F
      buffer.setUint32(offset, fileSize, Endian.little);
      offset += 4;
      buffer.setUint8(offset++, 0x57); // W
      buffer.setUint8(offset++, 0x41); // A
      buffer.setUint8(offset++, 0x56); // V
      buffer.setUint8(offset++, 0x45); // E

      // fmt chunk
      buffer.setUint8(offset++, 0x66); // f
      buffer.setUint8(offset++, 0x6D); // m
      buffer.setUint8(offset++, 0x74); // t
      buffer.setUint8(offset++, 0x20); // space
      buffer.setUint32(offset, 16, Endian.little);
      offset += 4;
      buffer.setUint16(offset, 1, Endian.little); // PCM
      offset += 2;
      buffer.setUint16(offset, numChannels, Endian.little);
      offset += 2;
      buffer.setUint32(offset, sampleRate, Endian.little);
      offset += 4;
      buffer.setUint32(offset, byteRate, Endian.little);
      offset += 4;
      buffer.setUint16(offset, blockAlign, Endian.little);
      offset += 2;
      buffer.setUint16(offset, bitsPerSample, Endian.little);
      offset += 2;

      // data chunk
      buffer.setUint8(offset++, 0x64); // d
      buffer.setUint8(offset++, 0x61); // a
      buffer.setUint8(offset++, 0x74); // t
      buffer.setUint8(offset++, 0x61); // a
      buffer.setUint32(offset, dataSize, Endian.little);
      offset += 4;

      // Audio data
      for (var i = 0; i < samples.length; i++) {
        final sample = (samples[i].clamp(-1.0, 1.0) * 32767).round();
        buffer.setInt16(offset, sample, Endian.little);
        offset += 2;
      }

      return buffer.buffer.asUint8List();
    } catch (e) {
      debugPrint('[TtsService] WAV creation error: $e');
      return Uint8List(0);
    }
  }

  Future<String> _getDefaultOutputPath() async {
    final baseDir = await getExternalStorageDirectory();
    final dir = baseDir ?? await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/tts_$timestamp.wav';
  }

  /// Clear cached engine for a model
  void clearEngine(String modelPath) {
    _ttsEngines.remove(modelPath);
  }

  /// Clear all cached engines
  void clearAllEngines() {
    _ttsEngines.clear();
    _defaultModelPath = null;
    _defaultModelName = null;
  }

  void dispose() {
    _cancelRequested = true;
    clearAllEngines();
    _stateController.close();
  }
}

class TtsGenerationResult {
  final Uint8List audioData;
  final String? filePath;
  final int sampleRate;
  final Duration duration;

  TtsGenerationResult({
    required this.audioData,
    this.filePath,
    required this.sampleRate,
    required this.duration,
  });
}
