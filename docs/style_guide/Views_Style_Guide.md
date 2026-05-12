# Views Style Guide

This document defines the required structure, naming, and patterns for all screens inside `lib/views/`.

---

## 1. Folder Layout

Each feature gets its own sub-folder. The folder name is the feature name in snake_case.

```
lib/views/
└── <feature>/
    ├── <feature>_view.dart        ← public entry point (StatelessWidget)
    ├── <feature>_view_model.dart  ← state + business logic
    ├── <feature>_content.dart     ← private UI (part file)
    └── widgets/                   ← feature-scoped widgets (part files)
        └── <widget_name>.dart
```

No flat files in `lib/views/`. Every screen lives inside its own folder.

---

## 2. View File (`*_view.dart`)

The view file is a thin `StatelessWidget`. It does one thing: instantiate the `ViewModelProvider`.

```dart
import 'package:trovara/core/base/view_model_provider.dart';
import '<feature>_view_model.dart';

part '<feature>_content.dart';

class FeatureView extends StatelessWidget {
  const FeatureView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<FeatureViewModel>(
    create: (context) => FeatureViewModel(),
    root: true,               // true for top-level screens; false for nested/embedded
    builder: (context, viewModel, child) => _FeatureContent(viewModel),
  );
}
```

**Rules:**

- No UI logic in the view file — only `ViewModelProvider` instantiation.
- `root: true` for screens that own the provider at the app root (Notes, Chat, Insights, Setting, Main). `root: false` (or omitted) for push-routed screens (Trash, Search).
- Import `part '<feature>_content.dart'` here (not in the content file).
- Widget-part files that belong to this view are also declared here with `part 'widgets/<name>.dart'`.

### Embedding pattern

If a view can be embedded inside another view (e.g., `ChatView` inside the main tab bar), accept an `embedded` flag and toggle `root` accordingly:

```dart
class ChatView extends StatelessWidget {
  const ChatView({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) => ViewModelProvider<ChatViewModel>(
    create: (context) => ChatViewModel(),
    root: !embedded,
    builder: (context, viewModel, child) => _ChatContent(viewModel, embedded: embedded),
  );
}
```

---

## 3. ViewModel File (`*_view_model.dart`)

The ViewModel holds all state and business logic. The view reads state through getters; it never mutates state directly.

```dart
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';

class FeatureViewModel extends BaseViewModel {
  // ── Services ────────────────────────────────────────────────────────────
  final SomeService _someService = ServiceLocator().someService;

  // ── State ────────────────────────────────────────────────────────────────
  List<Item> _items = [];
  bool _isLoading = true;

  // ── Public getters ───────────────────────────────────────────────────────
  List<Item> get items => _items;
  bool get isLoading => _isLoading;

  // ── Constructor / init ───────────────────────────────────────────────────
  FeatureViewModel() {
    Future.microtask(() => _initialize());
  }

  Future<void> _initialize() async {
    // setup, listeners, first load
  }

  // ── Public methods (called by the view) ──────────────────────────────────
  Future<void> doSomething(BuildContext context) async { ... }

  // ── Private helpers ──────────────────────────────────────────────────────
  void _loadItems() {
    _items = _someService.items;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _someService.removeListener(_onDataChanged);
    super.dispose();
  }
}
```

**Rules:**

- Extend `BaseViewModel` (which extends `CmChangeNotifier`).
- Obtain services from `ServiceLocator()` as final fields — never `new` them directly.
- Use `Future.microtask(_initialize)` in the constructor to defer async work until after the first frame.
- Expose state through **immutable getters**. Return `List.unmodifiable(...)` for collections that must not be mutated externally.
- Call `notifyListeners()` only after all state mutations for a logical operation are complete.
- Remove service listeners in `dispose()`.
- Group class members with section separator comments (`// ── Section ──`).

### Service listeners

When the ViewModel must react to changes in a service's state:

```dart
FeatureViewModel() {
  _someService.addListener(_onDataChanged);
  Future.microtask(_initialize);
}

void _onDataChanged() {
  if (!disposed) _loadItems();  // CmChangeNotifier exposes `disposed`
}

@override
void dispose() {
  _someService.removeListener(_onDataChanged);
  super.dispose();
}
```

### Singleton instance (cross-screen access)

Only use a singleton instance when another screen must call a method on this ViewModel (e.g., `NotesViewModel.instance?.scrollToTop()`):

```dart
static FeatureViewModel? _instance;
static FeatureViewModel? get instance => _instance;

FeatureViewModel() {
  _instance = this;
  ...
}
```

Do not use singletons for data sharing — use the service layer for that.

### User scoping

When the app has a signed-in user, filter data to that user's ID:

```dart
String? get _currentUserId => _driveService.currentUser?.id;

void _loadItems() {
  final userId = _currentUserId;
  _items = userId == null
      ? _someService.allItems
      : _someService.itemsForUser(userId);
  notifyListeners();
}
```

