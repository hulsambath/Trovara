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
