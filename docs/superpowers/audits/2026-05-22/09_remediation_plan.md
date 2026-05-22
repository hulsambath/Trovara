# Remediation Plan — 2026-05-22

Proposed PR batches, ordered by urgency × tractability. ROI weights: Critical=8 · High=4 · Medium=2 · Low=1 ÷ S=1 · M=3 · L=8.

**Scope note:** This plan covers the 4 completed dimensions (security, test gaps, architecture, deps). Bugs, fraud, bias, neg-correlation, and perf findings will be folded in after re-running `/audit --full` post session-limit reset.

---

## Batch 1 — Critical / High with S effort (ship this week)

These are the highest-ROI items: max impact per hour of work.

| # | Severity | Category | File:Line | Recommendation |
|---|---|---|---|---|
| 1 | Critical | TestGap | lib/core/repository/implementations/objectbox_embedding_repository.dart | Write `patrol_test/core/repository/implementations/objectbox_embedding_repository_test.dart` via `test-writer` agent |
| 2 | Critical | TestGap | lib/core/repository/implementations/objectbox_chat_message_repository.dart | Write `patrol_test/core/repository/implementations/objectbox_chat_message_repository_test.dart` |
| 3 | Critical | TestGap | lib/core/repository/implementations/objectbox_chat_thread_repository.dart | Write `patrol_test/core/repository/implementations/objectbox_chat_thread_repository_test.dart` |
| 4 | High | MVVM | lib/views/search/search_content.dart:708 | Move `TextParserService.parseQuillContent()` call out of widget into `SearchViewModel`; expose `previewFor(note)` |
| 5 | High | MVVM | lib/views/setting/setting_view_model.dart:222 | Replace `Navigator.of(context).push(MaterialPageRoute(...))` with `context.push('/trash')` |
| 6 | High | TestGap | lib/core/services/ai/multi_query_expansion_service.dart | Write test with stubbed `LlmClient` |
| 7 | High | TestGap | lib/core/services/ai/query_rewrite_service.dart | Write test with stubbed `LlmClient` |
| 8 | High | TestGap | lib/core/services/notes/text_parser_service.dart | Write pure unit test for tag/title/sanitization |

**PR scope:** Suggest splitting into two PRs to keep diffs reviewable:
- **PR 1.a (tests):** Items 1, 2, 3, 6, 7, 8 — all new `patrol_test/` files, zero production code change. Low risk to merge.
- **PR 1.b (MVVM):** Items 4, 5 — small refactors of existing views. Run `style-reviewer` on the diff before opening.

**Estimated effort:** 1-2 days total.

---

## Batch 2 — Critical / High with M effort (ship next sprint)

| # | Severity | Category | File:Line | Recommendation |
|---|---|---|---|---|
| 9 | Critical | TestGap | lib/core/repository/implementations/objectbox_note_repository.dart | Write note-repo test covering CRUD, title search, soft-delete, tag filter |
| 10 | Critical | TestGap | lib/core/services/sync/google_drive_sync_service.dart | Stubbed-DriveService test covering upload/download/conflict/no-op |
| 11 | Critical | TestGap | lib/core/services/auth/google_drive_service.dart | Test silent restore + sign-out with stubbed `google_sign_in` |
| 12 | Critical | TestGap | lib/core/services/chat/chat_drive_sync_service.dart | Push/pull paths with stubbed Drive |
| 13 | High | OAuth | lib/core/services/auth/google_drive_service.dart:83 | Invalidate `_driveApi` on sign-in; wrap `_GoogleAuthClient.send()` to refresh on each request |
| 14 | High | Ownership | lib/core/repository/implementations/objectbox_note_repository.dart:117 | Disable `userId IS NULL` arm once user has ever signed in; gate behind a stored flag |
| 15 | High | MVVM | lib/views/chat/widgets/chat_drawer.dart:23 | Move `ServiceLocator().chatService` call into `ChatViewModel`; pass threads to drawer as ctor arg |
| 16 | High | MVVM | lib/views/notes/widgets/note_card.dart:87 | Pre-compute preview text in `NotesViewModel`; pass on display model |
| 17 | High | MVVM | lib/views/setting/setting_content.dart:89 | Move `AppIconService` calls into `SettingViewModel` |
| 18 | High | TestGap | lib/core/services/chat/chat_service.dart | Test create/send/cancelStream with fake repos + stubbed `RagService` |
| 19 | High | TestGap | lib/core/services/chat/chat_source_service.dart | Test resolveSourceNotes (matched/fallback/empty) |
| 20 | High | TestGap | lib/core/services/notes/note_service.dart | Test create/update/softDelete/restore + embedding trigger |
| 21 | High | TestGap | lib/core/repository/implementations/objectbox_folder_repository.dart | Test folder CRUD + getNotesByFolder |
| 22 | High | TestGap | lib/core/repository/implementations/objectbox_custom_tag_repository.dart | Test add/rename/delete/getAll |

