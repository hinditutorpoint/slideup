import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/tts_request.dart';
import 'tts_isolate.dart';

class TtsService {
  static TtsService? _instance;
  static TtsService get instance => _instance ??= TtsService._();

  TtsService._();

  // Isolate Management
  Isolate? _isolate;
  SendPort? _sendPort;
  Completer<void>? _isolateInitCompleter;
  StreamSubscription? _isolateSubscription;
  bool _isDisposed = false;

  // Track requests
  final Map<String, Completer<bool>> _modelLoadCompleters = {};
  final Map<String, _GenerationRequestState> _pendingRequests = {};

  String? _defaultModelPath;
  String? _defaultModelName;
  bool _sherpaInitialized = false;

  final _stateController = StreamController<TtsPlaybackState>.broadcast();
  Stream<TtsPlaybackState> get stateStream => _stateController.stream;

  bool get isInitialized => _defaultModelPath != null && _sherpaInitialized;
  bool get isSherpaInitialized => _sherpaInitialized;
  String? get defaultModelPath => _defaultModelPath;
  String? get defaultModelName => _defaultModelName;

  // Track if generation is in progress (any request)
  bool get isGenerating => _pendingRequests.isNotEmpty;

  /// Ensure the isolate is initialized and bindings are ready
  Future<void> _ensureIsolateReady() async {
    if (_isolateInitCompleter != null) {
      return _isolateInitCompleter!.future;
    }

    _isolateInitCompleter = Completer<void>();
    debugPrint('[TtsService] Spawning TTS Isolate...');

    try {
      final receivePort = ReceivePort();
      _isolate = await Isolate.spawn(ttsIsolateEntry, receivePort.sendPort);

      final completer = Completer<SendPort>();

      _isolateSubscription = receivePort.listen((message) {
        if (message is SendPort) {
          completer.complete(message);
        } else if (message is Map<String, dynamic>) {
          _handleIsolateMessage(message);
        }
      });

      _sendPort = await completer.future;
      debugPrint('[TtsService] TTS Isolate spawned. Initializing bindings...');

      // Initialize Sherpa bindings in isolate
      _sendPort!.send({'command': TtsIsolateCommand.init});

      // Wait for success response (handled in _handleIsolateMessage)
      // We rely on _isolateInitCompleter being completed there
    } catch (e) {
      debugPrint('[TtsService] Isolate spawn failed: $e');
      _isolateInitCompleter?.completeError(e);
      _isolateInitCompleter = null;
    }

    return _isolateInitCompleter!.future;
  }

  void _handleIsolateMessage(Map<String, dynamic> message) {
    if (_isDisposed) return;

    final type = message['type'] as TtsIsolateResponse;

    switch (type) {
      case TtsIsolateResponse.initSuccess:
        debugPrint('[TtsService] Isolate bindings initialized');
        _sherpaInitialized = true;
        _isolateInitCompleter?.complete();
        _stateController.add(TtsPlaybackState.idle);
        break;

      case TtsIsolateResponse.initFailure:
        debugPrint('[TtsService] Isolate bindings failed: ${message['error']}');
        _stateController.add(TtsPlaybackState.error);
        _isolateInitCompleter?.completeError(message['error']);
        break;

      case TtsIsolateResponse.modelLoaded:
        final path = message['modelPath'];
        debugPrint('[TtsService] Model loaded in isolate: $path');
        _modelLoadCompleters[path]?.complete(true);
        _modelLoadCompleters.remove(path);
        break;

      case TtsIsolateResponse.modelLoadFailed:
        final path = message['modelPath'];
        debugPrint('[TtsService] Model load failed: ${message['error']}');
        _modelLoadCompleters[path]?.complete(false);
        _modelLoadCompleters.remove(path);
        break;

      case TtsIsolateResponse.generationProgress:
        final id = message['requestId'];
        final progress = message['progress'] as double;
        _pendingRequests[id]?.onProgress?.call(progress);
        break;

      case TtsIsolateResponse.generationSuccess:
        final id = message['requestId'];
        final success = message['success'] as GenerationSuccess;
        _handleGenerationSuccess(id, success);
        break;

      case TtsIsolateResponse.generationFailure:
        final id = message['requestId'];
        final error = message['error'];
        _handleGenerationFailure(id, error);
        break;
    }
  }

