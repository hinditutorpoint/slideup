// components/draggable_preview.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/video_edit_settings.dart';

// ═══════════════════════════════════════════════════════
// ✅ DRAGGABLE PREVIEW OVERLAY (for video player)
// ═══════════════════════════════════════════════════════

class DraggablePreview extends StatefulWidget {
  final Uint8List? previewFrame; // Optional - for static mode
  final Size videoSize;
  final List<TextTimelineItem> textItems;
  final List<ImageTimelineItem> imageItems;
  final Duration currentPosition;
  final ColorGradeSettings colorGrade;
  final Function(TextTimelineItem) onTextItemUpdated;
  final Function(ImageTimelineItem) onImageItemUpdated;
  final Function(String)? onItemSelected;
  final Function(String)? onItemDeleted;
  final String? selectedItemId;
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final bool isOverlayMode; // NEW: true when used on top of video player

  const DraggablePreview({
    super.key,
    this.previewFrame,
    required this.videoSize,
    required this.textItems,
    required this.imageItems,
    required this.currentPosition,
    required this.colorGrade,
    required this.onTextItemUpdated,
    required this.onImageItemUpdated,
    this.onItemSelected,
    this.onItemDeleted,
    this.selectedItemId,
    this.isPlaying = false,
    this.onPlayPause,
    this.isOverlayMode = false,
  });

  @override
  State<DraggablePreview> createState() => _DraggablePreviewState();
}

class _DraggablePreviewState extends State<DraggablePreview> {
  // Transform state
  String? _activeItemId;
  Offset _dragStartPosition = Offset.zero;
  Offset _itemStartPosition = Offset.zero;
  double _itemStartScale = 1.0;
  double _itemStartRotation = 0.0;

  // Gesture state
  bool _isTransforming = false;

  // Snap state
  bool _isSnappedX = false;
  bool _isSnappedY = false;

