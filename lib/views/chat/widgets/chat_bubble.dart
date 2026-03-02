part of '../chat_view.dart';

/// A single chat message bubble.
///
/// User messages are aligned right with the primary color background.
/// AI messages are aligned left with a surface-variant background
/// and include source attribution when available.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[_buildAvatar(context, colors), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? colors.primary
                        : message.isError
                        ? colors.errorContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: _buildContent(context, colors, isUser),
                ),
                // Source attribution (AI only)
                if (!isUser && !message.isLoading && message.sourceNoteTitles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _SourceAttribution(titles: message.sourceNoteTitles),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colors, bool isUser) {
    if (message.isLoading && message.content.isEmpty) {
      return _buildTypingIndicator(colors, isUser);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          message.content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isUser
                ? colors.onPrimaryContainer
                : message.isError
                ? colors.onErrorContainer
                : colors.onSurface,
            height: 1.4,
          ),
        ),
        if (message.isLoading && message.content.isNotEmpty) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _buildTypingIndicator(ColorScheme colors, bool isUser) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: isUser ? colors.onPrimary : colors.onSurfaceVariant),
      ),
      const SizedBox(width: 8),
      Text(
        'Thinking...',
        style: TextStyle(
          color: isUser ? colors.onPrimary : colors.onSurfaceVariant,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
  );

  Widget _buildAvatar(BuildContext context, ColorScheme colors) => Container(
    width: 28,
    height: 28,
    margin: const EdgeInsets.only(top: 2),
    decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
    child: Icon(Icons.auto_awesome, size: 16, color: colors.onPrimaryContainer),
  );
}
