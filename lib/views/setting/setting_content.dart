part of 'setting_view.dart';

class _SettingContent extends StatelessWidget {
  const _SettingContent(this.viewModel);

  final SettingViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Setting'), surfaceTintColor: Colors.transparent),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User Profile Section
        if (viewModel.isSignedIn) ...[
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
                    icon: const Icon(Icons.logout, weight: 4),
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign in to Google'),
              onTap: () => viewModel.signInGoogle(context),
            ),
          ),
          const SizedBox(height: 16),
        ],
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
        const SizedBox(height: 16),
        if (viewModel.isSignedIn) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: SvgPicture.asset(Assets.icons.googleDrive, width: 24, height: 24),
                    title: const Text('Sync with Google Drive'),
                    subtitle: const Text('Backup and restore data'),
                    trailing: const Icon(Icons.sync),
                    onTap: () => viewModel.syncWithGoogleDrive(context),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('Local Export/Import', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Export to file'),
                onTap: () => viewModel.exportToFile(context),
              ),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: const Text('Import from file'),
                onTap: () => viewModel.importFromFile(context),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
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