**PR scope:** One PR per category, three PRs total:
- **PR 2.a (test gaps):** Items 9, 10, 11, 12, 18, 19, 20, 21, 22 — 9 new test files.
- **PR 2.b (security/ownership):** Items 13, 14 — auth refresh + anonymous-note ownership fix.
- **PR 2.c (MVVM):** Items 15, 16, 17 — three view refactors.

**Estimated effort:** 1 week total.

---

## Batch 3 — Medium with S/M effort (bundle this month)

13 items: file-size violations (8), secrets storage migration (1), prompt-injection sanitization (2), Drive OAuth scope tightening (1), minor ownership in NoteService (1). Bundle by area; run `style-reviewer` on each diff before opening.

Notable subgroups:
- **Secrets storage:** Migrate `GoogleDriveAccountIdStorage` from `SharedPreferences` to `flutter_secure_storage` (`lib/core/storage/google_drive_auth_storage.dart:8`).
- **Prompt injection:** Sanitize chat input in `prompt_builder_service.dart:139` and Notion HTML in `notion_adapter.dart:210`.
- **OAuth scope:** Drop unused `email` + `profile` scopes from `google_drive_service.dart:20`.

---

## Batch 4 — L-effort items (design needed)

Address one at a time; each likely needs its own design discussion.

| Category | File | Why L effort |
|---|---|---|
| Ownership | vector_search_service.dart + embeddings | Need `userId` field on `NoteEmbedding` entity, build_runner regen, migration path for existing embeddings |
| Ownership | chat_thread_entity + chat repo | Same — needs `userId` field on `ChatThread`, migration |
| FileSize/refactor | rag_service.dart (681 LOC) | Recipe R2 split |
| FileSize/refactor | llm_client.dart (667 LOC) | Recipe R5 — provider per file under `_providers/` |
| FileSize/refactor | search_content.dart (875 LOC) | Recipe R1 — extract widgets |
| FileSize/refactor | note_view_model.dart (534 LOC) | Recipe R3 — extract `note_edit_service.dart` |
| FileSize/refactor | unified_tags_icon_button.dart (580 LOC) | Recipe R1 |
| FileSize/refactor | custom_tags_widget.dart (513 LOC) | Recipe R1+R4 |
| Prompt injection | prompt_builder_service.dart | Allow-list parser, XML-delimited context blocks |
| Dependency | objectbox 4→5 + go_router 14→17 + googleapis 13→16 | Major upgrades, breaking changes, regenerate code |

Per spec §6.1, default to PR-only (no GitHub issue per item). Revisit if a Batch 4 item spawns broader design.

---

## Low-priority backlog

35 Low findings across hardcoded strings (5), hardcoded colors (3), Material icons that should be Lucide (7), `print()` calls (3), inline `TextStyle` (2), and 19 patch/minor dependency bumps. Address opportunistically when touching the surrounding area; not worth dedicated PRs.

---

## Open questions (from spec §6)

These default to the spec defaults; revisit if the user wants to change them:
- **§6.1 Issue per batch?** Default: PR-only, no GitHub issues. (Batch 4 may warrant issues.)
- **§6.2 `/audit-deps` auto-upgrade?** Default: strictly read-only.
