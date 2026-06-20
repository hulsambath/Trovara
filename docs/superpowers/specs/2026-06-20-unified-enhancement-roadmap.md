# Trovara — Unified Enhancement Roadmap

**Date:** 2026-06-20
**Author:** Sambath HUL (with Claude Code)
**Status:** Approved direction — execution plans to be created per tier
**Scope:** Merges the existing Phase 2 Pro plans (`docs/superpowers/plans/phase2/`), codebase
health debt, and two new high-value feature ideas into a single prioritized sequence.

---

## 1. Current State (baseline at v1.0.0+6)

**Shipped & working:**
- Core notes app — MVVM + ObjectBox + go_router, flutter_quill editor, tags, trash, search.
- AI/RAG pipeline — embeddings, vector search, query rewrite, multi-query expansion, RAG chat
  (Gemini / OpenAI / OpenRouter).
- Import adapters — Obsidian, Notion, Storypad.
- Google Drive sync — notes + chat.
- Pro tier (partial) — Android Play Billing service, `ProAccessService` gating, `PaywallView`,
  and Phase-1 backend services: `KnowledgeGraphService`, `StructureAnalyzerService`,
  `ExportService` (MD/HTML), `QuizGeneratorService`.

**Planned but NOT built** — six TDD-ready task plans exist in `plans/phase2/`:
`01-paywall-and-billing` (partial), `02-researcher`, `03-writer`, `04-student`,
`05-collaborative`, `06-advanced`.

**Health flags:**
- Six files exceed the project's hard 300-LOC rule (see Tier 1).
- Billing is Android-only (`Platform.isAndroid` guard) — Pro cannot ship on iOS.
- RAG is 100% cloud-dependent — no offline/free-tier embedding path.
- No OS-level share target / quick capture despite having import adapters.

---

## 2. Sequencing (approved)

**Tier 1 (Foundation) → Writer → Researcher → Student → Advanced / Collaborative**, with
Tier 4 new ideas as a parking lot (top 2 fleshed out below).

Rationale: every Phase 2 plan adds files into already-oversized areas, and the Pro tier is
unsellable on iOS. Clear the foundation before compounding the debt, then ship the
highest-value Pro surfaces in impact order.

---

## Tier 1 — Foundation & Health (do first)

Not covered by the phase2 plans, but a prerequisite for them.

| # | Item | Why now |
|---|------|---------|
| 1.1 | **Refactor 300-LOC violators** | `search/search_content.dart` (875), `ai/rag_service.dart` (681), `ai/llm_client.dart` (667), `tages/unified_tags_icon_button.dart` (580), `notes/note/note_view_model.dart` (534), `tages/custom/custom_tags_widget.dart` (513). Apply the recipes in `docs/style_guide/File_Organization_Rules.md` before research/export panels add more. |
| 1.2 | **iOS billing parity** | Add a StoreKit implementation behind the existing `IBillingService` so Pro ships on iOS. Remove the Android-only assumption from gating UX. |
| 1.3 | **Finish Sub-phase 1** | Restore-purchases, receipt validation, paywall edge cases, error-key parity (some already done in recent commits). |

**Exit criteria:** no `lib/` file > 300 LOC; `IBillingService` has Android + iOS impls;
paywall passes manual purchase/restore on both platforms.

---

## Tier 2 — Highest user-value Pro features (planned)

### 2.1 Writer features — `plans/phase2/03-writer-features.md`
PDF/DOCX/MD/HTML export dialog, drag-drop structure tree, linear composition workspace,
project bundles with share links. Reuses existing `ExportService`. **Export is the single
most-requested capability for any notes app** → highest impact-to-effort.

### 2.2 Researcher features — `plans/phase2/02-researcher-features.md`
Toggleable research side panel in `NoteView`: Semantic Explorer, Connection Inspector,
Statistics Dashboard (`fl_chart`). Directly monetizes the RAG/graph differentiator.

### 2.3 Student features — `plans/phase2/04-student-features.md`
Three-step quiz flow (Generator → Taking with timer + spaced repetition → Results).
`QuizGeneratorService` already exists, so this is mostly UI.

---

## Tier 3 — Depth features (planned, heavier)

### 3.1 Advanced — `plans/phase2/06-advanced-features.md`
Interactive force-directed graph view + Study Groups with shareable deep links and a
local leaderboard. Needs new graph-viz + `app_links` dependencies.

### 3.2 Collaborative — `plans/phase2/05-collaborative-features.md`
Local-only note comments + version snapshots + line-diff view + LLM feedback digest.
Cloud sync of comments deferred to a future phase.

---

## Tier 4 — New ideas (not yet planned)

Two promoted to roadmap items; the rest parked.

### 4.1 (Promoted) On-device embedding fallback
**Problem:** RAG/search require a cloud embedding API key. Free-tier and privacy-conscious
users get no semantic value, and offline notes can't be searched semantically.
**Direction:** Add an `OnDeviceEmbeddingProvider` implementing the existing embedding
provider interface in `lib/core/services/ai/_providers/`, backed by a small quantized model
(e.g. via `tflite_flutter` or an ONNX runtime). Selected by `ServiceLocator` when no cloud
key is present, mirroring the existing Gemini→OpenAI→OpenRouter fallback chain.
**Value:** unlocks a genuinely useful free tier; strengthens the privacy story; offline search.
**Risks:** model size in the bundle, lower embedding quality vs. cloud, per-platform runtime.
**Effort:** Medium-High (new provider + model packaging + dimension-compatibility handling
with already-stored cloud embeddings).

### 4.2 (Promoted) Quick capture (OS share target)
**Problem:** Capturing into Trovara requires opening the app; the import pipeline only runs
on explicit file imports. High-friction for the "jot it now" moment.
**Direction:** Register an Android `ACTION_SEND` / iOS Share Extension that routes shared
text/URLs through the existing `NoteImportAdapter` → `MarkdownToQuillConverter` → ObjectBox
path, then triggers `EmbeddingService`. Add a minimal capture confirmation sheet.
**Value:** dramatically lowers capture friction — the top retention lever for notes apps.
**Risks:** platform-channel + extension target setup; background-write correctness.
**Effort:** Medium.

### 4.3 (Parked — future ideas)
- **Note templates** — reusable scaffolds for recurring note types.
- **Daily review / reminders** — surface the spaced-repetition engine (today only inside quiz)
  for general note review and notifications.
- **Voice notes + transcription** — audio capture with on-device or cloud transcription into a note.

---

## 3. Dependency Notes

- Tier 1.1 (refactors) should land before Tier 2 touches `NoteView` and `search`.
- Tier 1.2 (iOS billing) gates any iOS Pro release but not Android development.
- Writer Sub-phase 3 Task 12 wires the CSV export button stubbed in Researcher Sub-phase 2 —
  build Researcher's stub first or sequence the wiring after Writer lands (as the plans note).
- Tier 4.1 must reconcile on-device embedding dimensions with already-stored cloud embeddings
  (signature/versioning in `EmbeddingService`).

---

## 4. Next Steps

1. Create a Tier 1 execution plan (refactors + iOS billing) via the `writing-plans` skill.
2. Execute Phase 2 sub-phases in the approved order using each existing plan in
   `plans/phase2/` (each already broken into TDD steps).
3. Schedule Tier 4.1 / 4.2 brainstorming once Tier 2 ships.
