import 'package:flutter/material.dart';
import 'package:noteminds/models/mood_tag.dart';

/// A compact mood icon button for the app bar that shows selected moods
/// and opens a mood selection dialog when tapped
class MoodIconButton extends StatelessWidget {
  final List<String> selectedMoodIds;
  final ValueChanged<List<String>> onSelectionChanged;

  const MoodIconButton({super.key, required this.selectedMoodIds, required this.onSelectionChanged});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: _buildMoodIcon(context),
    onPressed: () => _showMoodSelectionDialog(context),
    tooltip: 'Select Mood',
  );

  Widget _buildMoodIcon(BuildContext context) {
    if (selectedMoodIds.isEmpty) {
      return Icon(Icons.mood_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }

    // Show the first selected mood's emoji
    final firstMood = MoodTags.getById(selectedMoodIds.first);
    if (firstMood != null) {
      return Stack(
        children: [
          Text(firstMood.emoji, style: const TextStyle(fontSize: 20)),
          if (selectedMoodIds.length > 1)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                child: Text(
                  '${selectedMoodIds.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    }

    return Icon(Icons.mood, color: Theme.of(context).colorScheme.primary);
  }

  void _showMoodSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          _MoodSelectionDialog(selectedMoodIds: selectedMoodIds, onSelectionChanged: onSelectionChanged),
    );
  }
}

/// Dialog for selecting mood tags
class _MoodSelectionDialog extends StatefulWidget {
  final List<String> selectedMoodIds;
  final ValueChanged<List<String>> onSelectionChanged;

  const _MoodSelectionDialog({required this.selectedMoodIds, required this.onSelectionChanged});

  @override
  State<_MoodSelectionDialog> createState() => _MoodSelectionDialogState();
}

class _MoodSelectionDialogState extends State<_MoodSelectionDialog> {
  late List<String> _selectedMoodIds;

  @override
  void initState() {
    super.initState();
    _selectedMoodIds = List.from(widget.selectedMoodIds);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Select Mood'),
    content: SizedBox(
      width: double.maxFinite,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: MoodTags.all.map((moodTag) {
          final isSelected = _selectedMoodIds.contains(moodTag.id);
          return _MoodChip(moodTag: moodTag, isSelected: isSelected, onTap: () => _handleMoodSelection(moodTag));
        }).toList(),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        onPressed: () {
          widget.onSelectionChanged(_selectedMoodIds);
          Navigator.of(context).pop();
        },
        child: const Text('Done'),
      ),
    ],
  );

  void _handleMoodSelection(MoodTag moodTag) {
    setState(() {
      if (_selectedMoodIds.contains(moodTag.id)) {
        _selectedMoodIds.remove(moodTag.id);
      } else {
        _selectedMoodIds.add(moodTag.id);
      }
    });
  }
}

/// Individual mood chip widget for the dialog
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
