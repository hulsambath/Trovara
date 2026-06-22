part of '../search_view.dart';

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
