# Trovara Pro Phase 2: UI & In-App Purchase Integration — Design Specification

**Date:** 2026-05-22
**Status:** Design Approved
**Author:** Brainstorming Session
**Objective:** Build all Pro-tier UI screens, ViewModels, and Android Play Billing integration on top of the Phase 1 backend services.

---

## Executive Summary

Phase 2 layers the user-facing experience on top of Phase 1's backend (KnowledgeGraphService, CitationExtractorService, ExportService, QuizGeneratorService, ProAccessService, and all ObjectBox repositories). It delivers:

- **Paywall** — Android Play Billing integration with a full-screen purchase UI
- **Researcher features** — Semantic Explorer, Connection Inspector, Statistics Dashboard
- **Writer features** — Export dialog, Structure View, Composition Workspace, Project Bundles
- **Student features** — Quiz generator, quiz taking, spaced repetition, performance analytics
- **Collaborative features** — Inline comments, version snapshots, feedback digest
- **Advanced** — Interactive graph visualization, study groups, peer comparison

**Platform:** Android only (Play Billing native). iOS/web deferred.
**Timeline:** 2–3 weeks (Week 1: Paywall + Researcher; Week 2: Writer + Student; Week 2.5: Collaborative + Advanced)
**Quality bar:** Enterprise-ready — polished animations, full accessibility labels, comprehensive error handling, performance targets met at 10K notes.

---

## Part 1: Architecture

### 1.1 Patterns

All UI follows Trovara's MVVM discipline:

- Views are stateless widgets; they never call services or repositories directly.
- ViewModels extend `BaseViewModel` (extends `ChangeNotifier`) and are wired via `ViewModelProvider<T>`.
- All new services and repositories are registered in `ServiceLocator` as lazy getters.
- No hardcoded strings — all user-visible text in `en.json` and `km.json`.
- No Material `Icons.*` — use `lucide_icons_flutter` exclusively.
- No hardcoded colors — use `Theme.of(context).colorScheme.*`.

### 1.2 Paywall as a First-Class Concern

`ProAccessService` (Phase 1) is the single source of truth for purchase state. Its `isProUnlocked` getter drives all feature gating. On startup, `initialize()` checks the stored purchase status. The UI responds reactively via `ChangeNotifier`.

**Feature access model:**

- Unpurchased users can view all feature surfaces in read-only/preview mode (they see results, but actions like export or quiz-taking are gated).
- Gating is applied at the ViewModel level (`if (!_proAccess.isProUnlocked) emit paywallState`), not in the view.
- This creates consistent, testable access control.

### 1.3 Billing Integration

`AndroidPlayBillingService` wraps the Android `BillingClient` via platform channels. It communicates with `ProAccessService` only — no other class calls billing directly. This isolates billing complexity and allows testing with mock implementations.

```
User taps "Unlock Pro"
  ↓
PaywallViewModel.initiatePurchase()
  ↓
AndroidPlayBillingService.launchBillingFlow(productId: "trovara_pro")
  ↓
BillingClient callback (success | cancelled | error)
  ↓
ProAccessService.unlockPro() [on success]
  ↓
ChangeNotifier propagates to all gated views
```

---

## Part 2: File Structure

### New Files by Week

#### Week 1: Paywall + Researcher Features

| File                                                          | Responsibility                                         |
| ------------------------------------------------------------- | ------------------------------------------------------ |
| `lib/views/pro/paywall_view.dart`                             | Full-screen purchase flow UI                           |
| `lib/views/pro/paywall_view_model.dart`                       | Purchase state, billing calls, error handling          |
| `lib/views/notes/research_panel_view.dart`                    | Sidebar container (tabbed: Explorer, Inspector, Stats) |
| `lib/views/notes/research_panel_view_model.dart`              | Shared graph query state across tabs                   |
| `lib/views/notes/widgets/semantic_explorer_widget.dart`       | Search input + result list (tab 1)                     |
| `lib/views/notes/widgets/connection_inspector_widget.dart`    | In/out edge detail (tab 2)                             |
| `lib/views/notes/widgets/statistics_dashboard_widget.dart`    | Charts + top-concept list (tab 3)                      |
| `lib/core/services/billing/android_play_billing_service.dart` | Platform-channel wrapper for Play Billing              |
| `lib/core/services/billing/i_billing_service.dart`            | Interface for billing (enables test mocking)           |

