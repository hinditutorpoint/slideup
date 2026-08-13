import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A sleek, customizable HSV Color Wheel widget with interactive touch selection,
/// brightness slider, hex/RGB preview, and quick swatches.
class ColorWheelWidget extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<Color>? onColorChangeEnd;
  final double wheelSize;

  const ColorWheelWidget({
    super.key,
    this.initialColor = const Color(0xFFFF6B6B),
    required this.onColorChanged,
    this.onColorChangeEnd,
    this.wheelSize = 240,
  });

  @override
  State<ColorWheelWidget> createState() => _ColorWheelWidgetState();
}

class _ColorWheelWidgetState extends State<ColorWheelWidget> {
  late double _hue; // 0..360
  late double _saturation; // 0..1
  late double _value; // 0..1

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value == 0 ? 1.0 : hsv.value;
  }

  Color get _currentColor {
    return HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
  }

  void _updateFromOffset(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    final distance = sqrt(dx * dx + dy * dy);
    final sat = (distance / radius).clamp(0.0, 1.0);

    var angle = atan2(dy, dx) * 180 / pi;
    if (angle < 0) angle += 360;

    setState(() {
      _hue = angle;
      _saturation = sat;
    });

    widget.onColorChanged(_currentColor);
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _currentColor;
    final rVal = (currentColor.r * 255).round();
    final gVal = (currentColor.g * 255).round();
    final bVal = (currentColor.b * 255).round();
    final argb = currentColor.toARGB32();
    final hexString =
        '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color Preview & Hex Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              // Color Chip Preview
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: currentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: currentColor.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Hex & RGB Text
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hexString,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'R: $rVal  G: $gVal  B: $bVal',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Color Wheel Grid Painter
        SizedBox(
          width: widget.wheelSize,
          height: widget.wheelSize,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onPanStart: (details) {
                  HapticFeedback.selectionClick();
                  _updateFromOffset(details.localPosition, size);
                },
                onPanUpdate: (details) {
                  _updateFromOffset(details.localPosition, size);
                },
                onPanEnd: (_) {
                  widget.onColorChangeEnd?.call(_currentColor);
                },
                child: CustomPaint(
                  size: size,
                  painter: _ColorWheelPainter(
                    hue: _hue,
                    saturation: _saturation,
                    value: _value,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // Brightness / Value Slider
        Row(
          children: [
            const Icon(Icons.brightness_5, color: Colors.white70, size: 20),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 10),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: _value,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (v) {
                    setState(() => _value = v);
                    widget.onColorChanged(_currentColor);
                  },
                  onChangeEnd: (_) {
                    widget.onColorChangeEnd?.call(_currentColor);
                  },
                ),
              ),
            ),
            const Icon(Icons.brightness_7, color: Colors.white, size: 20),
          ],
        ),
        const SizedBox(height: 12),

        // Quick Swatches Row
        _buildSwatchesRow(),
      ],
    );
  }

  Widget _buildSwatchesRow() {
    final swatches = const [
      Color(0xFFFF6B6B),
      Color(0xFF4ECDC4),
      Color(0xFFFFD166),
      Color(0xFF06D6A0),
      Color(0xFF118AB2),
      Color(0xFF9D4EDD),
      Color(0xFFFFFFFF),
      Color(0xFF000000),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: swatches.map((color) {
          final isSelected = _currentColor.toARGB32() == color.toARGB32();
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final hsv = HSVColor.fromColor(color);
              setState(() {
                _hue = hsv.hue;
                _saturation = hsv.saturation;
                _value = hsv.value == 0 ? 1.0 : hsv.value;
              });
              widget.onColorChanged(_currentColor);
              widget.onColorChangeEnd?.call(_currentColor);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _ColorWheelPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw rainbow hue sweep gradient
    final sweepGradient = SweepGradient(
      colors: const [
        Color(0xFFFF0000), // Red
        Color(0xFFFFFF00), // Yellow
        Color(0xFF00FF00), // Green
        Color(0xFF00FFFF), // Cyan
        Color(0xFF0000FF), // Blue
        Color(0xFFFF00FF), // Magenta
        Color(0xFFFF0000), // Red
      ],
    );

    final wheelPaint = Paint()
      ..shader = sweepGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, wheelPaint);

    // Radial saturation gradient overlay (white center to transparent edge)
    final radialGradient = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: value),
        Colors.white.withValues(alpha: 0.0),
      ],
    );

    final saturationPaint = Paint()
      ..shader = radialGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, saturationPaint);

    // Value darkness overlay if value < 1.0
    if (value < 1.0) {
      final darknessPaint = Paint()
        ..color = Colors.black.withValues(alpha: 1.0 - value)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, darknessPaint);
    }

    // Draw Touch Indicator Thumb
    final radAngle = hue * pi / 180;
    final thumbDist = saturation * radius;
    final thumbX = center.dx + thumbDist * cos(radAngle);
    final thumbY = center.dy + thumbDist * sin(radAngle);
    final thumbOffset = Offset(thumbX, thumbY);

    final thumbColor =
        HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();

    // Thumb outer shadow ring
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(thumbOffset, 14, shadowPaint);

    // Thumb outer white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbOffset, 12, borderPaint);

    // Thumb inner color center
    final innerPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbOffset, 9, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.hue != hue ||
        oldDelegate.saturation != saturation ||
        oldDelegate.value != value;
  }
}
