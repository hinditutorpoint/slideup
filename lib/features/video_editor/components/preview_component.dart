import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/video_edit_settings.dart';
import '../providers/timeline_provider.dart';

class PreviewComponent extends ConsumerStatefulWidget {
  final String videoPath;
  final bool showControls;
  final bool showOverlays;
  final bool enableInteraction;
  final ColorGradeSettings? colorGrade;
  final double volume;
  final bool showGrid;
  final bool showSafeArea;
  final VoidCallback? onTap;
  final ValueChanged<String>? onObjectTap;

  const PreviewComponent({
    super.key,
    required this.videoPath,
    this.showControls = true,
    this.showOverlays = true,
    this.enableInteraction = true,
    this.colorGrade,
    this.volume = 1.0,
    this.showGrid = false,
    this.showSafeArea = false,
    this.onTap,
    this.onObjectTap,
  });

  @override
  ConsumerState<PreviewComponent> createState() => PreviewComponentState();
}

class PreviewComponentState extends ConsumerState<PreviewComponent> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(PreviewComponent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoPath != widget.videoPath) {
      _disposeController();
      _initializeVideo();
    }

    if (oldWidget.volume != widget.volume) {
      _controller?.setVolume(widget.volume);
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.videoPath.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No video path provided';
      });
      return;
    }

    try {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });

      final file = File(widget.videoPath);
      if (!await file.exists()) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Video file not found';
        });
        return;
      }

      _controller = VideoPlayerController.file(file);

      await _controller!.initialize();
      _controller!.setVolume(widget.volume);
      _controller!.addListener(_onVideoUpdate);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _totalDuration = _controller!.value.duration;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load video: $e';
        });
      }
    }
  }

  void _onVideoUpdate() {
    if (_controller != null && mounted) {
      final position = _controller!.value.position;
      if (position != _currentPosition) {
        setState(() {
          _currentPosition = position;
        });
        ref.read(timelineProvider.notifier).setCurrentPosition(position);
      }
    }
  }

  void _disposeController() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════

  void play() => _controller?.play();
  void pause() => _controller?.pause();

  void togglePlayPause() {
    if (_controller?.value.isPlaying ?? false) {
      pause();
    } else {
      play();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
    setState(() => _currentPosition = position);
  }

  Duration? getCurrentPosition() => _currentPosition;
  Duration? getTotalDuration() => _controller?.value.duration;
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  void previousFrame() {
    final newPosition = _currentPosition - const Duration(milliseconds: 33);
    if (newPosition >= Duration.zero) seekTo(newPosition);
  }

  void nextFrame() {
    final duration = _controller?.value.duration ?? Duration.zero;
    final newPosition = _currentPosition + const Duration(milliseconds: 33);
    if (newPosition <= duration) seekTo(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildErrorState();
    if (!_isInitialized) return _buildLoadingState();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Video layer
            Positioned.fill(child: _buildVideoLayer()),

            // Grid overlay
            if (widget.showGrid) Positioned.fill(child: _buildGridOverlay()),

            // Safe area overlay
            if (widget.showSafeArea)
              Positioned.fill(child: _buildSafeAreaOverlay()),

            // Timeline overlays
            if (widget.showOverlays)
              Positioned.fill(child: _buildTimelineOverlays()),

            // Controls
            if (widget.showControls) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    Widget videoWidget = VideoPlayer(_controller!);

    if (widget.colorGrade != null && !widget.colorGrade!.isDefault) {
      videoWidget = ColorFiltered(
        colorFilter: ColorFilter.matrix(widget.colorGrade!.toColorMatrix()),
        child: videoWidget,
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: videoWidget,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // FIXED: Timeline Overlays with Safe Color Handling
  // ═══════════════════════════════════════════════════════

  Widget _buildTimelineOverlays() {
    final timelineState = ref.watch(timelineProvider);

    final visibleTextItems = timelineState.textItems.where((item) {
      return item.isVisibleAt(_currentPosition) &&
          !timelineState.hiddenItems.contains(item.id);
    }).toList();

    final visibleImageItems = timelineState.imageItems.where((item) {
      return item.isVisibleAt(_currentPosition) &&
          !timelineState.hiddenItems.contains(item.id);
    }).toList();

    if (visibleTextItems.isEmpty && visibleImageItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        // Validate constraints
        if (maxWidth <= 0 || maxHeight <= 0) {
          return const SizedBox.shrink();
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            ...visibleTextItems.map(
              (item) => _buildTextOverlayWidget(
                item: item,
                isSelected: timelineState.selectedItemId == item.id,
                isLocked: timelineState.lockedItems.contains(item.id),
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
            ),
            ...visibleImageItems.map(
              (item) => _buildImageOverlayWidget(
                item: item,
                isSelected: timelineState.selectedItemId == item.id,
                isLocked: timelineState.lockedItems.contains(item.id),
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextOverlayWidget({
    required TextTimelineItem item,
    required bool isSelected,
    required bool isLocked,
    required double maxWidth,
    required double maxHeight,
  }) {
    // Validate dimensions
    if (maxWidth <= 0 || maxHeight <= 0) {
      return const SizedBox.shrink();
    }

    // Safe position clamping
    final safeX = (item.x.isNaN || item.x.isInfinite)
        ? 0.5
        : item.x.clamp(0.05, 0.95);
    final safeY = (item.y.isNaN || item.y.isInfinite)
        ? 0.5
        : item.y.clamp(0.05, 0.95);

    // Calculate pixel position
    final centerX = safeX * maxWidth;
    final centerY = safeY * maxHeight;

    // Safe font size
    final safeFontSize = (item.style.fontSize.isNaN || item.style.fontSize <= 0)
        ? 24.0
        : item.style.fontSize.clamp(8.0, 200.0);

    // Safe colors with proper alpha handling
    final textColor = _safeColor(item.style.color, Colors.white);
    final bgColor = _safeColor(item.style.backgroundColor, Colors.transparent);
    final shadowColor = _safeColor(item.style.shadowColor, Colors.black54);

    // Safe shadow blur
    final safeShadowBlur =
        (item.style.shadowBlur.isNaN || item.style.shadowBlur < 0)
        ? 0.0
        : item.style.shadowBlur.clamp(0.0, 50.0);

    // Safe scale and rotation
    final safeScale = (item.scale.isNaN || item.scale <= 0)
        ? 1.0
        : item.scale.clamp(0.1, 5.0);
    final safeRotation = (item.rotation.isNaN || item.rotation.isInfinite)
        ? 0.0
        : item.rotation;

    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      child: Stack(
        children: [
          Positioned(
            left: centerX,
            top: centerY,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5), // Center the widget
              child: GestureDetector(
                onTap: widget.enableInteraction
                    ? () {
                        ref
                            .read(timelineProvider.notifier)
                            .selectItem(item.id, TimelineItemType.text);
                        widget.onObjectTap?.call(item.id);
                      }
                    : null,
                onPanUpdate: widget.enableInteraction && !isLocked
                    ? (details) =>
                          _onTextDrag(item, details, maxWidth, maxHeight)
                    : null,
                child: Transform.scale(
                  scale: safeScale,
                  child: Transform.rotate(
                    angle: safeRotation * 3.14159 / 180,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth * 0.9,
                        minWidth: 20,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected
                            ? Border.all(color: Colors.blue, width: 2)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        item.text.isEmpty ? 'Text' : item.text,
                        style: TextStyle(
                          fontFamily: item.style.fontFamily.isEmpty
                              ? null
                              : item.style.fontFamily,
                          fontSize: safeFontSize,
                          color: textColor,
                          fontWeight: item.style.bold
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontStyle: item.style.italic
                              ? FontStyle.italic
                              : FontStyle.normal,
                          letterSpacing: _safeDouble(
                            item.style.letterSpacing,
                            0,
                          ),
                          height: _safeDouble(
                            item.style.lineHeight,
                            1.2,
                            min: 0.5,
                            max: 3.0,
                          ),
                          shadows: safeShadowBlur > 0
                              ? [
                                  Shadow(
                                    color: shadowColor,
                                    offset: const Offset(2, 2),
                                    blurRadius: safeShadowBlur,
                                  ),
                                ]
                              : null,
                        ),
                        textAlign: _getTextAlign(item.style.textAlign),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageOverlayWidget({
    required ImageTimelineItem item,
    required bool isSelected,
    required bool isLocked,
    required double maxWidth,
    required double maxHeight,
  }) {
    // Validate dimensions
    if (maxWidth <= 0 || maxHeight <= 0) {
      return const SizedBox.shrink();
    }

    if (!item.hasValidImage) return const SizedBox.shrink();

    // Safe position clamping
    final safeX = (item.x.isNaN || item.x.isInfinite)
        ? 0.5
        : item.x.clamp(0.05, 0.95);
    final safeY = (item.y.isNaN || item.y.isInfinite)
        ? 0.5
        : item.y.clamp(0.05, 0.95);

    final centerX = safeX * maxWidth;
    final centerY = safeY * maxHeight;

    // Safe scale and opacity
    final safeScale = (item.scale.isNaN || item.scale <= 0)
        ? 0.3
        : item.scale.clamp(0.05, 3.0);
    final safeOpacity = (item.opacity.isNaN || item.opacity < 0)
        ? 1.0
        : item.opacity.clamp(0.0, 1.0);
    final safeRotation = (item.rotation.isNaN || item.rotation.isInfinite)
        ? 0.0
        : item.rotation;

    // Safe border values
    final safeBorderWidth = _safeDouble(item.borderWidth, 0, min: 0, max: 20);
    final safeBorderRadius = _safeDouble(
      item.borderRadius,
      0,
      min: 0,
      max: 100,
    );
    final borderColor = item.borderColor != null
        ? _safeColor(item.borderColor!, Colors.white)
        : Colors.white;

    final imageSize = 100.0 * safeScale;

    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      child: Stack(
        children: [
          Positioned(
            left: centerX,
            top: centerY,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: GestureDetector(
                onTap: widget.enableInteraction
                    ? () {
                        ref
                            .read(timelineProvider.notifier)
                            .selectItem(item.id, TimelineItemType.image);
                        widget.onObjectTap?.call(item.id);
                      }
                    : null,
                onPanUpdate: widget.enableInteraction && !isLocked
                    ? (details) =>
                          _onImageDrag(item, details, maxWidth, maxHeight)
                    : null,
                child: Transform.rotate(
                  angle: safeRotation * 3.14159 / 180,
                  child: Opacity(
                    opacity: safeOpacity,
                    child: Container(
                      width: imageSize,
                      height: imageSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(safeBorderRadius),
                        border: isSelected
                            ? Border.all(color: Colors.blue, width: 2)
                            : safeBorderWidth > 0
                            ? Border.all(
                                color: borderColor,
                                width: safeBorderWidth,
                              )
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(safeBorderRadius),
                        child: _buildImageWidget(item),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(ImageTimelineItem item) {
    if (item.imageBytes != null) {
      return Image.memory(
        item.imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImageError(),
      );
    }

    if (item.imagePath.isNotEmpty) {
      return Image.file(
        File(item.imagePath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImageError(),
      );
    }

    return _buildImageError();
  }

  Widget _buildImageError() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey, size: 24),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SAFE VALUE HELPERS
  // ═══════════════════════════════════════════════════════

  /// Safely creates a Color from an int value
  Color _safeColor(int colorValue, Color fallback) {
    try {
      // Handle transparent (0x00000000)
      if (colorValue == 0) return Colors.transparent;

      // Handle invalid values
      if (colorValue < 0) return fallback;

      // Ensure alpha channel is set if not provided
      if (colorValue <= 0xFFFFFF) {
        colorValue = 0xFF000000 | colorValue; // Add full opacity
      }

      return Color(colorValue);
    } catch (e) {
      debugPrint('Invalid color value: $colorValue, using fallback');
      return fallback;
    }
  }

  /// Safely returns a double value with bounds checking
  double _safeDouble(
    double value,
    double fallback, {
    double min = double.negativeInfinity,
    double max = double.infinity,
  }) {
    if (value.isNaN || value.isInfinite) return fallback;
    return value.clamp(min, max);
  }

  void _onTextDrag(
    TextTimelineItem item,
    DragUpdateDetails details,
    double maxWidth,
    double maxHeight,
  ) {
    if (maxWidth <= 0 || maxHeight <= 0) return;

    final newX = (item.x + details.delta.dx / maxWidth).clamp(0.05, 0.95);
    final newY = (item.y + details.delta.dy / maxHeight).clamp(0.05, 0.95);

    ref
        .read(timelineProvider.notifier)
        .updateTextItem(item.id, item.copyWith(x: newX, y: newY));
  }

  void _onImageDrag(
    ImageTimelineItem item,
    DragUpdateDetails details,
    double maxWidth,
    double maxHeight,
  ) {
    if (maxWidth <= 0 || maxHeight <= 0) return;

    final newX = (item.x + details.delta.dx / maxWidth).clamp(0.05, 0.95);
    final newY = (item.y + details.delta.dy / maxHeight).clamp(0.05, 0.95);

    ref
        .read(timelineProvider.notifier)
        .updateImageItem(item.id, item.copyWith(x: newX, y: newY));
  }

  TextAlign _getTextAlign(TextAlignCustom align) {
    switch (align) {
      case TextAlignCustom.left:
        return TextAlign.left;
      case TextAlignCustom.right:
        return TextAlign.right;
      case TextAlignCustom.center:
        return TextAlign.center;
    }
  }

  // ═══════════════════════════════════════════════════════
  // OVERLAYS
  // ═══════════════════════════════════════════════════════

  Widget _buildGridOverlay() {
    return CustomPaint(painter: _GridPainter());
  }

  Widget _buildSafeAreaOverlay() {
    return CustomPaint(painter: _SafeAreaPainter());
  }

  // ═══════════════════════════════════════════════════════
  // CONTROLS
  // ═══════════════════════════════════════════════════════

  Widget _buildControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: togglePlayPause,
              color: Colors.white,
            ),
            Expanded(
              child: SliderTheme(
                data: const SliderThemeData(
                  trackHeight: 2,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: _currentPosition.inMilliseconds.toDouble().clamp(
                    0,
                    _totalDuration.inMilliseconds.toDouble().clamp(
                      1,
                      double.infinity,
                    ),
                  ),
                  min: 0,
                  max: _totalDuration.inMilliseconds.toDouble().clamp(
                    1,
                    double.infinity,
                  ),
                  onChanged: (v) => seekTo(Duration(milliseconds: v.toInt())),
                  activeColor: Colors.white,
                  inactiveColor: Colors.white38,
                ),
              ),
            ),
            Text(
              '${_formatTime(_currentPosition)} / ${_formatTime(_totalDuration)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // STATES
  // ═══════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text('Loading video...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _errorMessage ?? 'Error loading video',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _initializeVideo,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ═══════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    final w3 = size.width / 3;
    final h3 = size.height / 3;

    canvas.drawLine(Offset(w3, 0), Offset(w3, size.height), paint);
    canvas.drawLine(Offset(w3 * 2, 0), Offset(w3 * 2, size.height), paint);
    canvas.drawLine(Offset(0, h3), Offset(size.width, h3), paint);
    canvas.drawLine(Offset(0, h3 * 2), Offset(size.width, h3 * 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SafeAreaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    paint.color = Colors.red.withValues(alpha: 0.5);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.1,
        size.height * 0.1,
        size.width * 0.8,
        size.height * 0.8,
      ),
      paint,
    );

    paint.color = Colors.yellow.withValues(alpha: 0.5);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.05,
        size.height * 0.05,
        size.width * 0.9,
        size.height * 0.9,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
