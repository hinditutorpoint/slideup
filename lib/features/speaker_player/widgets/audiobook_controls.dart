import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/audiobook_controller.dart';

class DraggableAudiobookControls extends StatefulWidget {
  final AudiobookStatus status;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onClose;
  final Color? backgroundColor;
  final Color? textColor;
  final Size screenSize;
  final EdgeInsets safeArea;

  const DraggableAudiobookControls({
    super.key,
    required this.status,
    required this.onPlayPause,
    required this.onStop,
    required this.onPrevious,
    required this.onNext,
    required this.screenSize,
    required this.safeArea,
    this.onClose,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<DraggableAudiobookControls> createState() =>
      _DraggableAudiobookControlsState();
}

class _DraggableAudiobookControlsState extends State<DraggableAudiobookControls>
    with SingleTickerProviderStateMixin {
  late Offset _position;
  late AnimationController _dismissAnimationController;
  late Animation<double> _dismissAnimation;

  bool _isDragging = false;
  bool _isInDismissZone = false;
  bool _isExpanded = true;

  static const double _controlsWidth = 320.0;
  static const double _controlsHeight = 180.0;
  static const double _miniHeight = 60.0;
  static const double _dismissZoneHeight = 100.0;

  @override
  void initState() {
    super.initState();

    // Initial position - bottom center
    _position = Offset(
      (widget.screenSize.width - _controlsWidth) / 2,
      widget.screenSize.height - _controlsHeight - widget.safeArea.bottom - 100,
    );

    _dismissAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _dismissAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _dismissAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _dismissAnimationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;

      // Clamp position to screen bounds
      final height = _isExpanded ? _controlsHeight : _miniHeight;
      _position = Offset(
        _position.dx.clamp(0, widget.screenSize.width - _controlsWidth),
        _position.dy.clamp(
          widget.safeArea.top,
          widget.screenSize.height - height - widget.safeArea.bottom,
        ),
      );

      // Check if in dismiss zone (bottom of screen)
      final dismissThreshold =
          widget.screenSize.height -
          _dismissZoneHeight -
          widget.safeArea.bottom;
      _isInDismissZone = _position.dy > dismissThreshold;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    if (_isInDismissZone) {
      // Dismiss with animation
      HapticFeedback.mediumImpact();
      _dismissAnimationController.forward().then((_) {
        widget.onStop();
        widget.onClose?.call();
      });
    } else {
      // Snap to edges
      _snapToEdge();
    }
  }

  void _snapToEdge() {
    final centerX = widget.screenSize.width / 2;
    final newX = _position.dx + _controlsWidth / 2 < centerX
        ? 16.0
        : widget.screenSize.width - _controlsWidth - 16;

    setState(() {
      _position = Offset(newX, _position.dy);
    });
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dismiss zone indicator
        if (_isDragging)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: _isInDismissZone
                  ? _dismissZoneHeight + widget.safeArea.bottom
                  : _dismissZoneHeight / 2 + widget.safeArea.bottom,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _isInDismissZone
                        ? Colors.red.withValues(alpha: 0.5)
                        : Colors.red.withValues(alpha: 0.2),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: _isInDismissZone
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      size: _isInDismissZone ? 32 : 24,
                    ),
                    if (_isInDismissZone)
                      const Text(
                        'Release to stop',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          ),

        // Draggable controls
        AnimatedPositioned(
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 200),
          left: _position.dx,
          top: _position.dy,
          child: FadeTransition(
            opacity: _dismissAnimation,
            child: ScaleTransition(
              scale: _dismissAnimation,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _controlsWidth,
                  height: _isExpanded ? _controlsHeight : _miniHeight,
                  child: _isExpanded
                      ? _buildExpandedControls()
                      : _buildMiniControls(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedControls() {
    final bgColor =
        widget.backgroundColor ?? Colors.black.withValues(alpha: 0.95);
    final fgColor = widget.textColor ?? Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: _isDragging
              ? _getStateColor().withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: _isDragging ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: fgColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                // State indicator
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getStateColor().withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildStateIcon(),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audiobook',
                        style: TextStyle(
                          color: fgColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            widget.status.stateLabel,
                            style: TextStyle(
                              color: _getStateColor(),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.status.detectedLanguage != null) ...[
                            Text(
                              ' • ',
                              style: TextStyle(
                                color: fgColor.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              widget.status.detectedLanguage!.toUpperCase(),
                              style: TextStyle(
                                color: fgColor.withValues(alpha: 0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Minimize button
                IconButton(
                  icon: Icon(
                    Icons.expand_more,
                    color: fgColor.withValues(alpha: 0.7),
                  ),
                  onPressed: _toggleExpanded,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Progress
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: widget.status.progress,
                    backgroundColor: fgColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(_getStateColor()),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page ${widget.status.currentPage + 1}',
                      style: TextStyle(
                        color: fgColor.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'of ${widget.status.totalPages}',
                      style: TextStyle(
                        color: fgColor.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.skip_previous_rounded,
                onPressed: widget.status.currentPage > 0
                    ? widget.onPrevious
                    : null,
                color: fgColor,
              ),
              _buildMainButton(fgColor),
              _buildControlButton(
                icon: Icons.skip_next_rounded,
                onPressed:
                    widget.status.currentPage < widget.status.totalPages - 1
                    ? widget.onNext
                    : null,
                color: fgColor,
              ),
              _buildControlButton(
                icon: Icons.stop_rounded,
                onPressed: widget.status.isActive || widget.status.isPaused
                    ? widget.onStop
                    : null,
                color: Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMiniControls() {
    final bgColor =
        widget.backgroundColor ?? Colors.black.withValues(alpha: 0.95);
    final fgColor = widget.textColor ?? Colors.white;

    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: _isDragging
                ? _getStateColor().withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: _isDragging ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // State dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _getStateColor(),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),

            // Page info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Page ${widget.status.currentPage + 1}/${widget.status.totalPages}',
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: widget.status.progress,
                      backgroundColor: fgColor.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(_getStateColor()),
                      minHeight: 2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Play/Pause
            IconButton(
              icon: Icon(
                widget.status.state == AudiobookState.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: fgColor,
                size: 24,
              ),
              onPressed: widget.onPlayPause,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),

            // Stop
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: Colors.red.shade300,
                size: 20,
              ),
              onPressed: widget.onStop,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateIcon() {
    if (widget.status.isProcessing) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(_getStateColor()),
        ),
      );
    }

    return Icon(
      widget.status.state == AudiobookState.playing
          ? Icons.play_arrow_rounded
          : widget.status.state == AudiobookState.paused
          ? Icons.pause_rounded
          : widget.status.state == AudiobookState.completed
          ? Icons.check_circle_rounded
          : Icons.auto_stories,
      color: _getStateColor(),
      size: 18,
    );
  }

  Widget _buildMainButton(Color color) {
    final isPlaying = widget.status.state == AudiobookState.playing;
    final isPaused = widget.status.state == AudiobookState.paused;
    final isProcessing = widget.status.isProcessing;

    return GestureDetector(
      onTap: (isPlaying || isPaused) && !isProcessing
          ? widget.onPlayPause
          : null,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _getStateColor(),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _getStateColor().withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isProcessing
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 26),
      color: onPressed != null ? color : color.withValues(alpha: 0.3),
      onPressed: onPressed,
    );
  }

  Color _getStateColor() {
    switch (widget.status.state) {
      case AudiobookState.playing:
        return Colors.green;
      case AudiobookState.paused:
        return Colors.orange;
      case AudiobookState.translating:
        return Colors.blue;
      case AudiobookState.generating:
      case AudiobookState.loading:
      case AudiobookState.preparing:
        return Colors.amber;
      case AudiobookState.error:
        return Colors.red;
      case AudiobookState.completed:
        return Colors.teal;
      case AudiobookState.idle:
        return Colors.grey;
    }
  }
}
