---
name: feature
description: Use when adding a new screen, modifying existing feature behavior, or wiring new business logic end-to-end in Trovara — creates MVVM scaffold, route, ServiceLocator wiring, and i18n keys.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
model: sonnet
---

# Feature Implementation

Guides end-to-end delivery of a Trovara feature: MVVM scaffold → route → services → i18n → quality gates.

## Before You Start

For features spanning more than two files, run the `system-design` skill first.

Read the nearest existing view for conventions:
```bash
ls lib/views/          # pick the closest feature as reference
```

## Steps

### 1 — Create the view folder

```
lib/views/<feature>/
├── <feature>_view.dart          # Shell: ViewModelProvider only
├── <feature>_view_model.dart    # Presentation / business-coordination logic
├── <feature>_content.dart       # part file; private _<Feature>Content
└── widgets/                     # part files for extracted sub-widgets
```

### 2 — `<feature>_view.dart` — shell only

```dart
import 'package:flutter/material.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import '<feature>_view_model.dart';
part '<feature>_content.dart';

class <Feature>View extends StatelessWidget {
  const <Feature>View({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<<Feature>ViewModel>(
    create: (context) => <Feature>ViewModel(),
    root: true,   // true for top-level screens; false for nested/modal screens
    builder: (context, viewModel, child) => _<Feature>Content(viewModel),
  );
}
```

### 3 — `<feature>_view_model.dart`

```dart
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/<domain>/<dependency>_service.dart';

class <Feature>ViewModel extends BaseViewModel {
  final <Dependency>Service _service = ServiceLocator().<dependencyService>;
  bool _isLoading = true;
  bool _isDisposed = false;

  bool get isLoading => _isLoading;

  <Feature>ViewModel() {
    Future.microtask(() => _initialize());
  }

  Future<void> _initialize() async {
    try {
      _isLoading = true;
      notifyListeners();
      _service.addListener(_onDataChanged);
      // load data...
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onDataChanged() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _service.removeListener(_onDataChanged);
    super.dispose();
  }
}
```

### 4 — `<feature>_content.dart` — part file

```dart
part of '<feature>_view.dart';

class _<Feature>Content extends StatelessWidget {
  final <Feature>ViewModel viewModel;
  const _<Feature>Content(this.viewModel);

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading) return const Center(child: CircularProgressIndicator());
    return /* your UI */;
  }
}
```

### 5 — Register route in `lib/core/route/app_router.dart`

```dart
GoRoute(
  path: '/<feature>',
  name: '<feature>',              // kebab-case
  pageBuilder: (context, state) => MaterialPage(
    key: state.pageKey,
    restorationId: '<feature>',
    child: const <Feature>View(),
  ),
),
```

For custom transitions (e.g., slide-up like Search), use `CustomTransitionPage` with `transitionsBuilder`.

Pass parameters via query string: `context.push('/<feature>?id=42')` → read with `state.uri.queryParameters['id']`.

### 6 — Wire services in `lib/core/di/service_locator.dart`

```dart
<Feature>Service? _<feature>Service;

<Feature>Service get <feature>Service {
  _<feature>Service ??= <Feature>Service(noteRepository: noteRepository);
  return _<feature>Service!;
}
```

Add `await <feature>Service.initialize();` in `initialize()` and `_<feature>Service?.dispose(); _<feature>Service = null;` in `dispose()` if the service holds resources.

### 7 — Add i18n keys to **both** locale files

`assets/translations/en.json`:
```json
"<feature>": {
  "title": "My Feature",
  "empty_state": "Nothing here yet"
}
```

`assets/translations/km.json`:
```json
"<feature>": {
  "title": "មុខងាររបស់ខ្ញុំ",
  "empty_state": "មិនទាន់មានអ្វីនៅទីនេះ"
}
```

Use in code: `tr('<feature>.title')`. Never hardcode user-visible strings.

### 8 — Verify

```bash
flutter analyze                  # zero new errors
flutter test patrol_test         # no regressions
```

## Rules

- Views call nothing but `ViewModelProvider` — no service access, no logic.
- Colors: `Theme.of(context).colorScheme.*` only. Text styles: `textTheme.*` only.
- Icons: `LucideIcons.*` from `lucide_icons_flutter` — never `Icons.*`.
- No `print()` — use `logger` (`package:logger`).
- Content files are `part of '<feature>_view.dart'` — never imported directly.
- Hard limit: 300 LOC per file. Extract widgets to `widgets/` before crossing 300.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Calling `ServiceLocator()` inside a `part` file | Access from ViewModel only; pass data as constructor args |
| Hardcoded user-visible string | Add to en.json + km.json, use `tr()` |
| Forgetting `root: true` on a top-level screen | Omits the global in-app-update banner |
| `Icons.*` instead of `LucideIcons.*` | Replace; analyzer won't catch this |
| Listener added in `_initialize()` but not removed in `dispose()` | Always pair `addListener` with `removeListener` in `dispose()` |
| `part` file declared but file not created | Dart analysis error at import time |
