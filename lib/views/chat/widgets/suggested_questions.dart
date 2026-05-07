part of '../chat_view.dart';

/// ChatGPT-style empty state with greeting and suggested prompt chips.
class _SuggestedQuestions extends StatelessWidget {
  const _SuggestedQuestions({required this.questions, required this.onTap});

  final List<String> questions;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
              child: Icon(LucideIcons.sparkles, size: 28, color: colors.onPrimary),
            ),
            const SizedBox(height: 20),
            Text(
              'How can I help?',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: colors.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about your notes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 36),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: questions.map((q) => _buildChip(context, colors, q)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, ColorScheme colors, String question) => GestureDetector(
    onTap: () => onTap(question),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant, width: 1),
      ),
      child: Text(question, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurface)),
    ),
  );
}
