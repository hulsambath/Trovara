part of '../chat_view.dart';

/// Text input field for typing chat messages.
///
/// Shows a text field with a send button. The send button is
/// disabled while the AI is processing a response.
class _ChatInputField extends StatefulWidget {
  const _ChatInputField({required this.onSubmit, required this.isEnabled});

  final void Function(String) onSubmit;
  final bool isEnabled;

  @override
  State<_ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<_ChatInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_hasText || !widget.isEnabled) return;

    final text = _controller.text;
    _controller.clear();
    widget.onSubmit(text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              enabled: widget.isEnabled,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Ask about your notes...',
                hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.all(0),
            child: IconButton.filled(
              onPressed: (_hasText && widget.isEnabled) ? _submit : null,
              icon: const Icon(Icons.arrow_upward, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: (_hasText && widget.isEnabled) ? colors.primary : colors.surfaceContainerHighest,
                foregroundColor: (_hasText && widget.isEnabled) ? colors.onPrimary : colors.onSurfaceVariant,
                fixedSize: const Size(38, 38),
                shape: const CircleBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
