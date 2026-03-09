part of 'chat_view.dart';

class _ChatContent extends StatefulWidget {
  const _ChatContent(this.viewModel, {this.embedded = false});

  final ChatViewModel viewModel;
  final bool embedded;

  @override
  State<_ChatContent> createState() => _ChatContentState();
}

class _ChatContentState extends State<_ChatContent> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (viewModel.hasMessages) _scrollToBottom();
    });

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.surface,
      appBar: _buildAppBar(context, colors),
      drawer: _ChatDrawer(
        currentThreadId: viewModel.currentThread?.id,
        onThreadSelected: (thread) {
          _scaffoldKey.currentState?.closeDrawer();
          viewModel.loadThread(thread);
        },
        onNewChat: () {
          _scaffoldKey.currentState?.closeDrawer();
          viewModel.startNewChat();
        },
        onDeleteThread: (threadId) async {
          await viewModel.deleteThread(threadId);
        },
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageArea(context, colors)),
          _ChatInputField(onSubmit: viewModel.sendMessage, isEnabled: !viewModel.isProcessing),
          const SizedBox(height: kBottomNavigationBarHeight / 2),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme colors) => AppBar(
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: colors.surface,
    leading: IconButton(
      icon: Icon(Icons.menu, color: colors.onSurface),
      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      tooltip: 'Chat history',
    ),
    centerTitle: true,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, size: 18, color: colors.primary),
        const SizedBox(width: 6),
        Text('Trovara', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    ),
    actions: [
      IconButton(
        icon: Icon(Icons.edit_square, size: 22, color: colors.onSurfaceVariant),
        onPressed: () => viewModel.startNewChat(),
        tooltip: 'New chat',
      ),
    ],
  );

  Widget _buildMessageArea(BuildContext context, ColorScheme colors) {
    if (!viewModel.isAvailable) {
      return _buildUnavailableState(context, colors);
    }

    if (!viewModel.hasMessages) {
      return _SuggestedQuestions(questions: ChatViewModel.suggestedQuestions, onTap: viewModel.sendMessage);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: viewModel.messages.length,
      itemBuilder: (context, index) {
        final message = viewModel.messages[index];
        final isLast = index == viewModel.messages.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 8 : 20),
          child: _ChatBubble(message: message),
        );
      },
    );
  }

  Widget _buildUnavailableState(BuildContext context, ColorScheme colors) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: colors.primaryContainer.withValues(alpha: 0.3), shape: BoxShape.circle),
            child: Icon(Icons.auto_awesome, size: 32, color: colors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Chat is not available',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: colors.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Please configure your Gemini API key to start asking questions about your notes.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
