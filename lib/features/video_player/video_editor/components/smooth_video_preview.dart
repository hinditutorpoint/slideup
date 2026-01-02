// components/smooth_video_preview.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:async';

class SmoothVideoPreview extends StatefulWidget {
  final String videoPath;
  final Duration currentPosition;
  final Duration trimStart;
  final Duration trimEnd;
  final bool isPlaying;
  final Function(Duration) onPositionChanged;
  final VoidCallback? onPlayPause;
  final Widget? overlayWidget;

  const SmoothVideoPreview({
    super.key,
    required this.videoPath,
    required this.currentPosition,
    required this.trimStart,
    required this.trimEnd,
    required this.isPlaying,
    required this.onPositionChanged,
    this.onPlayPause,
    this.overlayWidget,
  });

  @override
  State<SmoothVideoPreview> createState() => _SmoothVideoPreviewState();
}

class _SmoothVideoPreviewState extends State<SmoothVideoPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isDisposed = false;
  Timer? _positionUpdateTimer;
  Duration _lastReportedPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(SmoothVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoPath != widget.videoPath) {
      _reinitializeVideo();
    } else {
      if (oldWidget.isPlaying != widget.isPlaying) {
        _handlePlayPause();
      }

      // Only seek if position changed significantly and not playing
      if (!widget.isPlaying &&
          (oldWidget.currentPosition != widget.currentPosition) &&
          (widget.currentPosition -
                      (_controller?.value.position ?? Duration.zero))
                  .abs() >
              const Duration(milliseconds: 100)) {
        _seekToPosition();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _positionUpdateTimer?.cancel();
    _controller?.removeListener(_onVideoStateChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    if (_isDisposed) return;

    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));

      await _controller!.initialize();

      if (_isDisposed) {
        _controller?.dispose();
        return;
      }

      // Set to initial position
      await _controller!.seekTo(widget.currentPosition);

      // Add listener for video state changes
      _controller!.addListener(_onVideoStateChanged);

      if (mounted) {
        setState(() => _isInitialized = true);
      }

      // Start playing if needed
      if (widget.isPlaying) {
        _startPlayback();
      }
    } catch (e) {
      debugPrint('❌ Initialize video error: $e');
      if (mounted) {
        setState(() => _isInitialized = false);
      }
    }
  }

  Future<void> _reinitializeVideo() async {
    _positionUpdateTimer?.cancel();
    _controller?.removeListener(_onVideoStateChanged);
    await _controller?.dispose();
    _controller = null;
    setState(() => _isInitialized = false);
    await _initializeVideo();
  }

  void _onVideoStateChanged() {
    // This only handles video state changes, not position updates
    if (_isDisposed || !mounted) return;

    // Check if video ended unexpectedly
    if (_controller != null &&
        !_controller!.value.isPlaying &&
        widget.isPlaying) {
      // Video stopped but should be playing - restart from trim start
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted) {
          _controller?.seekTo(widget.trimStart);
          _controller?.play();
        }
      });
    }
  }

  void _startPlayback() {
    if (_controller == null || _isDisposed) return;

    try {
      // Start the video
      _controller!.play();

      // Start position update timer
      _positionUpdateTimer?.cancel();
      _positionUpdateTimer = Timer.periodic(
        const Duration(milliseconds: 50), // 20 updates per second
        (_) => _updatePosition(),
      );
    } catch (e) {
      debugPrint('❌ Start playback error: $e');
    }
  }

  void _stopPlayback() {
    if (_controller == null || _isDisposed) return;

    try {
      _controller!.pause();
      _positionUpdateTimer?.cancel();
    } catch (e) {
      debugPrint('❌ Stop playback error: $e');
    }
  }

  void _updatePosition() {
    if (_isDisposed || !mounted || _controller == null) {
      _positionUpdateTimer?.cancel();
      return;
    }

    try {
      final position = _controller!.value.position;

      // Check if we've gone past trim end
      if (position >= widget.trimEnd) {
        _stopPlayback();
        _controller!.seekTo(widget.trimStart);
        _notifyPositionChanged(widget.trimStart);
        return;
      }

      // Only notify if position changed significantly
      if ((position - _lastReportedPosition).abs() >
          const Duration(milliseconds: 100)) {
        _notifyPositionChanged(position);
      }
    } catch (e) {
      debugPrint('❌ Update position error: $e');
    }
  }

  void _notifyPositionChanged(Duration position) {
    if (_isDisposed || !mounted) return;

    _lastReportedPosition = position;

    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        try {
          widget.onPositionChanged(position);
        } catch (e) {
          debugPrint('❌ Position callback error: $e');
        }
      }
    });
  }

  Future<void> _handlePlayPause() async {
    if (_controller == null || !_isInitialized || _isDisposed) return;

    try {
      if (widget.isPlaying) {
        // Check if at end, if so restart from trim start
        final currentPos = _controller!.value.position;
        if (currentPos >= widget.trimEnd || currentPos < widget.trimStart) {
          await _controller!.seekTo(widget.trimStart);
        }
        _startPlayback();
      } else {
        _stopPlayback();
      }
    } catch (e) {
      debugPrint('❌ Handle play/pause error: $e');
    }
  }

  Future<void> _seekToPosition() async {
    if (_controller == null || !_isInitialized || _isDisposed) return;

    try {
      await _controller!.seekTo(widget.currentPosition);
    } catch (e) {
      debugPrint('❌ Seek error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onPlayPause,
      child: Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video player
                VideoPlayer(_controller!),

                // Custom overlays (text, images, etc.)
                if (widget.overlayWidget != null) widget.overlayWidget!,

                // Play/pause indicator (centered)
                if (!widget.isPlaying)
                  const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white70,
                      size: 64,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
