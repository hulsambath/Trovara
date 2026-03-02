part of '../chat_view.dart';

/// Empty-state widget showing suggested questions.
///
/// Displayed when the chat has no messages yet. Tapping a question
/// sends it as if the user typed it.
class _SuggestedQuestions extends StatelessWidget {
  const _SuggestedQuestions({required this.questions, required this.onTap});

  final List<String> questions;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: colors.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              'Ask your notes anything',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Get AI-powered answers based on your personal notes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              'Try asking',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...questions.map((q) => _buildQuestionCard(context, colors, q)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, ColorScheme colors, String question) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onTap(question),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 16, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(question, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurface)),
              ),
              Icon(Icons.arrow_forward_ios, size: 12, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    ),
  );
}
