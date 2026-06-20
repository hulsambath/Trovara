part of '../unified_tags_icon_button.dart';

/// Right-hand selection pane for the currently selected [_TagCategory].
class _TagTabBody extends StatelessWidget {
  const _TagTabBody({
    required this.category,
    required this.selectedActivityIds,
    required this.selectedMoodIds,
    required this.selectedTimeIds,
    required this.selectedPersonalGrowthIds,
    required this.suggestedTimeIds,
    required this.showTimeSuggestions,
    required this.selectedCustomTags,
    required this.availableCustomTags,
    required this.onToggleActivity,
    required this.onToggleMood,
    required this.onToggleTime,
    required this.onToggleGrowth,
    required this.onCustomTagsChanged,
  });

  final _TagCategory category;
  final List<String> selectedActivityIds;
  final List<String> selectedMoodIds;
  final List<String> selectedTimeIds;
  final List<String> selectedPersonalGrowthIds;
  final List<String> suggestedTimeIds;
  final bool showTimeSuggestions;
  final List<CustomTag> selectedCustomTags;
  final List<CustomTag> availableCustomTags;
  final ValueChanged<String> onToggleActivity;
  final ValueChanged<String> onToggleMood;
  final ValueChanged<String> onToggleTime;
  final ValueChanged<String> onToggleGrowth;
  final ValueChanged<List<CustomTag>> onCustomTagsChanged;

  static const _wrapSpacing = 8.0;

  @override
  Widget build(BuildContext context) => switch (category) {
    _TagCategory.activity => _activityTab(context),
    _TagCategory.mood => _moodTab(context),
    _TagCategory.time => _timeTab(context),
    _TagCategory.growth => _growthTab(context),
    _TagCategory.custom => _customTab(),
  };

  Widget _wrap(List<Widget> children) => Wrap(
    spacing: _wrapSpacing,
    runSpacing: _wrapSpacing,
    alignment: WrapAlignment.start,
    crossAxisAlignment: WrapCrossAlignment.start,
    children: children,
  );

  Widget _activityTab(BuildContext context) => _wrap(
    ActivityTags.all.map((tag) {
      final isSelected = selectedActivityIds.contains(tag.id);
      return _TagChip(
        icon: Icon(tag.icon, size: 16, color: isSelected ? tag.color : Theme.of(context).colorScheme.onSurfaceVariant),
        label: tag.label,
        isSelected: isSelected,
        color: tag.color,
        onTap: () => onToggleActivity(tag.id),
      );
    }).toList(),
  );

  Widget _moodTab(BuildContext context) => _wrap(
    MoodTags.all.map((tag) {
      final isSelected = selectedMoodIds.contains(tag.id);
      return _TagChip(
        icon: Text(tag.emoji, style: const TextStyle(fontSize: 16)),
        label: tag.label,
        isSelected: isSelected,
        color: tag.color,
        onTap: () => onToggleMood(tag.id),
      );
    }).toList(),
  );

  Widget _growthTab(BuildContext context) => _wrap(
    PersonalGrowthTags.all.map((tag) {
      final isSelected = selectedPersonalGrowthIds.contains(tag.id);
      return _TagChip(
        icon: Icon(tag.icon, size: 16, color: isSelected ? tag.color : Theme.of(context).colorScheme.onSurfaceVariant),
        label: tag.label,
        isSelected: isSelected,
        color: tag.color,
        onTap: () => onToggleGrowth(tag.id),
      );
    }).toList(),
  );

  Widget _customTab() => CustomTagsWidget(
    selectedCustomTags: selectedCustomTags,
    onCustomTagsChanged: onCustomTagsChanged,
    availableTags: availableCustomTags,
    hintText: 'Type a tag and press Enter or click +',
    maxTags: 20,
  );

  Widget _timeTab(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showTimeSuggestions && suggestedTimeIds.isNotEmpty) ...[
        _suggestedTimeSection(context),
        const SizedBox(height: 16),
      ],
      Expanded(
        child: _wrap(
          TimeTags.all.map((tag) {
            final isSelected = selectedTimeIds.contains(tag.id);
            final isSuggested = suggestedTimeIds.contains(tag.id);
            // Hide suggested tags from the main list to avoid duplication.
            if (showTimeSuggestions && isSuggested) return const SizedBox.shrink();
            return _timeChip(context, tag, isSelected, false);
          }).toList(),
        ),
      ),
    ],
  );

  Widget _suggestedTimeSection(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.sparkles, size: 16, color: colors.primary),
            const SizedBox(width: 4),
            Text(
              'Suggested',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _wrap(
          suggestedTimeIds.map((timeId) {
            final timeTag = TimeTags.getById(timeId);
            if (timeTag == null) return const SizedBox.shrink();
            return _timeChip(context, timeTag, selectedTimeIds.contains(timeId), true);
          }).toList(),
        ),
      ],
    );
  }

  Widget _timeChip(BuildContext context, TimeTag tag, bool isSelected, bool isSuggested) {
    final colors = Theme.of(context).colorScheme;
    return _TagChip(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 16, color: isSelected ? tag.color : colors.onSurfaceVariant),
          if (isSuggested && !isSelected) ...[
            const SizedBox(width: 4),
            Icon(LucideIcons.sparkles, size: 12, color: colors.primary),
          ],
        ],
      ),
      label: tag.label,
      isSelected: isSelected,
      color: tag.color,
      onTap: () => onToggleTime(tag.id),
    );
  }
}
