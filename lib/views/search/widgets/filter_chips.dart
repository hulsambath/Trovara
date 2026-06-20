part of '../search_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Filter chips
// ─────────────────────────────────────────────────────────────────────────────

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.activeColor,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effective = selected ? activeColor : colors.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: 0.15) : colors.surfaceContainerHighest,
          border: Border.all(color: selected ? activeColor : colors.outlineVariant, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: effective),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: effective,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BaseTagChip extends StatelessWidget {
  const _BaseTagChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.leadingIcon,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : colors.surfaceContainerHighest,
          border: Border.all(color: selected ? color : colors.outlineVariant, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 13, color: selected ? color : colors.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? color : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodFilterChip extends StatelessWidget {
  const _MoodFilterChip({required this.tag, required this.vm});

  final MoodTag tag;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) => _BaseTagChip(
    label: '${tag.emoji} ${tag.label}',
    selected: vm.selectedMoodIds.contains(tag.id),
    color: tag.color,
    onTap: () => vm.toggleMoodTag(tag.id),
  );
}

class _ActivityFilterChip extends StatelessWidget {
  const _ActivityFilterChip({required this.tag, required this.vm});

  final ActivityTag tag;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) => _BaseTagChip(
    label: tag.label,
    selected: vm.selectedActivityIds.contains(tag.id),
    color: tag.color,
    leadingIcon: tag.icon,
    onTap: () => vm.toggleActivityTag(tag.id),
  );
}

class _TimeFilterChip extends StatelessWidget {
  const _TimeFilterChip({required this.tag, required this.vm});

  final TimeTag tag;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) => _BaseTagChip(
    label: tag.label,
    selected: vm.selectedTimeIds.contains(tag.id),
    color: tag.color,
    leadingIcon: tag.icon,
    onTap: () => vm.toggleTimeTag(tag.id),
  );
}

class _GrowthFilterChip extends StatelessWidget {
  const _GrowthFilterChip({required this.tag, required this.vm});

  final PersonalGrowthTag tag;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) => _BaseTagChip(
    label: tag.label,
    selected: vm.selectedGrowthIds.contains(tag.id),
    color: tag.color,
    leadingIcon: tag.icon,
    onTap: () => vm.toggleGrowthTag(tag.id),
  );
}

class _CustomFilterChip extends StatelessWidget {
  const _CustomFilterChip({required this.tag, required this.vm});

  final CustomTag tag;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) => _BaseTagChip(
    label: tag.name,
    selected: vm.selectedCustomTagIds.contains(tag.id),
    color: tag.displayColor,
    onTap: () => vm.toggleCustomTag(tag.id),
  );
}
