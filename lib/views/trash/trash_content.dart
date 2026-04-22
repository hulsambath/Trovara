part of 'trash_view.dart';

class _TrashContent extends StatelessWidget {
  const _TrashContent(this.viewModel);

  final TrashViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recently Deleted'), surfaceTintColor: Colors.transparent),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Notes you delete appear here and are kept for 30 days before being removed forever. '
            'Items older than 30 days may already have been removed and are no longer recoverable.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody(context)),
      ],
    ),
  );

  Widget _buildBody(BuildContext context) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.deletedNotes.isEmpty) {
      return Center(
        child: Text(
          'No recently deleted notes',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: viewModel.deletedNotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final note = viewModel.deletedNotes[index];
        return Dismissible(
          key: ValueKey(note.id),
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.green,
            child: const Icon(LucideIcons.undo2, color: Colors.white),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Theme.of(context).colorScheme.error,
            child: const Icon(LucideIcons.trash, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              try {
                await viewModel.restoreNote(note);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note restored')));
                }
                return true;
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed to restore: $e'), backgroundColor: Colors.red));
                }
                return false;
              }
            } else {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Forever'),
                  content: const Text(
                    'This note will be permanently removed and cannot be recovered. Do you want to continue?',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete Forever'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  await viewModel.deleteNoteForever(note);
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Note permanently deleted')));
                  }
                  return true;
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red));
                  }
                  return false;
                }
              }
              return false;
            }
          },
          child: NoteCard(note: note, onTap: () {}, onLongPress: () {}, onToggleFavorite: () {}),
        );
      },
    );
  }
}
