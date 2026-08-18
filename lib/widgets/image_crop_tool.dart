import 'package:flutter/material.dart';
import 'dart:io';
import '../helpers/image_helper.dart';

class ImageCropTool extends StatefulWidget {
  final String imagePath;
  final void Function(String croppedPath) onCropped;

  const ImageCropTool({
    super.key,
    required this.imagePath,
    required this.onCropped,
  });

  @override
  State<ImageCropTool> createState() => _ImageCropToolState();
}

enum _DragMode { none, draw, move, corner }

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _ImageCropToolState extends State<ImageCropTool> {
  Size? _imageSize;
  Size? _boxSize;
  Rect? _cropRect;
  bool _isApplying = false;
  bool _initialized = false;

  _DragMode _dragMode = _DragMode.none;
  _Corner? _dragCorner;
  Offset _dragStart = Offset.zero;
  Rect _dragStartRect = Rect.zero;

  static const double _minSize = 32;
  static const double _touchSlop = 24;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    final size = await ImageHelper.getImageResolution(widget.imagePath);
    if (mounted) setState(() => _imageSize = size);
  }

  void _initCropIfNeeded() {
    if (_initialized || _boxSize == null) return;
    _initialized = true;
    final w = _boxSize!.width;
    final h = _boxSize!.height;
    final cw = w * 0.9;
    final ch = h * 0.9;
    _cropRect = Rect.fromLTWH(
      (w - cw) / 2,
      (h - ch) / 2,
      cw,
      ch,
    );
  }

  Rect _clampRect(Rect r) {
    final w = _boxSize!.width;
    final h = _boxSize!.height;
    var left = r.left.clamp(0.0, w).toDouble();
    var top = r.top.clamp(0.0, h).toDouble();
    var right = r.right.clamp(0.0, w).toDouble();
    var bottom = r.bottom.clamp(0.0, h).toDouble();
    if (right - left < _minSize) {
      if (r.right >= r.left) {
        right = (left + _minSize).clamp(0.0, w).toDouble();
      } else {
        left = (right - _minSize).clamp(0.0, w).toDouble();
      }
    }
    if (bottom - top < _minSize) {
      if (r.bottom >= r.top) {
        bottom = (top + _minSize).clamp(0.0, h).toDouble();
      } else {
        top = (bottom - _minSize).clamp(0.0, h).toDouble();
      }
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  _Corner? _hitTestCorner(Offset p) {
    if (_cropRect == null) return null;
    final r = _cropRect!;
    if ((p - r.topLeft).distance <= _touchSlop) return _Corner.topLeft;
    if ((p - r.topRight).distance <= _touchSlop) return _Corner.topRight;
    if ((p - r.bottomLeft).distance <= _touchSlop) return _Corner.bottomLeft;
    if ((p - r.bottomRight).distance <= _touchSlop) return _Corner.bottomRight;
    return null;
  }

  void _onPanStart(DragStartDetails details) {
    final p = details.localPosition;
    final corner = _hitTestCorner(p);
    if (corner != null) {
      _dragMode = _DragMode.corner;
      _dragCorner = corner;
    } else if (_cropRect != null && _cropRect!.contains(p)) {
      _dragMode = _DragMode.move;
    } else {
      _dragMode = _DragMode.draw;
      _cropRect = Rect.fromLTWH(p.dx, p.dy, 1, 1);
    }
    _dragStart = p;
    _dragStartRect = _cropRect ?? Rect.zero;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final p = details.localPosition;
    switch (_dragMode) {
      case _DragMode.none:
        break;
      case _DragMode.draw:
        final r = Rect.fromPoints(_dragStart, p);
        _cropRect = _clampRect(r);
        break;
      case _DragMode.move:
        final delta = p - _dragStart;
        _cropRect = _clampRect(_dragStartRect.shift(delta));
        break;
      case _DragMode.corner:
        final r = _dragStartRect;
        switch (_dragCorner!) {
          case _Corner.topLeft:
            _cropRect = _clampRect(
              Rect.fromLTRB(p.dx, p.dy, r.right, r.bottom),
            );
          case _Corner.topRight:
            _cropRect = _clampRect(
              Rect.fromLTRB(r.left, p.dy, p.dx, r.bottom),
            );
          case _Corner.bottomLeft:
            _cropRect = _clampRect(
              Rect.fromLTRB(p.dx, r.top, r.right, p.dy),
            );
          case _Corner.bottomRight:
            _cropRect = _clampRect(
              Rect.fromLTRB(r.left, r.top, p.dx, p.dy),
            );
        }
        break;
    }
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    _dragMode = _DragMode.none;
    _dragCorner = null;
    if (_cropRect != null) _cropRect = _clampRect(_cropRect!);
    setState(() {});
  }

  Future<void> _apply() async {
    if (_cropRect == null || _boxSize == null || _imageSize == null) return;
    setState(() => _isApplying = true);

    final scaleX = _imageSize!.width / _boxSize!.width;
    final scaleY = _imageSize!.height / _boxSize!.height;
    final r = _cropRect!;
    final x = (r.left * scaleX).round();
    final y = (r.top * scaleY).round();
    final right = (r.right * scaleX).round();
    final bottom = (r.bottom * scaleY).round();
    final width = (right - x).clamp(1, _imageSize!.width.toInt() - x);
    final height = (bottom - y).clamp(1, _imageSize!.height.toInt() - y);

    try {
      final croppedPath = await ImageHelper.cropImage(
        imagePath: widget.imagePath,
        x: x,
        y: y,
        width: width,
        height: height,
      );
      if (croppedPath != null) {
        widget.onCropped(croppedPath);
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception('Failed to crop image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cropping image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop Image'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isApplying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            onPressed: _isApplying ? null : _apply,
          ),
        ],
      ),
      body: _imageSize == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final maxH = constraints.maxHeight;
                final ratio = _imageSize!.width / _imageSize!.height;
                var boxW = maxW;
                var boxH = boxW / ratio;
                if (boxH > maxH) {
                  boxH = maxH;
                  boxW = boxH * ratio;
                }
                _boxSize = Size(boxW, boxH);
                _initCropIfNeeded();

                return Center(
                  child: SizedBox(
                    width: boxW,
                    height: boxH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.fill,
                          ),
                          if (_cropRect != null)
                            CustomPaint(
                              painter: _CropMaskPainter(_cropRect!),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Drag to draw, move, or resize the crop area',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }
}

class _CropMaskPainter extends CustomPainter {
  final Rect crop;

  const _CropMaskPainter(this.crop);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final maskPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTRB(0, 0, w, crop.top), maskPaint);
    canvas.drawRect(Rect.fromLTRB(0, crop.bottom, w, h), maskPaint);
    canvas.drawRect(
      Rect.fromLTRB(0, crop.top, crop.left, crop.bottom),
      maskPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(crop.right, crop.top, w, crop.bottom),
      maskPaint,
    );

    final gridPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    final gx1 = crop.left + crop.width / 3;
    final gx2 = crop.left + crop.width * 2 / 3;
    final gy1 = crop.top + crop.height / 3;
    final gy2 = crop.top + crop.height * 2 / 3;
    canvas.drawLine(Offset(gx1, crop.top), Offset(gx1, crop.bottom), gridPaint);
    canvas.drawLine(Offset(gx2, crop.top), Offset(gx2, crop.bottom), gridPaint);
    canvas.drawLine(Offset(crop.left, gy1), Offset(crop.right, gy1), gridPaint);
    canvas.drawLine(Offset(crop.left, gy2), Offset(crop.right, gy2), gridPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(crop, borderPaint);

    final handlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 20.0;
    void drawCorner(Offset c, double dx, double dy) {
      canvas.drawLine(c, c + Offset(dx * len, 0), handlePaint);
      canvas.drawLine(c, c + Offset(0, dy * len), handlePaint);
    }

    drawCorner(crop.topLeft, 1, 1);
    drawCorner(crop.topRight, -1, 1);
    drawCorner(crop.bottomLeft, 1, -1);
    drawCorner(crop.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_CropMaskPainter oldDelegate) => oldDelegate.crop != crop;
}