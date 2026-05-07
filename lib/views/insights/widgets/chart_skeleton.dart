import 'package:flutter/material.dart';

class ChartSkeleton extends StatefulWidget {
  const ChartSkeleton({this.height = 180, super.key});

  final double height;

  @override
  State<ChartSkeleton> createState() => _ChartSkeletonState();
}

class _ChartSkeletonState extends State<ChartSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double opacity = _animation.value;
        return SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              final double heightFactor = [0.6, 0.85, 0.45, 0.75, 0.55, 0.7][index];
              return Container(
                width: 14,
                height: widget.height * heightFactor * 0.85,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class LineSkeleton extends StatefulWidget {
  const LineSkeleton({this.height = 180, super.key});

  final double height;

  @override
  State<LineSkeleton> createState() => _LineSkeletonState();
}

class _LineSkeletonState extends State<LineSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double opacity = _animation.value;
        return SizedBox(
          height: widget.height,
          child: CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _LineSkeletonPainter(color: scheme.surfaceContainerHighest.withValues(alpha: opacity)),
          ),
        );
      },
    );
  }
}

class _LineSkeletonPainter extends CustomPainter {
  final Color color;

  _LineSkeletonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final points = [0.5, 0.4, 0.6, 0.35, 0.55, 0.3, 0.45, 0.5];
    final double segmentWidth = size.width / (points.length - 1);

    path.moveTo(0, size.height * points[0]);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(segmentWidth * i, size.height * points[i]);
    }

    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(segmentWidth * i, size.height * points[i]), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineSkeletonPainter oldDelegate) => oldDelegate.color != color;
}

class HeatmapSkeleton extends StatefulWidget {
  const HeatmapSkeleton({super.key});

  @override
  State<HeatmapSkeleton> createState() => _HeatmapSkeletonState();
}

class _HeatmapSkeletonState extends State<HeatmapSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double opacity = _animation.value;
        return SizedBox(
          height: 100,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 20,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemCount: 7 * 20,
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: opacity * (0.5 + (index % 7) * 0.07)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}
