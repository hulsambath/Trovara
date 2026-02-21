import 'package:flutter/material.dart';
import 'package:trovara/constants/device_constants.dart';

class WeekdayAxisText extends StatelessWidget {
  const WeekdayAxisText({required this.color, required this.headerHeight, super.key});

  final Color color;
  final double headerHeight;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: DeviceConstants.screenWidth(context) / 15,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(height: headerHeight),
        const _AxisSpacer(),
        const _AxisLabel('Mon'),
        const _AxisSpacer(),
        const _AxisLabel('Wed'),
        const _AxisSpacer(),
        const _AxisLabel('Fri'),
      ],
    ),
  );
}

class _AxisSpacer extends StatelessWidget {
  const _AxisSpacer();
  @override
  Widget build(BuildContext context) => const SizedBox(height: (14 + 3) * 1.5);
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.bodySmall);
}
