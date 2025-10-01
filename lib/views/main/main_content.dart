part of 'main_view.dart';

class _MainContent extends StatelessWidget {
  const _MainContent(this.viewModel, this.child);

  final MainViewModel viewModel;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
    primary: true,
    bottomNavigationBar: _buildBottomNavBar(context),
    body: buildBody(context, child),
  );

  Widget buildBody(BuildContext context, Widget child) => Stack(
    children: [
      child,
      const Positioned(bottom: 0, left: 0, right: 0, child: ConnectivityStatus()),
    ],
  );

  Widget _buildBottomNavBar(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    int currentIndex = 0;
    if (location == '/insights') {
      currentIndex = 1;
    } else if (location == '/setting') {
      currentIndex = 2;
    }

    return BottomNavigationBar(
      elevation: 0,
      useLegacyColorScheme: false,
      currentIndex: currentIndex,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurface,
      onTap: (value) {
        // Check if tapping on the same tab (Notes tab)
        if (value == 0 && currentIndex == 0) {
          // If already on Notes tab, scroll to top
          viewModel.onTabTap(context, value);
        } else {
          // Otherwise, switch to the new tab
          switch (value) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/insights');
              break;
            case 2:
              context.go('/setting');
              break;
          }
        }
      },
      items: const [
        BottomNavigationBarItem(
          tooltip: 'Note',
          icon: Icon(Icons.note_add),
          label: '',
          activeIcon: Icon(Icons.note_add),
        ),
        BottomNavigationBarItem(
          tooltip: 'Insights',
          icon: Icon(Icons.insights),
          label: '',
          activeIcon: Icon(Icons.insights),
        ),
        BottomNavigationBarItem(
          tooltip: 'Setting',
          icon: Icon(Icons.settings),
          label: '',
          activeIcon: Icon(Icons.settings),
        ),
      ],
    );
  }
}
