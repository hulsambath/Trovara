import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trovara/constants/device_constants.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/custom_tag_service.dart';
import 'package:trovara/models/activity_tag.dart';
import 'package:trovara/models/custom_tag.dart';
import 'package:trovara/models/mood_tag.dart';
import 'package:trovara/models/personal_growth_tag.dart';
import 'package:trovara/models/time_tag.dart';
import 'package:trovara/widgets/tages/custom/custom_tags_widget.dart';

/// Unified icon button that combines all tag types (activity, mood, time, personal growth, custom)
/// into a single button to minimize app bar space
class UnifiedTagsIconButton extends StatelessWidget {
  final List<String> selectedActivityIds;
  final List<String> selectedMoodIds;
  final List<String> selectedTimeIds;
  final List<String> selectedPersonalGrowthIds;
  final List<String> selectedCustomTags;
  final ValueChanged<List<String>> onActivityChanged;
  final ValueChanged<List<String>> onMoodChanged;
  final ValueChanged<List<String>> onTimeChanged;
  final ValueChanged<List<String>> onPersonalGrowthChanged;
  final ValueChanged<List<String>> onCustomTagsChanged;
  final DateTime? creationTime;
  final bool showTimeSuggestions;

  const UnifiedTagsIconButton({
    super.key,
    required this.selectedActivityIds,
    required this.selectedMoodIds,
    required this.selectedTimeIds,
    required this.selectedPersonalGrowthIds,
    required this.selectedCustomTags,
    required this.onActivityChanged,
    required this.onMoodChanged,
    required this.onTimeChanged,
    required this.onPersonalGrowthChanged,
    required this.onCustomTagsChanged,
    this.creationTime,
    this.showTimeSuggestions = true,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    icon: _buildUnifiedIcon(context),
    onPressed: () => _showUnifiedTagsDialog(context),
    tooltip: 'Tags (${_getTotalTagCount()})',
  );

  Widget _buildUnifiedIcon(BuildContext context) {
    final totalCount = _getTotalTagCount();

    if (totalCount == 0) {
      return Icon(LucideIcons.tag, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }

    // Show a combined icon with total count
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(LucideIcons.tags, color: Theme.of(context).colorScheme.primary),
        ),
        if (totalCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$totalCount',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  int _getTotalTagCount() =>
      selectedActivityIds.length +
      selectedMoodIds.length +
      selectedTimeIds.length +
      selectedPersonalGrowthIds.length +
      selectedCustomTags.length;

  void _showUnifiedTagsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _UnifiedTagsDialog(
        selectedActivityIds: selectedActivityIds,
        selectedMoodIds: selectedMoodIds,
        selectedTimeIds: selectedTimeIds,
        selectedPersonalGrowthIds: selectedPersonalGrowthIds,
        selectedCustomTags: selectedCustomTags,
        onActivityChanged: onActivityChanged,
        onMoodChanged: onMoodChanged,
        onTimeChanged: onTimeChanged,
        onPersonalGrowthChanged: onPersonalGrowthChanged,
        onCustomTagsChanged: onCustomTagsChanged,
        creationTime: creationTime,
        showTimeSuggestions: showTimeSuggestions,
      ),
    );
  }
}

/// Unified dialog with tabs for all tag types
class _UnifiedTagsDialog extends StatefulWidget {
  final List<String> selectedActivityIds;
  final List<String> selectedMoodIds;
  final List<String> selectedTimeIds;
  final List<String> selectedPersonalGrowthIds;
  final List<String> selectedCustomTags;
  final ValueChanged<List<String>> onActivityChanged;
  final ValueChanged<List<String>> onMoodChanged;
  final ValueChanged<List<String>> onTimeChanged;
  final ValueChanged<List<String>> onPersonalGrowthChanged;
  final ValueChanged<List<String>> onCustomTagsChanged;
  final DateTime? creationTime;
  final bool showTimeSuggestions;

  const _UnifiedTagsDialog({
    required this.selectedActivityIds,
    required this.selectedMoodIds,
    required this.selectedTimeIds,
    required this.selectedPersonalGrowthIds,
    required this.selectedCustomTags,
    required this.onActivityChanged,
    required this.onMoodChanged,
    required this.onTimeChanged,
    required this.onPersonalGrowthChanged,
    required this.onCustomTagsChanged,
    this.creationTime,
    this.showTimeSuggestions = true,
  });

  @override
  State<_UnifiedTagsDialog> createState() => _UnifiedTagsDialogState();
}

enum _TagCategory { activity, mood, time, growth, custom }

class _UnifiedTagsDialogState extends State<_UnifiedTagsDialog> {
  late List<String> _selectedActivityIds;
  late List<String> _selectedMoodIds;
  late List<String> _selectedTimeIds;
  late List<String> _selectedPersonalGrowthIds;
  late List<CustomTag> _selectedCustomTags;
  late List<String> _suggestedTimeIds;
  _TagCategory _selectedCategory = _TagCategory.activity;

