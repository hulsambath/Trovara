---
name: code-review
description: Review code like a senior engineer - prevent bugs, improve maintainability, enforce architecture, catch performance regressions, protect user privacy & security
---

# AI Code Review Skill

## Goal

Review code like a senior engineer:

- prevent bugs
- improve maintainability
- enforce architecture
- catch performance regressions
- protect user privacy & security

## Review Priorities (in order)

1. **Correctness** — Logic bugs, null safety, async correctness, race conditions
2. **Security** — No hardcoded secrets, API key exposure, injection vulnerabilities, auth bypass
3. **Architecture** — MVVM layering, ServiceLocator abuse, DI violations, state management
4. **Performance** — N+1 queries, unnecessary rebuilds, memory leaks, large builds on main thread
5. **Maintainability** — DRY, KISS, SOLID, naming, file organization, test coverage
6. **Readability** — Style, consistency, comments

## Trovara-Specific Patterns

### MVVM & Layering (Non-Negotiable)

Check that changes respect the strict layering:

- Views depend on ViewModels (via `ViewModelProvider<T>`)
- ViewModels depend on **interfaces** (`INoteRepository`, `IEmbeddingRepository`)
- Services depend on repository interfaces, never implementations
- **Never**: business logic in widgets, Views calling services, direct API calls in UI

### ServiceLocator Misuse

Detect and flag:

- `ServiceLocator()` calls inside services (violates layering)
- Hardcoded instantiation of repositories/services with `new` or constructor calls
- Missing lazy getters in `lib/core/di/service_locator.dart`
- Services not registered as disposable when they hold resources

### Repository Pattern

Ensure new repositories follow the recipe:

1. Interface in `core/repository/interfaces/I<Name>Repository.dart`
2. Implementation in `core/repository/implementations/objectbox_<name>_repository.dart`
3. Lazy getter in `ServiceLocator`
4. One primary class per file

### AI/RAG Pipeline

For changes to `lib/core/services/ai/`:

- Embedding service caching logic (SHA-256 signatures for change detection)
- Query rewriting & expansion (avoid redundant LLM calls)
- Token budget enforcement in prompt builder
- Provider fallback order: Gemini → OpenAI → OpenRouter
- Check for prompt injection vulnerabilities in user input

### Import Pipeline

For import adapters (`lib/core/import/adapters/`):

- Never parse Quill directly in adapters; use `MarkdownToQuillConverter`
- Emit only `ImportedNote` with Markdown body
- Add round-trip tests in `patrol_test/core/import/`

### Flutter-Specific

Prefer:

- `const` constructors & literals (enforced by analyzer)
- Small widgets (`lib/widgets/` or `lib/views/<feature>/widgets/`)
- Stateless by default (use `ChangeNotifierProvider` only when needed)
- `lucide_icons_flutter` only (never Material `Icons.*`)
- `Theme.of(context)` for colors, `tr('key')` for strings (never hardcoded)

Avoid:

- `build()` methods over ~150 lines (extract `_buildSection()` private methods)
- `ListView` without shrinkWrap in scrollable contexts
- `.toList()` on hot paths
- Direct `setState` or `notifyListeners` in loops
- `async` in build methods

## File Organization & Size Limits

Check against `docs/style_guide/File_Organization_Rules.md`:

- **Soft limit**: 250 LOC per file
- **Hard limit**: 300 LOC in `lib/core/` (strict)
- **One primary class per file** (exceptions: small enums, sealed types, private helpers <30 LOC)
- Views: under 200 LOC (extract widgets to `lib/widgets/` or `_sub_widgets.dart`)
- ViewModels: under 300 LOC (extract service logic to `lib/core/services/`)

If crossing limits → recommend refactor recipe before landing.

## Localization & Accessibility

- All user-visible strings must use `tr('key')` from `easy_localization`
- New strings added to **both** `assets/translations/en.json` AND `km.json`
- Semantic labels on interactive widgets (`.semanticLabel` for icons)
- No text-only icons without labels

## Testing

For patrol_test/ changes:

- Use `patrolTest` (local wrapper), not `patrolWidgetTest` from Patrol CLI
- Import `test_support.dart` for fixtures
- Logic tests should not require emulator; E2E tests belong in `integration_test/`
- Mock repositories via interfaces, not implementations
- Round-trip tests for import adapters

## Security Checklist

- [ ] No API keys in code (use `String.fromEnvironment` + `--dart-define`)
- [ ] No passwords/tokens hardcoded or logged
- [ ] Input validation at system boundaries (API responses, file uploads)
- [ ] No raw `jsonDecode` without validation
- [ ] Firebase rules correct for Firestore/Realtime DB changes
- [ ] Google Drive API scope minimized
- [ ] Sensitive data not logged in production

## Severity Levels

### Critical

- Security: API key exposure, auth bypass, injection
- Correctness: null crashes, infinite loops, race conditions
- Architecture: MVVM violation (UI calling services), missing DI
- Data loss: unhandled exceptions in state mutation

### Major

- Performance: N+1 queries, unnecessary rebuilds on every frame
- Architecture: service calling ServiceLocator, repo implementation leak
- Testing: untested public API, missing error cases
- File org: exceeds hard limits, multiple classes in one file

### Minor

- Code quality: DRY violation, unused imports, deep nesting
- Readability: unclear naming, missing comments on non-obvious logic
- Style: inconsistent formatting, magic numbers

### Nitpick

- Trailing whitespace, lint warnings, formatting

## Review Style

Be:

- **Direct** — name the problem, not the symptom
- **Technical** — cite CLAUDE.md rules, architecture docs, DRY/KISS/SOLID
- **Constructive** — "Consider extracting X as a private method" not "This is bad"
- **Context-aware** — check CLAUDE.md in the changed directory

Always include:

- **Problem**: What's wrong? (cite rule if relevant)
- **Impact**: Why does it matter? (correctness, perf, maintenance)
- **Recommendation**: How to fix? (be specific)

Example:

> **Architecture violation** (Major)
> `ChatViewModel` calls `ServiceLocator().ragService` directly instead of injecting via constructor. This breaks testability and violates MVVM.
> **Recommendation**: Add `RagService` as a constructor parameter; inject in ServiceLocator getter.

## Checks by File Type

### View Files (`lib/views/**/*.dart`)

- No direct service calls (must go through ViewModel)
- ViewModel accessed via `ViewModelProvider<T>`
- No business logic in build methods
- Strings use `tr('key')`
- Colors use `Theme.of(context)`
- Icons use `LucideIcons.*` only

### ViewModel Files (`*_view_model.dart`)

- Extends `BaseViewModel`
- Services injected as constructor params
- No direct `setState` calls (use `notifyListeners`)
- Error handling → show user-friendly messages
- Async methods tracked with `asyncOp` future

### Service Files (`lib/core/services/**`)

- No ServiceLocator calls (except top-level initialization)
- Dependencies injected via constructor
- Async setup in `initialize()` method
- If stateful, extends `CmChangeNotifier`
- Registered in `ServiceLocator` with dispose logic

### Repository Files (`lib/core/repository/**`)

- Interface-only in `interfaces/`
- ObjectBox impl in `implementations/`
- No service dependencies (only other repos)
- Query helpers on repo (sorting, filtering)
- Registered as lazy getter in ServiceLocator

### Test Files (`patrol_test/**`)

- Use `patrolTest` (local wrapper), not `flutter_test` directly
- Mock via interfaces, never concrete impls
- Arrange-Act-Assert structure
- Descriptive test names
- No skipped tests without comment
