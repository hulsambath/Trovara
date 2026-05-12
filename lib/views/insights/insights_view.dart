import 'package:flutter/material.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/views/insights/widgets/chart_empty_state.dart';
import 'package:trovara/views/insights/widgets/chart_skeleton.dart';
import 'package:trovara/views/insights/widgets/heatmap_with_axes.dart';
import 'package:trovara/views/insights/widgets/legend.dart';
import 'package:trovara/views/insights/widgets/sentiment_trend_chart.dart';
import 'package:trovara/views/insights/widgets/tag_display_helper.dart';
import 'package:trovara/views/insights/widgets/tag_frequency_chart.dart';
import 'package:trovara/widgets/trovara_card.dart';

import 'insights_view_model.dart';

part 'insights_content.dart';

class InsightsView extends StatelessWidget {
  const InsightsView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<InsightsViewModel>(
    create: (context) => InsightsViewModel(),
    root: true,
    builder: (context, viewModel, child) => _InsightsContent(viewModel),
  );
}
