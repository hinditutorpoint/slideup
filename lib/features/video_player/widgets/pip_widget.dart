import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/video_player_state.dart';
import '../providers/video_player_provider.dart';
import '../providers/pip_provider.dart';
import '../services/pip_service.dart';

class PiPWidget extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onExpand;

  const PiPWidget({super.key, this.onClose, this.onExpand});

  @override
  ConsumerState<PiPWidget> createState() => _PiPWidgetState();
}

class _PiPWidgetState extends ConsumerState<PiPWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  Offset? _dragStartOffset;
  Offset? _initialPosition;
  bool _showControls = true;
  bool _isResizing = false;
  double _resizeStartScale = 1.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pipState = ref.watch(pipProvider);
    final playerState = ref.watch(videoPlayerProvider);
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Semi-transparent background (optional)
        // GestureDetector(
        //   onTap: widget.onExpand,
        //   child: Container(color: Colors.black26),
        // ),

        // PiP Window
        AnimatedPositioned(
          duration: pipState.isDragging
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          left: pipState.position.x,
          top: pipState.position.y,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              //here throw error
              onTap: _toggleControls,
              //onPanStart: _handleDragStart,
              //onPanUpdate: (details) => _handleDragUpdate(details, screenSize),
              //onPanEnd: (details) => _handleDragEnd(screenSize),
              onLongPress: _handleLongPress,
              onLongPressEnd: (_) => _handleLongPressEnd(screenSize),
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              onScaleEnd: (_) => _handleScaleEnd(screenSize),
              child: _buildPiPWindow(pipState, playerState),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPiPWindow(PiPStateData pipState, VideoPlayerState playerState) {
    final size = pipState.size;
    final controlsMode = _getControlsMode(size);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Video
            _buildVideo(),

            // Controls overlay
            if (_showControls)
              _buildControlsOverlay(controlsMode, playerState, pipState),

            // Resize handle
            if (_showControls)
              Positioned(right: 0, bottom: 0, child: _buildResizeHandle()),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);

      return SizedBox.expand(
        child: Video(
          controller: notifier.videoController,
          controls: NoVideoControls,
          fit: BoxFit.contain,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ PiP video build error: $e');
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.red),
        ),
      );
    }
  }

  Widget _buildControlsOverlay(
    _ControlsMode mode,
    VideoPlayerState playerState,
    PiPStateData pipState,
  ) {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.5),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: Column(
          children: [
            // Top bar
            _buildTopBar(),

            const Spacer(),

            // Center/Bottom controls based on mode
            _buildCenterControls(mode, playerState),

            if (mode == _ControlsMode.expanded) _buildProgressBar(playerState),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Expand button
          _MiniIconButton(
            icon: Icons.open_in_full,
            onTap: _handleExpand,
            tooltip: 'Expand',
          ),
          // Close button
          _MiniIconButton(
            icon: Icons.close,
            onTap: _handleClose,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(
    _ControlsMode mode,
    VideoPlayerState playerState,
  ) {
    switch (mode) {
      case _ControlsMode.mini:
        // Only play/pause
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _MiniIconButton(
            icon: playerState.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 32,
            onTap: _handlePlayPause,
          ),
        );

      case _ControlsMode.small:
        // Play/pause + next/previous
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (playerState.canPlayPrevious)
                _MiniIconButton(
                  icon: Icons.skip_previous,
                  onTap: _handlePrevious,
                ),
              const SizedBox(width: 8),
              _MiniIconButton(
                icon: playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 36,
                onTap: _handlePlayPause,
              ),
              const SizedBox(width: 8),
              if (playerState.canPlayNext)
                _MiniIconButton(icon: Icons.skip_next, onTap: _handleNext),
            ],
          ),
        );

      case _ControlsMode.expanded:
        // Full controls
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (playerState.canPlayPrevious)
                _MiniIconButton(
                  icon: Icons.skip_previous,
                  onTap: _handlePrevious,
                ),
              _MiniIconButton(
                icon: Icons.replay_10,
                onTap: () => _handleSeek(-10),
              ),
              const SizedBox(width: 8),
              _MiniIconButton(
                icon: playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 40,
                onTap: _handlePlayPause,
              ),
              const SizedBox(width: 8),
              _MiniIconButton(
                icon: Icons.forward_10,
                onTap: () => _handleSeek(10),
              ),
              if (playerState.canPlayNext)
                _MiniIconButton(icon: Icons.skip_next, onTap: _handleNext),
            ],
          ),
        );
    }
  }

  Widget _buildProgressBar(VideoPlayerState playerState) {
    final progress = playerState.progress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
          minHeight: 3,
        ),
      ),
    );
  }

  Widget _buildResizeHandle() {
    return GestureDetector(
      onPanStart: (_) => _handleResizeStart(),
      onPanUpdate: _handleResizeUpdate,
      onPanEnd: (_) => _handleResizeEnd(),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: const Icon(Icons.open_in_full, color: Colors.white70, size: 14),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CONTROLS MODE
  // ═══════════════════════════════════════════════════════

  _ControlsMode _getControlsMode(PiPSize size) {
    if (size.width <= PiPSize.mini.width + 20) {
      return _ControlsMode.mini;
    } else if (size.width <= PiPSize.small.width + 30) {
      return _ControlsMode.small;
    } else {
      return _ControlsMode.expanded;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GESTURE HANDLERS
  // ═══════════════════════════════════════════════════════

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    HapticFeedback.selectionClick();
  }

  void _handleDragStart(DragStartDetails details) {
    try {
      _dragStartOffset = details.globalPosition;
      final pipState = ref.read(pipProvider);
      _initialPosition = Offset(pipState.position.x, pipState.position.y);
      ref.read(pipProvider.notifier).startDrag();
    } catch (e) {
      debugPrint('⚠️ Drag start error: $e');
    }
  }

  void _handleDragUpdate(DragUpdateDetails details, Size screenSize) {
    try {
      if (_dragStartOffset == null || _initialPosition == null) return;

      final delta = details.globalPosition - _dragStartOffset!;
      final newX = (_initialPosition!.dx + delta.dx);
      final newY = (_initialPosition!.dy + delta.dy);

      ref.read(pipProvider.notifier).setPosition(PiPPosition(x: newX, y: newY));
    } catch (e) {
      debugPrint('⚠️ Drag update error: $e');
    }
  }

  void _handleDragEnd(Size screenSize) {
    try {
      ref.read(pipProvider.notifier).endDrag(screenSize);
      _dragStartOffset = null;
      _initialPosition = null;
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('⚠️ Drag end error: $e');
    }
  }

  void _handleLongPress() {
    try {
      HapticFeedback.heavyImpact();
      ref.read(pipProvider.notifier).cycleSize();
    } catch (e) {
      debugPrint('⚠️ Long press error: $e');
    }
  }

  void _handleLongPressEnd(Size screenSize) {
    try {
      ref.read(pipProvider.notifier).snapToCorner(screenSize);
    } catch (e) {
      debugPrint('⚠️ Long press end error: $e');
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    try {
      final pipState = ref.read(pipProvider);
      _initialPosition = Offset(pipState.position.x, pipState.position.y);
      _dragStartOffset = details.focalPoint;
      _resizeStartScale = 1.0;

      // Detect if it's a pinch (2+ fingers) or drag (1 finger)
      if (details.pointerCount > 1) {
        _isResizing = true;
      } else {
        _isResizing = false;
        ref.read(pipProvider.notifier).startDrag();
      }
    } catch (e) {
      debugPrint('⚠️ Scale start error: $e');
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    try {
      if (_isResizing) {
        // Pinch to resize
        if (details.scale != 1.0) {
          final scaleDelta = (details.scale - _resizeStartScale) * 100;
          ref.read(pipProvider.notifier).resizeByDelta(scaleDelta);
          _resizeStartScale = details.scale;
        }
      } else {
        // Single finger drag
        if (_dragStartOffset == null || _initialPosition == null) return;

        final delta = details.focalPoint - _dragStartOffset!;
        final newX = _initialPosition!.dx + delta.dx;
        final newY = _initialPosition!.dy + delta.dy;

        ref
            .read(pipProvider.notifier)
            .setPosition(PiPPosition(x: newX, y: newY));
      }
    } catch (e) {
      debugPrint('⚠️ Scale update error: $e');
    }
  }

  void _handleScaleEnd(Size screenSize) {
    try {
      if (_isResizing) {
        ref.read(pipProvider.notifier).endResize();
      } else {
        ref.read(pipProvider.notifier).endDrag(screenSize);
        HapticFeedback.lightImpact();
      }

      _dragStartOffset = null;
      _initialPosition = null;
      _isResizing = false;
    } catch (e) {
      debugPrint('⚠️ Scale end error: $e');
    }
  }

  void _handleResizeStart() {
    try {
      ref.read(pipProvider.notifier).startResize();
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('⚠️ Resize start error: $e');
    }
  }

  void _handleResizeUpdate(DragUpdateDetails details) {
    try {
      final delta = details.delta.dx + details.delta.dy;
      ref.read(pipProvider.notifier).resizeByDelta(delta);
    } catch (e) {
      debugPrint('⚠️ Resize update error: $e');
    }
  }

  void _handleResizeEnd() {
    try {
      ref.read(pipProvider.notifier).endResize();
    } catch (e) {
      debugPrint('⚠️ Resize end error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYBACK HANDLERS
  // ═══════════════════════════════════════════════════════

  void _handlePlayPause() {
    try {
      ref.read(videoPlayerProvider.notifier).playOrPause();
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('⚠️ Play/pause error: $e');
    }
  }

  void _handlePrevious() {
    try {
      ref.read(videoPlayerProvider.notifier).playPrevious();
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('⚠️ Previous error: $e');
    }
  }

  void _handleNext() {
    try {
      ref.read(videoPlayerProvider.notifier).playNext();
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('⚠️ Next error: $e');
    }
  }

  void _handleSeek(int seconds) {
    try {
      ref.read(videoPlayerProvider.notifier).seekRelative(seconds);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('⚠️ Seek error: $e');
    }
  }

  void _handleExpand() {
    try {
      _animationController.reverse().then((_) {
        ref.read(pipProvider.notifier).disablePiP();
        ref.read(videoPlayerProvider.notifier).exitPiPMode();
        widget.onExpand?.call();
      });
    } catch (e) {
      debugPrint('⚠️ Expand error: $e');
    }
  }

  void _handleClose() {
    try {
      _animationController.reverse().then((_) {
        ref.read(videoPlayerProvider.notifier).stop();
        ref.read(pipProvider.notifier).disablePiP();
        widget.onClose?.call();
      });
    } catch (e) {
      debugPrint('⚠️ Close error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ HELPER WIDGETS
// ═══════════════════════════════════════════════════════

enum _ControlsMode { mini, small, expanded }

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  const _MiniIconButton({
    required this.icon,
    this.onTap,
    this.size = 24,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(size * 0.2),
        decoration: BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
