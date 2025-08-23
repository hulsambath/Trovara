part of 'main_view.dart';

class _MainContent extends StatelessWidget {
  const _MainContent(this.viewModel);

  final MainViewModel viewModel;

  @override
  Widget build(BuildContext context) => AutoTabsRouter(
    routes: const [NotesRoute(), SearchRoute(), SettingRoute()],
    transitionBuilder: (context, child, animation) => FadeTransition(opacity: animation, child: child),
    builder: (context, child) => Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      primary: true,
      bottomNavigationBar: _buildBottomNavBar(context),
      body: buildBody(context, child),
    ),
  );

  Widget buildBody(BuildContext context, Widget child) => Stack(
    children: [
      child,
      const Positioned(bottom: 0, left: 0, right: 0, child: ConnectivityStatus()),
    ],
  );

  Widget _buildBottomNavBar(BuildContext context) {
    final tabsRouter = AutoTabsRouter.of(context);

    return BottomNavigationBar(
      elevation: 0,
      useLegacyColorScheme: false,
      currentIndex: tabsRouter.activeIndex,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurface,
      onTap: (value) {
        // Check if tapping on the same tab (Notes tab)
        if (value == 0 && tabsRouter.activeIndex == 0) {
          // If already on Notes tab, scroll to top
          viewModel.onTabTap(context, value);
        } else {
          // Otherwise, switch to the new tab
          tabsRouter.setActiveIndex(value);
        }
      },
      items: const [
        BottomNavigationBarItem(
          tooltip: 'Note',
          icon: Icon(Icons.note_add),
          label: '',
          activeIcon: Icon(Icons.note_add),
        ),
        BottomNavigationBarItem(tooltip: 'Search', icon: Icon(Icons.search), label: '', activeIcon: Icon(Icons.search)),
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
