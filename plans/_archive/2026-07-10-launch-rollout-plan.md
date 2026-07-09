# Trovara Launch Rollout Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining gap between current Trovara state and the Notion/`TROVARA_LAUNCH_PLAN.md` release criteria, then ship to store.

**Architecture:** No new features — this is a stabilize → QA → build → submit sequence. Tasks 1-3 are code fixes (small, TDD-style). Tasks 4-9 are verification/QA/build/store tasks with exact commands and manual-check checklists (no code changes expected unless QA finds a bug).

**Tech Stack:** Flutter/Dart, `flutter analyze`, `patrol_test`, Android/iOS release builds, Shorebird.

## Global Constraints

- `flutter analyze` must show 0 new errors (existing project rule).
- All new/changed user-visible strings need matching keys in both `en.json` and `km.json` (`/i18n-check` must pass).
- Follow MVVM / ServiceLocator rules in `CLAUDE.md` for any code touched.
- Source doc: `docs/superpowers/plans/2026-07-10-launch-readiness-gap-analysis.md`.

---

### Task 1: Fix Shorebird `onError` unhandled-path warning

**Files:**

- Modify: `lib/initializer.dart:32`

**Interfaces:**

- Consumes: existing Shorebird patch-check call site.
- Produces: no new public API; fixes `body_might_complete_normally_catch_error` lint.

- [ ] **Step 1: Read the current code**

```bash
sed -n '20,45p' /Users/apple/Documents/project/Trovara/lib/initializer.dart
```

- [ ] **Step 2: Fix the `onError` handler so it returns on every path**

Locate the Shorebird patch-check `onError` callback flagged by `flutter analyze`. Ensure every branch explicitly returns (e.g. add a trailing `return;` or convert the block body to an expression that always yields a value), matching the return type the callback is declared with. Do not change the patch-check's retry/logging behavior — only make the control flow exhaustive.

- [ ] **Step 3: Verify the warning is gone**

```bash
cd /Users/apple/Documents/project/Trovara && flutter analyze lib/initializer.dart
```

Expected: no `body_might_complete_normally_catch_error` warning.

- [ ] **Step 4: Commit**

```bash
git add lib/initializer.dart
git commit -m "fix(core): ensure Shorebird patch-check onError returns on all paths"
```

---

### Task 2: Fix `invalid_use_of_visible_for_testing_member` warnings

**Files:**

- Modify: `patrol_test/core/di/chat_tier_wiring_test.dart`
- Modify: `patrol_test/core/services/ai/byok_key_store_test.dart`
- Modify: `patrol_test/views/chat/chat_tier_generation_test.dart`

**Interfaces:**

- Consumes: `SharedPreferences.setMockInitialValues` (the flagged `@visibleForTesting` API).
- Produces: no behavior change — same mock setup, without triggering the lint.

- [ ] **Step 1: Confirm the exact flagged lines**

```bash
cd /Users/apple/Documents/project/Trovara && flutter analyze 2>&1 | grep -B2 "invalid_use_of_visible_for_testing_member"
```

- [ ] **Step 2: Fix each occurrence**

`SharedPreferences.setMockInitialValues` is itself `@visibleForTesting` and is being called from test files, which is its intended use — the lint is a false-positive pattern in this codebase (also present before this plan). Confirm with the project's `patrol_test/CLAUDE.md` whether there's a project-sanctioned mock helper (e.g. a `test_support.dart` wrapper) that already suppresses this; if one exists, route all three call sites through it. If not, add a targeted `// ignore: invalid_use_of_visible_for_testing_member` comment on each call site with a one-line reason.

- [ ] **Step 3: Verify clean**

```bash
cd /Users/apple/Documents/project/Trovara && flutter analyze
```

Expected: 0 errors, 0 warnings (only `info` left, if any).

- [ ] **Step 4: Commit**

```bash
git add patrol_test/core/di/chat_tier_wiring_test.dart patrol_test/core/services/ai/byok_key_store_test.dart patrol_test/views/chat/chat_tier_generation_test.dart
git commit -m "fix(test): silence visible-for-testing lint on SharedPreferences mock setup"
```

---

### Task 3: Decide and act on Pro-tier persistence gap

