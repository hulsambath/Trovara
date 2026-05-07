part of 'insights_view.dart';

class _InsightsContent extends StatelessWidget {
  const _InsightsContent(this.viewModel);

  final InsightsViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Insights'), surfaceTintColor: Colors.transparent),
    body: RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (viewModel.errorMessage != null) ...[
            _ErrorBanner(message: viewModel.errorMessage!, onRetry: viewModel.refresh),
            const SizedBox(height: 16),
          ],
          _SectionCard(
            title: 'Notes Activity',
            subtitle: 'Year-specific heatmap',
            child: viewModel.isLoading
                ? const HeatmapSkeleton()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      HeatmapWithAxes(viewModel: viewModel),
                      const SizedBox(height: 8),
                      const Legend(),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Mood Trend',
            subtitle: 'Weekly sentiment (all time)',
            child: viewModel.isLoading ? const LineSkeleton() : SentimentTrendChart(data: viewModel.weeklySentiment),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Tag Usage',
            subtitle: 'Top tags used (all time)',
            child: viewModel.isLoading ? const ChartSkeleton() : _TagUsageSection(viewModel: viewModel),
          ),
          const SizedBox(height: kBottomNavigationBarHeight),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry', style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _TagUsageSection extends StatelessWidget {
  const _TagUsageSection({required this.viewModel});

  final InsightsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.hasTagData) {
      return const ChartEmptyState(message: 'No tags used yet');
    }

    final List<String> visibleCategories = viewModel.tagCategories
        .where((c) => (viewModel.tagFrequencyByCategory[c] ?? const {}).isNotEmpty)
        .toList();

    if (visibleCategories.isEmpty) {
      return const ChartEmptyState(message: 'No tags used yet');
    }

    final String selectedCategory = viewModel.tagCategories[viewModel.selectedTagCategoryIndex];

    String displayCategory = selectedCategory;
    Map<String, int> displayData = viewModel.tagFrequencyByCategory[displayCategory] ?? const {};
    if (displayData.isEmpty) {
      displayCategory = visibleCategories.first;
      displayData = viewModel.tagFrequencyByCategory[displayCategory] ?? const {};
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: visibleCategories.map((category) {
              final int index = viewModel.tagCategories.indexOf(category);
              final bool selected = viewModel.selectedTagCategoryIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(TagDisplayHelper.categoryLabel(category)),
                  selected: selected,
                  onSelected: (_) => viewModel.selectTagCategory(index),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        TagFrequencyChart(data: displayData, category: displayCategory),
      ],
    );
  }
}
