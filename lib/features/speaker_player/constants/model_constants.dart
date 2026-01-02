import '../models/model_info.dart';
import '../models/download_model.dart';

class ModelConstants {
  static const String hiveBoxName = 'sherpa_models'; // Different box name
  static const String settingsBoxName = 'settings';
  static const String modelsDirectory = 'sherpa_models';

  // Sherpa ONNX Model URLs
  static const List<ModelInfo> availableModels = [
    // TTS Models
    ModelInfo(
      id: 'vits-piper-en-us',
      name: 'VITS Piper English (US)',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2',
      modelType: SherpaModelType.tts,
      language: 'en-US',
      description: 'High-quality English TTS model',
      estimatedSize: 63 * 1024 * 1024,
    ),

    // STT Models
    ModelInfo(
      id: 'whisper-tiny-en',
      name: 'Whisper Tiny English',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.en.tar.bz2',
      modelType: SherpaModelType.stt,
      language: 'en',
      description: 'Fast English speech recognition',
      estimatedSize: 40 * 1024 * 1024,
    ),

    ModelInfo(
      id: 'vits-piper-hi-priyamvada',
      name: 'VITS Piper Hindi (Priyamvada)',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-hi_IN-priyamvada-medium.tar.bz2',
      modelType: SherpaModelType.tts,
      language: 'hi-IN',
      description: 'Hindi TTS model – female voice (Priyamvada)',
      estimatedSize: 70 * 1024 * 1024, // ~70 MB
    ),
    ModelInfo(
      id: 'vits-piper-hi-pratham',
      name: 'VITS Piper Hindi (Pratham)',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-hi_IN-pratham-medium.tar.bz2',
      modelType: SherpaModelType.tts,
      language: 'hi-IN',
      description: 'Hindi TTS model – male voice (Pratham)',
      estimatedSize: 70 * 1024 * 1024, // ~70 MB
    ),

    // VAD Models
    ModelInfo(
      id: 'silero-vad',
      name: 'Silero VAD',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx',
      modelType: SherpaModelType.vad,
      language: 'universal',
      description: 'Voice Activity Detection',
      estimatedSize: 2 * 1024 * 1024,
    ),
  ];

  static ModelInfo? getModelById(String id) {
    try {
      return availableModels.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<ModelInfo> getModelsByType(SherpaModelType type) {
    return availableModels.where((m) => m.modelType == type).toList();
  }

  static List<ModelInfo> getModelsByLanguage(String language) {
    return availableModels.where((m) => m.language == language).toList();
  }
}
