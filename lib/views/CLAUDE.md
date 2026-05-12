# lib/views/ — Working Rules

**Authoritative spec:** `docs/style_guide/Views_Style_Guide.md`. Read it before adding or restructuring a view.

## Hard rules (the analyzer + style-reviewer enforce these)

1. **Folder layout per feature**:
   ```
   <feature>/
   ├── <feature>_view.dart        ← StatelessWidget, only ViewModelProvider
   ├── <feature>_view_model.dart  ← extends BaseViewModel
   ├── <feature>_content.dart     ← part of view; private _FeatureContent
   └── widgets/<name>.dart         ← part files, private _Name widgets
   ```
2. **The `*_view.dart` file contains zero UI logic.** It instantiates `ViewModelProvider<T>`, declares `part` files, and nothing else.
3. **The `*_content.dart` file is `part of` the view.** Class is private (`_FeatureContent`). Receives the ViewModel as a constructor argument — never `Provider.of` or `context.watch`.
4. **The ViewModel never imports `package:flutter/material.dart` for widgets** (only for `BuildContext`/`ScrollController`/`TextEditingController` if needed). No `Widget`-typed fields.
5. **The View never calls a service or repository.** All data access goes through the ViewModel.
6. **Loading state: ViewModel exposes `bool get isLoading`.** Content checks it. No `FutureBuilder` in views.
7. **Navigation uses `go_router`**: `context.push('/route')` / `context.go('/')`. Never `Navigator.push` directly. Trigger from the ViewModel (pass `BuildContext` as a parameter) when a refresh-on-return is needed.
8. **`ValueKey('<feature>-<element>-<type>')`** on every interactive widget that a Patrol test might target.

## Pitfalls already encountered

- **Don't add a singleton `instance` field** unless another screen genuinely must reach in (today only `NotesViewModel.instance?.scrollToTop()` qualifies). Use the service layer for shared data instead.
- **Don't `notifyListeners()` mid-mutation** — batch all state changes for one logical step, then notify once.
- **Don't forget `if (context.mounted)` after `await`** before calling `ScaffoldMessenger.of(context)`.
- **Don't `dispose()` without removing service listeners** — leaks and `notifyListeners on disposed object` errors.

## DRY/KISS/SOLID applied to views

- A widget used in **only one feature** belongs in `lib/views/<feature>/widgets/` as a `part` file. A widget used in **2+ features** belongs in `lib/widgets/` as a public class.
- If two ViewModels are doing the same data-loading dance, the duplicated logic belongs in the corresponding **service** (under `lib/core/services/`), not in a shared base class.
- Don't introduce a new mixin or base class for "view template" reuse. If three views all need the same shell, make a `ViewShell` widget instead.

## File size & one-class-per-file

`docs/style_guide/File_Organization_Rules.md` applies here too. View-specific application:

- **Each file declares one class.** A view file declares the `View` class. A content file declares the `_Content` class. A widget file declares one `_Widget` class.
- **300 LOC per file. 200 for content. 150 for widgets.** (Soft limits in `Views_Style_Guide.md` § 12; this rule makes 300 the hard ceiling.)
- **When a content file gets long, extract sections** as `part` files in `widgets/` (Recipe R1). Pattern:
  ```dart
  // In <feature>_view.dart:
  part 'widgets/header_section.dart';
  part 'widgets/list_section.dart';
  part 'widgets/footer_section.dart';
  ```
  Each section file is `part of '<feature>_view.dart';` and declares a single private widget class.
- **When a ViewModel grows past 300 LOC, extract a service** (Recipe R3), don't split the ViewModel. ViewModels are presentation glue — when they hold business logic, that logic belongs in `lib/core/services/<domain>/`.

Known view offenders: `search_content.dart` (882), `note_view_model.dart` (483), `setting_view_model.dart` (447), `setting_content.dart` (382). When you touch these, take a slice off.

## When stuck

Look at `lib/views/notes/` (canonical pattern with singleton + listeners), `lib/views/chat/` (embedded mode + streaming), or `lib/views/insights/` (lazy init + complex state).
