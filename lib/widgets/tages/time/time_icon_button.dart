import 'package:flutter/material.dart';
import 'package:noteminds/models/time_tag.dart';

/// A compact time icon button for the app bar that shows selected time tags
/// and opens a time selection dialog when tapped
class TimeIconButton extends StatelessWidget {
  final List<String> selectedTimeIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final DateTime? creationTime;
  final bool showSuggestions;

  const TimeIconButton({
    super.key,
    required this.selectedTimeIds,
    required this.onSelectionChanged,
    this.creationTime,
    this.showSuggestions = true,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    icon: _buildTimeIcon(context),
    onPressed: () => _showTimeSelectionDialog(context),
    tooltip: 'Select Time',
  );

  Widget _buildTimeIcon(BuildContext context) {
    if (selectedTimeIds.isEmpty) {
      return Icon(Icons.access_time_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }

    // Show the first selected time tag's icon
    final firstTime = TimeTags.getById(selectedTimeIds.first);
    if (firstTime != null) {
      return Stack(
        children: [
          Icon(firstTime.icon, color: firstTime.color, size: 20),
          if (selectedTimeIds.length > 1)
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
                  '${selectedTimeIds.length}',
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

    return Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary);
  }

  void _showTimeSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _TimeSelectionDialog(
        selectedTimeIds: selectedTimeIds,
        onSelectionChanged: onSelectionChanged,
        creationTime: creationTime,
        showSuggestions: showSuggestions,
      ),
    );
  }
}

/// Dialog for selecting time tags
class _TimeSelectionDialog extends StatefulWidget {
  final List<String> selectedTimeIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final DateTime? creationTime;
  final bool showSuggestions;

  const _TimeSelectionDialog({
    required this.selectedTimeIds,
    required this.onSelectionChanged,
    this.creationTime,
    this.showSuggestions = true,
  });

  @override
  State<_TimeSelectionDialog> createState() => _TimeSelectionDialogState();
}

class _TimeSelectionDialogState extends State<_TimeSelectionDialog> {
  late List<String> _selectedTimeIds;
  late List<String> _suggestedIds;

  @override
  void initState() {
    super.initState();
    _selectedTimeIds = List.from(widget.selectedTimeIds);
    _suggestedIds = TimeTags.getTimeBasedSuggestions(widget.creationTime);

    // Auto-select suggestions if no time tags are selected and suggestions are enabled
    if (widget.showSuggestions && _selectedTimeIds.isEmpty) {
      _selectedTimeIds = List.from(_suggestedIds);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Select Time'),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showSuggestions && _suggestedIds.isNotEmpty) ...[
            _buildSuggestedSection(context),
            const SizedBox(height: 16),
          ],
          _buildAllTimeTags(context),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        onPressed: () {
          widget.onSelectionChanged(_selectedTimeIds);
          Navigator.of(context).pop();
        },
        child: const Text('Done'),
      ),
    ],
  );

  Widget _buildSuggestedSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: Theme.of(context).colorScheme.primary),
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
        children: _suggestedIds.map((timeId) {
          final timeTag = TimeTags.getById(timeId);
          if (timeTag == null) return const SizedBox.shrink();

          final isSelected = _selectedTimeIds.contains(timeId);
          return _buildTimeChip(context, timeTag, isSelected, true);
        }).toList(),
      ),
    ],
  );

  Widget _buildAllTimeTags(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: TimeTags.all.map((timeTag) {
      final isSelected = _selectedTimeIds.contains(timeTag.id);
      final isSuggested = _suggestedIds.contains(timeTag.id);

      // Hide suggested tags from the main list to avoid duplication
      if (widget.showSuggestions && isSuggested) {
        return const SizedBox.shrink();
      }

      return _buildTimeChip(context, timeTag, isSelected, false);
    }).toList(),
  );

  Widget _buildTimeChip(BuildContext context, TimeTag timeTag, bool isSelected, bool isSuggested) => ChoiceChip(
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          timeTag.icon,
          size: 16,
          color: isSelected ? timeTag.color : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(timeTag.label),
        if (isSuggested && !isSelected) ...[
          const SizedBox(width: 4),
          Icon(Icons.auto_awesome, size: 12, color: Theme.of(context).colorScheme.primary),
        ],
      ],
    ),
    selected: isSelected,
    onSelected: (selected) => _handleTimeSelection(timeTag, selected),
    selectedColor: timeTag.color.withValues(alpha: 0.2),
    checkmarkColor: timeTag.color,
    side: BorderSide(
      color: isSelected
          ? timeTag.color
          : isSuggested
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
          : Theme.of(context).colorScheme.outlineVariant,
      width: isSelected ? 2 : 1,
    ),
    labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: isSelected
          ? timeTag.color
          : isSuggested
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
    ),
  );

  void _handleTimeSelection(TimeTag timeTag, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedTimeIds.contains(timeTag.id)) {
          _selectedTimeIds.add(timeTag.id);
        }
      } else {
        _selectedTimeIds.remove(timeTag.id);
      }
    });
  }
}
