import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:trovara/views/insights/widgets/chart_empty_state.dart';
import 'package:trovara/views/insights/widgets/tag_display_helper.dart';

class TagFrequencyChart extends StatelessWidget {
  const TagFrequencyChart({required this.data, required this.category, super.key});

  final Map<String, int> data;
  final String category;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const ChartEmptyState(message: 'No tags used yet');
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;

    final List<MapEntry<String, int>> items = data.entries.toList()
      ..sort((a, b) {
        final int byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    final List<MapEntry<String, int>> top = items.take(6).toList();
    final double maxY = top.isEmpty ? 0 : top.map((e) => e.value).reduce(math.max).toDouble();

    double horizontalInterval() {
      if (maxY <= 3) return 1;
      if (maxY <= 10) return 2;
      return (maxY / 4).ceilToDouble();
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.15,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: horizontalInterval(),
            getDrawingHorizontalLine: (value) =>
                FlLine(color: scheme.outlineVariant.withValues(alpha: 0.35), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final int i = value.round();
                  if (i < 0 || i >= top.length) return const SizedBox.shrink();
                  final info = TagDisplayHelper.getInfo(context, category, top[i].key);
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: info.bottomWidget ?? const SizedBox.shrink(),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => scheme.surface,
              tooltipBorder: BorderSide(color: scheme.outlineVariant),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (group.x < 0 || group.x >= top.length) return null;
                final entry = top[group.x];
                final info = TagDisplayHelper.getInfo(context, category, entry.key);
                return BarTooltipItem(
                  '${info.label}\n',
                  TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                  children: [
                    TextSpan(
                      text: '${entry.value}',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: List<BarChartGroupData>.generate(top.length, (i) {
            final entry = top[i];
            final info = TagDisplayHelper.getInfo(context, category, entry.key);
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entry.value.toDouble(),
                  width: 14,
                  borderRadius: BorderRadius.circular(6),
                  color: info.color,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
