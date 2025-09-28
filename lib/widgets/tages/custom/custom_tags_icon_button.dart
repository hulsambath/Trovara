import 'package:flutter/material.dart';
import 'package:noteminds/constants/device_constants.dart';
import 'package:noteminds/core/di/service_locator.dart';
import 'package:noteminds/core/services/custom_tag_service.dart';
import 'package:noteminds/models/custom_tag.dart';
import 'package:noteminds/widgets/tages/custom/custom_tags_widget.dart';

/// Icon button for the app bar to manage custom tags
class CustomTagsIconButton extends StatelessWidget {
  final List<String> selectedTags;
  final Function(List<String>) onSelectionChanged;

  const CustomTagsIconButton({super.key, required this.selectedTags, required this.onSelectionChanged});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Stack(
      children: [
        const Icon(Icons.label_outline),
        if (selectedTags.isNotEmpty)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${selectedTags.length}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
    onPressed: () => _showCustomTagsDialog(context),
    tooltip: 'Custom Tags (${selectedTags.length})',
  );

  void _showCustomTagsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CustomTagsDialog(selectedTags: selectedTags, onTagsChanged: onSelectionChanged),
    );
  }
}

/// Dialog for managing custom tags
class _CustomTagsDialog extends StatefulWidget {
  final List<String> selectedTags;
  final Function(List<String>) onTagsChanged;

  const _CustomTagsDialog({required this.selectedTags, required this.onTagsChanged});

  @override
  State<_CustomTagsDialog> createState() => _CustomTagsDialogState();
}

class _CustomTagsDialogState extends State<_CustomTagsDialog> {
  late List<CustomTag> _currentCustomTags;

  final CustomTagService _customTagService = ServiceLocator().customTagService;

  @override
  void initState() {
    super.initState();
    // Convert string tags to CustomTag objects
    _currentCustomTags = _convertStringTagsToCustomTags(widget.selectedTags);
  }

  List<CustomTag> _convertStringTagsToCustomTags(List<String> stringTags) {
    final List<CustomTag> customTags = [];
    final availableTags = _customTagService.getAllCustomTags();

    for (final tagName in stringTags) {
      // Try to find existing custom tag
      final existingTag = availableTags.firstWhere(
        (tag) => tag.name.toLowerCase() == tagName.toLowerCase(),
        orElse: () => CustomTag.create(tagName),
      );
      customTags.add(existingTag);
    }

    return customTags;
  }

  void _updateCustomTags(List<CustomTag> newCustomTags) {
    setState(() {
      _currentCustomTags = newCustomTags;
    });
  }

  /// Get available custom tags for suggestions
  List<CustomTag> getAvailableCustomTags() => _customTagService.getAllCustomTags();

  void _saveAndClose() {
    // Convert CustomTag objects back to strings for the callback
    final tagNames = _currentCustomTags.map((tag) => tag.name).toList();
    widget.onTagsChanged(tagNames);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Icon(Icons.label_outline),
        const SizedBox(width: 8),
        const Text('Custom Tags'),
        const Spacer(),
        Text(
          '${_currentCustomTags.length}/20',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
    content: SizedBox(
      width: double.maxFinite,
      height: DeviceConstants.screenHeight(context) * 0.25, // Fixed height to accommodate the enhanced widget
      child: CustomTagsWidget(
        selectedCustomTags: _currentCustomTags,
        onCustomTagsChanged: _updateCustomTags,
        availableTags: getAvailableCustomTags(),
        hintText: 'Type a tag and press Enter or click +',
        maxTags: 20,
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(onPressed: _saveAndClose, child: const Text('Save')),
    ],
  );
}