  final CustomTagService _customTagService = ServiceLocator().customTagService;

  @override
  void initState() {
    super.initState();
    _selectedActivityIds = List.from(widget.selectedActivityIds);
    _selectedMoodIds = List.from(widget.selectedMoodIds);
    _selectedTimeIds = List.from(widget.selectedTimeIds);
    _selectedPersonalGrowthIds = List.from(widget.selectedPersonalGrowthIds);
    _selectedCustomTags = _convertStringTagsToCustomTags(widget.selectedCustomTags);
    _suggestedTimeIds = TimeTags.getTimeBasedSuggestions(widget.creationTime);

    // Auto-select time suggestions if no time tags are selected and suggestions are enabled
    if (widget.showTimeSuggestions && _selectedTimeIds.isEmpty) {
      _selectedTimeIds = List.from(_suggestedTimeIds);
    }
  }

  // No TabController anymore

  List<CustomTag> _convertStringTagsToCustomTags(List<String> stringTags) {
    final List<CustomTag> customTags = [];
    final availableTags = _customTagService.getAllCustomTags();

    for (final tagName in stringTags) {
      final existingTag = availableTags.firstWhere(
        (tag) => tag.name.toLowerCase() == tagName.toLowerCase(),
        orElse: () => CustomTag.create(tagName),
      );
      customTags.add(existingTag);
    }

    return customTags;
  }

  void _updateCustomTags(List<CustomTag> newCustomTags) {
    setState(() {
      _selectedCustomTags = newCustomTags;
    });
  }

  List<CustomTag> getAvailableCustomTags() => _customTagService.getAllCustomTags();

