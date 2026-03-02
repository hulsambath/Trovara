part of '../chat_view.dart';

/// Shows source note titles below an AI response bubble.
///
/// Displays a compact row of note-title chips so the user can see
/// which notes were used to generate the answer.
class _SourceAttribution extends StatelessWidget {
  const _SourceAttribution({required this.titles});

  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    if (titles.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.article_outlined, size: 12, color: colors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Sources',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: titles.map((title) => _buildSourceChip(context, colors, title)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceChip(BuildContext context, ColorScheme colors, String title) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: colors.outlineVariant, width: 0.5),
    ),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
