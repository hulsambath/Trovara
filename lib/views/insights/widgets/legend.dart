import 'package:flutter/material.dart';
import 'package:trovara/views/insights/widgets/util.dart';

class Legend extends StatelessWidget {
  const Legend({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final blocks = [0, 1, 2, 3, 4]
        .map(
          (v) => Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(color: colorForValue(v, scheme), borderRadius: BorderRadius.circular(2)),
          ),
        )
        .toList();

    return Row(
      children: [
        Text('Less', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 6),
        ...blocks,
        const SizedBox(width: 6),
        Text('More', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
