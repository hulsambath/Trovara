# Navigation and Routing

## Router Configuration

The app uses go_router for declarative routing with a shell route pattern for the bottom navigation bar.

### Base Router Setup

```dart
// lib/core/route/app_router.dart
class AppRouter {
  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    restorationScopeId: 'router',
    routes: [
      ShellRoute(
        pageBuilder: (context, state, child) => MainView(child: child),
        routes: [
          GoRoute(path: '/', name: 'notes', ...),
          GoRoute(path: '/insights', name: 'insights', ...),
          GoRoute(path: '/setting', name: 'setting', ...),
        ],
      ),
      GoRoute(path: '/note', name: 'note', ...),
    ],
  );
}
```

## Route Structure

### Main Routes
- `/` - Notes list view
- `/insights` - Analytics and insights
- `/setting` - App settings
- `/note` - Note editor (with optional title parameter)

### Navigation Patterns

1. Bottom Navigation:
```dart
void onTap(int value) {
  switch (value) {
    case 0: context.go('/');
    case 1: context.go('/insights');
    case 2: context.go('/setting');
  }
}
```

2. Push Routes:
```dart
// Navigate to note editor
context.push('/note');

// With parameters
context.push('/note?title=MyNote');
```

## View Structure

Each route maps to a view following this pattern:

```dart
class NotesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ViewModelProvider<NotesViewModel>(
    create: (context) => NotesViewModel(),
    builder: (context, viewModel, child) => _NotesContent(viewModel),
  );
}
```

## Shell Route (MainView)

The MainView serves as a shell containing:
- Bottom navigation bar
- Connectivity status
- Child route content

```dart
class MainView extends StatelessWidget {
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: _buildBottomNavBar(context),
    body: Stack(
      children: [
        child,
        ConnectivityStatus(),
      ],
    ),
  );
}
```

## Route Guards and Middleware

### Error Handling
```dart
GoRouter(
  onException: (context, state, router) {
    debugPrint('GoRouter exception: ${router.routerDelegate.currentConfiguration}');
  },
  // ...
)
```

### Navigation Control
- URL restoration through restorationScopeId
- Debug logging with debugLogDiagnostics
- Global context access through AppScope

## Deep Linking

The app supports deep linking through the URL scheme defined in:
- Android: AndroidManifest.xml
- iOS: Info.plist
- Web: index.html