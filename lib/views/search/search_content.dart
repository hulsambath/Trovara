part of 'search_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Root scaffold
// ─────────────────────────────────────────────────────────────────────────────

class _SearchContent extends StatefulWidget {
  const _SearchContent(this.viewModel);

  final SearchViewModel viewModel;

  @override
  State<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<_SearchContent> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  SearchViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    vm.addListener(_syncSearchFieldToViewModel);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  /// Keeps the app bar [TextField] aligned with [SearchViewModel.query] when the
  /// query is cleared without going through the field (e.g. "Clear all filters").
  void _syncSearchFieldToViewModel() {
    if (!mounted) return;
    if (vm.query.isEmpty && _textController.text.isNotEmpty) {
      _textController.clear();
    }
  }

  @override
  void dispose() {
    vm.removeListener(_syncSearchFieldToViewModel);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: _buildAppBar(context, colors),
      body: Column(
        children: [
          _FilterPanel(vm),
          const Divider(height: 1),
          _ResultsHeader(vm),
          Expanded(child: _ResultsList(vm)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme colors) => PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight),
    child: AppBar(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      leading: IconButton(icon: const Icon(LucideIcons.arrowLeft), onPressed: () => context.pop(), tooltip: 'Back'),
      title: _SearchBar(
        controller: _textController,
        focusNode: _focusNode,
        onChanged: vm.setQuery,
        onClear: () {
          _textController.clear();
          vm.clearQuery();
        },
      ),
      actions: [_SortButton(vm), const SizedBox(width: 4)],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Search bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.focusNode, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        onTapOutside: (_) => focusNode.unfocus(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurface),
        decoration: InputDecoration(
          hintText: 'Search notes…',
          hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
          prefixIcon: Icon(LucideIcons.search, size: 20, color: colors.onSurfaceVariant),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(LucideIcons.x, size: 18, color: colors.onSurfaceVariant),
                    onPressed: onClear,
                    splashRadius: 16,
                    tooltip: 'Clear',
                  )
                : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sort button + bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  const _SortButton(this.vm);

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(LucideIcons.arrowUpDown, color: colors.onSurfaceVariant),
      tooltip: 'Sort',
      onPressed: () => _showSortSheet(context),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Sort by',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              ...SearchSortOrder.values.map((order) {
                final isActive = vm.sortOrder == order;
                return ListTile(
                  leading: Icon(_sortIcon(order), color: isActive ? colors.primary : colors.onSurfaceVariant),
                  title: Text(_sortLabel(order)),
                  trailing: isActive ? Icon(LucideIcons.check, color: colors.primary) : null,
                  selected: isActive,
                  onTap: () {
                    vm.setSortOrder(order);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  IconData _sortIcon(SearchSortOrder o) => switch (o) {
    SearchSortOrder.newestFirst => LucideIcons.arrowDown,
    SearchSortOrder.oldestFirst => LucideIcons.arrowUp,
    SearchSortOrder.alphabetical => LucideIcons.arrowDownAZ,
    SearchSortOrder.recentlyUpdated => LucideIcons.rotateCw,
  };

  String _sortLabel(SearchSortOrder o) => switch (o) {
    SearchSortOrder.newestFirst => 'Newest first',
    SearchSortOrder.oldestFirst => 'Oldest first',
    SearchSortOrder.alphabetical => 'A → Z',
    SearchSortOrder.recentlyUpdated => 'Recently updated',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
//  Filter panel
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  const _FilterPanel(this.vm);

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tagCount = vm.activeTagFilterCount;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Toggle row ────────────────────────────────────────────────────
          InkWell(
            onTap: vm.toggleFiltersExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(LucideIcons.funnel, size: 18, color: colors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  if (tagCount > 0 || vm.showFavoritesOnly) ...[
                    const SizedBox(width: 6),
                    _CountBadge(tagCount + (vm.showFavoritesOnly ? 1 : 0)),
                  ],
                  const Spacer(),
                  if (vm.hasActiveFilters)
                    TextButton(
                      onPressed: vm.clearAllFilters,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: colors.error,
                      ),
                      child: const Text('Clear all'),
                    ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: vm.filtersExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(LucideIcons.chevronDown, size: 20, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded content ──────────────────────────────────────────────
          if (vm.filtersExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _QuickFilterChip(
                    label: 'Favorites',
                    icon: LucideIcons.heart,
                    selected: vm.showFavoritesOnly,
                    onTap: vm.toggleFavoritesOnly,
                    activeColor: Colors.red,
                  ),
                ],
              ),
            ),
            _TagCategory(
              label: 'Mood',
              icon: LucideIcons.smile,
              children: MoodTags.all.map((t) => _MoodFilterChip(tag: t, vm: vm)).toList(),
            ),
            _TagCategory(
              label: 'Activity',
              icon: LucideIcons.shapes,
              children: ActivityTags.all.map((t) => _ActivityFilterChip(tag: t, vm: vm)).toList(),
            ),
            _TagCategory(
              label: 'Time',
              icon: LucideIcons.clock,
              children: TimeTags.all.map((t) => _TimeFilterChip(tag: t, vm: vm)).toList(),
            ),
            _TagCategory(
              label: 'Growth',
              icon: LucideIcons.trendingUp,
              children: PersonalGrowthTags.all.map((t) => _GrowthFilterChip(tag: t, vm: vm)).toList(),
            ),
            if (vm.availableCustomTags.isNotEmpty)
              _TagCategory(
                label: 'Custom',
                icon: LucideIcons.tag,
                children: vm.availableCustomTags.map((t) => _CustomFilterChip(tag: t, vm: vm)).toList(),
              ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tag category row (horizontal scroll)
// ─────────────────────────────────────────────────────────────────────────────

class _TagCategory extends StatelessWidget {
  const _TagCategory({required this.label, required this.icon, required this.children});

  final String label;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
            child: Row(
              children: [
                Icon(icon, size: 14, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: children.map((c) => Padding(padding: const EdgeInsets.only(right: 6), child: c)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Filter chips
// ─────────────────────────────────────────────────────────────────────────────

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.activeColor,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effective = selected ? activeColor : colors.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: 0.15) : colors.surfaceContainerHighest,
          border: Border.all(color: selected ? activeColor : colors.outlineVariant, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: effective),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: effective,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BaseTagChip extends StatelessWidget {
  const _BaseTagChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.leadingIcon,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : colors.surfaceContainerHighest,
          border: Border.all(color: selected ? color : colors.outlineVariant, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 13, color: selected ? color : colors.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? color : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodFilterChip extends StatelessWidget {
  const _MoodFilterChip({required this.tag, required this.vm});

  final MoodTag tag;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) => _BaseTagChip(
    label: '${tag.emoji} ${tag.label}',
    selected: vm.selectedMoodIds.contains(tag.id),
    color: tag.color,
    onTap: () => vm.toggleMoodTag(tag.id),
  );
}

class _ActivityFilterChip extends StatelessWidget {
  const _ActivityFilterChip({required this.tag, required this.vm});

  final ActivityTag tag;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) => _BaseTagChip(
    label: tag.label,
    selected: vm.selectedActivityIds.contains(tag.id),
    color: tag.color,
    leadingIcon: tag.icon,
    onTap: () => vm.toggleActivityTag(tag.id),
  );
}

class _TimeFilterChip extends StatelessWidget {
  const _TimeFilterChip({required this.tag, required this.vm});

  final TimeTag tag;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) => _BaseTagChip(
    label: tag.label,
    selected: vm.selectedTimeIds.contains(tag.id),
    color: tag.color,
    leadingIcon: tag.icon,
    onTap: () => vm.toggleTimeTag(tag.id),
  );
}

class _GrowthFilterChip extends StatelessWidget {
  const _GrowthFilterChip({required this.tag, required this.vm});

  final PersonalGrowthTag tag;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) => _BaseTagChip(
    label: tag.label,
    selected: vm.selectedGrowthIds.contains(tag.id),
    color: tag.color,
    leadingIcon: tag.icon,
    onTap: () => vm.toggleGrowthTag(tag.id),
  );
}

class _CustomFilterChip extends StatelessWidget {
  const _CustomFilterChip({required this.tag, required this.vm});

  final CustomTag tag;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) => _BaseTagChip(
    label: tag.name,
    selected: vm.selectedCustomTagIds.contains(tag.id),
    color: tag.displayColor,
    onTap: () => vm.toggleCustomTag(tag.id),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Results header
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader(this.vm);

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = vm.resultCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            count == 0
                ? 'No notes found'
                : count == 1
                ? '1 note'
                : '$count notes',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          if (vm.hasActiveFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Filtered',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.onPrimaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Results list
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  const _ResultsList(this.vm);

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final notes = vm.filteredNotes;
    if (notes.isEmpty) return _EmptyState(vm: vm);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _SearchResultCard(note: notes[index], vm: vm),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Single result card
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.note, required this.vm});

  final Note note;
  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highlightStyle = TextStyle(
      backgroundColor: colors.primaryContainer,
      color: colors.onPrimaryContainer,
      fontWeight: FontWeight.w700,
    );
    final titleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600);
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(color: colors.onSurfaceVariant);

    final previewText = _buildPreview();
    final titleSpans = vm.buildHighlightSpans(note.title, titleStyle, highlightStyle);
    final previewSpans = previewText.isNotEmpty
        ? vm.buildHighlightSpans(previewText, subtitleStyle, highlightStyle)
        : <TextSpan>[];

    return TrovaraCard(
      onTap: () => context.push('/note?noteId=${note.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + favourite
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(children: titleSpans),
                ),
              ),
              if (note.isFavorite) ...[
                const SizedBox(width: 6),
                Icon(Icons.favorite_rounded, size: 16, color: Colors.red.withValues(alpha: 0.8)),
              ],
            ],
          ),

          // Content preview
          if (previewSpans.isNotEmpty) ...[
            const SizedBox(height: 4),
            RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(children: previewSpans),
            ),
          ],

          // Compact tag row
          if (_hasAnyTag()) ...[const SizedBox(height: 8), _CompactTagRow(note: note)],

          // Date
          const SizedBox(height: 8),
          Text(
            _formatDate(note.updatedAt),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  bool _hasAnyTag() =>
      note.moodTags.isNotEmpty ||
      note.activityTags.isNotEmpty ||
      note.timeTags.isNotEmpty ||
      note.personalGrowthTags.isNotEmpty ||
      note.customTagIds.isNotEmpty;

  String _buildPreview() {
    final full = TextParserService.parseQuillContent(note.contentJson);
    final q = vm.query.trim();

    if (q.isEmpty) return _truncate(full, 120);

    final idx = full.toLowerCase().indexOf(q.toLowerCase());
    if (idx == -1) return _truncate(full, 120);

    // Centre a window around the match so the highlighted text is visible.
    const window = 100;
    final start = (idx - window ~/ 2).clamp(0, full.length).toInt();
    final end = (start + window).clamp(0, full.length).toInt();
    final prefix = start > 0 ? '…' : '';
    final suffix = end < full.length ? '…' : '';
    return '$prefix${full.substring(start, end)}$suffix';
  }

  String _truncate(String text, int max) => text.length <= max ? text : '${text.substring(0, max)}…';

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Compact tag strip inside result card
// ─────────────────────────────────────────────────────────────────────────────

class _CompactTagRow extends StatelessWidget {
  const _CompactTagRow({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    for (final id in note.moodTags.take(2)) {
      final tag = MoodTags.getById(id);
      if (tag != null) chips.add(_MiniChip(label: tag.emoji, color: tag.color));
    }
    for (final id in note.activityTags.take(2)) {
      final tag = ActivityTags.getById(id);
      if (tag != null) chips.add(_MiniChip(label: tag.label, color: tag.color, icon: tag.icon));
    }
    for (final id in note.timeTags.take(1)) {
      final tag = TimeTags.getById(id);
      if (tag != null) chips.add(_MiniChip(label: tag.label, color: tag.color, icon: tag.icon));
    }
    for (final id in note.personalGrowthTags.take(1)) {
      final tag = PersonalGrowthTags.getById(id);
      if (tag != null) chips.add(_MiniChip(label: tag.label, color: tag.color, icon: tag.icon));
    }

    final total =
        note.moodTags.length +
        note.activityTags.length +
        note.timeTags.length +
        note.personalGrowthTags.length +
        note.customTagIds.length;
    if (total > chips.length) {
      final colors = Theme.of(context).colorScheme;
      chips.add(_MiniChip(label: '+${total - chips.length}', color: colors.onSurfaceVariant));
    }

    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 2)],
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w500, fontSize: 10),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.vm});

  final SearchViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasFilters = vm.hasActiveFilters;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? LucideIcons.funnelX : LucideIcons.search,
              size: 56,
              color: colors.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No notes match these filters' : 'Start typing to search',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: vm.clearAllFilters,
                icon: const Icon(LucideIcons.x, size: 16),
                label: const Text('Clear all filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(10)),
      child: Text(
        '$count',
        style: TextStyle(color: colors.onPrimary, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
