import 'dart:async';
import 'dart:io';
import 'package:video_player/video_player.dart';
import '../core/validation/numeric_guard.dart';

/// Lightweight preview engine md:325-347
/// No FFmpeg per frame — uses Flutter transforms, stays responsive
class PreviewEngine {
  VideoPlayerController? _controller;
  Duration _duration = Duration.zero;
  bool _disposed = false;
  int _opId = 0;

  VideoPlayerController? get controller => _controller;
  Duration get duration => _duration;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<void> load(String path) async {
    final op = ++_opId;
    await _disposeController();
    if (_disposed) return;
    final file = File(path);
    if (!await file.exists()) throw Exception('File not found: $path');
    final stat = await file.stat();
    if (stat.size == 0) throw Exception('Zero-byte file');
    final c = VideoPlayerController.file(file);
    _controller = c;
    await c.initialize();
    if (op != _opId || _disposed) {
      await c.dispose();
      return;
    }
    _duration = c.value.duration;
    if (!NumericGuard.isValidDuration(_duration)) _duration = Duration.zero;
    await c.setLooping(false);
  }

  Future<void> seekTo(Duration pos) async {
    if (!isInitialized) return;
    if (pos.isNegative) pos = Duration.zero;
    if (pos > _duration) pos = _duration;
    await _controller!.seekTo(pos);
  }

  Future<void> setVolume(double v) async {
    if (!isInitialized) return;
    final safe = NumericGuard.sanitizeVolume(v);
    await _controller!.setVolume(safe.clamp(0, 1));
  }

  Future<void> play() async {
    if (!isInitialized) return;
    await _controller!.play();
  }

  Future<void> pause() async {
    if (!isInitialized) return;
    await _controller!.pause();
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      try { await c.pause(); } catch (_) {}
      try { await c.dispose(); } catch (_) {}
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _opId++;
    await _disposeController();
  }
}
