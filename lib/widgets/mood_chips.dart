import 'package:flutter/material.dart';
import 'package:noteminds/models/mood_tag.dart';

/// A widget that displays mood tags as selectable chips
class MoodChips extends StatelessWidget {
  final List<String> selectedMoodIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final bool isCompact;

  const MoodChips({super.key, required this.selectedMoodIds, required this.onSelectionChanged, this.isCompact = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!isCompact) ...[
        Text(
          'Mood',
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
        children: MoodTags.all.map((moodTag) {
          final isSelected = selectedMoodIds.contains(moodTag.id);
          return _MoodChip(moodTag: moodTag, isSelected: isSelected, onTap: () => _handleMoodSelection(moodTag));
        }).toList(),
      ),
    ],
  );

  void _handleMoodSelection(MoodTag moodTag) {
    final newSelection = List<String>.from(selectedMoodIds);

    if (newSelection.contains(moodTag.id)) {
      newSelection.remove(moodTag.id);
    } else {
      newSelection.add(moodTag.id);
    }

    onSelectionChanged(newSelection);
  }
}

/// Individual mood chip widget
class _MoodChip extends StatelessWidget {
  final MoodTag moodTag;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodChip({required this.moodTag, required this.isSelected, required this.onTap});

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
          color: isSelected ? moodTag.color.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest,
          border: Border.all(color: isSelected ? moodTag.color : colorScheme.outlineVariant, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(moodTag.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              moodTag.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected ? moodTag.color : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact version of mood chips for use in note cards or lists
class CompactMoodChips extends StatelessWidget {
  final List<String> selectedMoodIds;
  final int maxDisplay;

  const CompactMoodChips({super.key, required this.selectedMoodIds, this.maxDisplay = 3});

  @override
  Widget build(BuildContext context) {
    if (selectedMoodIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayedMoods = selectedMoodIds.take(maxDisplay).toList();
    final remainingCount = selectedMoodIds.length - maxDisplay;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...displayedMoods.map((moodId) {
          final moodTag = MoodTags.getById(moodId);
          if (moodTag == null) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: moodTag.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(moodTag.emoji, style: const TextStyle(fontSize: 12)),
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
