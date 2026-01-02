import 'package:flutter/material.dart';

enum IndicatorType { brightness, volume }

class BrightnessVolumeIndicator extends StatelessWidget {
  final IndicatorType type;
  final double value;

  const BrightnessVolumeIndicator({
    super.key,
    required this.type,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isBrightness = type == IndicatorType.brightness;
    final alignment = isBrightness
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final safeValue = value.clamp(0.0, 1.0);

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Icon(
              _getIcon(safeValue),
              color: isBrightness ? Colors.yellow : Colors.blue,
              size: 28,
            ),

            const SizedBox(height: 12),

            // Vertical progress bar
            SizedBox(
              width: 36,
              height: 120,
              child: _VerticalProgressBar(
                value: safeValue,
                color: isBrightness ? Colors.yellow : Colors.blue,
              ),
            ),

            const SizedBox(height: 8),

            // Percentage text
            Text(
              '${(safeValue * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(double value) {
    if (type == IndicatorType.brightness) {
      if (value < 0.3) return Icons.brightness_low;
      if (value < 0.7) return Icons.brightness_medium;
      return Icons.brightness_high;
    } else {
      if (value <= 0) return Icons.volume_off;
      if (value < 0.3) return Icons.volume_mute;
      if (value < 0.7) return Icons.volume_down;
      return Icons.volume_up;
    }
  }
}

class _VerticalProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  const _VerticalProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final filledHeight = height * value;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Filled portion
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: double.infinity,
                height: filledHeight,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Level markers
              ...List.generate(5, (index) {
                final markerPosition = (index + 1) / 5;
                return Positioned(
                  bottom: height * markerPosition - 1,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: Colors.black26),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal variant for different layouts
class HorizontalBrightnessVolumeIndicator extends StatelessWidget {
  final IndicatorType type;
  final double value;

  const HorizontalBrightnessVolumeIndicator({
    super.key,
    required this.type,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isBrightness = type == IndicatorType.brightness;
    final safeValue = value.clamp(0.0, 1.0);
    final color = isBrightness ? Colors.yellow : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(safeValue), color: color, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: LinearProgressIndicator(
              value: safeValue,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '${(safeValue * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(double value) {
    if (type == IndicatorType.brightness) {
      if (value < 0.3) return Icons.brightness_low;
      if (value < 0.7) return Icons.brightness_medium;
      return Icons.brightness_high;
    } else {
      if (value <= 0) return Icons.volume_off;
      if (value < 0.3) return Icons.volume_mute;
      if (value < 0.7) return Icons.volume_down;
      return Icons.volume_up;
    }
  }
}
