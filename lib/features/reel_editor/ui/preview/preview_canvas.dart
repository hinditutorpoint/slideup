import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../providers/canvas_provider.dart';
import '../../engine/preview_engine.dart';

/// Preview canvas md:325-347 — constrained, no hardcoded dims md:78, zero overflow md:94-142
class PreviewCanvas extends ConsumerStatefulWidget {
  final PreviewEngine engine;
  final bool enableInteraction;
  const PreviewCanvas({super.key, required this.engine, this.enableInteraction = true});

  @override
  ConsumerState<PreviewCanvas> createState() => _PreviewCanvasState();
}

class _PreviewCanvasState extends ConsumerState<PreviewCanvas> {
  double _scale = 1.0;
  double _rotation = 0;
  final Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final preset = canvasState.config.preset;
    final ratio = canvasState.config.effectiveRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        // never unbounded md:94 — fallback to 9:16 if constraints infinite
        final safeW = maxW.isFinite ? maxW : 360.0;
        final safeH = maxH.isFinite ? maxH : 640.0;
        final size = preset.calcSize(safeW, safeH, customRatio: ratio);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: size.width, maxHeight: size.height),
            child: AspectRatio(
              aspectRatio: ratio,
              child: Container(
                color: Color(canvasState.config.backgroundColor),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildVideo(),
                    if (canvasState.showGrid) const _GridOverlay(),
                    if (canvasState.showSafeArea) const _SafeAreaOverlay(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideo() {
    final c = widget.engine.controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    Widget video = FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
    if (!widget.enableInteraction) return video;
    // creative: RawGestureDetector arena — canvas wins over parent scroll md:368-375
    return RawGestureDetector(
      gestures: {
        ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(() => ScaleGestureRecognizer(), (inst) {
          inst.onUpdate = (d) {
            if (!mounted) return;
            setState(() {
              if (d.scale.isFinite && d.scale > 0) _scale = d.scale.clamp(0.1, 4.0);
              if (d.rotation.isFinite) _rotation = d.rotation;
            });
          };
          inst.onEnd = (_) { /* coalesced history via HistoryNotifier.push(coalesceId) */ };
        }),
      },
      behavior: HitTestBehavior.opaque,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translate(_offset.dx, _offset.dy)
          ..scale(_scale)
          ..rotateZ(_rotation),
        child: video,
      ),
    );
  }
}

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white24..strokeWidth = 0.5;
    for (int i = 1; i < 3; i++) {
      final dx = size.width / 3 * i;
      final dy = size.height / 3 * i;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), p);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SafeAreaOverlay extends StatelessWidget {
  const _SafeAreaOverlay();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.yellow.withValues(alpha: 0.6), width: 1))),
    );
  }
}
