part of '../search_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Results list
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  const _ResultsList(this.vm);

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final notes = vm.filteredNotes;
    if (notes.isEmpty) return _EmptyState(vm: vm);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _SearchResultCard(note: notes[index], vm: vm),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Single result card
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.note, required this.vm});

  final Note note;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highlightStyle = TextStyle(
      backgroundColor: colors.primaryContainer,
      color: colors.onPrimaryContainer,
      fontWeight: FontWeight.w700,
    );
    final titleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600);
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(color: colors.onSurfaceVariant);

    final previewText = _buildPreview();
    final titleSpans = vm.buildHighlightSpans(note.title, titleStyle, highlightStyle);
    final previewSpans = previewText.isNotEmpty
        ? vm.buildHighlightSpans(previewText, subtitleStyle, highlightStyle)
        : <TextSpan>[];

    return TrovaraCard(
      onTap: () => context.push('/note?noteId=${note.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + favourite
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(children: titleSpans),
                ),
              ),
              if (note.isFavorite) ...[
                const SizedBox(width: 6),
                Icon(Icons.favorite_rounded, size: 16, color: Colors.red.withValues(alpha: 0.8)),
              ],
            ],
          ),

          // Content preview
          if (previewSpans.isNotEmpty) ...[
            const SizedBox(height: 4),
            RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(children: previewSpans),
            ),
          ],

          // Compact tag row
          if (_hasAnyTag()) ...[const SizedBox(height: 8), _CompactTagRow(note: note)],

          // Date
          const SizedBox(height: 8),
          Text(
            _formatDate(note.updatedAt),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  bool _hasAnyTag() =>
      note.moodTags.isNotEmpty ||
      note.activityTags.isNotEmpty ||
      note.timeTags.isNotEmpty ||
      note.personalGrowthTags.isNotEmpty ||
      note.customTagIds.isNotEmpty;

  String _buildPreview() {
    final full = TextParserService.parseQuillContent(note.contentJson);
    final q = vm.query.trim();

    if (q.isEmpty) return _truncate(full, 120);

    final idx = full.toLowerCase().indexOf(q.toLowerCase());
    if (idx == -1) return _truncate(full, 120);

    // Centre a window around the match so the highlighted text is visible.
    const window = 100;
    final start = (idx - window ~/ 2).clamp(0, full.length).toInt();
    final end = (start + window).clamp(0, full.length).toInt();
    final prefix = start > 0 ? '…' : '';
    final suffix = end < full.length ? '…' : '';
    return '$prefix${full.substring(start, end)}$suffix';
  }

  String _truncate(String text, int max) => text.length <= max ? text : '${text.substring(0, max)}…';

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Compact tag strip inside result card
// ─────────────────────────────────────────────────────────────────────────────

class _CompactTagRow extends StatelessWidget {
  const _CompactTagRow({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    for (final id in note.moodTags.take(2)) {
      final tag = MoodTags.getById(id);
      if (tag != null) chips.add(_MiniChip(label: tag.emoji, color: tag.color));
    }
    for (final id in note.activityTags.take(2)) {
      final tag = ActivityTags.getById(id);
      if (tag != null) chips.add(_MiniChip(label: tag.label, color: tag.color, icon: tag.icon));
    }
    for (final id in note.timeTags.take(1)) {
      final tag = TimeTags.getById(id);
      if (tag != null) chips.add(_MiniChip(label: tag.label, color: tag.color, icon: tag.icon));
    }
    for (final id in note.personalGrowthTags.take(1)) {
      final tag = PersonalGrowthTags.getById(id);
      if (tag != null) chips.add(_MiniChip(label: tag.label, color: tag.color, icon: tag.icon));
    }

    final total =
        note.moodTags.length +
        note.activityTags.length +
        note.timeTags.length +
        note.personalGrowthTags.length +
        note.customTagIds.length;
    if (total > chips.length) {
      final colors = Theme.of(context).colorScheme;
      chips.add(_MiniChip(label: '+${total - chips.length}', color: colors.onSurfaceVariant));
    }

    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 2)],
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w500, fontSize: 10),
        ),
      ],
    ),
  );
}
