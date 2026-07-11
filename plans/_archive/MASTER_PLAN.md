# Trovara — Master Plan

_Owner: Sambath · Status: Pre-release (Day 1 code fixes complete, Day 2 QA not started) · Last updated: 2026-07-10_

Consolidated from `TROVARA_LAUNCH_PLAN.md`, the Notion "🚀 Trovara Launch" page, and the 2026-07-10 gap analysis. This is the single source of truth for what Trovara is and how it ships. Task-by-task status lives in `ROADMAP.md`; executable sub-plans live in `plans/`.

## 1. One-line summary

Trovara is a **local-first, private notes app with AI chat over your own notes**, native in **Khmer and English**, that can **import from Obsidian, Notion, and Storypad**. The launch goal is to ship a stable release and stake out a clear position against Storypad and Notion.

## 2. The competitive picture

**Storypad** is an open-source diary/journal app (100k+ downloads, Khmer-made) built around a continuous timeline: rich text, photos, mood tracking, "throwback" memories, PIN/biometric lock, 20+ languages. It's delightful and personal, but it's a **journal** — not a knowledge base, and it has no AI or semantic search over your writing.

**Notion** is the heavyweight all-in-one workspace: databases, blocks, collaboration, templates. But it's **online-first**, heavy, slower offline, complex to onboard, and subscription-priced. Your data lives on their servers.

**Where Trovara wins** (the wedge to lead with):

- **Local-first & private** — notes live on-device (ObjectBox), work fully offline, sync to *your* Google Drive. Neither competitor offers true local-first privacy.
- **AI chat over your own notes** — RAG pipeline (embeddings + vector search + chat) lets you *ask your notes questions*. Storypad has nothing like it; Notion's AI is server-side and paywalled.
- **Native Khmer + English** — first-class Khmer support, unlike Notion; on par with Storypad's local roots but far more capable.
- **Frictionless migration** — import adapters for Obsidian, Notion, **and Storypad** mean you can pull users directly off both competitors.

**Where competitors still win** (be honest about this): Storypad has an established install base, polished journaling delight, and mood/timeline features; Notion has collaboration, cross-platform maturity, and ecosystem. Trovara should **not** try to match those in this launch.

## 3. Positioning statement

> For people who want to truly own their notes, Trovara is a private, local-first notebook that lets you import everything and then *ask your own notes anything* — without sending your life to someone else's cloud.

Tagline options: _"Own your notes. Ask them anything."_ · _"Your notes, private and intelligent."_

## 4. Goals & non-goals for this launch

**Goals**
- Ship a stable, crash-free release build of the current feature set.
- Make the wedge (local-first + AI chat + import) obvious in the first 60 seconds of use.
- Have a store listing that positions Trovara clearly against Storypad and Notion.

**Non-goals (explicitly out of scope for this launch)**
- Real-time collaboration / multi-user.
- New AI features beyond what exists.
- Mood tracking, timeline journaling, or other Storypad-style delight features.
- Web or desktop clients.
- Phase 2 Pro features beyond paywall/billing (researcher/writer/student/collaborative/advanced — see `plans/phase2/`, all speculative/unimplemented).

## 5. Success metrics

- **Stability:** crash-free sessions > 99%; zero P0 bugs at release.
- **Activation:** % of new users who create or import ≥1 note on day 1.
- **Wedge adoption:** % of new users who run ≥1 AI chat query in week 1.
- **Migration:** import success rate (Obsidian/Notion/Storypad) > 95% without data loss.
- **Store:** rating ≥ 4.5 in first two weeks; listing conversion tracked.

## 6. Release criteria (definition of "shippable")

- `flutter analyze` clean; `flutter test patrol_test` green.
- All critical flows verified: note create/edit/delete, editor formatting, each import adapter, AI chat, Google Drive sync.
- Khmer/English string parity (`/i18n-check` passes).
- Prod-release build installs and cold-starts cleanly on a real Android + iOS device.
- Store assets ready (screenshots, description, privacy notes).

## 7. Phases

A 5-day core with 2 buffer days for store review and fixes. Adjust to actual energy; the ordering matters more than the exact days. Live status per task: `ROADMAP.md`.

### Phase 1 — Stabilize (Day 1)
Triage the open bug list, fix all P0/P1 crashers, get `flutter analyze` clean and `flutter test patrol_test` green, lock the feature set. **Milestone:** clean analyzer + green tests, known-issues list written down.

### Phase 2 — Core-flow QA (Day 2)
Manually walk every critical flow on a real device: note CRUD, editor formatting, all three import adapters, AI chat, Drive sync. Test with a large note set and a fresh empty install. **Milestone:** every critical flow passes on-device.

### Phase 3 — Differentiation polish (Day 3)
Make the wedge visible: a first-run moment showing import + "ask your notes." Strong empty states for AI chat and notes list. Verify Khmer parity end-to-end and eyeball rendering. Tighten import success/failure messaging. **Milestone:** a new user "gets it" within the first minute.

### Phase 4 — Performance & release build (Day 4)
Build the prod-release flavor. Test cold start, large-library scroll, embedding/indexing time, and sync on real Android + iOS hardware. Fix any performance cliffs. **Milestone:** signed release builds run clean on real devices.

### Phase 5 — Store listing & soft launch (Day 5)
Screenshots showing the wedge. Description positioning vs Storypad/Notion with ASO keywords. Fill privacy details honestly. Submit to store(s). **Milestone:** submitted for review.

### Phase 6 — Buffer & response (Days 6-7)
Address store-review feedback, monitor crash reporting, respond to first reviews, hot-fix P0s via Shorebird OTA. **Milestone:** live, stable, monitored.

## 8. Top risks

- **Import data loss** — highest-trust feature; a bad import kills word-of-mouth. Over-test the three adapters.
- **AI cost/latency** — first-query indexing or slow responses undercut the wedge. Verify token budgets and provider fallback.
- **Khmer rendering edge cases** — font/shaping bugs in editor or chat. Check on-device, not just simulator.
- **Scope creep** — the temptation to "just add one more thing." The non-goals list is your defense.
- **Pro-tier state divergence on I/O failure** (identified 2026-07-10, fixed) — `unlockPro()`/`lockPro()` now persist before flipping in-memory state.
- **Shorebird OTA reliability** — the buffer-days hotfix path depends on the patch-check error handling working correctly (fixed 2026-07-10).

## 9. External tracking

Also tracked in the Notion "Trovara Launch" page and in Linear (project `Trovara`, team `Hulsambath`). Completed implementation plans are archived to Linear with label `implemented-plan` and deleted from `plans/` — see `ROADMAP.md` for what's archived vs. active.
