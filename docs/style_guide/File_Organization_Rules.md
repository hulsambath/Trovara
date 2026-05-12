# File Organization Rules

These rules apply to **every `.dart` file in `lib/`**. They are most strictly enforced in `lib/core/` (services, repositories) where a single file growing too large is the most common source of architectural drift.

---

## Rule 1 — One primary class per file

A `.dart` file declares **one** primary class. The file is named after that class in `snake_case`.

```
note_service.dart        → class NoteService
chat_view_model.dart     → class ChatViewModel
i_note_repository.dart   → abstract class INoteRepository
```

### Allowed co-residents in the same file

Co-locate **only** when the secondary declaration is tightly bound to the primary class and would not be reused elsewhere:

| Allowed | Constraint |
|---|---|
| Enum used **only** by the primary class | Declared near the top of the file |
| Exception thrown **only** by the primary class | Suffix `Exception`, no methods beyond constructor + `toString` |
| Sealed result type returned **only** by the primary class | Declared near the top |
| Private helper class (`_Foo`) | Combined helper-class size **< 30 lines** |

### Not allowed in the same file

- A second public widget. → Move to `widgets/<name>.dart` (view-scoped) or `lib/widgets/<name>.dart` (cross-feature).
- A second public service / repository / view-model. → Each gets its own file.
- A standalone enum or model that other files use. → Own file in `lib/models/` or alongside its main consumer.
- A "utils" / "helpers" pile. → Either inline as private functions in the primary class, or extract to `<feature>_utils.dart` with a single public class.

---

## Rule 2 — Hard limit: 300 lines per file

Counted as total lines (including blanks and comments). A file at 290 lines is on notice; a file at 301 must be refactored before the change is committed.

### Exemptions

- Generated files (`*.g.dart`, `*.freezed.dart`, `lib/objectbox.g.dart`, `lib/gen/**`) — never edited by hand anyway.
- ObjectBox `@Entity` models in `lib/models/` may go up to 400 lines if the entity has a large field set. Anything beyond 400 → split mixins or extract value objects.
- Test files in `patrol_test/` may go up to 500 lines if they cover a single subject thoroughly. Beyond 500 → split by behavior (`x_parsing_test.dart`, `x_serialization_test.dart`).

---

## Refactor recipes

When a file is over the limit or has too many classes, pick the recipe that matches:

### R1 — View has inline widgets

**Before:** `lib/views/notes/notes_content.dart` declares `_NoteCard`, `_TagChips`, `_EmptyState`.

**After:** Each becomes its own file as a `part` of the view:

```
lib/views/notes/
├── notes_view.dart          (declares: part 'widgets/note_card.dart'; etc.)
├── notes_content.dart       (just the screen layout)
└── widgets/
    ├── note_card.dart       (part of 'notes_view.dart';  class _NoteCard)
    ├── tag_chips.dart       (class _TagChips)
    └── empty_state.dart     (class _EmptyState)
```

### R2 — Service has many helper methods or nested classes

**Before:** `lib/core/services/notes/note_service.dart` is 1,200 lines doing CRUD + sorting + tag indexing + Drive sync.

**After:** Extract domain-specific helpers into a sibling file or sub-folder:

```
lib/core/services/notes/
├── note_service.dart                    (orchestration only, < 300 lines)
├── note_sorting.dart                    (one helper class with sort logic)
├── note_tag_indexer.dart                (one helper class)
└── _internal/
    └── note_drive_sync_helper.dart      (one helper, internal-only)
```

The original `NoteService` keeps the public surface and **delegates** to the helpers — callers don't change.

### R3 — Long ViewModel

**Before:** `setting_view_model.dart` at 450 lines mixing auth, import, export, sync, and UI state.

**After:** Move multi-step business logic into a service, leave only UI-driving state in the ViewModel:

```
lib/views/setting/setting_view_model.dart       (≤ 200 lines: state + UI methods)
lib/core/services/import/import_orchestrator.dart   (was the import logic)
lib/core/services/export/export_orchestrator.dart   (was the export logic)
```

The ViewModel calls `_importOrchestrator.runObsidianImport(...)` instead of doing 80 lines of file-picker plumbing.

### R4 — Multiple unrelated classes in one file

**Before:** `lib/core/storage/google_drive_auth_storage.dart` has `GoogleDriveAuthStorage`, `GoogleDriveSession`, `GoogleDriveTokenError`, `_AuthCacheEntry`, plus a free-floating helper.

**After:**
- Keep the storage class in the original file.
- Move `GoogleDriveSession` to `google_drive_session.dart`.
- Keep `GoogleDriveTokenError` co-located **only if** it's tiny and only thrown by the storage class.
- Inline the free helper as a private method or move it to `google_drive_auth_helpers.dart`.

### R5 — Big switch / strategy

**Before:** `LlmClient` has a 200-line switch over `LlmProvider` for chat + embeddings.

**After:** One file per provider implementation, registered via a small map:

```
lib/core/services/ai/llm_client.dart                  (public API + provider lookup)
lib/core/services/ai/_providers/gemini_provider.dart  (one class)
lib/core/services/ai/_providers/openai_provider.dart  (one class)
lib/core/services/ai/_providers/openrouter_provider.dart (one class)
```

(Open/Closed in action — adding a new provider is a new file, not a switch edit.)

### R6 — Multiple data classes / enums in one file

If `tag_types.dart` has `MoodType`, `ActivityType`, `TimeType` enums, split each to its own file under `lib/models/tags/`.

---

## How this gets enforced

| Mechanism | Behavior |
|---|---|
| `post-edit-reminder.sh` hook | Prints a warning when an edit leaves the file > 300 LOC. Non-blocking. |
| `style-reviewer` subagent | Lists every violation as **Blocking** in audit reports. |
| `/audit-file-sizes` slash command | One-shot scan of the whole repo for current violations. |
| Code reviewer (human) | Treats over-limit files as a refactor request, not a soft suggestion. |

There is no auto-formatter that splits files. **You are responsible for picking the right recipe before the file crosses the limit.**

---

## Current known violations (snapshot)

These pre-date this rule. **Do not pile new code into them** — when you must touch them, take a slice off using the matching recipe above:

| File | LOC | Recipe |
|---|---|---|
| `lib/core/services/notes/note_service.dart` | 1564 | R2 |
| `lib/views/search/search_content.dart` | 882 | R1 (extract section widgets) |
| `lib/core/services/ai/llm_client.dart` | 667 | R5 |
| `lib/core/services/ai/rag_service.dart` | 643 | R2 |
| `lib/widgets/tages/unified_tags_icon_button.dart` | 580 | R1 |
| `lib/widgets/tages/custom/custom_tags_widget.dart` | 513 | R1 + R4 |
| `lib/core/services/ai/embedding_service.dart` | 493 | R2 |
| `lib/views/notes/note/note_view_model.dart` | 483 | R3 |
| `lib/views/setting/setting_view_model.dart` | 447 | R3 |
| `lib/views/setting/setting_content.dart` | 382 | R1 |
| `lib/core/di/service_locator.dart` | 321 | (acceptable — DI hub by nature; still consider per-domain locators) |
| `lib/models/note.dart` | 304 | (within 400 model exemption) |

Run `/audit-file-sizes` to refresh this list at any time.