**Files:**

- Read: `lib/core/services/pro/pro_access_service.dart:13,23,35`

- [ ] **Step 1: Confirm current persistence behavior**

```bash
sed -n '1,60p' /Users/apple/Documents/project/Trovara/lib/core/services/pro/pro_access_service.dart
```

Confirm whether `isProUnlocked` state is held only in memory (resets on app restart) or already persisted somewhere.

- [ ] **Step 2: Surface the decision to the user**

Present two options and get an explicit answer before proceeding:

- **Fix now:** persist Pro-tier unlock state to `SharedPreferences` (mirrors the `ByokKeyStore` pattern already in the codebase) so it survives restart — small, scoped change.
- **Accept as known-issue:** document it in the launch notes and defer to a fast-follow release.

- [ ] **Step 3a (if "fix now"): implement persistence**

Add `SharedPreferences`-backed load/save to `ProAccessService`, following the exact pattern in `lib/core/services/ai/byok_key_store.dart` (load in `initialize()`, cache in memory, write-through on `unlockPro()`/`lockPro()`). Add a patrol_test covering restart-survival (mock `SharedPreferences.setMockInitialValues` with a pre-set key, confirm `isProUnlocked` is `true` after a fresh `ProAccessService().initialize()`).

- [ ] **Step 3b (if "accept as known-issue"): document only**

Add a line to the release notes / known-issues section (see Task 8) noting Pro status may reset on force-quit until a fast-follow.

- [ ] **Step 4: Commit (only if 3a taken)**

```bash
git add lib/core/services/pro/pro_access_service.dart patrol_test/core/services/pro/
git commit -m "fix(pro): persist Pro-tier unlock state across app restarts"
```

---

### Task 4: Run and confirm the full test suite

**Files:** none — verification only.

- [ ] **Step 1: Run patrol_test**

```bash
cd /Users/apple/Documents/project/Trovara && flutter test patrol_test --reporter=expanded 2>&1 | tail -60
```

Expected: all tests pass. If any fail, treat as a P0/P1 per the Day 1 triage rule — fix before continuing to Task 5.

- [ ] **Step 2: Run widget tests**

```bash
cd /Users/apple/Documents/project/Trovara && flutter test test/ --reporter=expanded
```

- [ ] **Step 3: Run i18n parity check**

```
/i18n-check
```

Expected: no missing keys (should already pass per prior audit — re-confirm after Tasks 1-3).

- [ ] **Step 4: Declare Day 1 (Stabilize) closed**

Print a one-line status: `flutter analyze` clean, `patrol_test` + `test/` green, i18n parity confirmed, Pro-tier decision recorded. This is the gate before Task 5.

---

### Task 5: On-device QA — core flows (Day 2)

**Files:** none — manual QA, file bugs as found.

- [ ] **Step 1: Build and install a staging debug build on a real Android device**

```bash
cd /Users/apple/Documents/project/Trovara && ./scripts/run_app.sh --quick
```

- [ ] **Step 2: Walk each flow and check it off**

- [ ] Note create / edit / delete
- [ ] Editor formatting (bold, lists, headings, links)
- [ ] Import: Obsidian adapter (use a real Obsidian vault export)
- [ ] Import: Notion adapter (use a real Notion Markdown/CSV export)
- [ ] Import: Storypad adapter (use a real Storypad JSON backup)
- [ ] AI chat over notes — ask a question that requires retrieval from >1 note
- [ ] Google Drive sync — edit on-device, confirm it lands in Drive; edit in Drive, confirm it syncs back
- [ ] Pro paywall — trigger purchase flow (use test/sandbox billing), confirm `isProUnlocked` flips and (per Task 3) survives an app restart

- [ ] **Step 3: Stress cases**

- [ ] Import a large note set (100+ notes) via one adapter — confirm no data loss, reasonable import time
- [ ] Fresh empty install — confirm empty states render correctly for notes list and AI chat

- [ ] **Step 4: File and fix anything broken**

For each bug found, fix it in a scoped commit (`fix(<scope>): <one-line>`), re-run `flutter analyze` + the relevant patrol_test file, then re-verify the specific flow on-device.

- [ ] **Step 5: Repeat Steps 1-4 on iOS**