  // UI settings
  bool _showGrid = false;
  bool _snapToCenter = true;
  bool _snapToThirds = true;
  static const double _snapThreshold = 0.025;
  static const double _gridSize = 0.1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        try {
          final previewSize = _calculatePreviewSize(constraints);
          final isCompact = constraints.maxHeight < 200;

          // If overlay mode, return transparent stack
          if (widget.isOverlayMode) {
            return _buildOverlayMode(previewSize, isCompact);
          }

          // Otherwise, return full preview with background
          return _buildStandaloneMode(previewSize, isCompact);
        } catch (e) {
          debugPrint('❌ DraggablePreview build error: $e');
          return const SizedBox.shrink();
        }
      },
    );
  }

  Size _calculatePreviewSize(BoxConstraints constraints) {
    try {
      final aspectRatio = widget.videoSize.width / widget.videoSize.height;
      final maxWidth = constraints.maxWidth - 24;
      final maxHeight = constraints.maxHeight - 24;

      double width = maxWidth;
      double height = width / aspectRatio;

      if (height > maxHeight) {
        height = maxHeight;
        width = height * aspectRatio;
      }

      return Size(
        width.clamp(100, constraints.maxWidth),
        height.clamp(100, constraints.maxHeight),
      );
    } catch (e) {
      return Size(constraints.maxWidth, constraints.maxHeight);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ OVERLAY MODE (Transparent, only overlays)
  // ═══════════════════════════════════════════════════════

  Widget _buildOverlayMode(Size previewSize, bool isCompact) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Grid overlay
        if (_showGrid) _buildGridOverlay(previewSize),

        // Snap guides (only during transform)
        if (_isTransforming) _buildSnapGuides(previewSize),

        // Image overlays
        ..._buildImageOverlays(previewSize),

        // Text overlays
        ..._buildTextOverlays(previewSize),

        // Toolbar (top-right corner)
        if (!widget.isPlaying)
          Positioned(top: 8, right: 8, child: _buildToolbar(isCompact)),

        // Transform controls for selected item
        if (widget.selectedItemId != null &&
            !_isTransforming &&
            !widget.isPlaying)
          Positioned(
            bottom: isCompact ? 40 : 50,
            left: 8,
            right: 8,
            child: _buildTransformControls(isCompact),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ STANDALONE MODE (With background frame)
  // ═══════════════════════════════════════════════════════

  Widget _buildStandaloneMode(Size previewSize, bool isCompact) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main content area
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: previewSize.width,
                height: previewSize.height,
                child: GestureDetector(
                  onTap: _deselectAll,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background frame
                      _buildVideoFrame(previewSize),

                      // Grid overlay
                      if (_showGrid) _buildGridOverlay(previewSize),

                      // Snap guides
                      if (_isTransforming) _buildSnapGuides(previewSize),

                      // Image overlays
                      ..._buildImageOverlays(previewSize),

                      // Text overlays
                      ..._buildTextOverlays(previewSize),

                      // Safe area indicator
                      if (!isCompact) _buildSafeAreaIndicator(previewSize),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Play/pause button
          if (widget.onPlayPause != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(child: _buildPlayButton(isCompact)),
            ),

          // Toolbar
          Positioned(top: 8, right: 8, child: _buildToolbar(isCompact)),

          // Position indicator
          if (_isTransforming && _activeItemId != null)
            Positioned(top: 8, left: 8, child: _buildPositionIndicator()),

          // Transform controls for selected item
          if (widget.selectedItemId != null && !_isTransforming)
            Positioned(
              bottom: isCompact ? 40 : 50,
              left: 8,
              right: 8,
              child: _buildTransformControls(isCompact),
            ),
        ],
      ),
    );
  }

  void _deselectAll() {
    if (widget.selectedItemId != null) {
      widget.onItemSelected?.call('');
      HapticFeedback.selectionClick();
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VIDEO FRAME (for standalone mode)
  // ═══════════════════════════════════════════════════════

  Widget _buildVideoFrame(Size previewSize) {
    if (widget.previewFrame == null) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.movie, color: Colors.white24, size: 48),
        ),
      );
    }

    try {
      return ColorFiltered(
        colorFilter: _buildColorFilter(widget.colorGrade),
        child: Image.memory(
          widget.previewFrame!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[900],
            child: const Icon(Icons.error_outline, color: Colors.red),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Build video frame error: $e');
      return Container(color: Colors.grey[900]);
    }
  }

  ColorFilter _buildColorFilter(ColorGradeSettings s) {
    try {
      return ColorFilter.matrix(s.toColorMatrix());
    } catch (e) {
      return const ColorFilter.mode(Colors.transparent, BlendMode.multiply);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GRID & GUIDES
  // ═══════════════════════════════════════════════════════

  Widget _buildGridOverlay(Size previewSize) {
    return IgnorePointer(
      child: CustomPaint(
        size: previewSize,
        painter: GridPainter(gridSize: _gridSize),
      ),
    );
  }

  Widget _buildSnapGuides(Size previewSize) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Vertical center guide
          if (_snapToCenter)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              left: previewSize.width / 2 - 0.5,
              top: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _isSnappedX ? 2 : 1,
                color: _isSnappedX
                    ? Colors.cyan
                    : Colors.cyan.withValues(alpha: 0.3),
              ),
            ),

          // Horizontal center guide
          if (_snapToCenter)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              left: 0,
              right: 0,
              top: previewSize.height / 2 - 0.5,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: _isSnappedY ? 2 : 1,
                color: _isSnappedY
                    ? Colors.cyan
                    : Colors.cyan.withValues(alpha: 0.3),
              ),
            ),

          // Thirds guides
          if (_snapToThirds) ...[
            for (final fraction in [1 / 3, 2 / 3])
              Positioned(
                left: previewSize.width * fraction - 0.5,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1,
                  color: Colors.orange.withValues(alpha: 0.2),
                ),
              ),
            for (final fraction in [1 / 3, 2 / 3])
              Positioned(
                left: 0,
                right: 0,
                top: previewSize.height * fraction - 0.5,
                child: Container(
                  height: 1,
                  color: Colors.orange.withValues(alpha: 0.2),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafeAreaIndicator(Size previewSize) {
    const safeMargin = 0.05;
    return IgnorePointer(
      child: Positioned.fill(
        child: Container(
          margin: EdgeInsets.all(previewSize.width * safeMargin),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSnappedX || _isSnappedY)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.adjust, size: 12, color: Colors.cyan),
            ),
          Text(
            _getActiveItemPositionText(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _getActiveItemPositionText() {
    if (_activeItemId == null) return '';

    try {
      for (final item in widget.textItems) {
        if (item.id == _activeItemId) {
          return 'X: ${(item.x * 100).toStringAsFixed(1)}%  Y: ${(item.y * 100).toStringAsFixed(1)}%';
        }
      }
      for (final item in widget.imageItems) {
        if (item.id == _activeItemId) {
          return 'X: ${(item.x * 100).toStringAsFixed(1)}%  Y: ${(item.y * 100).toStringAsFixed(1)}%';
        }
      }
    } catch (e) {
      debugPrint('❌ Get position text error: $e');
    }
    return '';
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TEXT OVERLAYS
  // ═══════════════════════════════════════════════════════

  List<Widget> _buildTextOverlays(Size previewSize) {
    try {
      final visibleItems = widget.textItems.where((item) {
        return item.isVisible &&
            widget.currentPosition >= item.startTime &&
            widget.currentPosition <= item.endTime;
      }).toList();

      return visibleItems.map((item) {
        return _buildDraggableTextOverlay(item, previewSize);
      }).toList();
    } catch (e) {
      debugPrint('❌ Build text overlays error: $e');
      return [];
    }
  }

  Widget _buildDraggableTextOverlay(TextTimelineItem item, Size previewSize) {
    try {
      final isSelected = widget.selectedItemId == item.id;
      final isActive = _activeItemId == item.id && _isTransforming;

      final x = item.x * previewSize.width;
      final y = item.y * previewSize.height;

      return Positioned(
        left: 0,
        top: 0,
        child: Transform.translate(
          offset: Offset(x, y),
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _selectItem(item.id),
              onScaleStart: item.isLocked
                  ? null
                  : (d) => _onTextScaleStart(item, d),
              onScaleUpdate: item.isLocked
                  ? null
                  : (d) => _onTextScaleUpdate(item, d, previewSize),
              onScaleEnd: item.isLocked ? null : (_) => _onTransformEnd(),
              child: _buildTextContent(item, isSelected, isActive, previewSize),
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Build draggable text overlay error: $e');
      return const SizedBox.shrink();
    }
  }

  Widget _buildTextContent(
    TextTimelineItem item,
    bool isSelected,
    bool isActive,
    Size previewSize,
  ) {
    return Transform.rotate(
      angle: item.rotation * math.pi / 180,
      child: Transform.scale(
        scale: item.scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: BoxConstraints(maxWidth: previewSize.width * 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Color(item.style.backgroundColor),
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(
                    color: isActive ? Colors.cyan : Colors.white,
                    width: 2,
                  )
                : null,
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: (isActive ? Colors.cyan : Colors.white).withValues(
                    alpha: 0.3,
                  ),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                item.text,
                style: TextStyle(
                  color: Color(item.style.color),
                  fontSize: item.style.fontSize * 0.4,
                  fontWeight: item.style.bold
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontStyle: item.style.italic
                      ? FontStyle.italic
                      : FontStyle.normal,
                  shadows: item.style.shadowBlur > 0
                      ? [
                          Shadow(
                            color: Color(item.style.shadowColor),
                            blurRadius: item.style.shadowBlur,
                          ),
                        ]
                      : null,
                ),
                textAlign: _getTextAlign(item.style.textAlign),
              ),
              if (item.isLocked)
                const Positioned(
                  top: -8,
                  right: -8,
                  child: Icon(Icons.lock, size: 10, color: Colors.orange),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextAlign _getTextAlign(TextAlignCustom align) {
    switch (align) {
      case TextAlignCustom.left:
        return TextAlign.left;
      case TextAlignCustom.right:
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ IMAGE OVERLAYS
  // ═══════════════════════════════════════════════════════

  List<Widget> _buildImageOverlays(Size previewSize) {
    try {
      final visibleItems = widget.imageItems.where((item) {
        return item.isVisible &&
            widget.currentPosition >= item.startTime &&
            widget.currentPosition <= item.endTime;
      }).toList();

      return visibleItems.map((item) {
        return _buildDraggableImageOverlay(item, previewSize);
      }).toList();
    } catch (e) {
      debugPrint('❌ Build image overlays error: $e');
      return [];
    }
  }

  Widget _buildDraggableImageOverlay(ImageTimelineItem item, Size previewSize) {
    try {
      final isSelected = widget.selectedItemId == item.id;
      final isActive = _activeItemId == item.id && _isTransforming;

      final x = item.x * previewSize.width;
      final y = item.y * previewSize.height;
      final itemWidth = previewSize.width * item.scale * 0.5;
      final itemHeight = itemWidth / item.aspectRatio;

      return Positioned(
        left: 0,
        top: 0,
        child: Transform.translate(
          offset: Offset(x - itemWidth / 2, y - itemHeight / 2),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectItem(item.id),
            onScaleStart: item.isLocked
                ? null
                : (d) => _onImageScaleStart(item, d),
            onScaleUpdate: item.isLocked
                ? null
                : (d) => _onImageScaleUpdate(item, d, previewSize),
            onScaleEnd: item.isLocked ? null : (_) => _onTransformEnd(),
            child: _buildImageContent(
              item,
              isSelected,
              isActive,
              itemWidth,
              itemHeight,
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Build draggable image overlay error: $e');
      return const SizedBox.shrink();
    }
  }

  Widget _buildImageContent(
    ImageTimelineItem item,
    bool isSelected,
    bool isActive,
    double width,
    double height,
  ) {
    return Transform.rotate(
      angle: item.rotation * math.pi / 180,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(item.borderRadius),
          border: isSelected
              ? Border.all(
                  color: isActive ? Colors.cyan : Colors.white,
                  width: 2,
                )
              : (item.borderWidth > 0
                    ? Border.all(
                        color: Color(item.borderColor ?? 0xFFFFFFFF),
                        width: item.borderWidth,
                      )
                    : null),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: (isActive ? Colors.cyan : Colors.white).withValues(
                  alpha: 0.3,
                ),
                blurRadius: 12,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(item.borderRadius),
              child: Opacity(
                opacity: item.opacity,
                child: _buildImageWidget(item),
              ),
            ),
            if (item.isLocked)
              const Positioned(
                top: -8,
                right: -8,
                child: Icon(Icons.lock, size: 10, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(ImageTimelineItem item) {
    try {
      if (item.imageBytes != null) {
        return Image.memory(
          item.imageBytes!,
          fit: _getBoxFit(item.fit),
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _imagePlaceholder(),
        );
      } else if (item.imagePath.isNotEmpty) {
        if (item.imagePath.startsWith('http')) {
          return Image.network(
            item.imagePath,
            fit: _getBoxFit(item.fit),
            errorBuilder: (_, __, ___) => _imagePlaceholder(),
          );
        } else {
          return Image.file(
            File(item.imagePath),
            fit: _getBoxFit(item.fit),
            errorBuilder: (_, __, ___) => _imagePlaceholder(),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Build image widget error: $e');
    }
    return _imagePlaceholder();
  }

  BoxFit _getBoxFit(ImageFit fit) {
    switch (fit) {
      case ImageFit.cover:
        return BoxFit.cover;
      case ImageFit.fill:
        return BoxFit.fill;
      case ImageFit.fitWidth:
        return BoxFit.fitWidth;
      case ImageFit.fitHeight:
        return BoxFit.fitHeight;
      default:
        return BoxFit.contain;
    }
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.image, color: Colors.grey, size: 24),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GESTURE HANDLERS
  // ═══════════════════════════════════════════════════════

  void _selectItem(String id) {
    try {
      HapticFeedback.selectionClick();
      widget.onItemSelected?.call(id);
    } catch (e) {
      debugPrint('❌ Select item error: $e');
    }
  }

  void _onTextScaleStart(TextTimelineItem item, ScaleStartDetails details) {
    setState(() {
      _activeItemId = item.id;
      _isTransforming = true;
      _dragStartPosition = details.localFocalPoint;
      _itemStartPosition = Offset(item.x, item.y);
      _itemStartScale = item.scale;
      _itemStartRotation = item.rotation;
      _isSnappedX = false;
      _isSnappedY = false;
    });
    widget.onItemSelected?.call(item.id);
    HapticFeedback.lightImpact();
  }

  void _onTextScaleUpdate(
    TextTimelineItem item,
    ScaleUpdateDetails details,
    Size previewSize,
  ) {
    if (!_isTransforming || _activeItemId != item.id) return;

    try {
      final focalDelta = details.localFocalPoint - _dragStartPosition;
      var newX = _itemStartPosition.dx + (focalDelta.dx / previewSize.width);
      var newY = _itemStartPosition.dy + (focalDelta.dy / previewSize.height);

      final snapResult = _applySnapping(newX, newY);
      newX = snapResult.x.clamp(0.05, 0.95);
      newY = snapResult.y.clamp(0.05, 0.95);

      double newScale = item.scale;
      if (details.pointerCount > 1) {
        newScale = (_itemStartScale * details.scale).clamp(0.3, 4.0);
      }

      double newRotation = item.rotation;
      if (details.pointerCount > 1 && details.rotation.abs() > 0.01) {
        newRotation = _itemStartRotation + (details.rotation * 180 / math.pi);
        final snapAngle = (newRotation / 45).round() * 45.0;
        if ((newRotation - snapAngle).abs() < 5) {
          newRotation = snapAngle;
        }
      }

      final updated = item.copyWith(
        x: newX,
        y: newY,
        scale: newScale,
        rotation: newRotation,
      );
      widget.onTextItemUpdated(updated);

      _dragStartPosition = details.localFocalPoint;
    } catch (e) {
      debugPrint('❌ Text scale update error: $e');
    }
  }

  void _onImageScaleStart(ImageTimelineItem item, ScaleStartDetails details) {
    setState(() {
      _activeItemId = item.id;
      _isTransforming = true;
      _dragStartPosition = details.localFocalPoint;
      _itemStartPosition = Offset(item.x, item.y);
      _itemStartScale = item.scale;
      _itemStartRotation = item.rotation;
      _isSnappedX = false;
      _isSnappedY = false;
    });
    widget.onItemSelected?.call(item.id);
    HapticFeedback.lightImpact();
  }

  void _onImageScaleUpdate(
    ImageTimelineItem item,
    ScaleUpdateDetails details,
    Size previewSize,
  ) {
    if (!_isTransforming || _activeItemId != item.id) return;

    try {
      final focalDelta = details.localFocalPoint - _dragStartPosition;
      var newX = _itemStartPosition.dx + (focalDelta.dx / previewSize.width);
      var newY = _itemStartPosition.dy + (focalDelta.dy / previewSize.height);

      final snapResult = _applySnapping(newX, newY);
      newX = snapResult.x.clamp(-0.25, 1.25);
      newY = snapResult.y.clamp(-0.25, 1.25);

      double newScale = item.scale;
      if (details.pointerCount > 1) {
        newScale = (_itemStartScale * details.scale).clamp(0.1, 3.0);
      }

      double newRotation = item.rotation;
      if (details.pointerCount > 1 && details.rotation.abs() > 0.01) {
        newRotation = _itemStartRotation + (details.rotation * 180 / math.pi);
        final snapAngle = (newRotation / 45).round() * 45.0;
        if ((newRotation - snapAngle).abs() < 5) {
          newRotation = snapAngle;
        }
      }

      final updated = item.copyWith(
        x: newX,
        y: newY,
        scale: newScale,
        rotation: newRotation,
      );
      widget.onImageItemUpdated(updated);

      _dragStartPosition = details.localFocalPoint;
    } catch (e) {
      debugPrint('❌ Image scale update error: $e');
    }
  }

  ({double x, double y}) _applySnapping(double x, double y) {
    var snappedX = x;
    var snappedY = y;
    var isSnapX = false;
    var isSnapY = false;

    final snapPoints = <double>[0.5];
    if (_snapToThirds) {
      snapPoints.addAll([1 / 3, 2 / 3]);
    }

    for (final point in snapPoints) {
      if ((x - point).abs() < _snapThreshold) {
        snappedX = point;
        isSnapX = true;
        break;
      }
    }

    for (final point in snapPoints) {
      if ((y - point).abs() < _snapThreshold) {
        snappedY = point;
        isSnapY = true;
        break;
      }
    }

    if (isSnapX != _isSnappedX || isSnapY != _isSnappedY) {
      if (isSnapX || isSnapY) {
        HapticFeedback.selectionClick();
      }
      setState(() {
        _isSnappedX = isSnapX;
        _isSnappedY = isSnapY;
      });
    }

    return (x: snappedX, y: snappedY);
  }

  void _onTransformEnd() {
    HapticFeedback.lightImpact();
    setState(() {
      _isTransforming = false;
      _activeItemId = null;
      _isSnappedX = false;
      _isSnappedY = false;
    });
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CONTROLS
  // ═══════════════════════════════════════════════════════

  Widget _buildPlayButton(bool isCompact) {
    return GestureDetector(
      onTap: () {
        widget.onPlayPause?.call();
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isCompact ? 8 : 12),
        decoration: BoxDecoration(
          color: widget.isPlaying
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Icon(
          widget.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: isCompact ? 24 : 32,
        ),
      ),
    );
  }

  Widget _buildToolbar(bool isCompact) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarButton(
            icon: Icons.grid_on,
            isActive: _showGrid,
            onTap: () => setState(() => _showGrid = !_showGrid),
            tooltip: 'Grid',
            isCompact: isCompact,
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            icon: Icons.center_focus_strong,
            isActive: _snapToCenter,
            onTap: () => setState(() => _snapToCenter = !_snapToCenter),
            tooltip: 'Snap to Center',
            isCompact: isCompact,
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            icon: Icons.grid_3x3,
            isActive: _snapToThirds,
            onTap: () => setState(() => _snapToThirds = !_snapToThirds),
            tooltip: 'Snap to Thirds',
            isCompact: isCompact,
          ),
        ],
      ),
    );
  }

  Widget _buildTransformControls(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.rotate_right,
            label: 'Rotate',
            onTap: _rotateSelectedItem,
            isCompact: isCompact,
          ),
          _ControlButton(
            icon: Icons.center_focus_strong,
            label: 'Center',
            onTap: _centerSelectedItem,
            isCompact: isCompact,
          ),
          _ControlButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            onTap: _deleteSelectedItem,
            color: Colors.red,
            isCompact: isCompact,
          ),
        ],
      ),
    );
  }

  void _rotateSelectedItem() {
    try {
      for (final item in widget.textItems) {
        if (item.id == widget.selectedItemId) {
          final updated = item.copyWith(rotation: item.rotation + 45);
          widget.onTextItemUpdated(updated);
          return;
        }
      }
      for (final item in widget.imageItems) {
        if (item.id == widget.selectedItemId) {
          final updated = item.copyWith(rotation: item.rotation + 45);
          widget.onImageItemUpdated(updated);
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ Rotate error: $e');
    }
  }

  void _centerSelectedItem() {
    try {
      for (final item in widget.textItems) {
        if (item.id == widget.selectedItemId) {
          final updated = item.copyWith(x: 0.5, y: 0.5);
          widget.onTextItemUpdated(updated);
          return;
        }
      }
      for (final item in widget.imageItems) {
        if (item.id == widget.selectedItemId) {
          final updated = item.copyWith(x: 0.5, y: 0.5);
          widget.onImageItemUpdated(updated);
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ Center error: $e');
    }
  }

  void _deleteSelectedItem() {
    widget.onItemDeleted?.call(widget.selectedItemId ?? '');
  }
}

// ═══════════════════════════════════════════════════════
// ✅ TOOLBAR BUTTON
// ═══════════════════════════════════════════════════════

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;
  final bool isCompact;

  const _ToolbarButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(isCompact ? 3 : 5),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.cyan.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: isCompact ? 12 : 14,
            color: isActive ? Colors.cyan : Colors.white54,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ CONTROL BUTTON
// ═══════════════════════════════════════════════════════

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isCompact;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 12,
          vertical: isCompact ? 4 : 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: isCompact ? 18 : 22),
            if (!isCompact) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: color ?? Colors.white70, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ GRID PAINTER
// ═══════════════════════════════════════════════════════

class GridPainter extends CustomPainter {
  final double gridSize;

  GridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 0.5;

      final cellWidth = size.width * gridSize;
      final cellHeight = size.height * gridSize;

      for (double x = 0; x <= size.width; x += cellWidth) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (double y = 0; y <= size.height; y += cellHeight) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }

      final thirdsPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 1;

      for (final fraction in [1 / 3, 2 / 3]) {
        canvas.drawLine(
          Offset(size.width * fraction, 0),
          Offset(size.width * fraction, size.height),
          thirdsPaint,
        );
        canvas.drawLine(
          Offset(0, size.height * fraction),
          Offset(size.width, size.height * fraction),
          thirdsPaint,
        );
      }
    } catch (e) {
      debugPrint('❌ Grid paint error: $e');
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
