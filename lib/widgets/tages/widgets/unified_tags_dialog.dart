part of '../unified_tags_icon_button.dart';

enum _TagCategory { activity, mood, time, growth, custom }

/// Unified dialog with a category sidebar and a per-category selection pane.
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

    // Auto-select time suggestions if no time tags are selected and suggestions are enabled.
    if (widget.showTimeSuggestions && _selectedTimeIds.isEmpty) {
      _selectedTimeIds = List.from(_suggestedTimeIds);
    }
  }

  List<CustomTag> _convertStringTagsToCustomTags(List<String> stringTags) {
    final availableTags = _customTagService.getAllCustomTags();
    return stringTags
        .map(
          (tagName) => availableTags.firstWhere(
            (tag) => tag.name.toLowerCase() == tagName.toLowerCase(),
            orElse: () => CustomTag.create(tagName),
          ),
        )
        .toList();
  }

  void _updateCustomTags(List<CustomTag> newCustomTags) => setState(() => _selectedCustomTags = newCustomTags);

  void _toggle(List<String> list, String id) =>
      setState(() => list.contains(id) ? list.remove(id) : list.add(id));

  void _saveAndClose() {
    widget.onActivityChanged(_selectedActivityIds);
    widget.onMoodChanged(_selectedMoodIds);
    widget.onTimeChanged(_selectedTimeIds);
    widget.onPersonalGrowthChanged(_selectedPersonalGrowthIds);
    widget.onCustomTagsChanged(_selectedCustomTags.map((tag) => tag.name).toList());
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
          SizedBox(
            width: 160,
            child: _CategorySidebar(
              selected: _selectedCategory,
              activityCount: _selectedActivityIds.length,
              moodCount: _selectedMoodIds.length,
              timeCount: _selectedTimeIds.length,
              growthCount: _selectedPersonalGrowthIds.length,
              customCount: _selectedCustomTags.length,
              onSelect: (category) => setState(() => _selectedCategory = category),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _TagTabBody(
                category: _selectedCategory,
                selectedActivityIds: _selectedActivityIds,
                selectedMoodIds: _selectedMoodIds,
                selectedTimeIds: _selectedTimeIds,
                selectedPersonalGrowthIds: _selectedPersonalGrowthIds,
                suggestedTimeIds: _suggestedTimeIds,
                showTimeSuggestions: widget.showTimeSuggestions,
                selectedCustomTags: _selectedCustomTags,
                availableCustomTags: _customTagService.getAllCustomTags(),
                onToggleActivity: (id) => _toggle(_selectedActivityIds, id),
                onToggleMood: (id) => _toggle(_selectedMoodIds, id),
                onToggleTime: (id) => _toggle(_selectedTimeIds, id),
                onToggleGrowth: (id) => _toggle(_selectedPersonalGrowthIds, id),
                onCustomTagsChanged: _updateCustomTags,
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(onPressed: _saveAndClose, child: const Text('Save')),
    ],
  );
}
