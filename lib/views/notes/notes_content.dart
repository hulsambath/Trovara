part of 'notes_view.dart';

class _NotesContent extends StatelessWidget {
  const _NotesContent(this.viewModel);

  final NotesViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(body: _buildBody(context), floatingActionButton: _buildFAB(context));

  Widget _buildBody(BuildContext context) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.notes.isEmpty) {
      return _buildEmptyState(context);
    }

    return CustomScrollView(
      controller: viewModel.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildAppBar(context),
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            HapticFeedback.heavyImpact();
            await viewModel.refreshNotes();
          },
        ),
        _buildNotesList(context),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) => SliverAppBar(
    floating: true,
    snap: true,
    title: Text('notemyminds', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
    actions: [
      IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _openRecentlyDeleted(context),
        tooltip: 'Recently Deleted',
      ),
      IconButton(
        icon: const Icon(Icons.sync),
        onPressed: () => viewModel.syncWithGoogleDrive(context),
        tooltip: 'Sync with Google Drive',
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );

  Widget _buildNotesList(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.all(16),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final note = viewModel.notes[index];
        return NoteCard(
          note: note,
          onTap: () => viewModel.openNote(context, note),
          onLongPress: () => viewModel.showNoteOptions(context, note),
          onToggleFavorite: () => viewModel.toggleFavorite(note),
        );
      }, childCount: viewModel.notes.length),
    ),
  );

  Widget _buildEmptyState(BuildContext context) => Center(
    child: Text(
      'No notes yet',
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );

  Widget _buildFAB(BuildContext context) => FloatingActionButton.small(
    heroTag: 'add_note',
    shape: const CircleBorder(),
    onPressed: () => viewModel.createNewNote(context),
    child: const Icon(Icons.add),
  );

  void _openRecentlyDeleted(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TrashView()));
  }
}
