import 'package:flutter/material.dart';

class SpeedIndicatorWidget extends StatefulWidget {
  final double speed;
  final bool showLabel;

  const SpeedIndicatorWidget({
    super.key,
    this.speed = 2.0,
    this.showLabel = true,
  });

  @override
  State<SpeedIndicatorWidget> createState() => _SpeedIndicatorWidgetState();
}

class _SpeedIndicatorWidgetState extends State<SpeedIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(top: 60),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fast_forward, color: Colors.white, size: 20),
                  if (widget.showLabel) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${widget.speed}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact speed badge for controls bar
class SpeedBadge extends StatelessWidget {
  final double speed;
  final VoidCallback? onTap;

  const SpeedBadge({super.key, required this.speed, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isNormal = (speed - 1.0).abs() < 0.01;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isNormal ? Colors.white24 : Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${speed}x',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isNormal ? FontWeight.normal : FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
