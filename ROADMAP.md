# Roadmap — Status: IN_PROGRESS

## Goal

Ship Trovara v1 within the 3–7 day launch window. See MASTER_PLAN.md for full context; Notion "🚀 Trovara Launch" page is the external source of truth.

## Tasks

### Day 1 — Stabilize
- [ ] D1-1: Triage bug list; fix all P0/P1 crashers (STATUS: NOT_STARTED — no bug list captured yet; per research brief, wire Crashlytics visibility + rank against the five critical flows)
- [x] D1-2: Get `flutter analyze` clean (STATUS: DONE — 2026-07-11, `dart fix --apply` cleared all 15 info lints, commit 5cabe3c; "No issues found")
- [x] D1-3: Get `flutter test patrol_test` green (STATUS: DONE — 2026-07-11, all 288 tests pass before and after lint fixes)
- [ ] D1-4: Lock feature set / freeze scope (STATUS: BLOCKED — scope freeze is an owner decision; needs Sambath's sign-off on the non-goals list)

### Day 2 — Core-flow QA (real device)
- [ ] D2-1: QA note create / edit / delete (STATUS: NOT_STARTED)
- [ ] D2-2: QA editor formatting (STATUS: NOT_STARTED)
- [ ] D2-3: QA all three import adapters — Obsidian, Notion, Storypad (STATUS: NOT_STARTED)
- [ ] D2-4: QA AI chat over notes (STATUS: NOT_STARTED)
- [ ] D2-5: QA Google Drive sync (STATUS: NOT_STARTED)
- [ ] D2-6: Test large note set + fresh empty install (STATUS: NOT_STARTED)

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

- **D1-4 (scope freeze):** requires the owner to confirm the frozen feature set and non-goals; an agent cannot make this call. Unblock by writing the non-goals list into MASTER_PLAN.md.
- **D1-1 (crash triage):** no bug list exists yet. Needs on-device crash capture (Crashlytics or manual repro list) before triage can start.

## Definition of Done

- `flutter analyze` clean and `flutter test patrol_test` green.
- All critical flows verified on-device (note CRUD, editor, imports, AI chat, Drive sync).
- Khmer/English string parity (`/i18n-check` passes).
- Prod-release build cold-starts cleanly on real Android + iOS.
- Store assets ready and app submitted.
