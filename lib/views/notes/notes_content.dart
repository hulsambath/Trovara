part of 'notes_view.dart';

class _NotesContent extends StatelessWidget {
  const _NotesContent(this.viewModel);

  final NotesViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _buildBody(context),
    floatingActionButton: FloatingActionButton(
      key: const ValueKey('notes-create-fab'),
      child: const Icon(LucideIcons.plus),
      onPressed: () => viewModel.createNewNote(context),
      tooltip: 'Create new note',
    ),
  );

  Widget _buildBody(BuildContext context) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
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
    title: Text('Trovara', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
    actions: [
      // ── Search ─────────────────────────────────────────────────────────
      IconButton(
        key: const ValueKey('notes-search-button'),
        icon: const Icon(LucideIcons.search),
        onPressed: () => context.push('/search'),
        tooltip: 'Search & filter notes',
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );

  Widget _buildNotesList(BuildContext context) {
    if (viewModel.notes.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState(context));
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final note = viewModel.notes[index];
          return Column(
            children: [
              if (index != 0) const SizedBox(height: 16),
              NoteCard(
                note: note,
                onTap: () => viewModel.openNote(context, note),
                onLongPress: () => viewModel.showNoteOptions(context, note),
                onToggleFavorite: () => viewModel.toggleFavorite(note),
              ),
            ],
          );
        }, childCount: viewModel.notes.length),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          LucideIcons.filePlus,
          key: const ValueKey('notes-empty-icon'),
          size: 56,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 16),
        Text(
          'No notes yet',
          key: const ValueKey('notes-empty-title'),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap + to create your first note',
          key: const ValueKey('notes-empty-hint'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}
