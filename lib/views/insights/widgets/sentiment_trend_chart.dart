import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:trovara/views/insights/widgets/chart_empty_state.dart';

class SentimentTrendChart extends StatelessWidget {
  const SentimentTrendChart({required this.data, super.key});

  final List<(DateTime, double)> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const ChartEmptyState(message: 'Add mood tags to notes to see your trend', icon: Icons.mood_outlined);
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;

    final List<DateTime> dates = data.map((e) => DateTime(e.$1.year, e.$1.month, e.$1.day)).toList();
    final List<FlSpot> spots = List<FlSpot>.generate(data.length, (i) {
      final double y = data[i].$2.clamp(-1.0, 1.0);
      return FlSpot(i.toDouble(), y);
    });

    final Set<int> labelIndices = _buildBottomLabelIndices(data.length);

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(0, spots.length - 1).toDouble(),
          minY: -1.0,
          maxY: 1.0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.5,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: scheme.outlineVariant.withValues(alpha: 0.35), strokeWidth: 1),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: 0, color: scheme.outlineVariant.withValues(alpha: 0.7), strokeWidth: 1),
            ],
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final String? label = switch (value.round()) {
                    1 => '😊',
                    0 => '😐',
                    -1 => '😢',
                    _ => null,
                  };

                  if (label == null) return const SizedBox.shrink();
                  return Text(label, style: Theme.of(context).textTheme.bodySmall);
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final int i = value.round();
                  if (i < 0 || i >= dates.length) return const SizedBox.shrink();
                  if (!labelIndices.contains(i)) return const SizedBox.shrink();

                  final DateTime d = dates[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${d.day}/${d.month}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => scheme.surface,
              tooltipBorder: BorderSide(color: scheme.outlineVariant),
              getTooltipItems: (spots) => spots.map((s) {
                final int i = s.x.round();
                final DateTime d = i >= 0 && i < dates.length ? dates[i] : DateTime.now();
                return LineTooltipItem(
                  '${d.day}/${d.month}/${d.year}\n',
                  TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                  children: [
                    TextSpan(
                      text: s.y.toStringAsFixed(2),
                      style: TextStyle(color: _sentimentColor(s.y, scheme)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: scheme.primary,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3,
                  color: _sentimentColor(spot.y, scheme),
                  strokeWidth: 1,
                  strokeColor: scheme.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                applyCutOffY: true,
                cutOffY: 0,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [scheme.error.withValues(alpha: 0.20), scheme.error.withValues(alpha: 0.00)],
                ),
              ),
              aboveBarData: BarAreaData(
                show: true,
                applyCutOffY: true,
                cutOffY: 0,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [scheme.primary.withValues(alpha: 0.22), scheme.primary.withValues(alpha: 0.00)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Set<int> _buildBottomLabelIndices(int length) {
    if (length <= 1) return {0};
    if (length <= 4) return {for (int i = 0; i < length; i++) i};

    final int last = length - 1;
    final int i1 = (last / 3).round();
    final int i2 = (2 * last / 3).round();

    return {0, i1.clamp(0, last), i2.clamp(0, last), last};
  }

  Color _sentimentColor(double score, ColorScheme scheme) {
    if (score > 0.3) return scheme.primary;
    if (score < -0.3) return scheme.error;
    return scheme.onSurfaceVariant;
  }
}