---

## 4. Content File (`*_content.dart`)

The content file is a **private** `StatelessWidget` that holds all actual UI. It is a `part` of the view file.

```dart
part of '<feature>_view.dart';

class _FeatureContent extends StatelessWidget {
  const _FeatureContent(this.viewModel);

  final FeatureViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _buildBody(context),
  );

  Widget _buildBody(BuildContext context) { ... }

  Widget _buildAppBar(BuildContext context) { ... }

  Widget _buildEmptyState(BuildContext context) { ... }
}
```

**Rules:**

- The class name is prefixed with `_` (private).
- Receives the ViewModel as a constructor argument — never reads from `context` via `Provider.of`.
- Split `build` into private `_build*` methods to keep each method under ~40 lines.
- Do not call services or perform async work here — delegate to the ViewModel.
- Loading state is handled by checking `viewModel.isLoading`, not `FutureBuilder`.

### Standard loading guard

```dart
Widget _buildBody(BuildContext context) {
  if (viewModel.isLoading) {
    return const Center(child: CircularProgressIndicator());
  }
  return _buildLoadedContent(context);
}
```

### Standard empty state

```dart
Widget _buildEmptyState(BuildContext context) => Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(LucideIcons.someIcon, size: 48, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 16),
      Text('No items yet', style: Theme.of(context).textTheme.titleMedium),
    ],
  ),
);
```

---

## 5. Widget Files (`widgets/*.dart`)

Feature-scoped widgets that are reused within the same view live in the `widgets/` sub-folder and are declared as `part` files of the view.

```dart
// In the view file:
part 'widgets/feature_card.dart';
```

```dart
// In widgets/feature_card.dart:
part of '<feature>_view.dart';

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item, this.onTap});

  final Item item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) { ... }
}
```

**Rules:**

- Private (`_` prefix) when used only within the view.
- Widgets that are reused across multiple features go into `lib/widgets/` (public, no `_` prefix).
- Accept data and callbacks as constructor parameters — never read the ViewModel directly.

---

## 6. Navigation

Navigate using `go_router` named routes. Never use `Navigator.push` directly.

```dart
// Push (adds to stack)
context.push('/note?title=${Uri.encodeComponent(note.title)}');

// Replace root
context.go('/');
```

Trigger navigation from the ViewModel when possible, passing `BuildContext` as a parameter:

```dart
// In ViewModel
void openNote(BuildContext context, Note note) {
  context.push('/note?title=${Uri.encodeComponent(note.title)}')
    .then((_) => _loadNotes());  // refresh on return
}
```

---

## 7. Error Handling

Surface errors to the user via snackbars or dialogs — never let exceptions propagate silently. Catch at the ViewModel level:

```dart
Future<void> doSomething(BuildContext context) async {
  try {
    await _someService.doSomething();
  } catch (e) {
    _logger.e('doSomething failed', error: e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    }
  }
}
```

Always check `context.mounted` before showing UI feedback after an `await`.

---

## 8. Keys for Testability

Add `ValueKey` to interactive widgets that are targeted by Patrol tests:

```dart
IconButton(
  key: const ValueKey('notes-create-button'),
  icon: const Icon(LucideIcons.plus),
  onPressed: () => viewModel.createNewNote(context),
),
```

Key format: `'<feature>-<element>-<type>'` (e.g., `'notes-search-button'`, `'chat-send-button'`).

---

## 9. Theme Usage

Never hardcode colors or text styles. Use `Theme.of(context)`:

```dart
// Colors
color: Theme.of(context).colorScheme.primary
color: Theme.of(context).colorScheme.surfaceContainerLow
color: Theme.of(context).colorScheme.outline

// Text styles
style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)
style: Theme.of(context).textTheme.bodyMedium
```

---

## 10. Icons

Use `lucide_icons_flutter` exclusively:

```dart
import 'package:lucide_icons_flutter/lucide_icons.dart';

Icon(LucideIcons.search)
Icon(LucideIcons.plus)
Icon(LucideIcons.trash2)
```

Do not use `Icons.*` (Material icon font).

---

## 11. Internationalization

All user-visible strings must go through `easy_localization`:

```dart
import 'package:easy_localization/easy_localization.dart';

Text(tr('notes.empty_state.title'))
```

String keys live in `assets/translations/en.json` and `assets/translations/km.json`. Add both translations when adding a new key.

---

## 12. File Size Limits

| File type           | Soft limit |
| ------------------- | ---------- |
| `*_view.dart`       | ~20 lines  |
| `*_view_model.dart` | ~300 lines |
| `*_content.dart`    | ~200 lines |
| `widgets/*.dart`    | ~150 lines |

If a ViewModel exceeds ~300 lines, extract a dedicated service or helper class rather than splitting the ViewModel.
