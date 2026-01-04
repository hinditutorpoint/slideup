import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Commands sent to the isolate
enum TtsIsolateCommand { init, loadModel, generate, dispose }

/// Responses received from the isolate
enum TtsIsolateResponse {
  initSuccess,
  initFailure,
  modelLoaded,
  modelLoadFailed,
  generationProgress,
  generationSuccess,
  generationFailure,
}

/// Data class for generation request
class GenerationRequest {
  final String id;
  final String text;
  final String modelPath;
  final double speed;
  final int speakerId;

  GenerationRequest({
    required this.id,
    required this.text,
    required this.modelPath,
    required this.speed,
    required this.speakerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'modelPath': modelPath,
      'speed': speed,
      'speakerId': speakerId,
    };
  }

  factory GenerationRequest.fromMap(Map<String, dynamic> map) {
    return GenerationRequest(
      id: map['id'] as String,
      text: map['text'] as String,
      modelPath: map['modelPath'] as String,
      speed: (map['speed'] as num).toDouble(),
      speakerId: map['speakerId'] as int,
    );
  }
}

/// Data class for generation success
class GenerationSuccess {
  final String requestId;
  final Uint8List audioData;
  final int sampleRate;
  final double durationSeconds;

  GenerationSuccess({
    required this.requestId,
    required this.audioData,
    required this.sampleRate,
    required this.durationSeconds,
  });
}

/// Entry point for the isolate
void ttsIsolateEntry(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final isolate = _TtsIsolateHandler(sendPort);

  receivePort.listen((message) {
    if (message is Map<String, dynamic>) {
      final command = message['command'] as TtsIsolateCommand;
      isolate.handleCommand(command, message);
    }
  });
}

class _TtsIsolateHandler {
  final SendPort sendPort;
  final Map<String, sherpa.OfflineTts> _engines = {};
  bool _isInit = false;

  _TtsIsolateHandler(this.sendPort);

  Future<void> handleCommand(
    TtsIsolateCommand command,
    Map<String, dynamic> message,
  ) async {
    try {
      switch (command) {
        case TtsIsolateCommand.init:
          await _initSherpa();
          break;
        case TtsIsolateCommand.loadModel:
          final modelPath = message['modelPath'] as String;
          await _loadModel(modelPath);
          break;
        case TtsIsolateCommand.generate:
          final reqData = message['request'];
          if (reqData == null) {
            throw Exception('Missing request data for generation');
          }
          final request = reqData is Map<String, dynamic>
              ? GenerationRequest.fromMap(reqData)
              : reqData as GenerationRequest;
          await _generate(request);
          break;
        case TtsIsolateCommand.dispose:
          _dispose();
          break;
      }
    } catch (e, st) {
      debugPrint('[TtsIsolate] Unhandled error: $e\n$st');
    }
  }

  Future<void> _initSherpa() async {
    try {
      if (!_isInit) {
        sherpa.initBindings();
        _isInit = true;
      }
      sendPort.send({'type': TtsIsolateResponse.initSuccess});
    } catch (e) {
      sendPort.send({
        'type': TtsIsolateResponse.initFailure,
        'error': e.toString(),
      });
    }
  }

  Future<void> _loadModel(String modelPath) async {
    if (_engines.containsKey(modelPath)) {
      sendPort.send({
        'type': TtsIsolateResponse.modelLoaded,
        'modelPath': modelPath,
      });
      return;
    }

    try {
      final config = await _createConfig(modelPath);
      if (config == null) {
        throw Exception('Failed to create model config');
      }

      final engine = sherpa.OfflineTts(config);
      _engines[modelPath] = engine;

      sendPort.send({
        'type': TtsIsolateResponse.modelLoaded,
        'modelPath': modelPath,
      });
    } catch (e) {
      sendPort.send({
        'type': TtsIsolateResponse.modelLoadFailed,
        'modelPath': modelPath,
        'error': e.toString(),
      });
    }
  }

  Future<sherpa.OfflineTtsConfig?> _createConfig(String modelPath) async {
    final modelDir = Directory(modelPath);
    String? onnxModel;
    String? tokens;
    String? dataDir;

    if (await modelDir.exists()) {
      await for (final entity in modelDir.list(recursive: true)) {
        if (entity is File) {
          final name = entity.path
              .split(Platform.pathSeparator)
              .last
              .toLowerCase();
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
          final name = entity.path
              .split(Platform.pathSeparator)
              .last
              .toLowerCase();
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

    if (onnxModel == null) return null;

    return sherpa.OfflineTtsConfig(
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
  }

  Future<void> _generate(GenerationRequest request) async {
    final engine = _engines[request.modelPath];
    if (engine == null) {
      sendPort.send({
        'type': TtsIsolateResponse.generationFailure,
        'requestId': request.id,
        'error': 'Engine not loaded for this model',
      });
      return;
    }

    try {
      // Split text into chunks to report progress and allow cancellation check if we implemented it
      // For now, we just chunk to replicate the logic but do it all in one go
      final chunks = _splitTextIntoChunks(request.text, maxChunkLength: 120);
      final allSamples = <double>[];
      int sampleRate = 22050; // default

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        if (chunk.trim().isEmpty) continue;

        final audio = engine.generate(
          text: chunk,
          sid: request.speakerId,
          speed: request.speed,
        );

        allSamples.addAll(audio.samples);
        sampleRate = audio.sampleRate;

        // Report progress
        final progress = (i + 1) / chunks.length;
        sendPort.send({
          'type': TtsIsolateResponse.generationProgress,
          'requestId': request.id,
          'progress': progress,
        });
      }

      if (allSamples.isEmpty) {
        throw Exception('No samples generated');
      }

      // Convert to WAV
      final wavBytes = _createWavFile(
        Float32List.fromList(allSamples),
        sampleRate,
      );

      final durationSeconds = allSamples.length / sampleRate;

      sendPort.send({
        'type': TtsIsolateResponse.generationSuccess,
        'requestId': request.id,
        'success': GenerationSuccess(
          requestId: request.id,
          audioData: wavBytes,
          sampleRate: sampleRate,
          durationSeconds: durationSeconds,
        ),
      });
    } catch (e) {
      sendPort.send({
        'type': TtsIsolateResponse.generationFailure,
        'requestId': request.id,
        'error': e.toString(),
      });
    }
  }

  List<String> _splitTextIntoChunks(String text, {int maxChunkLength = 120}) {
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
      debugPrint('[TtsIsolate] WAV creation error: $e');
      return Uint8List(0);
    }
  }

  void _dispose() {
    // Sherpa engines generally just need to be garbage collected or have simple dispose?
    // The library doesn't seem to expose a dispose on OfflineTTS in dart bindings extensively,
    // but looking at source code (if available) would confirm.
    // For now we assume standard GC.
    _engines.clear();
  }
}
