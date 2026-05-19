part of '../chat_view.dart';

/// ChatGPT-style message display.
///
/// User messages: right-aligned grey pill, no avatar.
/// AI messages: left-aligned with small sparkle avatar, plain text, no bubble.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return isUser ? _buildUserMessage(context) : _buildAssistantMessage(context);
  }

  Widget _buildUserMessage(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 48),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurface, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantMessage(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(context, colors),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAssistantContent(context, colors),
              if (!message.isLoading && message.sourceNotes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _SourceAttribution(sources: message.sourceNotes),
                ),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildAssistantContent(BuildContext context, ColorScheme colors) {
    if (message.isLoading && message.content.isEmpty) {
      return const _TypingIndicator();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          message.content,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: message.isError ? colors.error : colors.onSurface, height: 1.5),
        ),
        if (message.isLoading && message.content.isNotEmpty)
          const Padding(padding: EdgeInsets.only(top: 6), child: _TypingIndicator()),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, ColorScheme colors) => Container(
    width: 28,
    height: 28,
    margin: const EdgeInsets.only(top: 2),
    decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
    child: Icon(LucideIcons.sparkles, size: 15, color: colors.onPrimary),
  );
}

/// Three-dot bouncing typing indicator (ChatGPT-style).
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)),
    );

    _animations = List.generate(
      3,
      (i) => Tween<double>(begin: 0.0, end: -6.0).animate(
        CurvedAnimation(
          parent: _controllers[i],
          curve: Interval(i * 0.2, 0.6 + i * 0.2, curve: Curves.easeInOut),
        ),
      ),
    );

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => AnimatedBuilder(
            animation: _animations[i],
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
