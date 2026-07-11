# Roadmap — Status: IN_PROGRESS

## Goal

Ship Trovara v1 within the 3–7 day launch window. See MASTER_PLAN.md for full context; Notion "🚀 Trovara Launch" page is the external source of truth.

## Tasks

### Day 1 — Stabilize
- [x] D1-1: Triage bug list; fix all P0/P1 crashers (STATUS: DONE — 2026-07-11, Linear HUL-14. No known P0/P1 crashers exist (analyzer clean, 288 tests green, none reported); Crashlytics is now wired (FlutterError + PlatformDispatcher + zone handler, release-only collection) so any crasher surfaced during Day 2 on-device QA gets a symbolicated trace and is triaged P0/P1 against the five critical flows)
- [x] D1-2: Get `flutter analyze` clean (STATUS: DONE — 2026-07-11, `dart fix --apply` cleared all 15 info lints, commit 5cabe3c; "No issues found")
- [x] D1-3: Get `flutter test patrol_test` green (STATUS: DONE — 2026-07-11, all 288 tests pass before and after lint fixes)
- [ ] D1-4: Lock feature set / freeze scope (STATUS: IN_PROGRESS — draft scope freeze + non-goals written into MASTER_PLAN.md § Scope Freeze on 2026-07-11; needs Sambath's sign-off, then check off here and in Notion)

### Day 2 — Core-flow QA (real device)
- [x] D2-1: QA note create / edit / delete (STATUS: DONE — 2026-07-11, Linear HUL-15. E2E `patrol_test/e2e/note_crud_test.dart` passes on iPhone 17 Pro Max simulator: create via FAB → title → save-on-back → edit → long-press → Delete → confirm → gone. Required repairing the entire Patrol iOS E2E infra (RunnerUITests target, scheme, Podfile, patrol config) which had never worked)
- [ ] D2-2: QA editor formatting (STATUS: IN_PROGRESS — Quill↔Markdown formatting round-trips are covered by `patrol_test/core/import/converters/` (round_trip_test etc., all green). On-device formatting toolbar interaction not automated: Quill's editor isn't reachable via `enterText`; needs a short manual pass or a keyboard-driven E2E later)
- [x] D2-3: QA all three import adapters — Obsidian, Notion, Storypad (STATUS: DONE — 2026-07-11. Storypad adapter had ZERO tests (top launch risk "guard against import data loss"); added 29-test suite. All import suites green (121 tests: adapters + converters + round-trip). On-device import UI with a real export file remains a manual spot-check)
- [ ] D2-4: QA AI chat over notes (STATUS: BLOCKED (manual) — logic layer fully tested (rag_service, llm_client, chat view models — green) and the keyless UI state ("Chat is not available") verified in the E2E smoke test. Live chat QA needs a build with a real API key (`--dart-define-from-file=configs/trovara_staging.json`, keys present) and a human judging response quality)
- [ ] D2-5: QA Google Drive sync (STATUS: BLOCKED (manual) — requires interactive Google sign-in on-device; cannot automate. Silent-restore path exercised at startup in every E2E run without crashing)
- [ ] D2-6: Test large note set + fresh empty install (STATUS: IN_PROGRESS — fresh empty install verified: app uninstalled from simulator, reinstalled by E2E run, first-run empty state + smoke pass. Large note set (hundreds of notes → list scroll + search) still to do; belongs with Day 4 performance pass)

### Day 3 — Differentiation polish
- [ ] D3-1: First-run moment showing import + "ask your notes" (STATUS: NOT_STARTED)
- [ ] D3-2: Strong empty states for AI chat and notes list (STATUS: NOT_STARTED)
- [ ] D3-3: Verify Khmer parity (`/i18n-check`) + on-device text rendering (STATUS: NOT_STARTED)
- [ ] D3-4: Tighten import success/failure messaging (STATUS: NOT_STARTED)

### Day 4 — Performance & release build
- [ ] D4-1: Build prod-release APK + IPA (STATUS: NOT_STARTED)
- [ ] D4-2: Test cold start, large-library scroll, indexing time, sync on real hardware (STATUS: NOT_STARTED)
- [ ] D4-3: Fix any performance cliffs — indexing, first AI query latency (STATUS: NOT_STARTED)

### Day 5 — Store listing & soft launch
- [ ] D5-1: Screenshots showing the wedge — import, AI chat, Khmer UI (STATUS: NOT_STARTED)
- [ ] D5-2: Description positioning vs Storypad/Notion + ASO keywords (STATUS: NOT_STARTED)
- [ ] D5-3: Fill privacy details — local data, user's own Drive sync (STATUS: NOT_STARTED)
- [ ] D5-4: Submit to store(s) (STATUS: NOT_STARTED)

### Days 6–7 — Buffer & response
- [ ] D6-1: Address store-review feedback (STATUS: NOT_STARTED)
- [ ] D6-2: Monitor crash reporting (STATUS: NOT_STARTED)
- [ ] D6-3: Respond to first reviews; hot-fix P0s via Shorebird OTA (STATUS: NOT_STARTED)

## Blockers

- **D1-4 (scope freeze):** draft written in MASTER_PLAN.md § Scope Freeze; awaiting owner sign-off (edit or approve).

## Definition of Done

- `flutter analyze` clean and `flutter test patrol_test` green.
- All critical flows verified on-device (note CRUD, editor, imports, AI chat, Drive sync).
- Khmer/English string parity (`/i18n-check` passes).
- Prod-release build cold-starts cleanly on real Android + iOS.
- Store assets ready and app submitted.
