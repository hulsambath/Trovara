import 'package:flutter/material.dart';
import 'package:notemyminds/models/activity_tag.dart';

/// A widget that displays activity tags as selectable ChoiceChips
class ActivityChips extends StatelessWidget {
  final List<String> selectedActivityIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final bool isCompact;

  const ActivityChips({
    super.key,
    required this.selectedActivityIds,
    required this.onSelectionChanged,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!isCompact) ...[
        Text(
          'Activity',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ActivityTags.all.map((activityTag) {
          final isSelected = selectedActivityIds.contains(activityTag.id);
          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activityTag.icon,
                  size: 16,
                  color: isSelected ? activityTag.color : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(activityTag.label),
              ],
            ),
            selected: isSelected,
            onSelected: (selected) => _handleActivitySelection(activityTag, selected),
            selectedColor: activityTag.color.withValues(alpha: 0.2),
            checkmarkColor: activityTag.color,
            side: BorderSide(
              color: isSelected ? activityTag.color : Theme.of(context).colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isSelected ? activityTag.color : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
    ],
  );

  void _handleActivitySelection(ActivityTag activityTag, bool selected) {
    final newSelection = List<String>.from(selectedActivityIds);

    if (selected) {
      if (!newSelection.contains(activityTag.id)) {
        newSelection.add(activityTag.id);
      }
    } else {
      newSelection.remove(activityTag.id);
    }

    onSelectionChanged(newSelection);
  }
}

/// Compact version of activity chips for use in note cards or lists
class CompactActivityChips extends StatelessWidget {
  final List<String> selectedActivityIds;
  final int maxDisplay;

  const CompactActivityChips({super.key, required this.selectedActivityIds, this.maxDisplay = 3});

  @override
  Widget build(BuildContext context) {
    if (selectedActivityIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayedActivities = selectedActivityIds.take(maxDisplay).toList();
    final remainingCount = selectedActivityIds.length - maxDisplay;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...displayedActivities.map((activityId) {
          final activityTag = ActivityTags.getById(activityId);
          if (activityTag == null) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: activityTag.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(activityTag.icon, size: 12, color: activityTag.color),
                const SizedBox(width: 2),
                Text(
                  activityTag.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 10, color: activityTag.color, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$remainingCount',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
