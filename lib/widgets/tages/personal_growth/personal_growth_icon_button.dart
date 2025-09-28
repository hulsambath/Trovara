import 'package:flutter/material.dart';
import 'package:noteminds/models/personal_growth_tag.dart';

/// A compact personal growth icon button for the app bar that shows selected personal growth tags
/// and opens a personal growth selection dialog when tapped
class PersonalGrowthIconButton extends StatelessWidget {
  final List<String> selectedPersonalGrowthIds;
  final ValueChanged<List<String>> onSelectionChanged;

  const PersonalGrowthIconButton({
    super.key,
    required this.selectedPersonalGrowthIds,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    icon: _buildPersonalGrowthIcon(context),
    onPressed: () => _showPersonalGrowthSelectionDialog(context),
    tooltip: 'Select Personal Growth',
  );

  Widget _buildPersonalGrowthIcon(BuildContext context) {
    if (selectedPersonalGrowthIds.isEmpty) {
      return Icon(Icons.trending_up_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }

    // Show the first selected personal growth tag's icon
    final firstPersonalGrowth = PersonalGrowthTags.getById(selectedPersonalGrowthIds.first);
    if (firstPersonalGrowth != null) {
      return Stack(
        children: [
          Icon(firstPersonalGrowth.icon, color: firstPersonalGrowth.color, size: 20),
          if (selectedPersonalGrowthIds.length > 1)
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
                  '${selectedPersonalGrowthIds.length}',
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

    return Icon(Icons.trending_up, color: Theme.of(context).colorScheme.primary);
  }

  void _showPersonalGrowthSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _PersonalGrowthSelectionDialog(
        selectedPersonalGrowthIds: selectedPersonalGrowthIds,
        onSelectionChanged: onSelectionChanged,
      ),
    );
  }
}

/// Dialog for selecting personal growth tags
class _PersonalGrowthSelectionDialog extends StatefulWidget {
  final List<String> selectedPersonalGrowthIds;
  final ValueChanged<List<String>> onSelectionChanged;

  const _PersonalGrowthSelectionDialog({required this.selectedPersonalGrowthIds, required this.onSelectionChanged});

  @override
  State<_PersonalGrowthSelectionDialog> createState() => _PersonalGrowthSelectionDialogState();
}

class _PersonalGrowthSelectionDialogState extends State<_PersonalGrowthSelectionDialog> {
  late List<String> _selectedPersonalGrowthIds;

  @override
  void initState() {
    super.initState();
    _selectedPersonalGrowthIds = List.from(widget.selectedPersonalGrowthIds);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Select Personal Growth'),
    content: SizedBox(
      width: double.maxFinite,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: PersonalGrowthTags.all.map((personalGrowthTag) {
          final isSelected = _selectedPersonalGrowthIds.contains(personalGrowthTag.id);
          return _PersonalGrowthChip(
            personalGrowthTag: personalGrowthTag,
            isSelected: isSelected,
            onTap: () => _handlePersonalGrowthSelection(personalGrowthTag),
          );
        }).toList(),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        onPressed: () {
          widget.onSelectionChanged(_selectedPersonalGrowthIds);
          Navigator.of(context).pop();
        },
        child: const Text('Done'),
      ),
    ],
  );

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

/// Individual personal growth chip widget for the dialog
class _PersonalGrowthChip extends StatelessWidget {
  final PersonalGrowthTag personalGrowthTag;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonalGrowthChip({required this.personalGrowthTag, required this.isSelected, required this.onTap});

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
          color: isSelected ? personalGrowthTag.color.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected ? personalGrowthTag.color : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              personalGrowthTag.icon,
              size: 16,
              color: isSelected ? personalGrowthTag.color : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              personalGrowthTag.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected ? personalGrowthTag.color : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
