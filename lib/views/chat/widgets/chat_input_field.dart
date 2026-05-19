part of '../chat_view.dart';

/// ChatGPT-style input field: rounded pill with embedded send button.
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
    final text = _controller.text;
    final trimmed = text.trim();
    if (trimmed.isEmpty || !widget.isEnabled) {
      _chatUiLogger.d('Chat action: submit ignored (hasText=${trimmed.isNotEmpty}, enabled=${widget.isEnabled})');
      return;
    }

    _chatUiLogger.d('Chat action: submit message len=${trimmed.length} preview="${_preview(trimmed)}"');
    _controller.clear();
    widget.onSubmit(text);
    _focusNode.requestFocus();
  }

  String _preview(String text) {
    const max = 80;
    final normalized = text.replaceAll('\n', ' ');
    if (normalized.length <= max) return normalized;
    return '${normalized.substring(0, max)}...';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canSend = _hasText && widget.isEnabled;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: colors.surface,
      child: Container(
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(26)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                onTapOutside: (_) => _focusNode.unfocus(),
                enabled: widget.isEnabled,
                maxLines: 6,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: canSend ? colors.primary : colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: canSend ? _submit : null,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: Icon(
                        LucideIcons.arrowUp,
                        size: 20,
                        color: canSend ? colors.onPrimary : colors.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
