import 'package:flutter/material.dart';
import 'package:noteminds/core/services/text_parser_service.dart';
import 'package:noteminds/models/note.dart';
import 'package:noteminds/widgets/tages/activity/activity_chips.dart';
import 'package:noteminds/widgets/tages/custom/custom_tags_widget.dart';
import 'package:noteminds/widgets/tages/mood/mood_chips.dart';
import 'package:noteminds/widgets/tages/personal_growth/personal_growth_chips.dart';
import 'package:noteminds/widgets/tages/time/time_chips.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleFavorite,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      note.isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: note.isFavorite ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onToggleFavorite,
                    tooltip: note.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              if (note.contentJson.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  TextParserService.getPreviewText(note.contentJson),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (note.moodTags.isNotEmpty ||
                  note.activityTags.isNotEmpty ||
                  note.timeTags.isNotEmpty ||
                  note.personalGrowthTags.isNotEmpty ||
                  note.customTagObjects.isNotEmpty) ...[
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (note.moodTags.isNotEmpty) ...[
                          CompactMoodChips(selectedMoodIds: note.moodTags),
                          if (note.activityTags.isNotEmpty ||
                              note.timeTags.isNotEmpty ||
                              note.personalGrowthTags.isNotEmpty ||
                              note.customTagObjects.isNotEmpty)
                            const SizedBox(width: 8),
                        ],
                        if (note.activityTags.isNotEmpty) ...[
                          CompactActivityChips(selectedActivityIds: note.activityTags),
                          if (note.timeTags.isNotEmpty ||
                              note.personalGrowthTags.isNotEmpty ||
                              note.customTagObjects.isNotEmpty)
                            const SizedBox(width: 8),
                        ],
                        if (note.timeTags.isNotEmpty) ...[
                          CompactTimeChips(selectedTimeIds: note.timeTags),
                          if (note.personalGrowthTags.isNotEmpty || note.customTagObjects.isNotEmpty)
                            const SizedBox(width: 8),
                        ],
                        if (note.personalGrowthTags.isNotEmpty) ...[
                          CompactPersonalGrowthChips(selectedPersonalGrowthIds: note.personalGrowthTags),
                          if (note.customTagObjects.isNotEmpty) const SizedBox(width: 8),
                        ],
                        if (note.customTagObjects.isNotEmpty)
                          CompactCustomTagsWidget(selectedTags: note.customTagObjects.map((tag) => tag.name).toList()),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Created: ${_formatDate(note.createdAt)} • Updated: ${_formatDate(note.updatedAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
