import 'dart:io';
import 'package:flutter/foundation.dart';
//import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as path;
import '../models/subtitle_segment.dart';
//import '../services/video_service.dart';

class WhisperService {
  static final WhisperService instance = WhisperService._();
  WhisperService._();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      debugPrint('✅ Whisper initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Whisper: $e');
      _isInitialized = false;
    }
  }

  Future<String?> transcribeVideo(String videoPath) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Extract audio from video
      debugPrint('🎵 Extracting audio from video...');
      final audioPath = await _extractAudioFromVideo(videoPath);
      if (audioPath == null) {
        debugPrint('❌ Failed to extract audio');
        return null;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error transcribing video: $e');
      return null;
    }
  }

  Future<String?> _extractAudioFromVideo(String videoPath) async {
    try {
      final baseDir = await getExternalStorageDirectory();
      if (baseDir == null) return null;

      final audioDir = Directory('${baseDir.path}/audio');
      if (!audioDir.existsSync()) {
        audioDir.createSync(recursive: true);
      }

      final name = path.basenameWithoutExtension(videoPath);
      final outputPath = '${audioDir.path}/${name}_16k.wav';

      final command =
          '-y -i "$videoPath" '
          '-vn '
          '-ac 1 '
          '-ar 16000 '
          '-sample_fmt s16 '
          '"$outputPath"';

      final session = await FFmpegKit.execute(command);
      final rc = await session.getReturnCode();

      if (ReturnCode.isSuccess(rc) && File(outputPath).existsSync()) {
        debugPrint('✅ 16kHz WAV created: $outputPath');
        return outputPath;
      }

      debugPrint('❌ FFmpeg failed');
      return null;
    } catch (e, st) {
      debugPrint('❌ Error: $e \n$st');
      return null;
    }
  }

  Future<List<SubtitleSegment>> getTimedTranscription(String videoPath) async {
    try {
      if (!_isInitialized) await initialize();

      final audioPath = await _extractAudioFromVideo(videoPath);
      debugPrint('Extracted audio path: $audioPath');
      if (audioPath == null || !File(audioPath).existsSync()) return [];
      //final baseDir = await getExternalStorageDirectory();
      //final modelDir = Directory('${baseDir?.path}/models');
      return [];
    } catch (e) {
      debugPrint('❌ Error getting timed transcription: $e');
      return [];
    }
  }

  void dispose() {
    _isInitialized = false;
  }
}
