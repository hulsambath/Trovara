# Master Plan

## Goal

Ship Trovara v1 to the app store(s) within the 3–7 day launch window tracked in the Notion "🚀 Trovara Launch" page. Positioning: *Own your notes. Ask them anything.* — local-first private notes with AI chat over your own notes, native Khmer + English, one-tap imports from Obsidian, Notion, and Storypad.

## Context

- Source of truth for the checklist: Notion page "🚀 Trovara Launch" (id `39412ece-cab4-817e-b90b-fa33900f118a`).
- Research on how to execute Day 1 (tooling choices, triage scheme, pitfalls): `trovara-day1-research-brief.md` at repo root.
- Day 1 is a gate, not a feature day — bias toward fast, low-setup, reversible choices. No new capability until post-launch.
- Critical flows that define P0/P1: note CRUD, editor, imports (Obsidian/Notion/Storypad), AI chat, Google Drive sync. Any crash or data loss on these = P0; broken-but-recoverable = P1; everything else = P2/backlog.
- Working branch: `fix/launch-day1-stabilize` (branched for the stabilization phase).

## Phases

1. **Day 1 — Stabilize**: triage/fix P0–P1 crashers, `flutter analyze` clean, `flutter test patrol_test` green, freeze scope.
2. **Day 2 — Core-flow QA** (on real device): note create/edit/delete, editor formatting, all three import adapters, AI chat over notes, Drive sync, large note set + fresh empty install.
3. **Day 3 — Differentiation polish**: first-run moment (import + "ask your notes"), strong empty states, Khmer parity + on-device rendering, import success/failure messaging.
4. **Day 4 — Performance & release build**: prod-release APK + IPA; test cold start, large-library scroll, indexing time, sync on real hardware; fix performance cliffs.
5. **Day 5 — Store listing & soft launch**: screenshots, description + ASO, privacy details, submit.
6. **Days 6–7 — Buffer & response**: store-review feedback, crash monitoring, Shorebird OTA hot-fixes for P0s.

## Scope Freeze (D1-4 — DRAFT, pending owner sign-off)

**In scope for v1** (exactly what exists today — stabilize/polish only):
- Note CRUD + flutter_quill editor
- Import adapters: Obsidian, Notion, Storypad
- AI chat over notes (RAG pipeline, Gemini→OpenAI→OpenRouter fallback)
- Google Drive sync (notes + chat)
- Khmer + English localization
- Shorebird OTA for post-launch hot-fixes

**Non-goals for v1** (do not build, even if easy):
- No new import sources, LLM providers, or note features
- No collaboration, sharing, web, or desktop
- No Sentry (Crashlytics only), no analytics beyond crash reporting
- No paywall/monetization changes beyond the existing Pro unlock
- UI changes limited to Day 3's list: first-run moment, empty states, import messaging

Any P2 bug or idea that isn't a crasher on the five critical flows goes to the post-launch backlog, not this window.

## Definition of Done

- `flutter analyze` clean and `flutter test patrol_test` green.
- All critical flows verified on-device (note CRUD, editor, imports, AI chat, Drive sync).
- Khmer/English string parity (`/i18n-check` passes).
- Prod-release build cold-starts cleanly on real Android + iOS.
- Store assets ready (screenshots, description, privacy) and app submitted.
