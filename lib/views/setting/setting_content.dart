part of 'setting_view.dart';

class _SettingContent extends StatelessWidget {
  const _SettingContent(this.viewModel);

  final SettingViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings'), surfaceTintColor: Colors.transparent),
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ── User Profile ───────────────────────────────────────────────────
        if (viewModel.isSignedIn) ...[
          _buildSectionLabel(context, 'Account'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  viewModel.accountPhotoUrl != null
                      ? CircleAvatar(backgroundImage: NetworkImage(viewModel.accountPhotoUrl!), radius: 32)
                      : CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          radius: 32,
                          child: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary, size: 32),
                        ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          viewModel.accountName ?? 'Google User',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          viewModel.accountEmail ?? '',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    icon: const Icon(Icons.logout),
                    onPressed: () => _showLogoutConfirmationDialog(context),
                    tooltip: 'Sign out',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (!viewModel.isSignedIn) ...[
          _buildSectionLabel(context, 'Account'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign in to Google'),
              onTap: () => viewModel.signInGoogle(context),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Appearance ─────────────────────────────────────────────────────
        _buildSectionLabel(context, 'Appearance'),
        const SizedBox(height: 8),
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) => Card(
            child: ListTile(
              leading: Icon(
                themeProvider.isDarkMode() ? Icons.dark_mode : Icons.light_mode,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Theme Mode'),
              subtitle: Text(themeProvider.isDarkMode() ? 'Dark' : 'Light'),
              trailing: Switch(
                value: themeProvider.isDarkMode(),
                onChanged: (v) => context.read<ThemeProvider>().setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
              ),
            ),
          ),
        ),
        FutureBuilder<bool>(
          future: AppIconService.isSupported,
          builder: (context, snapshot) {
            if (snapshot.data != true) return const SizedBox.shrink();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.palette_outlined, color: Theme.of(context).colorScheme.primary),
                    title: const Text('App Icon'),
                    subtitle: const Text('Change the app icon on your home screen'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAppIconPicker(context),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // ── Google Drive Sync ──────────────────────────────────────────────
        if (viewModel.isSignedIn) ...[
          _buildSectionLabel(context, 'Cloud Sync'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: SvgPicture.asset('assets/icons/google drive.svg', width: 24, height: 24),
              title: const Text('Sync with Google Drive'),
              subtitle: const Text('Backup and restore all notes'),
              trailing: const Icon(Icons.sync),
              onTap: () => viewModel.syncWithGoogleDrive(context),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Notes ──────────────────────────────────────────────────────────
        _buildSectionLabel(context, 'Notes'),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Recently Deleted'),
            subtitle: const Text('Notes here are kept for 30 days before being removed forever'),
            onTap: () => viewModel.openRecentlyDeleted(context),
          ),
        ),
        const SizedBox(height: 16),

        // ── Export ─────────────────────────────────────────────────────────
        _buildSectionLabel(context, 'Export'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.data_object, color: Theme.of(context).colorScheme.primary),
                title: const Text('Export as JSON'),
                subtitle: const Text('Full backup — import back into Trovara on any device'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => viewModel.exportToFile(context),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.text_snippet_outlined, color: Theme.of(context).colorScheme.primary),
                title: const Text('Export as Markdown'),
                subtitle: const Text('Obsidian-compatible .md file with YAML frontmatter'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => viewModel.exportAsMarkdown(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Import ─────────────────────────────────────────────────────────
        _buildSectionLabel(context, 'Import'),
        const SizedBox(height: 8),
        _buildImportInfoBanner(context),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              // Trovara JSON
              ListTile(
                leading: _buildPlatformIcon(
                  context,
                  icon: Icons.data_object,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Trovara backup (.json)'),
                subtitle: const Text('Restore from a previous Trovara export'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => viewModel.importFromFile(context),
              ),
              const Divider(height: 1, indent: 56),
              // Obsidian
              ListTile(
                leading: _buildPlatformIcon(context, icon: Icons.diamond_outlined, color: const Color(0xFF7E56C2)),
                title: const Text('Obsidian vault (.md files)'),
                subtitle: const Text('Select .md files from your vault — preserves [[wikilinks]] & tags'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => viewModel.importFromObsidian(context),
              ),
              const Divider(height: 1, indent: 56),
              // Notion
              ListTile(
                leading: _buildPlatformIcon(
                  context,
                  icon: Icons.article_outlined,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                ),
                title: const Text('Notion export (.md / .csv)'),
                subtitle: const Text('Select exported Markdown files from Notion'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => viewModel.importFromNotion(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Search Index ───────────────────────────────────────────────────
        _buildSectionLabel(context, 'Search Index'),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.manage_search, color: Theme.of(context).colorScheme.primary),
            title: const Text('Re-index all notes'),
            subtitle: const Text('Fixes missing AI search results by re-embedding all notes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => viewModel.reembedAllNotes(context),
          ),
        ),

        const SizedBox(height: kToolbarHeight * 2),
      ],
    ),
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

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
          Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
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

  // ── Dialogs / bottom sheets ────────────────────────────────────────────────

  void _showAppIconPicker(BuildContext context) {
    final details = AppIconService.getIconDetails();

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: FutureBuilder<String>(
          future: AppIconService.getCurrentIcon(),
          builder: (context, snapshot) {
            final currentIcon = snapshot.data ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      'App Icon',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  ...details.map((icon) {
                    final identifier = icon['identifier'];
                    final path = icon['path'];
                    final label = icon['label'];
                    final isSelected = identifier == currentIcon;
                    return ListTile(
                      leading: path != null && path.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(path, width: 48, height: 48, fit: BoxFit.cover),
                            )
                          : const Icon(Icons.image),
                      title: Text(label ?? identifier ?? ''),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () async {
                        if (identifier != null) {
                          await AppIconService.changeIcon(identifier);
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      },
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: <Widget>[
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Sign Out'),
            onPressed: () {
              Navigator.of(context).pop();
              viewModel.signOutGoogle(context);
            },
          ),
        ],
      ),
    );
  }
}