Same checklist, iOS device or simulator with real billing sandbox where applicable.

---

### Task 6: Differentiation polish (Day 3)

**Files:**

- Likely: `lib/views/notes/`, `lib/views/chat/`, first-run/onboarding view if one exists

- [ ] **Step 1: Verify or add a first-run moment showing import + "ask your notes"**

Check whether an onboarding/first-run screen already exists. If not, this is a scope decision — confirm with the user whether to build one now or defer (the plan's non-goals exclude new features beyond what exists; a first-run _nudge_ using existing screens is in scope, a new onboarding flow may not be).

- [ ] **Step 2: Confirm empty states for AI chat and notes list are strong**

On a fresh install, check both screens render helpful empty-state copy/CTA (not blank).

- [ ] **Step 3: Verify Khmer parity + on-device text rendering**

Switch device language to Khmer, walk the core flows from Task 5, confirm no untranslated strings, no rendering/clipping issues with Khmer script.

- [ ] **Step 4: Tighten import success/failure messaging**

Trigger an import failure (malformed file) for each adapter, confirm the user gets a clear, localized error — not a raw exception or silent failure.

---

### Task 7: Performance & release build (Day 4)

**Files:** none — build + measurement only.

- [ ] **Step 1: Build prod-release artifacts**

```bash
cd /Users/apple/Documents/project/Trovara
./scripts/build_apk.sh --trovara
./scripts/build_ipa.sh
```

- [ ] **Step 2: Install and measure on real hardware**

- [ ] Cold start time (Android + iOS)
- [ ] Large-library scroll performance (100+ notes)
- [ ] Import indexing time for a large note set
- [ ] First AI query latency (cold and warm)
- [ ] Drive sync time for a realistic library size

- [ ] **Step 3: Fix any performance cliffs found**

Scope each fix to a single commit; re-measure after each fix.

---

### Task 8: Store listing & submission (Day 5)

**Files:** none — content creation, outside the Dart codebase.

- [ ] **Step 1: Capture screenshots showing the wedge**

Import flow, AI chat answering a question, Khmer UI — on both platforms' required screenshot sizes.

- [ ] **Step 2: Write store description**

Use the positioning from `TROVARA_LAUNCH_PLAN.md` §3 ("Own your notes. Ask them anything.") and the competitive wedge vs. Storypad/Notion. Include ASO keywords: notes, AI, private, local-first, Obsidian import, Notion import, Khmer.

- [ ] **Step 3: Fill privacy details**

Local data storage, user's own Google Drive for sync, no third-party data sharing beyond the user-configured AI provider (Gemini/OpenAI/OpenRouter/BYOK) — be explicit that note content is sent to the user's chosen LLM provider for AI chat.

- [ ] **Step 4: Include known-issues note if Task 3 chose "accept as known-issue"**

- [ ] **Step 5: Submit to store(s)**

Confirm with the user before submitting — this is a one-way, externally-visible action.

---

### Task 9: Buffer & response (Days 6-7)

**Files:** as needed for hotfixes.

- [ ] **Step 1: Monitor crash reporting daily**

- [ ] **Step 2: Respond to first store reviews**

- [ ] **Step 3: Hot-fix any P0s via Shorebird OTA**

Confirm Task 1's fix landed before relying on this path. For each hotfix: scoped commit, `flutter analyze` + `flutter test patrol_test` green, then follow the project's Shorebird push script.

---

## Self-Review Against Spec

- [x] Covers all release criteria from `2026-07-10-launch-readiness-gap-analysis.md` §1: analyzer clean (Tasks 1-2), tests green (Task 4), on-device QA (Task 5), i18n parity (Task 4), prod build cold-start (Task 7), store assets (Task 8).
- [x] Covers the 3 new risks flagged in the gap analysis: Pro-tier persistence (Task 3), Shorebird onError bug (Task 1), thin `test/` coverage (flagged in Task 4 as a re-check point, not expanded — out of scope per original launch plan's non-goals).
- [x] Re-baselines the original Day 1-7 plan rather than restarting it — Day 1 tasks (1-4) close out existing near-complete work before Day 2 QA begins.
- [x] No placeholders — every step has an exact command or a concrete checklist item.
