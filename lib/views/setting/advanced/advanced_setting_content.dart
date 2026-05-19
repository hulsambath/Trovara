part of 'advanced_setting_view.dart';

class _AdvancedSettingContent extends StatelessWidget {
  const _AdvancedSettingContent(this.viewModel);

  final AdvancedSettingViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Advanced'), surfaceTintColor: Colors.transparent),
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ── Export ────────────────────────────────────────────────────────────
        _buildSectionLabel(context, 'Export'),
        const SizedBox(height: 8),
        TrovaraCard(
          child: ListTile(
            leading: Icon(LucideIcons.fileText, color: Theme.of(context).colorScheme.primary),
            title: const Text('Export as Markdown'),
            subtitle: const Text('Obsidian-compatible .md file with YAML frontmatter'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => viewModel.exportAsMarkdown(context),
          ),
        ),
        const SizedBox(height: 16),

        // ── Import from another app ───────────────────────────────────────────
        _buildSectionLabel(context, 'Import from another app'),
        const SizedBox(height: 8),
        _buildImportInfoBanner(context),
        const SizedBox(height: 8),
        TrovaraCard(
          child: Column(
            children: [
              ListTile(
                leading: _buildPlatformIcon(context, icon: LucideIcons.diamond, color: const Color(0xFF7E56C2)),
                title: const Text('From Obsidian'),
                subtitle: const Text('Select .md files from your vault'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => viewModel.importFromObsidian(context),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: _buildPlatformIcon(
                  context,
                  icon: LucideIcons.fileText,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                ),
                title: const Text('From Notion'),
                subtitle: const Text('Select exported files from Notion'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => viewModel.importFromNotion(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── AI Search ─────────────────────────────────────────────────────────
        _buildSectionLabel(context, 'AI Search'),
        const SizedBox(height: 8),
        TrovaraCard(
          child: ListTile(
            leading: Icon(LucideIcons.refreshCw, color: Theme.of(context).colorScheme.primary),
            title: const Text('Re-index all notes'),
            subtitle: const Text('Fixes missing search results by rebuilding the search index'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => viewModel.reembedAllNotes(context),
          ),
        ),
        const SizedBox(height: kToolbarHeight * 2),
      ],
    ),
  );

  Widget _buildSectionLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 2),
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _buildPlatformIcon(BuildContext context, {required IconData icon, required Color color}) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
    child: Icon(icon, color: color, size: 20),
  );

  Widget _buildImportInfoBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Imports are non-destructive — existing notes are only updated when '
              'the imported version is newer. Deleted notes are never re-imported.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
