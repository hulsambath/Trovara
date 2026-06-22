part of '../custom_tags_widget.dart';

class _ExistingTagChip extends StatelessWidget {
  const _ExistingTagChip({required this.tag, required this.onTap});

  final CustomTag tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
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
          Container(width: 8, height: 8, decoration: BoxDecoration(color: tag.displayColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            tag.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tag.displayColor, fontWeight: FontWeight.w500),
          ),
          if (tag.usageCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '(${tag.usageCount})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tag.displayColor.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
          const SizedBox(width: 4),
          Icon(LucideIcons.plus, size: 14, color: tag.displayColor),
        ],
      ),
    ),
  );
}

class _StringTagChip extends StatelessWidget {
  const _StringTagChip({required this.tag, required this.enabled, required this.onDelete});

  final String tag;
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(tag, style: Theme.of(context).textTheme.bodySmall),
    deleteIcon: enabled ? const Icon(LucideIcons.x, size: 18) : null,
    onDeleted: enabled ? onDelete : null,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
    deleteIconColor: Theme.of(context).colorScheme.onPrimaryContainer,
  );
}

class _CustomTagChip extends StatelessWidget {
  const _CustomTagChip({required this.tag, required this.enabled, required this.onDelete});

  final CustomTag tag;
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(tag.name, style: Theme.of(context).textTheme.bodySmall),
    deleteIcon: enabled ? const Icon(LucideIcons.x, size: 18) : null,
    onDeleted: enabled ? onDelete : null,
    backgroundColor: tag.displayColor.withValues(alpha: 0.2),
    labelStyle: TextStyle(color: tag.displayColor, fontWeight: FontWeight.w500),
    deleteIconColor: tag.displayColor,
  );
}
