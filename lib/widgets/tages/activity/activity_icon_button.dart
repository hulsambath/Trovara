import 'package:flutter/material.dart';
import 'package:noteminds/models/activity_tag.dart';

/// A compact activity icon button for the app bar that shows selected activities
/// and opens an activity selection dialog when tapped
class ActivityIconButton extends StatelessWidget {
  final List<String> selectedActivityIds;
  final ValueChanged<List<String>> onSelectionChanged;

  const ActivityIconButton({super.key, required this.selectedActivityIds, required this.onSelectionChanged});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: _buildActivityIcon(context),
    onPressed: () => _showActivitySelectionDialog(context),
    tooltip: 'Select Activity',
  );

  Widget _buildActivityIcon(BuildContext context) {
    if (selectedActivityIds.isEmpty) {
      return Icon(Icons.category_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }

    // Show the first selected activity's icon
    final firstActivity = ActivityTags.getById(selectedActivityIds.first);
    if (firstActivity != null) {
      return Stack(
        children: [
          Icon(firstActivity.icon, color: firstActivity.color, size: 20),
          if (selectedActivityIds.length > 1)
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
                  '${selectedActivityIds.length}',
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

    return Icon(Icons.category, color: Theme.of(context).colorScheme.primary);
  }

  void _showActivitySelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          _ActivitySelectionDialog(selectedActivityIds: selectedActivityIds, onSelectionChanged: onSelectionChanged),
    );
  }
}

/// Dialog for selecting activity tags
class _ActivitySelectionDialog extends StatefulWidget {
  final List<String> selectedActivityIds;
  final ValueChanged<List<String>> onSelectionChanged;

  const _ActivitySelectionDialog({required this.selectedActivityIds, required this.onSelectionChanged});

  @override
  State<_ActivitySelectionDialog> createState() => _ActivitySelectionDialogState();
}

class _ActivitySelectionDialogState extends State<_ActivitySelectionDialog> {
  late List<String> _selectedActivityIds;

  @override
  void initState() {
    super.initState();
    _selectedActivityIds = List.from(widget.selectedActivityIds);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Select Activity'),
    content: SizedBox(
      width: double.maxFinite,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ActivityTags.all.map((activityTag) {
          final isSelected = _selectedActivityIds.contains(activityTag.id);
          return _ActivityChip(
            activityTag: activityTag,
            isSelected: isSelected,
            onTap: () => _handleActivitySelection(activityTag),
          );
        }).toList(),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        onPressed: () {
          widget.onSelectionChanged(_selectedActivityIds);
          Navigator.of(context).pop();
        },
        child: const Text('Done'),
      ),
    ],
  );

  void _handleActivitySelection(ActivityTag activityTag) {
    setState(() {
      if (_selectedActivityIds.contains(activityTag.id)) {
        _selectedActivityIds.remove(activityTag.id);
      } else {
        _selectedActivityIds.add(activityTag.id);
      }
    });
  }
}

/// Individual activity chip widget for the dialog
class _ActivityChip extends StatelessWidget {
  final ActivityTag activityTag;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActivityChip({required this.activityTag, required this.isSelected, required this.onTap});

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
          color: isSelected ? activityTag.color.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected ? activityTag.color : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(activityTag.icon, size: 16, color: isSelected ? activityTag.color : colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              activityTag.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected ? activityTag.color : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
