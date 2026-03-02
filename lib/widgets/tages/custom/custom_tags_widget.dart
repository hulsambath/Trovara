import 'package:flutter/material.dart';
import 'package:trovara/models/custom_tag.dart';

/// Widget for managing custom tags with text input and removable chips
/// Supports both string-based tags (for backward compatibility) and CustomTag objects
class CustomTagsWidget extends StatefulWidget {
  // For backward compatibility - use either selectedTags OR selectedCustomTags
  final List<String>? selectedTags;
  final Function(List<String>)? onTagsChanged;

  // New CustomTag-based approach
  final List<CustomTag>? selectedCustomTags;
  final Function(List<CustomTag>)? onCustomTagsChanged;

  final String? hintText;
  final int maxTags;
  final bool enabled;
  final List<CustomTag>? availableTags; // For suggestions

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
    final trimmedTag = tagText.trim();
    if (trimmedTag.isEmpty) return;

    if (_isCustomTagMode) {
      _addCustomTag(trimmedTag);
    } else {
      _addStringTag(trimmedTag);
    }
  }

  void _addStringTag(String trimmedTag) {
    final selectedTags = widget.selectedTags!;

    // Check if tag already exists
    if (selectedTags.contains(trimmedTag)) {
      _showDuplicateTagSnackBar();
      return;
    }

    // Check max tags limit
    if (selectedTags.length >= widget.maxTags) {
      _showMaxTagsSnackBar();
      return;
    }

    // Add the tag
    final newTags = List<String>.from(selectedTags)..add(trimmedTag);
    widget.onTagsChanged!(newTags);
    _textController.clear();
  }

  void _addCustomTag(String trimmedTag) {
    final selectedCustomTags = widget.selectedCustomTags!;

    // Check if tag already exists in selected tags
    if (selectedCustomTags.any((tag) => tag.name.toLowerCase() == trimmedTag.toLowerCase())) {
      _showDuplicateTagSnackBar();
      return;
    }

    // Check max tags limit
    if (selectedCustomTags.length >= widget.maxTags) {
      _showMaxTagsSnackBar();
      return;
    }

    // Create new tag or find existing one
    final existingTag =
        widget.availableTags?.firstWhere(
          (tag) => tag.name.toLowerCase() == trimmedTag.toLowerCase(),
          orElse: () => CustomTag.create(trimmedTag),
        ) ??
        CustomTag.create(trimmedTag);

    // Add the tag
    final newTags = List<CustomTag>.from(selectedCustomTags)..add(existingTag);
    widget.onCustomTagsChanged!(newTags);
    _textController.clear();
    _hideSuggestions();
  }

  void _removeTag(dynamic tag) {
    if (_isCustomTagMode) {
      final newTags = List<CustomTag>.from(widget.selectedCustomTags!)..remove(tag);
      widget.onCustomTagsChanged!(newTags);
    } else {
      final newTags = List<String>.from(widget.selectedTags!)..remove(tag);
      widget.onTagsChanged!(newTags);
    }
  }

  void _selectSuggestion(CustomTag tag) {
    if (!_isCustomTagMode) return;

    final selectedCustomTags = widget.selectedCustomTags!;

    if (selectedCustomTags.any((selectedTag) => selectedTag.id == tag.id)) {
      _showDuplicateTagSnackBar();
      return;
    }

    if (selectedCustomTags.length >= widget.maxTags) {
      _showMaxTagsSnackBar();
      return;
    }

    final newTags = List<CustomTag>.from(selectedCustomTags)..add(tag);
    widget.onCustomTagsChanged!(newTags);
    _textController.clear();
    _hideSuggestions();
  }

  void _updateSuggestions(String query) {
    if (!_isCustomTagMode || query.isEmpty) {
      _hideSuggestions();
      return;
    }

    final availableTags = widget.availableTags ?? [];
    final filteredSuggestions = availableTags
        .where(
          (tag) =>
              tag.name.toLowerCase().contains(query.toLowerCase()) &&
              !widget.selectedCustomTags!.any((selectedTag) => selectedTag.id == tag.id),
        )
        .toList();

    setState(() {
      _suggestions = filteredSuggestions.take(5).toList();
      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  void _hideSuggestions() {
    setState(() {
      _showSuggestions = false;
      _suggestions.clear();
    });
  }

  void _showDuplicateTagSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tag already exists'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showMaxTagsSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum ${widget.maxTags} tags allowed'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_hasAvailableTags) ...[_buildExistingTagsSection(context), const SizedBox(height: 16)],

      if (widget.enabled) ...[
        TextField(
          controller: _textController,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'Add custom tag...',
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addTag(_textController.text),

              tooltip: 'Add tag',
            ),
            border: const OutlineInputBorder(),
          ),
          onTapUpOutside: (event) => _focusNode.unfocus(),
          onSubmitted: _addTag,
          onChanged: _updateSuggestions,
          onTap: () {
            if (_textController.text.isNotEmpty) {
              _updateSuggestions(_textController.text);
            }
          },

          textInputAction: TextInputAction.done,
          maxLength: 50,
          buildCounter: (context, {required currentLength, maxLength, required isFocused}) => Text(
            '$currentLength/$maxLength',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),

        if (_isCustomTagMode && _showSuggestions && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: _suggestions
                  .map(
                    (tag) => ListTile(
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: tag.displayColor, shape: BoxShape.circle),
                      ),
                      title: Text(tag.name),
                      subtitle: tag.usageCount > 0 ? Text('Used ${tag.usageCount} times') : null,
                      onTap: () => _selectSuggestion(tag),
                      dense: true,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],

        const SizedBox(height: 8),
      ],

      if (_hasSelectedTags) ...[
        _buildSelectedTagsSection(context),
      ] else if (widget.enabled) ...[
        Text(
          'No custom tags added yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ],
  );

  bool get _hasSelectedTags {
    if (_isCustomTagMode) {
      return widget.selectedCustomTags!.isNotEmpty;
    } else {
      return widget.selectedTags!.isNotEmpty;
    }
  }

  bool get _hasAvailableTags => widget.availableTags != null && widget.availableTags!.isNotEmpty;

  List<Widget> _buildTagChips() {
    if (_isCustomTagMode) {
      return widget.selectedCustomTags!.map((tag) => _buildCustomTagChip(tag)).toList();
    } else {
      return widget.selectedTags!.map((tag) => _buildStringTagChip(tag)).toList();
    }
  }

  Widget _buildExistingTagsSection(BuildContext context) {
    final availableTags = widget.availableTags!;
    final selectedTagIds = _isCustomTagMode ? widget.selectedCustomTags!.map((tag) => tag.id).toSet() : <int>{};

    // Filter out already selected tags
    final unselectedTags = availableTags.where((tag) => !selectedTagIds.contains(tag.id)).toList();

    if (unselectedTags.isEmpty) {
      return const SizedBox.shrink();
    }

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
          children: unselectedTags.map((tag) => _buildExistingTagChip(context, tag)).toList(),
        ),
      ],
    );
  }

  Widget _buildSelectedTagsSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Theme.of(context).colorScheme.primary),
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

  Widget _buildExistingTagChip(BuildContext context, CustomTag tag) => InkWell(
    onTap: () => _selectSuggestion(tag),
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tag.displayColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tag.displayColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tag.displayColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            tag.name,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tag.displayColor, fontWeight: FontWeight.w500),
          ),
          if (tag.usageCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '(${tag.usageCount})',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tag.displayColor.withValues(alpha: 0.7), fontSize: 10),
            ),
          ],
          const SizedBox(width: 4),
          Icon(Icons.add, size: 14, color: tag.displayColor),
        ],
      ),
    ),
  );

  Widget _buildStringTagChip(String tag) => Chip(
    label: Text(tag, style: Theme.of(context).textTheme.bodySmall),
    deleteIcon: widget.enabled ? const Icon(Icons.close, size: 18) : null,
    onDeleted: widget.enabled ? () => _removeTag(tag) : null,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
    deleteIconColor: Theme.of(context).colorScheme.onPrimaryContainer,
  );

  Widget _buildCustomTagChip(CustomTag tag) => Chip(
    label: Text(tag.name, style: Theme.of(context).textTheme.bodySmall),
    deleteIcon: widget.enabled ? const Icon(Icons.close, size: 18) : null,
    onDeleted: widget.enabled ? () => _removeTag(tag) : null,
    backgroundColor: tag.displayColor.withValues(alpha: 0.2),
    labelStyle: TextStyle(color: tag.displayColor, fontWeight: FontWeight.w500),
    deleteIconColor: tag.displayColor,
  );
}

