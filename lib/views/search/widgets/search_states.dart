part of '../search_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Results header
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader(this.vm);

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = vm.resultCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            count == 0
                ? 'No notes found'
                : count == 1
                ? '1 note'
                : '$count notes',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          if (vm.hasActiveFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Filtered',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.onPrimaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.vm});

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasFilters = vm.hasActiveFilters;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? LucideIcons.funnelX : LucideIcons.search,
              size: 56,
              color: colors.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No notes match these filters' : 'Start typing to search',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: vm.clearAllFilters,
                icon: const Icon(LucideIcons.x, size: 16),
                label: const Text('Clear all filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(10)),
      child: Text(
        '$count',
        style: TextStyle(color: colors.onPrimary, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
