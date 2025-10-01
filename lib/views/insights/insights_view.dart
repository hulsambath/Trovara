import 'package:flutter/material.dart';
import 'package:noteminds/core/base/view_model_provider.dart';
import 'package:noteminds/views/insights/widgets/heatmap_with_axes.dart';
import 'package:noteminds/views/insights/widgets/legend.dart';

import 'insights_view_model.dart';

part 'insights_content.dart';

class InsightsView extends StatelessWidget {
  const InsightsView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<InsightsViewModel>(
    create: (context) => InsightsViewModel(),
    builder: (context, viewModel, child) => _InsightsContent(viewModel),
  );
}
