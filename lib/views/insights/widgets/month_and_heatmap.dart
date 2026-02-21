import 'package:flutter/material.dart';
import 'package:trovara/views/insights/insights_view_model.dart';
import 'package:trovara/views/insights/widgets/util.dart';

class MonthAndHeatmap extends StatelessWidget {
  const MonthAndHeatmap({required this.viewModel, required this.cellSize, required this.cellSpacing, super.key});

  static const double headerHeight = 20;

  final InsightsViewModel viewModel;
  final double cellSize;
  final double cellSpacing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle? monthStyle = Theme.of(context).textTheme.bodySmall;
    final List<List<int>> weeks = viewModel.weeksGrid;

    if (viewModel.isLoading) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }

    if (weeks.isEmpty) {
      return SizedBox(
        height: headerHeight + (cellSize + cellSpacing) * 7,
        child: Center(child: Text('No data', style: Theme.of(context).textTheme.bodyMedium)),
      );
    }

    final DateTime start = viewModel.startDate;

    List<Widget> buildMonthHeader() {
      final List<Widget> segments = [];
      int col = 0;
      while (col < weeks.length) {
        final DateTime weekStart = start.add(Duration(days: col * 7));
        final int currentMonth = weekStart.month;
        int span = 1;
        while (col + span < weeks.length) {
          final DateTime nextWeek = start.add(Duration(days: (col + span) * 7));
          if (nextWeek.month != currentMonth) break;
          span++;
        }
        final double segmentWidth = (span * cellSize) + ((span - 1) * cellSpacing);
        segments.add(
          SizedBox(
            width: segmentWidth,
            height: headerHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_monthShort(currentMonth), style: monthStyle),
            ),
          ),
        );
        if (col + span < weeks.length) segments.add(SizedBox(width: cellSpacing, height: headerHeight));
        col += span;
      }
      return segments;
    }

    List<Widget> buildGridRow() {
      final List<Widget> cols = [];
      for (int col = 0; col < weeks.length; col++) {
        final List<int> days = weeks[col];
        cols.add(
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(7, (row) {
              final int value = row < days.length ? days[row] : 0;
              final Color color = colorForValue(value, scheme);
              return Padding(
                padding: EdgeInsets.only(bottom: row == 6 ? 0 : cellSpacing),
                child: Container(
                  width: cellSize,
                  height: cellSize,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                ),
              );
            }),
          ),
        );
        if (col != weeks.length - 1) cols.add(SizedBox(width: cellSpacing));
      }
      return cols;
    }

    return SizedBox(
      height: headerHeight + (cellSize + cellSpacing) * 7,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: buildMonthHeader()),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: buildGridRow()),
          ],
        ),
      ),
    );
  }

  String _monthShort(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m - 1];
  }
}
