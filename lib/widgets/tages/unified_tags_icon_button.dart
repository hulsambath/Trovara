import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trovara/constants/device_constants.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/notes/custom_tag_service.dart';
import 'package:trovara/models/activity_tag.dart';
import 'package:trovara/models/custom_tag.dart';
import 'package:trovara/models/mood_tag.dart';
import 'package:trovara/models/personal_growth_tag.dart';
import 'package:trovara/models/time_tag.dart';
import 'package:trovara/widgets/tages/custom/custom_tags_widget.dart';

part 'widgets/unified_tags_dialog.dart';
part 'widgets/unified_tag_chip.dart';
part 'widgets/unified_tag_tabs.dart';

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
