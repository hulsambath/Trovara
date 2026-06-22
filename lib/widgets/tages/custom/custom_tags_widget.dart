import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trovara/models/custom_tag.dart';

export 'compact_custom_tags_widget.dart';

part 'widgets/custom_tag_chips.dart';

/// Widget for managing custom tags with text input and removable chips.
/// Supports both string-based tags (for backward compatibility) and CustomTag objects.
class CustomTagsWidget extends StatefulWidget {
  final List<String>? selectedTags;
  final Function(List<String>)? onTagsChanged;
  final List<CustomTag>? selectedCustomTags;
  final Function(List<CustomTag>)? onCustomTagsChanged;
  final String? hintText;
  final int maxTags;
  final bool enabled;
  final List<CustomTag>? availableTags;

  const CustomTagsWidget({
    super.key,
    this.selectedTags,
    this.onTagsChanged,
    this.selectedCustomTags,
    this.onCustomTagsChanged,
    this.hintText,
    this.maxTags = 20,
    this.enabled = true,
    this.availableTags,
  }) : assert(
         (selectedTags != null && onTagsChanged != null) || (selectedCustomTags != null && onCustomTagsChanged != null),
         'Either selectedTags/onTagsChanged OR selectedCustomTags/onCustomTagsChanged must be provided',
       );

  @override
  State<CustomTagsWidget> createState() => _CustomTagsWidgetState();
}

class _CustomTagsWidgetState extends State<CustomTagsWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<CustomTag> _suggestions = [];
  bool _showSuggestions = false;

  bool get _isCustomTagMode => widget.selectedCustomTags != null;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTag(String tagText) {
    final trimmed = tagText.trim();
    if (trimmed.isEmpty) return;
    _isCustomTagMode ? _addCustomTag(trimmed) : _addStringTag(trimmed);
  }

  void _addStringTag(String trimmed) {
    final tags = widget.selectedTags!;
    if (tags.contains(trimmed)) { _showDuplicateSnackBar(); return; }
    if (tags.length >= widget.maxTags) { _showMaxTagsSnackBar(); return; }
    widget.onTagsChanged!(List<String>.from(tags)..add(trimmed));
    _textController.clear();
  }

  void _addCustomTag(String trimmed) {
    final tags = widget.selectedCustomTags!;
    if (tags.any((t) => t.name.toLowerCase() == trimmed.toLowerCase())) { _showDuplicateSnackBar(); return; }
    if (tags.length >= widget.maxTags) { _showMaxTagsSnackBar(); return; }
    final tag = widget.availableTags?.firstWhere(
          (t) => t.name.toLowerCase() == trimmed.toLowerCase(),
          orElse: () => CustomTag.create(trimmed),
        ) ??
        CustomTag.create(trimmed);
    widget.onCustomTagsChanged!(List<CustomTag>.from(tags)..add(tag));
    _textController.clear();
    _hideSuggestions();
  }

  void _removeTag(dynamic tag) {
    if (_isCustomTagMode) {
      widget.onCustomTagsChanged!(List<CustomTag>.from(widget.selectedCustomTags!)..remove(tag));
    } else {
      widget.onTagsChanged!(List<String>.from(widget.selectedTags!)..remove(tag));
    }
  }

  void _selectSuggestion(CustomTag tag) {
    if (!_isCustomTagMode) return;
    final tags = widget.selectedCustomTags!;
    if (tags.any((t) => t.id == tag.id)) { _showDuplicateSnackBar(); return; }
    if (tags.length >= widget.maxTags) { _showMaxTagsSnackBar(); return; }
    widget.onCustomTagsChanged!(List<CustomTag>.from(tags)..add(tag));
    _textController.clear();
    _hideSuggestions();
  }

  void _updateSuggestions(String query) {
    if (!_isCustomTagMode || query.isEmpty) { _hideSuggestions(); return; }
    final filtered = (widget.availableTags ?? [])
        .where((t) =>
            t.name.toLowerCase().contains(query.toLowerCase()) &&
            !widget.selectedCustomTags!.any((s) => s.id == t.id))
        .take(5)
        .toList();
    setState(() {
      _suggestions = filtered;
      _showSuggestions = filtered.isNotEmpty;
    });
  }

  void _hideSuggestions() => setState(() { _showSuggestions = false; _suggestions.clear(); });

  void _showDuplicateSnackBar() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Tag already exists'), duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating, margin: EdgeInsets.all(16)),
  );

  void _showMaxTagsSnackBar() => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Maximum ${widget.maxTags} tags allowed'), duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16)),
  );

  bool get _hasSelectedTags =>
      _isCustomTagMode ? widget.selectedCustomTags!.isNotEmpty : widget.selectedTags!.isNotEmpty;

  bool get _hasAvailableTags => widget.availableTags != null && widget.availableTags!.isNotEmpty;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_hasAvailableTags) ...[_buildExistingTagsSection(context), const SizedBox(height: 16)],
      if (widget.enabled) ...[_buildInput(context), const SizedBox(height: 8)],
      if (_hasSelectedTags)
        _buildSelectedTagsSection(context)
      else if (widget.enabled)
        Text(
          'No custom tags added yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
    ],
  );

  Widget _buildInput(BuildContext context) => Column(
    children: [
      TextField(
        controller: _textController,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Add custom tag...',
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          suffixIcon: IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _addTag(_textController.text),
            tooltip: 'Add tag',
          ),
          border: const OutlineInputBorder(),
        ),
        onTapUpOutside: (event) => _focusNode.unfocus(),
        onSubmitted: _addTag,
        onChanged: _updateSuggestions,
        onTap: () { if (_textController.text.isNotEmpty) _updateSuggestions(_textController.text); },
        textInputAction: TextInputAction.done,
        maxLength: 50,
        buildCounter: (context, {required currentLength, maxLength, required isFocused}) => Text(
          '$currentLength/$maxLength',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      if (_isCustomTagMode && _showSuggestions && _suggestions.isNotEmpty) ...[
        const SizedBox(height: 4),
        _buildSuggestionsDropdown(context),
      ],
    ],
  );

  Widget _buildSuggestionsDropdown(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: _suggestions
          .map((tag) => ListTile(
                leading: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: tag.displayColor, shape: BoxShape.circle),
                ),
                title: Text(tag.name),
                subtitle: tag.usageCount > 0 ? Text('Used ${tag.usageCount} times') : null,
                onTap: () => _selectSuggestion(tag),
                dense: true,
              ))
          .toList(),
    ),
  );

  Widget _buildExistingTagsSection(BuildContext context) {
    final available = widget.availableTags!;
    final selectedIds = _isCustomTagMode ? widget.selectedCustomTags!.map((t) => t.id).toSet() : <int>{};
    final unselected = available.where((t) => !selectedIds.contains(t.id)).toList();
    if (unselected.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existing Tags',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: unselected.map((t) => _ExistingTagChip(tag: t, onTap: () => _selectSuggestion(t))).toList(),
        ),
      ],
    );
  }

  Widget _buildSelectedTagsSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(LucideIcons.circleCheck, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Selected Tags',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: _buildTagChips()),
    ],
  );

  List<Widget> _buildTagChips() {
    if (_isCustomTagMode) {
      return widget.selectedCustomTags!
          .map((t) => _CustomTagChip(tag: t, enabled: widget.enabled, onDelete: () => _removeTag(t)))
          .toList();
    }
    return widget.selectedTags!
        .map((t) => _StringTagChip(tag: t, enabled: widget.enabled, onDelete: () => _removeTag(t)))
        .toList();
  }
}
