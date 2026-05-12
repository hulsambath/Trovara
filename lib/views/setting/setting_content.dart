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
        // ── Account ───────────────────────────────────────────────────────────
        _buildSectionLabel(context, 'Account'),
        const SizedBox(height: 8),
        if (viewModel.isSignedIn)
          TrovaraCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  viewModel.accountPhotoUrl != null
                      ? CircleAvatar(backgroundImage: NetworkImage(viewModel.accountPhotoUrl!), radius: 32)
                      : CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          radius: 32,
                          child: Icon(LucideIcons.user, color: Theme.of(context).colorScheme.onPrimary, size: 32),
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
                    icon: const Icon(LucideIcons.logOut),
                    onPressed: () => _showLogoutConfirmationDialog(context),
                    tooltip: 'Sign out',
                  ),
                ],
              ),
            ),
          )
        else
          TrovaraCard(
            child: ListTile(
              leading: const Icon(LucideIcons.logIn),
              title: const Text('Sign in with Google'),
              subtitle: const Text('Sync your notes across devices'),
              onTap: () => viewModel.signInGoogle(context),
            ),
          ),
        const SizedBox(height: 16),

        // ── Appearance ────────────────────────────────────────────────────────
        _buildSectionLabel(context, 'Appearance'),
        const SizedBox(height: 8),
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) => TrovaraCard(
            child: ListTile(
              leading: Icon(
                themeProvider.isDarkMode() ? LucideIcons.moon : LucideIcons.sun,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(themeProvider.isDarkMode() ? 'Dark mode' : 'Light mode'),
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
                TrovaraCard(
                  child: ListTile(
                    leading: Icon(LucideIcons.palette, color: Theme.of(context).colorScheme.primary),
                    title: const Text('App icon'),
                    subtitle: const Text('Change the icon on your home screen'),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => _showAppIconPicker(context),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // ── Backup & Sync ─────────────────────────────────────────────────────
        _buildSectionLabel(context, 'Backup & Sync'),
        const SizedBox(height: 8),
        TrovaraCard(
          child: Column(
            children: [
              if (viewModel.isSignedIn) ...[
                ListTile(
                  leading: SvgPicture.asset('assets/icons/google drive.svg', width: 24, height: 24),
                  title: const Text('Sync with Google Drive'),
                  subtitle: const Text('Keep your notes safe and up to date'),
                  trailing: const Icon(LucideIcons.refreshCw),
                  onTap: () => viewModel.syncWithGoogleDrive(context),
                ),
                const Divider(height: 1, indent: 56),
              ],
              ListTile(
                leading: Icon(LucideIcons.hardDriveDownload, color: Theme.of(context).colorScheme.primary),
                title: const Text('Back up your notes'),
                subtitle: const Text('Save a copy of all your notes to your device'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => viewModel.exportToFile(context),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(LucideIcons.hardDriveUpload, color: Theme.of(context).colorScheme.primary),
                title: const Text('Restore from backup'),
                subtitle: const Text('Load notes from a previous backup'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => viewModel.importFromFile(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Notes ─────────────────────────────────────────────────────────────
        _buildSectionLabel(context, 'Notes'),
        const SizedBox(height: 8),
        TrovaraCard(
          child: ListTile(
            leading: const Icon(LucideIcons.trash2),
            title: const Text('Recently Deleted'),
            subtitle: const Text('Notes are kept for 30 days before being removed'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => viewModel.openRecentlyDeleted(context),
          ),
        ),
        const SizedBox(height: 16),

        // ── Advanced ──────────────────────────────────────────────────────────
        TrovaraCard(
          child: ListTile(
            leading: Icon(LucideIcons.settings2, color: Theme.of(context).colorScheme.onSurfaceVariant),
            title: const Text('Advanced'),
            subtitle: const Text('Export formats, import from other apps, AI search'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => viewModel.openAdvancedSettings(context),
          ),
        ),
        const SizedBox(height: 32),

        // ── Version ───────────────────────────────────────────────────────────
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (snapshot.data == null) return const SizedBox.shrink();
            final info = snapshot.data!;
            final ver = '${info.version}+${info.buildNumber}';
            return Center(
              child: Text(
                'Trovara $ver',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            );
          },
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
                          : const Icon(LucideIcons.image),
                      title: Text(label ?? identifier ?? ''),
                      trailing: isSelected
                          ? Icon(LucideIcons.circleCheck, color: Theme.of(context).colorScheme.primary)
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
