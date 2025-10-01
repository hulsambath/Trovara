import 'package:flutter/material.dart';
import 'package:noteminds/views/insights/insights_view_model.dart';
import 'package:noteminds/views/insights/widgets/month_and_heatmap.dart';
import 'package:noteminds/views/insights/widgets/weekday_axis.dart';
import 'package:noteminds/views/insights/widgets/year_axis.dart';

class HeatmapWithAxes extends StatelessWidget {
  const HeatmapWithAxes({required this.viewModel, super.key});

  static const double _cellSize = 14;
  static const double _cellSpacing = 3;

  final InsightsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (viewModel.isLoading) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WeekdayAxisText(color: scheme.onSurface, headerHeight: MonthAndHeatmap.headerHeight),
        const SizedBox(width: 8),
        Expanded(
          child: MonthAndHeatmap(viewModel: viewModel, cellSize: _cellSize, cellSpacing: _cellSpacing),
        ),
        const SizedBox(width: 8),
        YearAxis(viewModel: viewModel),
      ],
    );
  }
}
