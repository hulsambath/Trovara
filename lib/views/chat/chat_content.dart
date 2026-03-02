part of 'chat_view.dart';

class _ChatContent extends StatefulWidget {
  const _ChatContent(this.viewModel);

  final ChatViewModel viewModel;

  @override
  State<_ChatContent> createState() => _ChatContentState();
}

class _ChatContentState extends State<_ChatContent> {
  final ScrollController _scrollController = ScrollController();

  ChatViewModel get viewModel => widget.viewModel;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scroll to bottom whenever messages change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (viewModel.hasMessages) _scrollToBottom();
    });

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageArea(context)),
            _ChatInputField(onSubmit: viewModel.sendMessage, isEnabled: !viewModel.isProcessing),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(
    title: Text(
      'Ask your notes',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    actions: [
      if (viewModel.hasMessages)
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: () => _confirmClearConversation(context),
          tooltip: 'Clear conversation',
        ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );

  Widget _buildMessageArea(BuildContext context) {
    if (!viewModel.isAvailable) {
      return _buildUnavailableState(context);
    }

    if (!viewModel.hasMessages) {
      return _SuggestedQuestions(questions: ChatViewModel.suggestedQuestions, onTap: viewModel.sendMessage);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: viewModel.messages.length,
      itemBuilder: (context, index) {
        final message = viewModel.messages[index];
        return _ChatBubble(message: message);
      },
    );
  }

  Widget _buildUnavailableState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Chat is not available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'The AI assistant requires a Gemini API key to work. '
              'Please configure `GEMINI_API_KEY` to start asking questions about your notes.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearConversation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear conversation'),
        content: const Text('This will delete all messages in this chat. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              viewModel.clearConversation();
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