/// Compact version for displaying custom tags in note cards
/// Supports both string-based tags (for backward compatibility) and CustomTag objects
class CompactCustomTagsWidget extends StatelessWidget {
  // For backward compatibility
  final List<String>? selectedTags;

  // New CustomTag-based approach
  final List<CustomTag>? selectedCustomTags;

  final int maxDisplay;

  const CompactCustomTagsWidget({super.key, this.selectedTags, this.selectedCustomTags, this.maxDisplay = 3})
    : assert(
        selectedTags != null || selectedCustomTags != null,
        'Either selectedTags OR selectedCustomTags must be provided',
      );

  bool get _isCustomTagMode => selectedCustomTags != null;

  @override
  Widget build(BuildContext context) {
    final tags = _isCustomTagMode ? selectedCustomTags! : selectedTags!;

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayedTags = tags.take(maxDisplay).toList();
    final remainingCount = tags.length - maxDisplay;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...displayedTags.map((tag) => _buildCompactChip(context, tag)),
        if (remainingCount > 0) _buildMoreChip(context, remainingCount),
      ],
    );
  }

  Widget _buildCompactChip(BuildContext context, dynamic tag) {
    if (_isCustomTagMode) {
      return _buildCustomTagCompactChip(context, tag as CustomTag);
    } else {
      return _buildStringCompactChip(context, tag as String);
    }
  }

  Widget _buildStringCompactChip(BuildContext context, String tag) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Text(
      tag,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSecondaryContainer, fontSize: 11),
    ),
  );

  Widget _buildCustomTagCompactChip(BuildContext context, CustomTag tag) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: tag.displayColor.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: tag.displayColor.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Text(
      tag.name,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: tag.displayColor, fontSize: 11, fontWeight: FontWeight.w500),
    ),
  );

  Widget _buildMoreChip(BuildContext context, int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Text(
      '+$count',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
