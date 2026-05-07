part of '../chat_view.dart';

/// Compact source attribution shown below AI responses.
///
/// Displays referenced note titles as small tappable chips,
/// matching the ChatGPT "sources" style.
class _SourceAttribution extends StatelessWidget {
  const _SourceAttribution({required this.titles});

  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    if (titles.isEmpty) return const SizedBox.shrink();

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
        Wrap(spacing: 6, runSpacing: 6, children: titles.map((t) => _buildChip(context, colors, t)).toList()),
      ],
    );
  }

  Widget _buildChip(BuildContext context, ColorScheme colors, String title) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.fileText, size: 12, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
