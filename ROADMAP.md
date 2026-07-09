<!--
Machine-readable task list. Status values: DONE | IN_PROGRESS | BLOCKED | TODO | DEFERRED.
Each task links to its sub-plan in plans/ when one exists. See MASTER_PLAN.md for phase context.
Last updated: 2026-07-10
-->

# Trovara Roadmap

## Phase 1 — Stabilize

| ID | Task | Status | Plan | Notes |
|---|---|---|---|---|
| P1-1 | Fix Shorebird `onError` unhandled-path warning | DONE | — | Commit `a828ffa`, reviewed clean |
| P1-2 | Fix `invalid_use_of_visible_for_testing_member` warnings | DONE | — | Commit `509220f`, reviewed clean (6 occurrences across 3 files, not 3 as originally scoped) |
| P1-3 | Persist Pro-tier unlock state across app restarts | DONE | — | Commits `be6a22c`, `7022f2e` (reviewer-found I/O-ordering fix). Also fixed a regression this introduced in 2 pre-existing tests that hung on a real platform channel. |
| P1-4 | Run full test suite (`patrol_test` + `test/` + `/i18n-check`) and declare Day 1 closed | TODO | `plans/2026-07-10-launch-rollout-plan.md` (Task 4) | Blocked only on doing the run, not on unresolved code |

## Phase 2 — Core-flow QA (Day 2)

| ID | Task | Status | Plan | Notes |
|---|---|---|---|---|
| P2-1 | On-device QA: note CRUD, editor formatting | TODO | `plans/2026-07-10-launch-rollout-plan.md` (Task 5) | Requires physical device |
| P2-2 | On-device QA: Obsidian import adapter | TODO | same | |
| P2-3 | On-device QA: Notion import adapter | TODO | same | |
| P2-4 | On-device QA: Storypad import adapter | TODO | same | |
| P2-5 | On-device QA: AI chat over notes (multi-note retrieval) | TODO | same | |
| P2-6 | On-device QA: Google Drive sync (both directions) | TODO | same | |
| P2-7 | On-device QA: Pro paywall + restart-survival | TODO | same | Now testable — persistence landed in P1-3 |
| P2-8 | Stress test: large note set import | TODO | same | |
| P2-9 | Stress test: fresh empty install | TODO | same | |
| P2-10 | Repeat P2-1..P2-9 on iOS | TODO | same | |

## Phase 3 — Differentiation polish (Day 3)

| ID | Task | Status | Plan | Notes |
|---|---|---|---|---|
| P3-1 | First-run moment showing import + "ask your notes" | TODO | `plans/2026-07-10-launch-rollout-plan.md` (Task 6) | Scope decision needed: build new vs. use existing screens |
| P3-2 | Strong empty states for AI chat and notes list | TODO | same | |
| P3-3 | Khmer parity + on-device text rendering check | TODO | same | |
| P3-4 | Tighten import success/failure messaging | TODO | same | |

## Phase 4 — Performance & release build (Day 4)

| ID | Task | Status | Plan | Notes |
|---|---|---|---|---|
| P4-1 | Build prod-release APK + IPA | TODO | `plans/2026-07-10-launch-rollout-plan.md` (Task 7) | |
| P4-2 | Measure cold start, scroll perf, indexing time, AI latency, sync time | TODO | same | |
| P4-3 | Fix any performance cliffs found | TODO | same | |

## Phase 5 — Store listing & soft launch (Day 5)

| ID | Task | Status | Plan | Notes |
|---|---|---|---|---|
| P5-1 | Screenshots (import, AI chat, Khmer UI) | TODO | `plans/2026-07-10-launch-rollout-plan.md` (Task 8) | |
| P5-2 | Store description + ASO keywords | TODO | same | |
| P5-3 | Privacy details | TODO | same | |
| P5-4 | Submit to store(s) | TODO | same | Requires explicit sign-off — one-way external action |

## Phase 6 — Buffer & response (Days 6-7)

| ID | Task | Status | Plan | Notes |
|---|---|---|---|---|
| P6-1 | Monitor crash reporting | TODO | `plans/2026-07-10-launch-rollout-plan.md` (Task 9) | |
| P6-2 | Respond to first store reviews | TODO | same | |
| P6-3 | Hot-fix P0s via Shorebird OTA | TODO | same | Depends on P1-1 |

## Deferred / speculative (Phase 2 of the Pro tier — not this launch)

| ID | Task | Status | Plan | Notes |
|---|---|---|---|---|
| PRO-1 | Paywall & Android Play Billing | DONE | archived: Linear HUL-13 | Superset shipped (iOS StoreKit too) |
| PRO-2 | Researcher features (Research Panel UI) | DEFERRED | `plans/phase2/02-researcher-features.md` | Backend services exist, no UI |
| PRO-3 | Writer features (export UI, structure analysis UI) | DEFERRED | `plans/phase2/03-writer-features.md` | Backend services exist, no UI |
| PRO-4 | Student features (quiz-taking/results UI) | DEFERRED | `plans/phase2/04-student-features.md` | Backend service exists, no UI |
| PRO-5 | Collaborative features (comments, version snapshots) | DEFERRED | `plans/phase2/05-collaborative-features.md` | Not started |
| PRO-6 | Advanced features (graph visualization, study groups) | DEFERRED | `plans/phase2/06-advanced-features.md` | Not started |

## Partially implemented (pre-existing, not blocking launch)

| ID | Task | Status | Plan | Notes |
|---|---|---|---|---|
| MIG-1 | Gemini/Firebase AI migration | IN_PROGRESS | `plans/2026-05-13-gemini-firebase-ai-migration.md` | `google_generative_ai` dep not removed; `llm_client.dart` still defaults Gemini to old key-based provider |
| TIER-1 | Pro-tier implementation (UI layer) | IN_PROGRESS | `plans/2026-05-22-trovara-pro-tier-implementation.md` | Backend (graph/citation/export/quiz services) done; `lib/views/research/` UI never built |

## Archived (completed, moved to Linear)

Implemented plans are archived as Linear issues (label `implemented-plan`, project `Trovara`, team `Hulsambath`) and their `.md` files deleted from `plans/`:

- HUL-9 — ChatSourceService Implementation Plan
- HUL-10 — Quality Audit System Implementation Plan
- HUL-11 — Paywall Review Fixes Implementation Plan
- HUL-12 — Tiered AI Chat — Plan A: Tier Infrastructure
- HUL-13 — Sub-Phase 1: Paywall & Android Play Billing