  Future<void> _handleGenerationSuccess(
    String id,
    GenerationSuccess success,
  ) async {
    final state = _pendingRequests.remove(id);
    if (state == null) return;

    try {
      // Save to file
      String? filePath;
      try {
        filePath = state.outputPath ?? await _getDefaultOutputPath();
        final file = File(filePath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(success.audioData);
        debugPrint('[TtsService] Audio saved to: $filePath');
      } catch (e) {
        debugPrint('[TtsService] File save error: $e');
        filePath = null;
      }

      _stateController.add(TtsPlaybackState.idle);

      state.completer.complete(
        TtsGenerationResult(
          audioData: success.audioData,
          filePath: filePath,
          sampleRate: success.sampleRate,
          duration: Duration(
            milliseconds: (success.durationSeconds * 1000).round(),
          ),
        ),
      );
    } catch (e) {
      state.completer.complete(null);
    }
  }

  void _handleGenerationFailure(String id, String error) {
    debugPrint('[TtsService] Generation failed: $error');
    final state = _pendingRequests.remove(id);
    if (state != null) {
      _stateController.add(TtsPlaybackState.error);
      state.completer.complete(null);
    }
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
    try {
      await _ensureIsolateReady();

      if (_modelLoadCompleters.containsKey(modelPath)) {
        return _modelLoadCompleters[modelPath]!.future;
      }

      final completer = Completer<bool>();
      _modelLoadCompleters[modelPath] = completer;

      _sendPort!.send({
        'command': TtsIsolateCommand.loadModel,
        'modelPath': modelPath,
      });

      return completer.future;
    } catch (e) {
      debugPrint('[TtsService] Init engine error: $e');
      return false;
    }
  }

  /// Generate audio from text (delegates to isolate)
  Future<TtsGenerationResult?> generateAudio({
    required String text,
    String? modelPath,
    double speed = 1.0,
    int speakerId = 0,
    String? outputPath,
    void Function(double progress)? onProgress,
  }) async {
    return generateAudioWithChunks(
      text: text,
      modelPath: modelPath ?? _defaultModelPath ?? '',
      speed: speed,
      speakerId: speakerId,
      outputPath: outputPath,
      onProgress: onProgress,
    );
  }

  /// Generate audio with chunks (now just delegates to isolate, but keeping signature)
  Future<TtsGenerationResult?> generateAudioWithChunks({
    required String text,
    required String modelPath,
    double speed = 1.0,
    int speakerId = 0,
    String? outputPath,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('[TtsService] ===== generateAudioWithChunks START =====');
    debugPrint('[TtsService] Text length: ${text.length} chars');
    debugPrint(
      '[TtsService] Text preview: ${text.length > 100 ? text.substring(0, 100) : text}...',
    );
    debugPrint('[TtsService] Model: $modelPath');
    debugPrint('[TtsService] Output path: $outputPath');

    try {
      // Ensure engine is loaded
      debugPrint('[TtsService] Checking engine initialization...');
      final engineReady = await _initializeEngine(modelPath);
      if (!engineReady) {
        debugPrint('[TtsService] ❌ Engine failed to initialize');
        return null;
      }
      debugPrint('[TtsService] ✓ Engine ready');

      _stateController.add(TtsPlaybackState.generating);

      final requestId = '${DateTime.now().microsecondsSinceEpoch}';
      final completer = Completer<TtsGenerationResult?>();

      _pendingRequests[requestId] = _GenerationRequestState(
        completer: completer,
        onProgress: onProgress,
        outputPath: outputPath,
      );

      final request = GenerationRequest(
        id: requestId,
        text: text,
        modelPath: modelPath,
        speed: speed,
        speakerId: speakerId,
      );

      debugPrint('[TtsService] Sending request to isolate (ID: $requestId)...');
      try {
        _sendPort!.send({
          'command': TtsIsolateCommand.generate,
          'request': request.toMap(),
        });
        debugPrint('[TtsService] ✓ Request sent to isolate successfully');
      } catch (sendError, sendStack) {
        debugPrint('[TtsService] ❌ CRITICAL: Failed to send to isolate!');
        debugPrint('[TtsService] Error: $sendError');
        debugPrint('[TtsService] Stack: $sendStack');
        _pendingRequests.remove(requestId);
        _stateController.add(TtsPlaybackState.error);
        return null;
      }

      debugPrint('[TtsService] Waiting for isolate response...');
      final result = await completer.future;
      debugPrint(
        '[TtsService] ===== generateAudioWithChunks END (${result != null ? "SUCCESS" : "NULL"}) =====',
      );
      return result;
    } catch (e, st) {
      debugPrint('[TtsService] Generate request error: $e\n$st');
      _stateController.add(TtsPlaybackState.error);
      return null;
    }
  }

  Future<String> _getDefaultOutputPath() async {
    final baseDir = await getExternalStorageDirectory();
    final dir = baseDir ?? await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return '${dir.path}/tts_${timestamp}_$random.wav';
  }

  /// Cancels any ongoing generation (best effort)
  void cancelGeneration() {
    // Current isolate impl process chunks sequentially, we can't easily interrupt
    // without disposing the engine. For now, we just clear pending listeners.
    for (var req in _pendingRequests.values) {
      req.completer.complete(null);
    }
    _pendingRequests.clear();
    _stateController.add(TtsPlaybackState.idle);
  }

  void clearEngine(String modelPath) {
    // No-op for now, or send dispose command if needed
  }

  void clearAllEngines() {
    // No-op
  }

  void dispose() {
    _isDisposed = true;
    _isolateSubscription?.cancel();
    _isolate?.kill();
    _isolate = null;
    _sendPort = null;
    _stateController.close();
  }
}

class _GenerationRequestState {
  final Completer<TtsGenerationResult?> completer;
  final void Function(double)? onProgress;
  final String? outputPath;

  _GenerationRequestState({
    required this.completer,
    this.onProgress,
    this.outputPath,
  });
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
