import 'package:flutter/material.dart';
import 'package:trovara/core/services/text_parser_service.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/widgets/tages/activity/activity_chips.dart';
import 'package:trovara/widgets/tages/custom/custom_tags_widget.dart';
import 'package:trovara/widgets/tages/mood/mood_chips.dart';
import 'package:trovara/widgets/tages/personal_growth/personal_growth_chips.dart';
import 'package:trovara/widgets/tages/time/time_chips.dart';

class NoteCard extends StatefulWidget {
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
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
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
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.note.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.note.contentJson.isNotEmpty) ...[
                    IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      tooltip: _isExpanded ? 'Collapse content' : 'Expand content',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                  IconButton(
                    icon: Icon(
                      widget.note.isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: widget.note.isFavorite ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: widget.onToggleFavorite,
                    tooltip: widget.note.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              if (widget.note.contentJson.isNotEmpty) ...[
                AnimatedCrossFade(
                  firstChild: Text(
                    TextParserService.getPreviewText(widget.note.contentJson),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondChild: Text(
                    TextParserService.parseQuillContent(widget.note.contentJson),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
              if (widget.note.moodTags.isNotEmpty ||
                  widget.note.activityTags.isNotEmpty ||
                  widget.note.timeTags.isNotEmpty ||
                  widget.note.personalGrowthTags.isNotEmpty ||
                  widget.note.customTagObjects.isNotEmpty) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.note.moodTags.isNotEmpty) ...[
                          CompactMoodChips(selectedMoodIds: widget.note.moodTags),
                          if (widget.note.activityTags.isNotEmpty ||
                              widget.note.timeTags.isNotEmpty ||
                              widget.note.personalGrowthTags.isNotEmpty ||
                              widget.note.customTagObjects.isNotEmpty)
                            const SizedBox(width: 8),
                        ],
                        if (widget.note.activityTags.isNotEmpty) ...[
                          CompactActivityChips(selectedActivityIds: widget.note.activityTags),
                          if (widget.note.timeTags.isNotEmpty ||
                              widget.note.personalGrowthTags.isNotEmpty ||
                              widget.note.customTagObjects.isNotEmpty)
                            const SizedBox(width: 8),
                        ],
                        if (widget.note.timeTags.isNotEmpty) ...[
                          CompactTimeChips(selectedTimeIds: widget.note.timeTags),
                          if (widget.note.personalGrowthTags.isNotEmpty || widget.note.customTagObjects.isNotEmpty)
                            const SizedBox(width: 8),
                        ],
                        if (widget.note.personalGrowthTags.isNotEmpty) ...[
                          CompactPersonalGrowthChips(selectedPersonalGrowthIds: widget.note.personalGrowthTags),
                          if (widget.note.customTagObjects.isNotEmpty) const SizedBox(width: 8),
                        ],
                        if (widget.note.customTagObjects.isNotEmpty)
                          CompactCustomTagsWidget(
                            selectedTags: widget.note.customTagObjects.map((tag) => tag.name).toList(),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.note.isDeleted && widget.note.deletedAt != null
                          ? 'Deleted: ${_getTimeAgoString(widget.note.deletedAt!)}'
                          : 'Created: ${_formatDate(widget.note.createdAt)} • Updated: ${_formatDate(widget.note.updatedAt)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

  /// Format a DateTime as relative time (e.g., "2 hours ago", "3 days ago")
  String _getTimeAgoString(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }
}
