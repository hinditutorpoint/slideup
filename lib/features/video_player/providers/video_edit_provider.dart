import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/video_edit_settings.dart';
import '../services/video_edit_service.dart';
import '../services/thumbnail_service.dart';
import '../services/settings_storage_service.dart';

// ═══════════════════════════════════════════════════════
// ✅ PROVIDERS
// ═══════════════════════════════════════════════════════

final videoEditServiceProvider = Provider<VideoEditService>((ref) {
  return VideoEditService();
});

final thumbnailServiceProvider = Provider<ThumbnailService>((ref) {
  final service = ThumbnailService();
  ref.onDispose(() => service.dispose());
  return service;
});

final videoEditProvider = NotifierProvider<VideoEditNotifier, VideoEditState>(
  () {
    return VideoEditNotifier();
  },
);

final colorPresetsProvider = FutureProvider<List<ColorPreset>>((ref) async {
  final customPresets = await SettingsStorageService.loadCustomColorPresets();
  return [...ColorPreset.defaultPresets, ...customPresets];
});

final isProcessingProvider = Provider<bool>((ref) {
  return ref.watch(videoEditProvider.select((s) => s.isProcessing));
});

final processProgressProvider = Provider<double>((ref) {
  return ref.watch(videoEditProvider.select((s) => s.processProgress));
});

// ═══════════════════════════════════════════════════════
// ✅ VIDEO EDIT NOTIFIER
// ═══════════════════════════════════════════════════════

class VideoEditNotifier extends Notifier<VideoEditState> {
  final _uuid = const Uuid();

  String? _currentVideoPath;
  Duration _currentVideoDuration = Duration.zero;

  // Access services via getters that use ref
  VideoEditService get _editService => ref.read(videoEditServiceProvider);
  ThumbnailService get _thumbnailService => ref.read(thumbnailServiceProvider);

