part of '../chat_view.dart';

/// Compact source attribution shown below AI responses.
///
/// Displays referenced note titles as small tappable chips,
/// matching the ChatGPT "sources" style.
class _SourceAttribution extends StatelessWidget {
  const _SourceAttribution({required this.sources});

  final List<ChatSourceNote> sources;

  @override
  Widget build(BuildContext context) {
    final validSources = sources.where((s) => s.title.trim().isNotEmpty && s.id != 0).toList();
    if (validSources.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.bookOpen, size: 13, color: colors.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              'Sources',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: validSources.map((s) => _buildChip(context, colors, s)).toList()),
      ],
    );
  }

  Widget _buildChip(BuildContext context, ColorScheme colors, ChatSourceNote source) => Material(
    color: colors.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openNoteDetails(context, source),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileText, size: 12, color: colors.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.title,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (source.hasLabel)
                    Text(
                      source.label,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.arrowUpRight, size: 12, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    ),
  );

  void _openNoteDetails(BuildContext context, ChatSourceNote source) {
    if (source.id == 0) return;
    _chatUiLogger.d('Chat action: open source note ${source.id} "${source.title}"');
    context.push('/note?noteId=${source.id}', extra: const {'readOnly': true});
  }
}
