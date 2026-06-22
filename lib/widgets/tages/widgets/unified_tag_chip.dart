part of '../unified_tags_icon_button.dart';

/// Left-hand category list inside [_UnifiedTagsDialog].
class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({
    required this.selected,
    required this.activityCount,
    required this.moodCount,
    required this.timeCount,
    required this.growthCount,
    required this.customCount,
    required this.onSelect,
  });

  final _TagCategory selected;
  final int activityCount;
  final int moodCount;
  final int timeCount;
  final int growthCount;
  final int customCount;
  final ValueChanged<_TagCategory> onSelect;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      _tile(context, LucideIcons.shapes, 'Activity', activityCount, _TagCategory.activity),
      _tile(context, LucideIcons.smile, 'Mood', moodCount, _TagCategory.mood),
      _tile(context, LucideIcons.clock, 'Time', timeCount, _TagCategory.time),
      _tile(context, LucideIcons.trendingUp, 'Growth', growthCount, _TagCategory.growth),
      _tile(context, LucideIcons.tag, 'Custom', customCount, _TagCategory.custom),
    ],
  );

  Widget _tile(BuildContext context, IconData icon, String label, int count, _TagCategory category) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = selected == category;
    return ListTile(
      selected: isSelected,
      leading: Icon(icon, color: isSelected ? colors.primary : colors.onSurfaceVariant),
      title: Row(
        children: [
          Expanded(child: Text(label)),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(10)),
              child: Text(
                '$count',
                style: TextStyle(color: colors.onPrimary, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: () => onSelect(category),
    );
  }
}

/// Generic selectable tag chip used across all tag tabs.
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest,
          border: Border.all(color: isSelected ? color : colorScheme.outlineVariant, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected ? color : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
