import 'package:flutter/material.dart';
import 'package:notemyminds/models/personal_growth_tag.dart';

/// A widget that displays personal growth tags as selectable ChoiceChips in a horizontal scrollable list
class PersonalGrowthChips extends StatelessWidget {
  final List<String> selectedPersonalGrowthIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final bool isCompact;

  const PersonalGrowthChips({
    super.key,
    required this.selectedPersonalGrowthIds,
    required this.onSelectionChanged,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!isCompact) ...[
        Text(
          'Personal Growth',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
      ],
      SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: PersonalGrowthTags.all.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final personalGrowthTag = PersonalGrowthTags.all[index];
            final isSelected = selectedPersonalGrowthIds.contains(personalGrowthTag.id);

            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    personalGrowthTag.icon,
                    size: 16,
                    color: isSelected ? personalGrowthTag.color : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(personalGrowthTag.label),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) => _handlePersonalGrowthSelection(personalGrowthTag, selected),
              selectedColor: personalGrowthTag.color.withValues(alpha: 0.2),
              checkmarkColor: personalGrowthTag.color,
              side: BorderSide(
                color: isSelected ? personalGrowthTag.color : Theme.of(context).colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
              labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected ? personalGrowthTag.color : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          },
        ),
      ),
    ],
  );

  void _handlePersonalGrowthSelection(PersonalGrowthTag personalGrowthTag, bool selected) {
    final newSelection = List<String>.from(selectedPersonalGrowthIds);

    if (selected) {
      if (!newSelection.contains(personalGrowthTag.id)) {
        newSelection.add(personalGrowthTag.id);
      }
    } else {
      newSelection.remove(personalGrowthTag.id);
    }

    onSelectionChanged(newSelection);
  }
}

/// Compact version of personal growth chips for use in note cards or lists
class CompactPersonalGrowthChips extends StatelessWidget {
  final List<String> selectedPersonalGrowthIds;
  final int maxDisplay;

  const CompactPersonalGrowthChips({super.key, required this.selectedPersonalGrowthIds, this.maxDisplay = 3});

  @override
  Widget build(BuildContext context) {
    if (selectedPersonalGrowthIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayedPersonalGrowth = selectedPersonalGrowthIds.take(maxDisplay).toList();
    final remainingCount = selectedPersonalGrowthIds.length - maxDisplay;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...displayedPersonalGrowth.map((personalGrowthId) {
          final personalGrowthTag = PersonalGrowthTags.getById(personalGrowthId);
          if (personalGrowthTag == null) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: personalGrowthTag.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(personalGrowthTag.icon, size: 12, color: personalGrowthTag.color),
                const SizedBox(width: 2),
                Text(
                  personalGrowthTag.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: personalGrowthTag.color,
                    fontWeight: FontWeight.w500,
                  ),
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
