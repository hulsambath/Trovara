part of 'insights_view.dart';

class _InsightsContent extends StatelessWidget {
  const _InsightsContent(this.viewModel);

  final InsightsViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Insights'), surfaceTintColor: Colors.transparent),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Heatmap of Notes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              HeatmapWithAxes(viewModel: viewModel),
              const SizedBox(height: 8),
              const Legend(),
            ],
          ),
        ),
      ),
    ),
  );
}
