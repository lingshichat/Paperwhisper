import 'package:flutter/material.dart';

class StampAnimation extends StatefulWidget {
  final Widget child;
  final bool isStamped;
  final VoidCallback? onStampComplete;

  const StampAnimation({
    super.key,
    required this.child,
    this.isStamped = false,
    this.onStampComplete,
  });

  @override
  State<StampAnimation> createState() => _StampAnimationState();
}

class _StampAnimationState extends State<StampAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _shakeAnimation; // 震动/反弹

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // 快速盖章
    );

    // 1. Initial Scale: Huge -> Small -> Normal (Bounce)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 3.0, end: 0.9), weight: 60), // 快速下落
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 1.05),
        weight: 20,
      ), // 触底反弹
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 20), // 稳定
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    // 2. Opacity: Transparent -> visible
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // 3. Shake/Rotation (Impact wobble)
    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.05), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.05), weight: 30),
          TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.0), weight: 20),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
          ),
        );

    if (widget.isStamped) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(StampAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStamped && !oldWidget.isStamped) {
      _controller.reset();
      _controller.forward().then((_) {
        widget.onStampComplete?.call();
      });
    } else if (!widget.isStamped && oldWidget.isStamped) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isStamped && !_controller.isAnimating) {
      return const SizedBox.shrink(); // Hide if not stamped
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Use OverflowBox to prevent layout errors when scale is > 1.0 (starts at 3.0)
        return OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle:
                  -0.1 +
                  (_controller.value > 0.6
                      ? _shakeAnimation.value
                      : 0), // Base rotation -0.1 rad
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
