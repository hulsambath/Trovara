part of '../search_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Filter panel
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  const _FilterPanel(this.vm);

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tagCount = vm.activeTagFilterCount;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Toggle row ────────────────────────────────────────────────────
          InkWell(
            onTap: vm.toggleFiltersExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(LucideIcons.funnel, size: 18, color: colors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  if (tagCount > 0 || vm.showFavoritesOnly) ...[
                    const SizedBox(width: 6),
                    _CountBadge(tagCount + (vm.showFavoritesOnly ? 1 : 0)),
                  ],
                  const Spacer(),
                  if (vm.hasActiveFilters)
                    TextButton(
                      onPressed: vm.clearAllFilters,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: colors.error,
                      ),
                      child: const Text('Clear all'),
                    ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: vm.filtersExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(LucideIcons.chevronDown, size: 20, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded content ──────────────────────────────────────────────
          if (vm.filtersExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _QuickFilterChip(
                    label: 'Favorites',
                    icon: LucideIcons.heart,
                    selected: vm.showFavoritesOnly,
                    onTap: vm.toggleFavoritesOnly,
                    activeColor: Colors.red,
                  ),
                ],
              ),
            ),
            _TagCategory(
              label: 'Mood',
              icon: LucideIcons.smile,
              children: MoodTags.all.map((t) => _MoodFilterChip(tag: t, vm: vm)).toList(),
            ),
            _TagCategory(
              label: 'Activity',
              icon: LucideIcons.shapes,
              children: ActivityTags.all.map((t) => _ActivityFilterChip(tag: t, vm: vm)).toList(),
            ),
            _TagCategory(
              label: 'Time',
              icon: LucideIcons.clock,
              children: TimeTags.all.map((t) => _TimeFilterChip(tag: t, vm: vm)).toList(),
            ),
            _TagCategory(
              label: 'Growth',
              icon: LucideIcons.trendingUp,
              children: PersonalGrowthTags.all.map((t) => _GrowthFilterChip(tag: t, vm: vm)).toList(),
            ),
            if (vm.availableCustomTags.isNotEmpty)
              _TagCategory(
                label: 'Custom',
                icon: LucideIcons.tag,
                children: vm.availableCustomTags.map((t) => _CustomFilterChip(tag: t, vm: vm)).toList(),
              ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tag category row (horizontal scroll)
// ─────────────────────────────────────────────────────────────────────────────

class _TagCategory extends StatelessWidget {
  const _TagCategory({required this.label, required this.icon, required this.children});

  final String label;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
            child: Row(
              children: [
                Icon(icon, size: 14, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: children.map((c) => Padding(padding: const EdgeInsets.only(right: 6), child: c)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
