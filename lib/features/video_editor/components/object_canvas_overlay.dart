import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/timeline_provider.dart';
import 'video_layer_content.dart';
import '../providers/video_editor_provider.dart';

// ═══════════════════════════════════════════════════════
// ✅ ON-CANVAS OBJECT OVERLAY
// • All visible text/image overlays are drawn on the preview.
// • Tap any overlay to select it.
// • Selected overlay: 4 corner handles (drag to resize),
//   a top rotate knob (drag to rotate), plus body drag to move
//   and two-finger pinch to scale/rotate.
// • Tap empty area to deselect.
// ═══════════════════════════════════════════════════════

class ObjectCanvasOverlay extends ConsumerStatefulWidget {
  const ObjectCanvasOverlay({super.key});

  @override
  ConsumerState<ObjectCanvasOverlay> createState() =>
      _ObjectCanvasOverlayState();
}

class _ObjectCanvasOverlayState extends ConsumerState<ObjectCanvasOverlay> {
  final GlobalKey _stackKey = GlobalKey();

  // gesture start state
  double _startScale = 1.0;
  double _startRotation = 0.0;
  double _startX = 0.5;
  double _startY = 0.5;
  Offset? _startFocal;
  Rect _startBoxRect = Rect.zero;
  Offset _startCenter = Offset.zero;
  double _startDist = 1.0;
  double _startAngle = 0.0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineProvider);
    final items = state
        .getVisibleItemsAt(state.currentPosition)
        .where((i) =>
            i is TextTimelineItem ||
            i is ImageTimelineItem ||
            i is VideoOverlayTimelineItem ||
            i is SolidColorTimelineItem)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          key: _stackKey,
          fit: StackFit.expand,
          children: [
            // Deselect + close the properties panel when tapping empty area
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  ref.read(timelineProvider.notifier).clearSelection();
                  if (ref.read(videoEditorProvider).currentPanel ==
                      EditorPanel.properties) {
                    ref
                        .read(videoEditorProvider.notifier)
                        .togglePanel(EditorPanel.properties);
                  }
                },
                child: const SizedBox.expand(),
              ),
            ),

            for (final item in items)
              _buildOverlayItem(
                item,
                Size(constraints.maxWidth, constraints.maxHeight),
                item.id == state.selectedItemId,
              ),
          ],
        );
      },
    );
  }

  // ── One overlay object ──
  Widget _buildOverlayItem(TimelineItem item, Size box, bool isSelected) {
    // Keyframe interpolation (only when NOT selected/editing)
    double renderX = item.x;
    double renderY = item.y;
    double renderScale = item.scale;
    double renderRotation = item.rotation;
    double renderOpacity = 1.0;
    if (item is ImageTimelineItem) renderOpacity = item.opacity;
    if (item is VideoOverlayTimelineItem) renderOpacity = item.opacity;
    if (item is SolidColorTimelineItem) renderOpacity = item.opacity;

    if (!isSelected) {
      final kf = _getInterpolated(item);
      if (kf != null) {
        renderX = kf.x ?? item.x;
        renderY = kf.y ?? item.y;
        renderScale = kf.scale ?? item.scale;
        renderRotation = kf.rotation ?? item.rotation;
        if (kf.opacity != null) renderOpacity = kf.opacity!;
      }
    }

    final Widget content;
    if (item is ImageTimelineItem) {
      content = _buildImage(item, box);
    } else if (item is VideoOverlayTimelineItem) {
      final w = box.width * 0.4;
      final h = 16 / 9 >= 1 ? w * 9 / 16 : w;
      content = SizedBox(
        width: w,
        height: h,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: VideoLayerContent(item: item),
        ),
      );
    } else if (item is SolidColorTimelineItem) {
      final w = box.width * 0.4 * item.width;
      final h = box.height * 0.4 * item.height;
      content = Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Color(item.colorValue),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    } else {
      content = _buildText(item as TextTimelineItem);
    }

    final editable = !item.isLocked;

    Widget wrappedContent = content;

    if (isSelected) {
      wrappedContent = Stack(
        clipBehavior: Clip.none,
        children: [
          content,

          // Selection outline tightly around object content
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: item.isLocked
                        ? Colors.grey
                        : const Color(0xFF6C63FF),
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          if (editable) ...[
            // 4 corner resize handles attached to the 4 corners of the object
            Positioned(
              left: -8,
              top: -8,
              child: _resizeHandle(item),
            ),
            Positioned(
              right: -8,
              top: -8,
              child: _resizeHandle(item),
            ),
            Positioned(
              left: -8,
              bottom: -8,
              child: _resizeHandle(item),
            ),
            Positioned(
              right: -8,
              bottom: -8,
              child: _resizeHandle(item),
            ),

            // Rotate knob with connector line above the object
            Positioned(
              top: -30,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _rotateHandle(item),
                  Container(
                    width: 1.5,
                    height: 8,
                    color: const Color(0xFF6C63FF),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    final transformed = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(renderRotation * math.pi / 180)
        ..scale(renderScale),
      child: Opacity(
        opacity: renderOpacity.clamp(0.0, 1.0),
        child: wrappedContent,
      ),
    );

    final positioned = Align(
      alignment: Alignment(
        (renderX * 2 - 1).clamp(-1.0, 1.0),
        (renderY * 2 - 1).clamp(-1.0, 1.0),
      ),
      child: transformed,
    );

    if (!isSelected) {
      // Tap to select + open the properties panel
      return GestureDetector(
        onTap: () {
          ref
              .read(timelineProvider.notifier)
              .selectItem(item.id, item.type);
          if (ref.read(videoEditorProvider).currentPanel !=
              EditorPanel.properties) {
            ref
                .read(videoEditorProvider.notifier)
                .togglePanel(EditorPanel.properties);
          }
        },
        child: positioned,
      );
    }

    // Selected → drag to move / pinch
    return editable
        ? GestureDetector(
            onScaleStart: (d) {
              _startScale = item.scale;
              _startRotation = item.rotation;
              _startX = item.x;
              _startY = item.y;
              _startFocal = d.focalPoint;
              HapticFeedback.lightImpact();
            },
            onScaleUpdate: (d) => _onBodyUpdate(d, item),
            onScaleEnd: (_) {
              _startFocal = null;
              HapticFeedback.selectionClick();
            },
            child: positioned,
          )
        : positioned;
  }

  // ── Corner resize handle ──
  Widget _resizeHandle(TimelineItem item) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) {
        _beginCenterBased(item);
        _startDist =
            (_startCenter - d.focalPoint).distance.clamp(1.0, 100000.0);
      },
      onScaleUpdate: (d) {
        if (_startDist <= 0) return;
        final cur = (_startCenter - d.focalPoint).distance;
        final ns = (_startScale * cur / _startDist).clamp(0.05, 5.0);
        _apply(item.id, item.type, _startX, _startY, ns, _startRotation);
      },
      onScaleEnd: (_) => HapticFeedback.selectionClick(),
      child: _handleDot(),
    );
  }

  // ── Rotate knob (top center) ──
  Widget _rotateHandle(TimelineItem item) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) {
        _beginCenterBased(item);
        _startAngle = _angleTo(_startCenter, d.focalPoint);
      },
      onScaleUpdate: (d) {
        final cur = _angleTo(_startCenter, d.focalPoint);
        var nr = _startRotation + (cur - _startAngle) * 180 / math.pi;
        nr = nr % 360;
        if (nr < 0) nr += 360;
        _apply(item.id, item.type, _startX, _startY, _startScale, nr);
      },
      onScaleEnd: (_) => HapticFeedback.selectionClick(),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 4),
          ],
        ),
        child: const Icon(Icons.rotate_right, size: 13, color: Colors.white),
      ),
    );
  }

  void _beginCenterBased(TimelineItem item) {
    _startScale = item.scale;
    _startRotation = item.rotation;
    _startX = item.x;
    _startY = item.y;
    _startBoxRect = _globalRect();
    _startCenter = Offset(
      _startBoxRect.left + item.x * _startBoxRect.width,
      _startBoxRect.top + item.y * _startBoxRect.height,
    );
  }

  double _angleTo(Offset center, Offset p) =>
      math.atan2(p.dy - center.dy, p.dx - center.dx);

  // ── Body drag to move ──
  void _onBodyUpdate(ScaleUpdateDetails d, TimelineItem item) {
    if (_startFocal == null) return;
    final box = _globalRect();
    if (box.width == 0 || box.height == 0) return;
    final dx = (d.focalPoint.dx - _startFocal!.dx) / box.width;
    final dy = (d.focalPoint.dy - _startFocal!.dy) / box.height;
    final nx = (_startX + dx).clamp(0.0, 1.0);
    final ny = (_startY + dy).clamp(0.0, 1.0);
    final ns = (_startScale * d.scale).clamp(0.05, 5.0);
    final nr = (_startRotation + d.rotation * 180 / math.pi) % 360;
    _apply(item.id, item.type, nx, ny, ns, nr);
  }

  void _apply(
    String id,
    TimelineItemType type,
    double x,
    double y,
    double scale,
    double rotation,
  ) {
    final notifier = ref.read(timelineProvider.notifier);
    final state = ref.read(timelineProvider);
    if (type == TimelineItemType.text) {
      final it = state.textItems.cast<TimelineItem?>().firstWhere(
        (t) => t?.id == id,
        orElse: () => null,
      );
      if (it == null) return;
      notifier.updateTextItem(
        id,
        (it as TextTimelineItem).copyWith(x: x, y: y, scale: scale, rotation: rotation),
      );
    } else if (type == TimelineItemType.image) {
      final it = state.imageItems.cast<TimelineItem?>().firstWhere(
        (t) => t?.id == id,
        orElse: () => null,
      );
      if (it == null) return;
      notifier.updateImageItem(
        id,
        (it as ImageTimelineItem).copyWith(x: x, y: y, scale: scale, rotation: rotation),
      );
    } else if (type == TimelineItemType.video) {
      final it = state.videoOverlayItems.cast<TimelineItem?>().firstWhere(
        (t) => t?.id == id,
        orElse: () => null,
      );
      if (it == null) return;
      notifier.updateVideoOverlayItem(
        id,
        (it as VideoOverlayTimelineItem).copyWith(x: x, y: y, scale: scale, rotation: rotation),
      );
    } else if (type == TimelineItemType.solidColor) {
      final it = state.solidColorItems.cast<TimelineItem?>().firstWhere(
        (t) => t?.id == id,
        orElse: () => null,
      );
      if (it == null) return;
      notifier.updateSolidColorItem(
        id,
        (it as SolidColorTimelineItem).copyWith(x: x, y: y, scale: scale, rotation: rotation),
      );
    }
  }

  /// Returns interpolated keyframe values at the current playhead, or null if
  /// no keyframes exist for this item.
  KeyframeData? _getInterpolated(TimelineItem item) {
    final state = ref.read(timelineProvider);
    final kfs = state.keyframes[item.id];
    if (kfs == null || kfs.isEmpty) return null;
    final relativePos = state.currentPosition - item.startTime;
    return KeyframeData.interpolate(kfs, relativePos);
  }

  Rect _globalRect() {
    final obj = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (obj == null) return Rect.zero;
    final offset = obj.localToGlobal(Offset.zero);
    return Rect.fromLTWH(offset.dx, offset.dy, obj.size.width, obj.size.height);
  }

  Widget _handleDot() => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF6C63FF), width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      );

  // ── RENDERERS ──

  Widget _buildText(TextTimelineItem item) {
    final s = item.style;
    final previewScale = (_globalRect().width) / 1080;
    final w = previewScale > 0 ? previewScale : 400 / 1080;
    final fontSize = (s.fontSize * w).clamp(4.0, 400.0);

    final baseStyle = TextStyle(
      fontFamily: s.fontFamily.isNotEmpty ? s.fontFamily : null,
      fontSize: fontSize,
      color: Color(s.color),
      fontWeight: s.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: s.letterSpacing * w,
      height: s.lineHeight,
      shadows: s.shadowBlur > 0
          ? [
              Shadow(
                blurRadius: s.shadowBlur * w,
                color: Color(s.shadowColor),
                offset: Offset(2 * w, 2 * w),
              ),
            ]
          : null,
    );

    final child = s.strokeWidth > 0
        ? Stack(
            children: [
              Text(
                item.text,
                textAlign: _mapAlign(s.textAlign),
                style: baseStyle.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = s.strokeWidth * w
                    ..strokeJoin = StrokeJoin.round
                    ..color = Color(s.strokeColor),
                ),
              ),
              Text(
                item.text,
                textAlign: _mapAlign(s.textAlign),
                style: baseStyle,
              ),
            ],
          )
        : Text(
            item.text,
            textAlign: _mapAlign(s.textAlign),
            style: baseStyle,
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: s.backgroundColor != 0 ? Color(s.backgroundColor) : null,
      child: child,
    );
  }

  Widget _buildImage(ImageTimelineItem item, Size box) {
    final width = box.width * item.scale;
    final height = (item.aspectRatio > 0 ? width / item.aspectRatio : width);

    final image = item.imageBytes != null
        ? Image.memory(
            item.imageBytes!,
            fit: _mapFit(item.fit),
            gaplessPlayback: true,
          )
        : Image.file(
            File(item.imagePath),
            fit: _mapFit(item.fit),
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 48,
            ),
          );

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(item.borderRadius),
        child: Container(
          decoration: BoxDecoration(
            border: item.borderWidth > 0
                ? Border.all(
                    color: Color(item.borderColor ?? 0xFFFFFFFF),
                    width: item.borderWidth,
                  )
                : null,
            borderRadius: BorderRadius.circular(item.borderRadius),
          ),
          child: image,
        ),
      ),
    );
  }

  TextAlign _mapAlign(TextAlignCustom a) {
    switch (a) {
      case TextAlignCustom.left:
        return TextAlign.left;
      case TextAlignCustom.right:
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }

  BoxFit _mapFit(ImageFit fit) {
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
}