#### Week 2: Writer Features + Student Features

| File                                                  | Responsibility                                    |
| ----------------------------------------------------- | ------------------------------------------------- |
| `lib/views/pro/export_dialog_view.dart`               | Format selector, preview pane, batch options      |
| `lib/views/pro/export_dialog_view_model.dart`         | Invokes ExportService, manages format/path state  |
| `lib/views/pro/structure_view.dart`                   | Drag-drop outline tree of notes                   |
| `lib/views/pro/structure_view_model.dart`             | Hierarchy state, StructureAnalyzerService calls   |
| `lib/views/pro/composition_workspace_view.dart`       | Linear document view (concatenated notes)         |
| `lib/views/pro/composition_workspace_view_model.dart` | Note ordering, word count, reading time           |
| `lib/views/pro/project_bundle_list_view.dart`         | Project list with create/delete                   |
| `lib/views/pro/project_bundle_detail_view.dart`       | Notes within a project, share-link generation     |
| `lib/views/pro/project_bundle_view_model.dart`        | IProjectBundleRepository calls                    |
| `lib/views/pro/quiz_generator_view.dart`              | Note/project selector, question count, difficulty |
| `lib/views/pro/quiz_generator_view_model.dart`        | QuizGeneratorService, progress state              |
| `lib/views/pro/quiz_taking_view.dart`                 | Multiple-choice UI, timer, progress bar           |
| `lib/views/pro/quiz_taking_view_model.dart`           | Answer tracking, spaced-repetition state          |
| `lib/views/pro/quiz_results_view.dart`                | Score, per-question breakdown, remediation links  |
| `lib/views/pro/quiz_results_view_model.dart`          | Analytics, suggested review notes                 |
| `lib/core/services/export/pdf_export_service.dart`    | PDF rendering (using `pdf` package)               |
| `lib/core/services/export/docx_export_service.dart`   | Word .docx rendering (using `docx_template`)      |

#### Week 2.5: Collaborative + Advanced

| File                                                                             | Responsibility                                              |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `lib/views/pro/collaborative_panel_view.dart`                                    | Comments thread, version history list                       |
| `lib/views/pro/collaborative_panel_view_model.dart`                              | Comment CRUD, snapshot creation                             |
| `lib/views/pro/graph_visualization_view.dart`                                    | Interactive force-directed graph                            |
| `lib/views/pro/graph_visualization_view_model.dart`                              | Node/edge data loading, selection state                     |
| `lib/views/pro/study_group_view.dart`                                            | Shareable quiz links, peer leaderboard                      |
| `lib/views/pro/study_group_view_model.dart`                                      | Share token generation, comparison state                    |
| `lib/models/note_comment.dart`                                                   | ObjectBox entity: noteId, text, createdAt, authorLabel      |
| `lib/models/version_snapshot.dart`                                               | ObjectBox entity: noteId, snapshotContent, label, createdAt |
| `lib/core/repository/interfaces/inote_comment_repository.dart`                   | Comment CRUD interface                                      |
| `lib/core/repository/interfaces/iversion_snapshot_repository.dart`               | Snapshot interface                                          |
| `lib/core/repository/implementations/objectbox_note_comment_repository.dart`     | ObjectBox implementation                                    |
| `lib/core/repository/implementations/objectbox_version_snapshot_repository.dart` | ObjectBox implementation                                    |

### Modified Files

