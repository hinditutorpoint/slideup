import 'dart:typed_data';

/// TTS playback state
enum TtsPlaybackState {
  initial,
  idle,
  loading,
  generating,
  playing,
  paused,
  completed,
  error,
  stopped,
}

/// TTS request configuration
class TtsRequest {
  final String id;
  final String text;
  final String? modelPath; // Optional - uses default if null
  final double speed;
  final double pitch;
  final int speakerId;
  final bool showUi;
  final bool saveToFile;
  final String? outputPath;
  final Function(TtsPlaybackState state)? onStateChanged;
  final Function(double progress)? onProgress;
  final Function(String? filePath, Uint8List? audioData)? onAudioGenerated;
  final Function(String error)? onError;
  final Function()? onCompleted;

  TtsRequest({
    String? id,
    required this.text,
    this.modelPath, // Optional
    this.speed = 1.0,
    this.pitch = 1.0,
    this.speakerId = 0,
    this.showUi = true,
    this.saveToFile = false,
    this.outputPath,
    this.onStateChanged,
    this.onProgress,
    this.onAudioGenerated,
    this.onError,
    this.onCompleted,
  }) : id = id ?? 'tts_${DateTime.now().millisecondsSinceEpoch}';

  TtsRequest copyWith({
    String? id,
    String? text,
    String? modelPath,
    double? speed,
    double? pitch,
    int? speakerId,
    bool? showUi,
    bool? saveToFile,
    String? outputPath,
    Function(TtsPlaybackState state)? onStateChanged,
    Function(double progress)? onProgress,
    Function(String? filePath, Uint8List? audioData)? onAudioGenerated,
    Function(String error)? onError,
    Function()? onCompleted,
  }) {
    return TtsRequest(
      id: id ?? this.id,
      text: text ?? this.text,
      modelPath: modelPath ?? this.modelPath,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      speakerId: speakerId ?? this.speakerId,
      showUi: showUi ?? this.showUi,
      saveToFile: saveToFile ?? this.saveToFile,
      outputPath: outputPath ?? this.outputPath,
      onStateChanged: onStateChanged ?? this.onStateChanged,
      onProgress: onProgress ?? this.onProgress,
      onAudioGenerated: onAudioGenerated ?? this.onAudioGenerated,
      onError: onError ?? this.onError,
      onCompleted: onCompleted ?? this.onCompleted,
    );
  }
}

/// TTS playback status
class TtsStatus {
  final String? requestId;
  final TtsPlaybackState state;
  final double progress;
  final Duration position;
  final Duration duration;
  final String? error;
  final String? text;
  final String? audioFilePath;
  final String? modelName;

  const TtsStatus({
    this.requestId,
    this.state = TtsPlaybackState.idle,
    this.progress = 0.0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
    this.text,
    this.audioFilePath,
    this.modelName,
  });

  TtsStatus copyWith({
    String? requestId,
    TtsPlaybackState? state,
    double? progress,
    Duration? position,
    Duration? duration,
    String? error,
    String? text,
    String? audioFilePath,
    String? modelName,
  }) {
    return TtsStatus(
      requestId: requestId ?? this.requestId,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      error: error ?? this.error,
      text: text ?? this.text,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      modelName: modelName ?? this.modelName,
    );
  }

  factory TtsStatus.playing({
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
    String? text,
  }) {
    return TtsStatus(
      state: TtsPlaybackState.playing,
      position: position,
      duration: duration,
      progress: duration.inMilliseconds > 0
          ? position.inMilliseconds / duration.inMilliseconds
          : 0.0,
      text: text,
    );
  }

  bool get isPlaying => state == TtsPlaybackState.playing;
  bool get isPaused => state == TtsPlaybackState.paused;
  bool get isLoading =>
      state == TtsPlaybackState.loading || state == TtsPlaybackState.generating;

  bool get isGenerating => state == TtsPlaybackState.generating;
  bool get isIdle => state == TtsPlaybackState.idle;
  bool get isCompleted => state == TtsPlaybackState.completed;
  bool get hasError => state == TtsPlaybackState.error;

  String get positionText => _formatDuration(position);
  String get durationText => _formatDuration(duration);
  String get progressText => '${(progress * 100).toInt()}%';

  factory TtsStatus.initial() {
    return const TtsStatus(
      state: TtsPlaybackState.idle,
      position: Duration.zero,
      duration: Duration.zero,
      progress: 0.0,
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