  void _saveAndClose() {
    widget.onActivityChanged(_selectedActivityIds);
    widget.onMoodChanged(_selectedMoodIds);
    widget.onTimeChanged(_selectedTimeIds);
    widget.onPersonalGrowthChanged(_selectedPersonalGrowthIds);

    // Convert CustomTag objects back to strings for the callback
    final customTagNames = _selectedCustomTags.map((tag) => tag.name).toList();
    widget.onCustomTagsChanged(customTagNames);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Icon(LucideIcons.tags), SizedBox(width: 8), Text('Tags')],
    ),
    content: SizedBox(
      width: double.maxFinite,
      height: DeviceConstants.screenHeight(context) * 0.6,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 160, child: _buildCategoryList(context)),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(padding: const EdgeInsets.only(left: 16), child: _buildRightPane()),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(onPressed: _saveAndClose, child: const Text('Save')),
    ],
  );

  Widget _buildCategoryList(BuildContext context) => ListView(
    children: [
      _buildCategoryTile(
        context,
        icon: LucideIcons.shapes,
        label: 'Activity',
        count: _selectedActivityIds.length,
        category: _TagCategory.activity,
      ),
      _buildCategoryTile(
        context,
        icon: LucideIcons.smile,
        label: 'Mood',
        count: _selectedMoodIds.length,
        category: _TagCategory.mood,
      ),
      _buildCategoryTile(
        context,
        icon: LucideIcons.clock,
        label: 'Time',
        count: _selectedTimeIds.length,
        category: _TagCategory.time,
      ),
      _buildCategoryTile(
        context,
        icon: LucideIcons.trendingUp,
        label: 'Growth',
        count: _selectedPersonalGrowthIds.length,
        category: _TagCategory.growth,
      ),
      _buildCategoryTile(
        context,
        icon: LucideIcons.tag,
        label: 'Custom',
        count: _selectedCustomTags.length,
        category: _TagCategory.custom,
      ),
    ],
  );

  Widget _buildCategoryTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    required _TagCategory category,
  }) {
    final bool selected = _selectedCategory == category;
    return ListTile(
      selected: selected,
      leading: Icon(
        icon,
        color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Expanded(child: Text(label)),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () => setState(() => _selectedCategory = category),
    );
  }

  Widget _buildRightPane() {
    switch (_selectedCategory) {
      case _TagCategory.activity:
        return _buildActivityTab();
      case _TagCategory.mood:
        return _buildMoodTab();
      case _TagCategory.time:
        return _buildTimeTab();
      case _TagCategory.growth:
        return _buildPersonalGrowthTab();
      case _TagCategory.custom:
        return _buildCustomTagsTab();
    }
  }

  Widget _buildActivityTab() => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.start,
    crossAxisAlignment: WrapCrossAlignment.start,
    children: ActivityTags.all.map((activityTag) {
      final isSelected = _selectedActivityIds.contains(activityTag.id);
      return _buildActivityChip(activityTag, isSelected);
    }).toList(),
  );

  Widget _buildMoodTab() => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.start,
    crossAxisAlignment: WrapCrossAlignment.start,
    children: MoodTags.all.map((moodTag) {
      final isSelected = _selectedMoodIds.contains(moodTag.id);
      return _buildMoodChip(moodTag, isSelected);
    }).toList(),
  );

  Widget _buildTimeTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.showTimeSuggestions && _suggestedTimeIds.isNotEmpty) ...[
        _buildSuggestedTimeSection(),
        const SizedBox(height: 16),
      ],
      Expanded(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: TimeTags.all.map((timeTag) {
            final isSelected = _selectedTimeIds.contains(timeTag.id);
            final isSuggested = _suggestedTimeIds.contains(timeTag.id);

            // Hide suggested tags from the main list to avoid duplication
            if (widget.showTimeSuggestions && isSuggested) {
              return const SizedBox.shrink();
            }

            return _buildTimeChip(timeTag, isSelected, false);
          }).toList(),
        ),
      ),
    ],
  );

  Widget _buildPersonalGrowthTab() => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.start,
    crossAxisAlignment: WrapCrossAlignment.start,
    children: PersonalGrowthTags.all.map((personalGrowthTag) {
      final isSelected = _selectedPersonalGrowthIds.contains(personalGrowthTag.id);
      return _buildPersonalGrowthChip(personalGrowthTag, isSelected);
    }).toList(),
  );

  Widget _buildCustomTagsTab() => CustomTagsWidget(
    selectedCustomTags: _selectedCustomTags,
    onCustomTagsChanged: _updateCustomTags,
    availableTags: getAvailableCustomTags(),
    hintText: 'Type a tag and press Enter or click +',
    maxTags: 20,
  );

  Widget _buildSuggestedTimeSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(LucideIcons.sparkles, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            'Suggested',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: _suggestedTimeIds.map((timeId) {
          final timeTag = TimeTags.getById(timeId);
          if (timeTag == null) return const SizedBox.shrink();

          final isSelected = _selectedTimeIds.contains(timeId);
          return _buildTimeChip(timeTag, isSelected, true);
        }).toList(),
      ),
    ],
  );

  // Individual chip builders
  Widget _buildActivityChip(ActivityTag activityTag, bool isSelected) => _buildChip(
    icon: Icon(
      activityTag.icon,
      size: 16,
      color: isSelected ? activityTag.color : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    label: activityTag.label,
    isSelected: isSelected,
    color: activityTag.color,
    onTap: () => _handleActivitySelection(activityTag),
  );

  Widget _buildMoodChip(MoodTag moodTag, bool isSelected) => _buildChip(
    icon: Text(moodTag.emoji, style: const TextStyle(fontSize: 16)),
    label: moodTag.label,
    isSelected: isSelected,
    color: moodTag.color,
    onTap: () => _handleMoodSelection(moodTag),
  );

  Widget _buildTimeChip(TimeTag timeTag, bool isSelected, bool isSuggested) => _buildChip(
    icon: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          timeTag.icon,
          size: 16,
          color: isSelected ? timeTag.color : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        if (isSuggested && !isSelected) ...[
          const SizedBox(width: 4),
          Icon(LucideIcons.sparkles, size: 12, color: Theme.of(context).colorScheme.primary),
        ],
      ],
    ),
    label: timeTag.label,
    isSelected: isSelected,
    color: timeTag.color,
    onTap: () => _handleTimeSelection(timeTag),
  );

  Widget _buildPersonalGrowthChip(PersonalGrowthTag personalGrowthTag, bool isSelected) => _buildChip(
    icon: Icon(
      personalGrowthTag.icon,
      size: 16,
      color: isSelected ? personalGrowthTag.color : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    label: personalGrowthTag.label,
    isSelected: isSelected,
    color: personalGrowthTag.color,
    onTap: () => _handlePersonalGrowthSelection(personalGrowthTag),
  );

  Widget _buildChip({
    required Widget icon,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
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

  // Selection handlers
  void _handleActivitySelection(ActivityTag activityTag) {
    setState(() {
      if (_selectedActivityIds.contains(activityTag.id)) {
        _selectedActivityIds.remove(activityTag.id);
      } else {
        _selectedActivityIds.add(activityTag.id);
      }
    });
  }

  void _handleMoodSelection(MoodTag moodTag) {
    setState(() {
      if (_selectedMoodIds.contains(moodTag.id)) {
        _selectedMoodIds.remove(moodTag.id);
      } else {
        _selectedMoodIds.add(moodTag.id);
      }
    });
  }

  void _handleTimeSelection(TimeTag timeTag) {
    setState(() {
      if (_selectedTimeIds.contains(timeTag.id)) {
        _selectedTimeIds.remove(timeTag.id);
      } else {
        _selectedTimeIds.add(timeTag.id);
      }
    });
  }

  void _handlePersonalGrowthSelection(PersonalGrowthTag personalGrowthTag) {
    setState(() {
      if (_selectedPersonalGrowthIds.contains(personalGrowthTag.id)) {
        _selectedPersonalGrowthIds.remove(personalGrowthTag.id);
      } else {
        _selectedPersonalGrowthIds.add(personalGrowthTag.id);
      }
    });
  }
}