| File                               | Change                                                                                                    |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `lib/core/di/service_locator.dart` | Register new billing, PDF, docx, comment, snapshot services and repositories                              |
| `lib/core/route/app_router.dart`   | Add routes: `/pro/paywall`, `/pro/research`, `/pro/export`, `/pro/quiz`, `/pro/graph`, `/pro/project/:id` |
| `lib/views/notes/note_view.dart`   | Add "Research Panel" toggle button and "Export" action                                                    |
| `lib/views/main_view.dart`         | Add "Unlock Pro" banner when not purchased                                                                |
| `assets/translations/en.json`      | Add all Pro UI strings                                                                                    |
| `assets/translations/km.json`      | Mirror all Pro UI strings                                                                                 |

---

## Part 3: Feature Designs

### 3.1 Paywall

**PaywallViewModel state:**

- `isLoading` — billing flow in progress
- `isPurchased` — success state, triggers navigation back
- `errorMessage` — String? for billing errors

**PaywallView layout:**

- Hero illustration at top
- Feature bullets (researcher, writer, student icons + 1-line description each)
- Large "Unlock Pro — $24.99" CTA button
- "One-time purchase. No subscription." subtext
- "Restore Purchase" text link at bottom

**Edge cases:**

- User cancels billing flow → dismiss loading, show "Purchase cancelled"
- Billing unavailable (sideload / no Play Store) → show "Purchase unavailable on this device"
- Network error → "Could not connect. Try again."
- User already purchased (restore) → `ProAccessService.unlockPro()` called, navigates back

### 3.2 Researcher Features

**ResearchPanelView:**

- Toggleable sidebar (25–40% width, main note area shrinks with `AnimatedContainer`)
- Three tabs: Explorer, Inspector, Stats
- Accessible from NoteView via an icon button in the AppBar

**Semantic Explorer tab:**

- `TextField` for query input, search button
- Results as `ListView` of note cards showing title + relevance score
- Filter chips: by date, by tag (uses existing tag model), by project
- Each result card is tappable → navigate to the note
- Empty state: "No related notes found. Try a broader query."

**Connection Inspector tab:**

- Accepts a note ID (populated when user selects a note from Explorer or taps from NoteView)
- Shows two `ExpansionTile` sections: "Referenced by (N)" and "References (N)"
- Each edge shown as: note title + edge type chip (Semantic / Citation / Hierarchical) + strength badge
- Tapping a linked note navigates to it

**Statistics Dashboard tab:**

- Top 20 most-connected concepts as `BarChart` (using `fl_chart` package)
- Citation frequency list: source URL / note title + count
- Research density: concepts with more than 5 notes shown with a density indicator
- "Export as CSV" button (calls `ExportService.toCsv(stats)`)

### 3.3 Writer Features

**ExportDialogView:**

- `BottomSheet` dialog triggered from NoteView or ProjectBundleDetailView
- Format selector: Markdown / HTML / PDF / Word (segmented button)
- "Include TOC" toggle
- "Embed images" toggle
- "Preview" button → opens `WebView` for HTML preview or `PdfViewer` for PDF
- "Export" button → saves to device Downloads folder, shows `SnackBar` with "Open" action

**StructureView:**

- Full-screen view accessed from Pro menu
- `TreeView` widget showing parent-child hierarchy
- Drag handles on each node for reordering
- Cluster suggestion: if `StructureAnalyzerService` returns a new grouping, show a `Banner` widget: "These 8 notes form a cluster. Create project?"
- "Flatten" / "Nest" toggle button

**CompositionWorkspaceView:**

- `ListView` of notes in project order, each as an inline editable quill block
- On edit, changes sync back to individual notes via `NoteRepository.save()`
- Word count + reading time shown in AppBar
- "Decompose" button restores individual note editing mode

**ProjectBundleListView / DetailView:**

- List shows project name, note count, last modified
- FAB creates a new project (dialog: name input)
- Detail view shows notes as draggable list for reordering
- "Share Link" button generates a read-only share token and copies to clipboard

### 3.4 Student Features

