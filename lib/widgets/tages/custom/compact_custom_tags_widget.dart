import 'package:flutter/material.dart';
import 'package:trovara/models/custom_tag.dart';

/// Compact display of custom tags for note cards.
/// Supports both string-based and CustomTag-object modes.
class CompactCustomTagsWidget extends StatelessWidget {
  final List<String>? selectedTags;
  final List<CustomTag>? selectedCustomTags;
  final int maxDisplay;

  const CompactCustomTagsWidget({super.key, this.selectedTags, this.selectedCustomTags, this.maxDisplay = 3})
    : assert(
        selectedTags != null || selectedCustomTags != null,
        'Either selectedTags OR selectedCustomTags must be provided',
      );

  bool get _isCustomTagMode => selectedCustomTags != null;

  @override
  Widget build(BuildContext context) {
    final tags = _isCustomTagMode ? selectedCustomTags! : selectedTags!;
    if (tags.isEmpty) return const SizedBox.shrink();

    final displayedTags = tags.take(maxDisplay).toList();
    final remainingCount = tags.length - maxDisplay;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...displayedTags.map((tag) => _buildCompactChip(context, tag)),
        if (remainingCount > 0) _buildMoreChip(context, remainingCount),
      ],
    );
  }

  Widget _buildCompactChip(BuildContext context, dynamic tag) => _isCustomTagMode
      ? _buildCustomTagCompactChip(context, tag as CustomTag)
      : _buildStringCompactChip(context, tag as String);

  Widget _buildStringCompactChip(BuildContext context, String tag) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Text(
      tag,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSecondaryContainer,
        fontSize: 11,
      ),
    ),
  );

  Widget _buildCustomTagCompactChip(BuildContext context, CustomTag tag) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: tag.displayColor.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: tag.displayColor.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Text(
      tag.name,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: tag.displayColor,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _buildMoreChip(BuildContext context, int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Text(
      '+$count',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
