import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PatternLockWidget extends StatefulWidget {
  final Function(List<int> pattern) onPatternComplete;
  final VoidCallback? onStarted;
  final bool isError;
  final String? errorMessage;
  final Color? activeColor;
  final Color? errorColor;

  const PatternLockWidget({
    super.key,
    required this.onPatternComplete,
    this.onStarted,
    this.isError = false,
    this.errorMessage,
    this.activeColor,
    this.errorColor,
  });

  @override
  State<PatternLockWidget> createState() => _PatternLockWidgetState();
}

class _PatternLockWidgetState extends State<PatternLockWidget> {
  final List<int> _selectedIndices = [];
  Offset? _currentTouchPoint;
  bool _isDragging = false;

  void _onPanStart(DragStartDetails details, Size size) {
    widget.onStarted?.call();
    setState(() {
      _selectedIndices.clear();
      _isDragging = true;
      _currentTouchPoint = details.localPosition;
    });
    _checkTouchPoint(details.localPosition, size);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (!_isDragging) return;
    setState(() {
      _currentTouchPoint = details.localPosition;
    });
    _checkTouchPoint(details.localPosition, size);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    setState(() {
      _isDragging = false;
      _currentTouchPoint = null;
    });
    if (_selectedIndices.isNotEmpty) {
      widget.onPatternComplete(List.from(_selectedIndices));
    }
  }

  void _checkTouchPoint(Offset touch, Size size) {
    final cellWidth = size.width / 3;
    final cellHeight = size.height / 3;
    final hitRadius = min(cellWidth, cellHeight) * 0.35;

    for (int i = 0; i < 9; i++) {
      final col = i % 3;
      final row = i ~/ 3;
      final center = Offset(
        cellWidth * col + cellWidth / 2,
        cellHeight * row + cellHeight / 2,
      );

      final distance = (touch - center).distance;
      if (distance <= hitRadius) {
        if (!_selectedIndices.contains(i)) {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedIndices.add(i);
          });
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.primaryColor;
    final errorColor = widget.errorColor ?? Colors.redAccent;

    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          return GestureDetector(
            onPanStart: (details) => _onPanStart(details, size),
            onPanUpdate: (details) => _onPanUpdate(details, size),
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              size: size,
              painter: _PatternPainter(
                selectedIndices: _selectedIndices,
                currentTouchPoint: _currentTouchPoint,
                isError: widget.isError,
                activeColor: activeColor,
                errorColor: errorColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final List<int> selectedIndices;
  final Offset? currentTouchPoint;
  final bool isError;
  final Color activeColor;
  final Color errorColor;

  _PatternPainter({
    required this.selectedIndices,
    required this.currentTouchPoint,
    required this.isError,
    required this.activeColor,
    required this.errorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / 3;
    final cellHeight = size.height / 3;
    final dotRadius = min(cellWidth, cellHeight) * 0.12;
    final ringRadius = min(cellWidth, cellHeight) * 0.28;

    final currentColor = isError ? errorColor : activeColor;

    // Calculate node center positions
    final centers = List<Offset>.generate(9, (i) {
      final col = i % 3;
      final row = i ~/ 3;
      return Offset(
        cellWidth * col + cellWidth / 2,
        cellHeight * row + cellHeight / 2,
      );
    });

    // 1. Draw lines between selected nodes
    if (selectedIndices.isNotEmpty) {
      final linePaint = Paint()
        ..color = currentColor.withValues(alpha: 0.8)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(centers[selectedIndices.first].dx, centers[selectedIndices.first].dy);

      for (int i = 1; i < selectedIndices.length; i++) {
        final pt = centers[selectedIndices[i]];
        path.lineTo(pt.dx, pt.dy);
      }

      if (currentTouchPoint != null && !isError) {
        path.lineTo(currentTouchPoint!.dx, currentTouchPoint!.dy);
      }

      canvas.drawPath(path, linePaint);
    }

    // 2. Draw dots and active outer rings
    for (int i = 0; i < 9; i++) {
      final center = centers[i];
      final isSelected = selectedIndices.contains(i);

      if (isSelected) {
        // Outer ring glow
        final ringPaint = Paint()
          ..color = currentColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, ringRadius, ringPaint);

        final ringBorderPaint = Paint()
          ..color = currentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(center, ringRadius, ringBorderPaint);

        // Core dot
        final dotPaint = Paint()
          ..color = currentColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, dotRadius, dotPaint);
      } else {
        // Unselected dot
        final dotPaint = Paint()
          ..color = Colors.white54
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, dotRadius * 0.7, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.selectedIndices != selectedIndices ||
        oldDelegate.currentTouchPoint != currentTouchPoint ||
        oldDelegate.isError != isError ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.errorColor != errorColor;
  }
}