**QuizGeneratorView:**

- Note / project multi-select (shows `CheckboxListTile` for each note or project)
- Question count slider (5–50)
- Difficulty toggle: Mixed / Easy / Medium / Hard
- "Generate Quiz" button → shows `LinearProgressIndicator` while LLM generates
- On complete → navigate to `QuizTakingView`

**QuizTakingView:**

- One question per screen (PageView with slide animation)
- Progress bar + "Question N of M" label
- Four `RadioListTile` options
- Optional timer (shown as countdown `CircularProgressIndicator`)
- "Submit Answer" button → reveals correct/incorrect with answer explanation
- Spaced repetition: incorrect answers are re-queued (appended to end of session)

**QuizResultsView:**

- Score card: "You scored X / Y (Z%)"
- `ListView` of all questions: correct (green) / incorrect (red) + user answer
- "Review weak notes" section: tappable links to source notes for incorrect answers
- "Take again" + "New quiz" FAB options
- Performance chart: bar chart of previous sessions (if any stored)

### 3.5 Collaborative Features

**NoteCommentRepository** persists comments locally. In MVP, comments are device-local only (Phase 2). Cloud sync of comments is deferred to Phase 3.

**CollaborativePanelView:**

- Side panel (drawer) showing two tabs: Comments, Versions
- Comments tab: `ListView` of `NoteComment` entries, `TextField` + "Post" button at bottom
- Versions tab: `ListView` of `VersionSnapshot` entries with label + created date
  - "Snapshot now" button (prompts for label)
  - Tapping a snapshot shows a `diff`-style view (text comparison with additions in green, deletions in red)

**Feedback digest:**

- "Summarize feedback" button calls `LlmClient.generate(prompt: "Summarize these comments: ${allComments}")` and displays in a modal

### 3.6 Graph Visualization

**GraphVisualizationView:**

- Force-directed graph using `graphview` package (pub.dev)
- Nodes are circles labeled with note title (truncated to 20 chars)
- Edge color by type: semantic (blue), citation (orange), hierarchical (purple)
- Pan and zoom with `InteractiveViewer`
- Tap a node → highlight its edges + show inspector panel (connection count, top connections)
- Legend at bottom-right
- Filter toggle: show/hide edge types

**Performance:** For >200 nodes, show only the top 100 by in-degree. Show "Showing top 100 nodes" notice.

### 3.7 Study Groups

**StudyGroupView:**

- List of shared quiz links the user has generated
- "Share this quiz" button: generates a share token, copies deep-link URL to clipboard
- Peer comparison: if other devices have submitted results for the same quiz token, show a leaderboard (score + timestamp). MVP: local-only (comparison requires same-device multi-profile, deferred to Phase 3 cloud sync).

---

## Part 4: Error Handling

| Scenario                            | Handling                                                                                                                      |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Play Billing unavailable            | Log error, assume not purchased, show paywall. "Restore Purchase" retry available.                                            |
| Export fails mid-file               | Show `AlertDialog` with error message + retry button. Offer fallback format (e.g., fall back to Markdown if PDF fails).       |
| Quiz generation timeout (>10s)      | Show `SnackBar` "Generation is taking longer than expected. Please try again or select fewer notes." Cancel current LLM call. |
| Graph query slow (>2s)              | Show `CircularProgressIndicator` overlay. After 5s timeout, show partial results with "Load more" option.                     |
| Note sync conflict on comment save  | Queue comment locally, sync on next Drive sync cycle. Show "Saved locally" toast.                                             |
| Snapshot diff fails (large note)    | Fall back to showing snapshot content without diff highlights.                                                                |
| Billing already purchased (restore) | Call `ProAccessService.unlockPro()`, show "Pro restored" SnackBar, dismiss paywall.                                           |

---

## Part 5: Navigation

All Pro routes added to `app_router.dart`:

