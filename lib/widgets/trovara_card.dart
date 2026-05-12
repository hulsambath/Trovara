import 'package:flutter/material.dart';

class TrovaraCard extends StatelessWidget {
  const TrovaraCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const _radius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paddedChild = padding != null ? Padding(padding: padding!, child: child) : child;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: _radius,
        child: InkWell(
          borderRadius: _radius,
          onTap: onTap,
          onLongPress: onLongPress,
          child: paddedChild,
        ),
      ),
    );
  }
}
