import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NmRefreshIndicator extends StatelessWidget {
  const NmRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.backgroundColor,
    this.color,
    this.strokeWidth = 2,
    this.elevation = 0,
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? backgroundColor;
  final Color? color;
  final double strokeWidth;
  final double elevation;

  @override
  Widget build(BuildContext context) => RefreshIndicator.adaptive(
    onRefresh: () async {
      HapticFeedback.heavyImpact();
      await onRefresh();
    },
    backgroundColor: backgroundColor,
    color: color,
    strokeWidth: strokeWidth,
    elevation: elevation,
    child: child,
  );
}