```
/pro/paywall         → PaywallView
/pro/research        → ResearchPanelView (full-screen mode on mobile)
/pro/export          → ExportDialogView (BottomSheet, push via showModalBottomSheet)
/pro/structure       → StructureView
/pro/composition     → CompositionWorkspaceView
/pro/project/:id     → ProjectBundleDetailView
/pro/quiz/generate   → QuizGeneratorView
/pro/quiz/take       → QuizTakingView
/pro/quiz/results    → QuizResultsView
/pro/graph           → GraphVisualizationView
/pro/study-group     → StudyGroupView
/pro/collaborate     → CollaborativePanelView (Drawer, not a full route)
```

---

## Part 6: Performance Targets

| Operation                              | Target |
| -------------------------------------- | ------ |
| Research panel open                    | <300ms |
| Semantic search (1K notes)             | <500ms |
| Graph visualization render (100 nodes) | <1s    |
| Quiz generation (10 questions)         | <10s   |
| Export to PDF (20-note project)        | <5s    |
| Export to Markdown/HTML                | <500ms |
| Statistics dashboard load              | <1s    |

---

## Part 7: Testing Strategy

### Unit Tests (patrol_test/)

- `PaywallViewModel`: purchase success, purchase cancel, billing unavailable, restore purchase
- `ResearchPanelViewModel`: search returns results, empty state, filter by tag, connection inspector
- `ExportDialogViewModel`: format selection, preview generation, save to file
- `QuizGeneratorViewModel`: generation in progress, success, timeout, cancel
- `QuizTakingViewModel`: answer tracking, spaced repetition re-queue, score calculation
- `StructureViewModel`: hierarchy loading, cluster suggestions
- `CollaborativePanelViewModel`: add comment, list comments, create snapshot, restore snapshot
- `AndroidPlayBillingService`: mock platform channel responses for all billing states

### Widget Tests (test/)

- PaywallView renders feature bullets, CTA, restore link
- QuizTakingView shows correct/incorrect state after answer submission
- ExportDialogView enables/disables export button based on format selection

### Integration Tests (integration_test/)

- Full "Unlock Pro → access Researcher → search → export" flow
- Full "Generate quiz → take quiz → view results → review note" flow
- "Create project → add notes → export as PDF" flow

### Accessibility

- All interactive elements have `Semantics` labels
- Color is never the sole indicator (icons + text used alongside color)
- Minimum touch target size: 48×48dp
- Test with TalkBack enabled

---

## Part 8: Localization

All new user-visible strings must be added to both:

- `assets/translations/en.json`
- `assets/translations/km.json`

Key string groups:

- `pro.paywall.*` — paywall UI
- `pro.researcher.*` — researcher feature labels
- `pro.writer.*` — writer feature labels
- `pro.student.*` — student feature labels
- `pro.collaborative.*` — comment/version labels
- `pro.graph.*` — graph visualization labels
- `pro.billing.*` — billing error messages

---

## Part 9: Success Criteria

- Play Billing purchase flow completes end-to-end on Android
- Semantic Explorer returns relevant results (cosine similarity > 0.7)
- Quiz generation produces 10 varied questions within 10 seconds
- PDF export produces a readable document with correct formatting
- All new UI strings exist in both `en.json` and `km.json`
- `flutter analyze` passes with no new errors
- All patrol_tests pass for new ViewModels
- No regression in Phase 1 tests (255 tests continue to pass)

---

## Appendix: Open Questions

1. **Graph visualization library:** `graphview` (simpler) vs. custom canvas (more control) — `graphview` recommended for MVP speed.
2. **PDF library:** `pdf` package (pub.dev) is Flutter-native and avoids native code. Confirmed approach.
3. **Comment cloud sync:** Deferred to Phase 3 when cloud sync architecture is revisited.
4. **Spaced repetition algorithm:** SM-2 algorithm is standard; consider `super_memo` package or implement inline.
5. **Share link deep-links:** Require `app_links` package for Android deep-link handling — add to Week 2.5.
