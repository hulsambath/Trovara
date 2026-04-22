import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trovara/models/time_tag.dart';

/// A widget that displays time-based tags with automatic suggestions
class TimeChips extends StatefulWidget {
  final List<String> selectedTimeIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final DateTime? creationTime;
  final bool showSuggestions;

  const TimeChips({
    super.key,
    required this.selectedTimeIds,
    required this.onSelectionChanged,
    this.creationTime,
    this.showSuggestions = true,
  });

  @override
  State<TimeChips> createState() => _TimeChipsState();
}

class _TimeChipsState extends State<TimeChips> {
  late List<String> _selectedTimeIds;
  late List<String> _suggestedIds;

  @override
  void initState() {
    super.initState();
    _selectedTimeIds = List.from(widget.selectedTimeIds);
    _suggestedIds = TimeTags.getTimeBasedSuggestions(widget.creationTime);

    // Auto-select suggestions if no time tags are selected and suggestions are enabled
    // Use addPostFrameCallback to avoid calling setState during build
    if (widget.showSuggestions && _selectedTimeIds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectedTimeIds = List.from(_suggestedIds);
          widget.onSelectionChanged(_selectedTimeIds);
        }
      });
    }
  }

  @override
  void didUpdateWidget(TimeChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTimeIds != widget.selectedTimeIds) {
      _selectedTimeIds = List.from(widget.selectedTimeIds);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Time',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      if (widget.showSuggestions && _suggestedIds.isNotEmpty) ...[
        _buildSuggestedSection(context),
        const SizedBox(height: 12),
      ],
      if (_hasAlternativeTags()) ...[_buildAlternativeSection(context), const SizedBox(height: 8)],
      _buildAllTimeTags(context),
    ],
  );

  Widget _buildSuggestedSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
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
      const SizedBox(height: 6),
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

  bool _hasAlternativeTags() {
    if (!widget.showSuggestions) return false;
    return TimeTags.all.any((tag) => !_suggestedIds.contains(tag.id));
  }

  Widget _buildAlternativeSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(LucideIcons.ellipsis, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            'Other Options',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
          Icon(LucideIcons.sparkles, size: 12, color: Theme.of(context).colorScheme.primary),
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

    widget.onSelectionChanged(_selectedTimeIds);
  }
}

/// Compact version of time chips for use in note cards or lists
class CompactTimeChips extends StatelessWidget {
  final List<String> selectedTimeIds;
  final int maxDisplay;

  const CompactTimeChips({super.key, required this.selectedTimeIds, this.maxDisplay = 3});

  @override
  Widget build(BuildContext context) {
    if (selectedTimeIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayedTimes = selectedTimeIds.take(maxDisplay).toList();
    final remainingCount = selectedTimeIds.length - maxDisplay;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...displayedTimes.map((timeId) {
          final timeTag = TimeTags.getById(timeId);
          if (timeTag == null) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: timeTag.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(timeTag.icon, size: 12, color: timeTag.color),
                const SizedBox(width: 2),
                Text(
                  timeTag.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 10, color: timeTag.color, fontWeight: FontWeight.w500),
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
