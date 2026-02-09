import 'package:flutter/material.dart';
import 'package:notemyminds/views/insights/insights_view_model.dart';

class YearAxis extends StatelessWidget {
  const YearAxis({required this.viewModel, super.key});

  final InsightsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    final List<int> years = viewModel.availableYears;

    final List<Widget> labels = years
        .map(
          (y) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => viewModel.setYear(y),
              child: Text(
                '$y',
                style: style?.copyWith(
                  color: y == viewModel.selectedYear
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: y == viewModel.selectedYear ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        )
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: labels);
  }
}
