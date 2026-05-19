part of '../chat_view.dart';

/// Drawer that displays a list of past chat threads (ChatGPT sidebar style).
///
/// Threads are fetched from [ChatService] via [ServiceLocator].
/// Tapping a thread calls [onThreadSelected]; tapping "New chat" calls [onNewChat].
class _ChatDrawer extends StatelessWidget {
  const _ChatDrawer({
    required this.onThreadSelected,
    required this.onNewChat,
    required this.onDeleteThread,
    this.currentThreadId,
  });

  final void Function(ChatThread thread) onThreadSelected;
  final VoidCallback onNewChat;
  final Future<void> Function(int threadId) onDeleteThread;
  final int? currentThreadId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chatService = ServiceLocator().chatService;
    final threads = chatService.getGlobalThreads();

    return Drawer(
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, colors),
            const Divider(height: 1),
            Expanded(
              child: threads.isEmpty ? _buildEmptyState(context, colors) : _buildThreadList(context, colors, threads),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colors) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
          child: Icon(LucideIcons.sparkles, size: 16, color: colors.onPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Chat History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          icon: Icon(LucideIcons.squarePen, size: 22, color: colors.onSurfaceVariant),
          onPressed: onNewChat,
          tooltip: 'New chat',
        ),
      ],
    ),
  );

  Widget _buildEmptyState(BuildContext context, ColorScheme colors) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.messageCircle, size: 48, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat to ask questions about your notes',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildThreadList(BuildContext context, ColorScheme colors, List<ChatThread> threads) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final last7Days = today.subtract(const Duration(days: 7));
    final last30Days = today.subtract(const Duration(days: 30));

    final todayThreads = <ChatThread>[];
    final yesterdayThreads = <ChatThread>[];
    final last7Threads = <ChatThread>[];
    final last30Threads = <ChatThread>[];
    final olderThreads = <ChatThread>[];

    for (final thread in threads) {
      final threadDate = DateTime(thread.updatedAt.year, thread.updatedAt.month, thread.updatedAt.day);
      if (!threadDate.isBefore(today)) {
        todayThreads.add(thread);
      } else if (!threadDate.isBefore(yesterday)) {
        yesterdayThreads.add(thread);
      } else if (!threadDate.isBefore(last7Days)) {
        last7Threads.add(thread);
      } else if (!threadDate.isBefore(last30Days)) {
        last30Threads.add(thread);
      } else {
        olderThreads.add(thread);
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (todayThreads.isNotEmpty) ...[
          _buildSectionHeader(context, colors, 'Today'),
          ...todayThreads.map((t) => _buildThreadTile(context, colors, t)),
        ],
        if (yesterdayThreads.isNotEmpty) ...[
          _buildSectionHeader(context, colors, 'Yesterday'),
          ...yesterdayThreads.map((t) => _buildThreadTile(context, colors, t)),
        ],
        if (last7Threads.isNotEmpty) ...[
          _buildSectionHeader(context, colors, 'Previous 7 Days'),
          ...last7Threads.map((t) => _buildThreadTile(context, colors, t)),
        ],
        if (last30Threads.isNotEmpty) ...[
          _buildSectionHeader(context, colors, 'Previous 30 Days'),
          ...last30Threads.map((t) => _buildThreadTile(context, colors, t)),
        ],
        if (olderThreads.isNotEmpty) ...[
          _buildSectionHeader(context, colors, 'Older'),
          ...olderThreads.map((t) => _buildThreadTile(context, colors, t)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, ColorScheme colors, String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: 0.3),
    ),
  );

  Widget _buildThreadTile(BuildContext context, ColorScheme colors, ChatThread thread) {
    final title = thread.title ?? 'New conversation';
    final displayTitle = title.length > 40 ? '${title.substring(0, 40)}...' : title;
    final isActive = currentThreadId == thread.id;

    return InkWell(
      onTap: () {
        _chatUiLogger.d('Chat action: tap thread ${thread.id} (${thread.title ?? 'New conversation'})');
        onThreadSelected(thread);
      },
      onLongPress: () {
        _chatUiLogger.d('Chat action: long-press thread ${thread.id} (${thread.title ?? 'New conversation'})');
        _showDeleteDialog(context, thread);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isActive ? colors.primaryContainer.withValues(alpha: 0.3) : null,
        ),
        child: Row(
          children: [
            Icon(LucideIcons.messageCircle, size: 16, color: isActive ? colors.primary : colors.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayTitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isActive ? colors.primary : colors.onSurface,
                  fontWeight: isActive ? FontWeight.w600 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ChatThread thread) {
    _chatUiLogger.d('Chat action: show delete dialog for thread ${thread.id}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete conversation'),
        content: const Text('This conversation will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () {
              _chatUiLogger.d('Chat action: cancel delete thread ${thread.id}');
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _chatUiLogger.d('Chat action: confirm delete thread ${thread.id}');
              Navigator.of(ctx).pop();
              onDeleteThread(thread.id);
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
