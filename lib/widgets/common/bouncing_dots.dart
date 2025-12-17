import 'package:flutter/material.dart';

// Bouncing dots loading indicator - equivalent to BouncingDots.tsx

class BouncingDots extends StatefulWidget {
  final Color? color;
  final double size;

  const BouncingDots({
    this.color,
    this.size = 8.0,
    super.key,
  });

  @override
  State<BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).primaryColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final value = _calculateOffset(index);
            return Transform.translate(
              offset: Offset(0, value * -10),
              child: Container(
                width: widget.size,
                height: widget.size,
                margin: EdgeInsets.symmetric(horizontal: widget.size / 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }

  double _calculateOffset(int index) {
    final progress = _controller.value;
    final delay = index * 0.2;
    final adjustedProgress = (progress - delay).clamp(0.0, 1.0);

    if (adjustedProgress < 0.5) {
      return adjustedProgress * 2;
    } else {
      return 2 - (adjustedProgress * 2);
    }
  }
}

