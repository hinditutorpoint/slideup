import 'package:flutter/material.dart';

import '../models/video_player_state.dart';

class SeekIndicatorWidget extends StatefulWidget {
  final SeekDirection direction;
  final int seconds;

  const SeekIndicatorWidget({
    super.key,
    required this.direction,
    required this.seconds,
  });

  @override
  State<SeekIndicatorWidget> createState() => _SeekIndicatorWidgetState();
}

class _SeekIndicatorWidgetState extends State<SeekIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(SeekIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds ||
        oldWidget.direction != widget.direction) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.direction == SeekDirection.none) {
      return const SizedBox.shrink();
    }

    final isForward = widget.direction == SeekDirection.forward;
    final alignment = isForward ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          );
        },
        child: Container(
          margin: EdgeInsets.only(
            left: isForward ? 0 : 48,
            right: isForward ? 48 : 0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated arrows
              _AnimatedArrows(isForward: isForward),

              const SizedBox(width: 8),

              // Seconds text
              Text(
                '${widget.seconds}s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedArrows extends StatefulWidget {
  final bool isForward;

  const _AnimatedArrows({required this.isForward});

  @override
  State<_AnimatedArrows> createState() => _AnimatedArrowsState();
}

class _AnimatedArrowsState extends State<_AnimatedArrows>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.isForward ? Icons.fast_forward : Icons.fast_rewind;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animValue = ((_controller.value + delay) % 1.0);
            final opacity = animValue < 0.5 ? animValue * 2 : 2 - animValue * 2;

            return Opacity(
              opacity: opacity.clamp(0.3, 1.0),
              child: Icon(icon, color: Colors.white, size: 20),
            );
          }),
        );
      },
    );
  }
}

/// Utility wrapper for AnimatedBuilder with null safety
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedWidget(
      listenable: animation,
      builder: builder,
      child: child,
    );
  }
}

class AnimatedWidget extends StatelessWidget {
  final Listenable listenable;
  final Widget? child;
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedWidget({
    super.key,
    required this.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => builder(context, child),
      child: child,
    );
  }
}