  @override
  VideoEditState build() {
    // Return initial state
    return const VideoEditState();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  void setVideoSource(String path, Duration duration) {
    _currentVideoPath = path;
    _currentVideoDuration = duration;
  }

  void enterEditMode() {
    state = state.copyWith(isEditing: true);
  }

  void exitEditMode() {
    state = const VideoEditState();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ COLOR GRADING
  // ═══════════════════════════════════════════════════════

  void updateColorGrade(ColorGradeSettings settings) {
    state = state.copyWith(colorGrade: settings);
  }

  void resetColorGrade() {
    state = state.copyWith(colorGrade: const ColorGradeSettings());
  }

  void updateBrightness(double value) {
    state = state.copyWith(
      colorGrade: state.colorGrade.copyWith(brightness: value),
    );
  }

  void updateContrast(double value) {
    state = state.copyWith(
      colorGrade: state.colorGrade.copyWith(contrast: value),
    );
  }

  void updateSaturation(double value) {
    state = state.copyWith(
      colorGrade: state.colorGrade.copyWith(saturation: value),
    );
  }

  void updateHue(double value) {
    state = state.copyWith(colorGrade: state.colorGrade.copyWith(hue: value));
  }

  void updateRed(double value) {
    state = state.copyWith(colorGrade: state.colorGrade.copyWith(red: value));
  }

  void updateGreen(double value) {
    state = state.copyWith(colorGrade: state.colorGrade.copyWith(green: value));
  }

  void updateBlue(double value) {
    state = state.copyWith(colorGrade: state.colorGrade.copyWith(blue: value));
  }

  void updateTemperature(double value) {
    state = state.copyWith(
      colorGrade: state.colorGrade.copyWith(temperature: value),
    );
  }

  void applyPreset(ColorPreset preset) {
    state = state.copyWith(colorGrade: preset.settings);
  }

  Future<void> saveAsPreset(String name) async {
    try {
      final preset = ColorPreset(
        id: _uuid.v4(),
        name: name,
        settings: state.colorGrade,
      );
      await SettingsStorageService.saveCustomColorPreset(preset);
    } catch (e) {
      debugPrint('❌ Save preset error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CLIP MARKERS
  // ═══════════════════════════════════════════════════════

  void addClipMarker(Duration startTime, Duration endTime, {String? label}) {
    final marker = ClipMarker(
      id: _uuid.v4(),
      startTime: startTime,
      endTime: endTime,
      label: label,
      colorGrade: state.colorGrade.isDefault ? null : state.colorGrade,
    );

    state = state.copyWith(clipMarkers: [...state.clipMarkers, marker]);
  }

  void updateClipMarker(String id, ClipMarker updated) {
    final markers = state.clipMarkers.map((m) {
      return m.id == id ? updated : m;
    }).toList();

    state = state.copyWith(clipMarkers: markers);
  }

  void removeClipMarker(String id) {
    final markers = state.clipMarkers.where((m) => m.id != id).toList();
    state = state.copyWith(clipMarkers: markers);
  }

  void setActiveClip(ClipMarker? clip) {
    state = state.copyWith(activeClip: clip);
  }

  void clearClipMarkers() {
    state = state.copyWith(clipMarkers: [], activeClip: null);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TRIM
  // ═══════════════════════════════════════════════════════

  void setTrimStart(Duration? time) {
    state = state.copyWith(trimStart: time);
  }

  void setTrimEnd(Duration? time) {
    state = state.copyWith(trimEnd: time);
  }

  void clearTrim() {
    state = state.copyWith(trimStart: null, trimEnd: null);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PROCESSING
  // ═══════════════════════════════════════════════════════

  Future<String?> exportTrimmedVideo({String? outputPath}) async {
    if (_currentVideoPath == null) {
      debugPrint('❌ No video source set');
      return null;
    }

    final start = state.trimStart ?? Duration.zero;
    final end = state.trimEnd ?? _currentVideoDuration;

    if (start >= end) {
      debugPrint('❌ Invalid trim range');
      return null;
    }

    state = state.copyWith(isProcessing: true, processProgress: 0.0);

    try {
      final result = await _editService.trimVideo(
        inputPath: _currentVideoPath!,
        startTime: start,
        endTime: end,
        outputPath: outputPath,
        onProgress: (progress) {
          // Update progress if the notifier is still active
          try {
            state = state.copyWith(processProgress: progress);
          } catch (_) {
            // Notifier may have been disposed
          }
        },
      );

      return result;
    } catch (e) {
      debugPrint('❌ Export trimmed video error: $e');
      return null;
    } finally {
      // Reset processing state if notifier is still active
      try {
        state = state.copyWith(isProcessing: false);
      } catch (_) {
        // Notifier may have been disposed
      }
    }
  }

  Future<String?> exportWithColorGrading({String? outputPath}) async {
    if (_currentVideoPath == null) {
      debugPrint('❌ No video source set');
      return null;
    }

    state = state.copyWith(isProcessing: true, processProgress: 0.0);

    try {
      final result = await _editService.applyColorGrading(
        inputPath: _currentVideoPath!,
        settings: state.colorGrade,
        outputPath: outputPath,
        onProgress: (progress) {
          try {
            state = state.copyWith(processProgress: progress);
          } catch (_) {}
        },
      );

      return result;
    } catch (e) {
      debugPrint('❌ Export with color grading error: $e');
      return null;
    } finally {
      try {
        state = state.copyWith(isProcessing: false);
      } catch (_) {}
    }
  }

  Future<String?> exportClip(ClipMarker marker, {String? outputPath}) async {
    if (_currentVideoPath == null) {
      debugPrint('❌ No video source set');
      return null;
    }

    state = state.copyWith(isProcessing: true, processProgress: 0.0);

    try {
      final result = await _editService.createClipFromMarker(
        inputPath: _currentVideoPath!,
        marker: marker,
        outputPath: outputPath,
        onProgress: (progress) {
          try {
            state = state.copyWith(processProgress: progress);
          } catch (_) {}
        },
      );

      return result;
    } catch (e) {
      debugPrint('❌ Export clip error: $e');
      return null;
    } finally {
      try {
        state = state.copyWith(isProcessing: false);
      } catch (_) {}
    }
  }

  Future<String?> extractAudio({
    String format = 'mp3',
    int bitrate = 192,
    String? outputPath,
  }) async {
    if (_currentVideoPath == null) {
      debugPrint('❌ No video source set');
      return null;
    }

    state = state.copyWith(isProcessing: true, processProgress: 0.0);

    try {
      final result = await _editService.extractAudio(
        inputPath: _currentVideoPath!,
        format: format,
        bitrate: bitrate,
        outputPath: outputPath,
        onProgress: (progress) {
          try {
            state = state.copyWith(processProgress: progress);
          } catch (_) {}
        },
      );

      if (result != null) {
        state = state.copyWith(extractedAudioPath: result);
      }

      return result;
    } catch (e) {
      debugPrint('❌ Extract audio error: $e');
      return null;
    } finally {
      try {
        state = state.copyWith(isProcessing: false);
      } catch (_) {}
    }
  }

  Future<List<Uint8List>> extractFrames({
    int fps = 1,
    int maxFrames = 50,
  }) async {
    if (_currentVideoPath == null) {
      debugPrint('❌ No video source set');
      return [];
    }

    state = state.copyWith(isProcessing: true, processProgress: 0.0);

    try {
      final frames = await _editService.extractFrames(
        inputPath: _currentVideoPath!,
        startTime: state.trimStart,
        endTime: state.trimEnd,
        fps: fps,
        maxFrames: maxFrames,
        onProgress: (progress) {
          try {
            state = state.copyWith(processProgress: progress);
          } catch (_) {}
        },
      );

      state = state.copyWith(extractedFrames: frames);
      return frames;
    } catch (e) {
      debugPrint('❌ Extract frames error: $e');
      return [];
    } finally {
      try {
        state = state.copyWith(isProcessing: false);
      } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PREVIEW
  // ═══════════════════════════════════════════════════════

  Future<Uint8List?> getColorPreview({Duration? atPosition}) async {
    if (_currentVideoPath == null) return null;

    try {
      return await _editService.generateColorPreview(
        inputPath: _currentVideoPath!,
        settings: state.colorGrade,
        atPosition: atPosition,
      );
    } catch (e) {
      debugPrint('❌ Get color preview error: $e');
      return null;
    }
  }

  Future<Uint8List?> getThumbnailAtPosition(Duration position) async {
    if (_currentVideoPath == null) return null;

    try {
      return await _thumbnailService.getThumbnailAtPosition(
        videoPath: _currentVideoPath!,
        position: position,
      );
    } catch (e) {
      debugPrint('❌ Get thumbnail error: $e');
      return null;
    }
  }

  Future<List<Uint8List>> generateTimelineThumbnails({int count = 10}) async {
    if (_currentVideoPath == null) return [];

    try {
      return await _thumbnailService.generateTimelineThumbnails(
        videoPath: _currentVideoPath!,
        videoDuration: _currentVideoDuration,
        count: count,
      );
    } catch (e) {
      debugPrint('❌ Generate timeline thumbnails error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CANCEL
  // ═══════════════════════════════════════════════════════

  Future<void> cancelProcessing() async {
    try {
      await _editService.cancelCurrentOperation();
      try {
        state = state.copyWith(isProcessing: false);
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ Cancel processing error: $e');
    }
  }
}
