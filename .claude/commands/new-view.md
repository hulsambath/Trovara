---
description: Scaffold a new view folder following docs/style_guide/Views_Style_Guide.md
argument-hint: <feature_name_in_snake_case>
---

# New View Scaffolder

Create a new view at `lib/views/$1/` that follows `docs/style_guide/Views_Style_Guide.md` exactly.

**Argument**: `$1` is the feature name in `snake_case` (e.g. `bookmarks`, `weekly_review`). Convert to `PascalCase` for class names (e.g. `Bookmarks`, `WeeklyReview`).

## Steps

1. **Validate** that `$1` is a non-empty snake_case identifier (`^[a-z][a-z0-9_]*$`). If not, stop and ask the user to provide a valid name.
2. **Check** that `lib/views/$1/` does not already exist. If it does, stop and ask whether to overwrite.
3. **Read** `docs/style_guide/Views_Style_Guide.md` and `lib/views/CLAUDE.md` if not already loaded.
4. **Create** the following four files (use the conventions from the style guide — every rule must be honored):

   - `lib/views/$1/$1_view.dart` — `StatelessWidget` that returns `ViewModelProvider<{Pascal}ViewModel>`. Declare `part '$1_content.dart';`. Set `root: true` by default.
   - `lib/views/$1/$1_view_model.dart` — class extending `BaseViewModel`. Section comment headers (`// ── Section ──`). Constructor uses `Future.microtask(_initialize)`. Includes `bool _isLoading`, `bool get isLoading`, `Future<void> _initialize()`, and a placeholder public method.
   - `lib/views/$1/$1_content.dart` — `part of '$1_view.dart';` with private `_{Pascal}Content extends StatelessWidget`. Has the standard loading guard, an empty state placeholder, and `_build*` methods.
   - `lib/views/$1/widgets/.gitkeep` — empty placeholder so the directory exists.

5. **Wire route (only if asked).** If the user passed a `--route` flag or asks "and add a route", append a `GoRoute` in `lib/core/route/app_router.dart` using the existing pattern. Otherwise leave routing alone — the user may want to embed the view inside an existing screen.
6. **Report** the four created files and remind the user to:
   - Add any new strings to **both** `assets/translations/en.json` and `km.json`.
   - Add tests under `patrol_test/` if the ViewModel grows logic.
   - Run `flutter analyze` (the Stop hook will do this automatically).

## Hard rules (do NOT skip)

- The view file is exactly the `ViewModelProvider` instantiation — no UI logic.
- The content file is `part of` the view, class is private (`_` prefix).
- All UI text must use `tr('...')` with placeholder keys like `'$1.title'`.
- All colors via `Theme.of(context).colorScheme.*`. All text styles via `Theme.of(context).textTheme.*`.
- Icons from `lucide_icons_flutter`.
- Add `key: ValueKey('$1-<element>-button')` to interactive widgets.

If anything in these rules conflicts with what the user asked for, **ask before deviating** — don't silently break the style guide.
