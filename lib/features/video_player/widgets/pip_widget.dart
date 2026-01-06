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

  Offset? _initialPosition;
  Offset? _dragStartOffset;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
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

    return AnimatedPositioned(
      duration: pipState.isDragging || pipState.isResizing
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      left: pipState.position.x,
      top: pipState.position.y,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: _toggleControls,
          onLongPress: _handleLongPress,
          onPanStart: (details) => _handleDragStart(details, pipState),
          onPanUpdate: _handleDragUpdate,
          onPanEnd: (details) => _handleDragEnd(screenSize),
          child: _buildWindowContent(pipState, playerState, screenSize),
        ),
      ),
    );
  }

  Widget _buildWindowContent(
    PiPStateData pipState,
    VideoPlayerState playerState,
    Size screenSize,
  ) {
    final isCompact = pipState.size.width < 220;

    return Container(
      width: pipState.size.width,
      height: pipState.size.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(color: Colors.white.withValues(alpha: 0.05), blurRadius: 1),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(child: _buildVideoPlayer()),
            if (_showControls)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.0, 0.25, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
            if (_showControls)
              Positioned.fill(
                child: _buildControls(pipState, playerState, isCompact),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _buildResizeHandle(pipState, screenSize),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    try {
      return Video(
        controller: ref.read(videoPlayerProvider.notifier).videoController,
        controls: NoVideoControls,
        fit: BoxFit.cover,
      );
    } catch (e) {
      debugPrint('⚠️ PiP video error: $e');
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.red, size: 32),
        ),
      );
    }
  }

  Widget _buildControls(
    PiPStateData pipState,
    VideoPlayerState playerState,
    bool isCompact,
  ) {
    final height = pipState.size.height;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTopBar(),
        const Spacer(),
        _buildCenterControls(playerState, isCompact),
        const Spacer(),
        if (height > 100)
          _buildProgressBar(playerState)
        else
          SizedBox(height: pipState.size.width < 180 ? 4 : 8),
      ],
    );
  }

  Widget _buildTopBar() {
    final pipState = ref.watch(pipProvider);
    final width = pipState.size.width;
    final isVerySmall = width < 180;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isVerySmall ? 4 : 8,
        isVerySmall ? 4 : 6,
        isVerySmall ? 4 : 8,
        0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isVerySmall)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.drag_indicator,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'PiP',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          _TopBarButton(
            icon: Icons.open_in_full_rounded,
            onTap: _handleExpand,
            size: isVerySmall ? 12 : 16,
          ),
          SizedBox(width: isVerySmall ? 2 : 4),
          _TopBarButton(
            icon: Icons.close_rounded,
            onTap: _handleClose,
            isDestructive: true,
            size: isVerySmall ? 12 : 16,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(VideoPlayerState playerState, bool isCompact) {
    final pipState = ref.watch(pipProvider);
    final width = pipState.size.width;
    final height = pipState.size.height;

    final minDimension = width < height ? width : height;
    final buttonSize = (minDimension * 0.25).clamp(20.0, 36.0);
    final skipSize = (minDimension * 0.18).clamp(16.0, 28.0);
    final spacing = (width * 0.04).clamp(6.0, 16.0);
    final showSkipButtons = width > 180;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width < 180 ? 4 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSkipButtons && playerState.canPlayPrevious) ...[
            _ControlButton(
              icon: Icons.skip_previous_rounded,
              size: skipSize,
              onTap: _handlePrevious,
            ),
            SizedBox(width: spacing),
          ],
          _PlayPauseButton(
            isPlaying: playerState.isPlaying,
            onTap: _handlePlayPause,
            size: buttonSize,
          ),
          if (showSkipButtons && playerState.canPlayNext) ...[
            SizedBox(width: spacing),
            _ControlButton(
              icon: Icons.skip_next_rounded,
              size: skipSize,
              onTap: _handleNext,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(VideoPlayerState playerState) {
    final pipState = ref.watch(pipProvider);
    final width = pipState.size.width;
    final height = pipState.size.height;

    if (height < 100) return const SizedBox.shrink();

    final isVerySmall = width < 180;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isVerySmall ? 6 : 12,
        0,
        isVerySmall ? 28 : 40,
        isVerySmall ? 6 : 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (width > 160)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(playerState.position),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: isVerySmall ? 9 : 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(playerState.duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: isVerySmall ? 9 : 10,
                  ),
                ),
              ],
            ),
          if (width > 160) const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(1.5),
            child: SizedBox(
              height: isVerySmall ? 2 : 3,
              child: LinearProgressIndicator(
                value: playerState.progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(PiPStateData pipState, Size screenSize) {
    final width = pipState.size.width;
    final handleSize = width < 180 ? 24.0 : 32.0;
    final iconSize = width < 180 ? 10.0 : 14.0;

    return GestureDetector(
      onPanStart: _handleResizeStart,
      onPanUpdate: (details) => _handleResizeUpdate(details, screenSize),
      onPanEnd: _handleResizeEnd,
      child: Container(
        width: handleSize,
        height: handleSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: width < 180 ? 0.08 : 0.1),
            ],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(handleSize * 0.5),
            bottomRight: const Radius.circular(16),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: handleSize * 0.125,
              bottom: handleSize * 0.125,
              child: Icon(
                Icons.open_in_full_rounded,
                size: iconSize,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            if (width >= 180) ...[
              Positioned(
                right: handleSize * 0.1875,
                bottom: handleSize * 0.3125,
                child: Container(
                  width: handleSize * 0.25,
                  height: 1.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              Positioned(
                right: handleSize * 0.3125,
                bottom: handleSize * 0.1875,
                child: Container(
                  width: 1.5,
                  height: handleSize * 0.25,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleControls() {
    HapticFeedback.selectionClick();
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    ref.read(pipProvider.notifier).cycleSize();
  }

  void _handleDragStart(DragStartDetails details, PiPStateData pipState) {
    _dragStartOffset = details.globalPosition;
    _initialPosition = Offset(pipState.position.x, pipState.position.y);
    ref.read(pipProvider.notifier).startDrag();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dragStartOffset == null || _initialPosition == null) return;

    final delta = details.globalPosition - _dragStartOffset!;
    ref
        .read(pipProvider.notifier)
        .setPosition(
          PiPPosition(
            x: _initialPosition!.dx + delta.dx,
            y: _initialPosition!.dy + delta.dy,
          ),
        );
  }

  void _handleDragEnd(Size screenSize) {
    HapticFeedback.lightImpact();
    ref.read(pipProvider.notifier).endDrag(screenSize);
    _dragStartOffset = null;
    _initialPosition = null;
  }

  void _handleResizeStart(DragStartDetails details) {
    HapticFeedback.selectionClick();
    ref.read(pipProvider.notifier).startResize();
  }

  void _handleResizeUpdate(DragUpdateDetails details, Size screenSize) {
    final pipState = ref.read(pipProvider);
    final delta = details.delta.dx + details.delta.dy;
    final newWidth = (pipState.size.width + delta).clamp(
      150.0,
      screenSize.width - 40,
    );
    final newHeight = newWidth * (9 / 16);
    final maxHeight = screenSize.height - pipState.position.y - 40;
    final constrainedHeight = newHeight.clamp(84.0, maxHeight);
    final constrainedWidth = constrainedHeight * (16 / 9);

    ref
        .read(pipProvider.notifier)
        .setSize(PiPSize(width: constrainedWidth, height: constrainedHeight));
  }

  void _handleResizeEnd(DragEndDetails details) {
    HapticFeedback.lightImpact();
    ref.read(pipProvider.notifier).endResize();
  }

  void _handlePlayPause() {
    HapticFeedback.selectionClick();
    ref.read(videoPlayerProvider.notifier).playOrPause();
  }

  void _handlePrevious() {
    HapticFeedback.mediumImpact();
    ref.read(videoPlayerProvider.notifier).playPrevious();
  }

  void _handleNext() {
    HapticFeedback.mediumImpact();
    ref.read(videoPlayerProvider.notifier).playNext();
  }

  void _handleExpand() async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(videoPlayerProvider.notifier).savePosition();
    } catch (_) {}
    await _animationController.reverse();
    widget.onExpand?.call();
  }

  void _handleClose() async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(videoPlayerProvider.notifier).savePosition();
    } catch (_) {}
    await _animationController.reverse();
    widget.onClose?.call();
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final double size;

  const _TopBarButton({
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final padding = size < 14 ? 4.0 : 6.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDestructive
              ? Colors.red.shade300
              : Colors.white.withValues(alpha: 0.9),
          size: size,
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final padding = size < 20 ? 4.0 : (size * 0.25).clamp(5.0, 8.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final double size;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final padding = size < 24 ? 4.0 : (size * 0.25).clamp(6.0, 10.0);
    final borderWidth = size < 24 ? 0.5 : (size > 30 ? 1.5 : 1.0);
    final isVerySmall = size < 24;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isVerySmall
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: isVerySmall
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: borderWidth,
                ),
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: size,
        ),
      ),
    );
  }
}
