# Trovara Pro Tier Design Specification

**Date:** 2026-05-22
**Status:** Design Approved
**Author:** Brainstorming Session
**Objective:** Monetize Trovara with a $24.99 one-time Pro tier that serves researchers, writers, and students through an integrated Knowledge Graph system.

---

## Executive Summary

Trovara Pro introduces a **semantic Knowledge Graph** — a local-first system that automatically tracks relationships between notes, sources, and concepts. Built on existing RAG infrastructure, the graph powers three complementary feature suites:

- **Researchers:** Bulk analysis, citation tracking, semantic exploration
- **Writers:** Multi-format export, collaborative drafting, project organization
- **Students:** Intelligent quiz generation, spaced repetition, knowledge gap detection

All features are unified by the graph, creating a cohesive experience where analysis informs structure, export preserves relationships, and quizzes target high-value concepts.

**Pricing:** $24.99 one-time purchase. No subscriptions, no trials.

---

## Part 1: Core Architecture

### Knowledge Graph Foundation

The Knowledge Graph is a directed, weighted graph where nodes represent notes and edges represent three types of relationships:

| Edge Type        | Definition                                        | How Detected                                                | Used By                                                |
| ---------------- | ------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------ |
| **Semantic**     | Notes discuss related concepts                    | Cosine similarity of embeddings (threshold: 0.7)            | Researchers (explorer), students (quiz clustering)     |
| **Source**       | Note A cites/references note B or external source | Regex extraction of URLs + internal note links              | Researchers (citation tracker), writers (bibliography) |
| **Hierarchical** | Parent-child relationship (outline structure)     | Manual (user drag/drop in Structure View) or auto-suggested | Writers (outline organization)                         |

### Automatic Graph Building

**Trigger:** Note creation or edit
**Process:**

1. User saves a note
2. EmbeddingService (existing) computes embeddings
3. KnowledgeGraphService analyzes the note:
   - Extracts citations via regex (URLs, internal links)
   - Queries stored embeddings to find similar notes
   - Creates/updates edges; prunes stale edges
4. Graph updates within 1–2 seconds
5. All UI views (Research Panel, Structure View, Quiz Generator) reflect changes

**Async execution:** Graph building runs in background; doesn't block editor.

### Data Storage

**New ObjectBox entities:**

- `GraphNode` — wraps a Note with metadata (creation time, last updated, in-graph timestamp)
- `GraphEdge` — relationship between two nodes
  - `sourceNodeId`, `targetNodeId` (note IDs)
  - `edgeType` (semantic | source | hierarchical)
  - `strength` (0.0–1.0, relevance score for semantic edges)
  - `metadata` (edge-specific data: URL for source edges, user notes for hierarchical)
- `Citation` — external source
  - `url`, `title`, `author`, `datePublished`, `format` (APA/MLA/Chicago)
- `ProjectBundle` — groups notes for writers
  - `name`, `noteIds` (ordered list), `description`, `createdAt`

**Storage location:** Local ObjectBox only (no cloud sync of graph initially).
**Backup:** Full graph exports to Google Drive alongside notes for disaster recovery.

---

## Part 2: Feature Suites

### 2.1 Researcher Features

#### Bulk Analysis Suite

**Semantic Explorer**

- Search across all notes for patterns: "show me all arguments about AI risk"
- Results ranked by relevance (cosine similarity to query embedding)
- Filter by date, tag, or project
- Drill down: click a concept to see all connected notes

**Connection Inspector**

- Click any note to see its in-degree and out-degree (what connects to it, what it connects to)
- View sorted by strength (most relevant first)
- See relationship type: semantic, citation, or hierarchical

**Statistics Dashboard**

- Top 20 most-connected concepts (by in-degree)
- Topic frequency (concept mentions across corpus)
- Citation patterns (which sources appear most often)
- Research density by topic (how many notes per concept)
- Export as CSV or summary report

**UI Location:** Research Panel (left sidebar, toggleable). Occupies 25–40% of viewport; main note area shrinks.

#### Citation & Source Tracker

**Inline Citation System**

- While editing a note, researchers tag sources using syntax: `[citation: https://example.com]` or `[citation: Note Title]`
- Inline annotations show source metadata on hover
- Auto-completion suggests previously cited sources

**Bibliography Generator**

- Select a note or project → generate formatted bibliography (APA, MLA, Chicago)
- Copy to clipboard or export as .bib file
- Deduplication: same source cited multiple times appears once

**Source Integrity View**

- "Which of my notes cite this source?"
- Backlinks sorted by date and frequency
- Identifies over-reliance (single source cited 10+ times)

**Backlink View**

- "What cites this source?" — research dependency map

---

### 2.2 Writer Features

#### Export Engine

**Supported formats:**

- Markdown (with embedded links, code blocks, emphasis preserved)
- PDF (formatted, table of contents, page breaks between chapters)
- HTML (standalone, styled for readability)
- Word (.docx) with styles
- **Future:** Medium, Substack, LinkedIn (with platform metadata)

**Smart formatting:**

- Internal note links become hyperlinks or footnote references (configurable)
- Citations auto-convert to footnotes
- Generates table of contents from note structure
- Images/attachments embedded or linked (configurable)

**Batch export:**

- Select multiple notes or a project → export as a single document
- Custom chapter ordering (drag-and-drop)
- Custom styling templates (default, book, article, thesis)
- Preview before export (WYSIWYG)

#### Organization & Collaborative Drafting

**Structure View**

- Outline view of notes showing hierarchical relationships (tree)
- Drag-and-drop to reorganize
- Collapse/expand clusters
- Flatten (all notes in one view) or nest (hierarchical)

**Project Bundles**

- Group related notes: "Novel Draft A", "Research for Article X"
- Read-only shared links for collaborators
- Notes appear in reading order within project

**Composition Workspace**

- View project as linear document (all notes concatenated)
- Edit inline, changes sync back to individual notes
- Word count and reading time estimates
- "Decompose back" to restore individual note editing

**Collaborative Features**

- **Share links:** Generate read-only shareable URL to a project (collaborators see notes in order)
- **Inline comments:** Collaborators comment on specific sections; visible in context to author
- **Version snapshots:** Save draft versions ("v1 original", "v2 post-editor-feedback")
- **Feedback digest:** Collect all comments into summary view with suggestions
- **Export with track changes:** Show additions/deletions since last snapshot

**Knowledge Graph integration:**

- System automatically suggests logical groupings from the graph
- "These 12 notes form a cluster. Make a project?" (user can accept/ignore)
- Project outline inferred from hierarchical edges in graph

---

### 2.3 Student Features

#### Intelligent Quiz Generator

**Auto-generation:**

- Select a note or project → system generates 5–50 multiple-choice questions
- Question types:
  - Comprehension: "What is X?" (direct from text)
  - Application: "Which example demonstrates Y?" (inference)
  - Synthesis: "How do Z and W relate?" (cross-note connections)
- Difficulty varied (easy, medium, hard)

**Quiz Features**

- **Self-test mode:** Take quiz, review answers after completion
- **Timed mode:** Practice under exam conditions (configurable duration)
- **Flashcard mode:** Convert questions into flashcard decks with spaced repetition
- **Study groups:** Share quiz sets (read-only link) with classmates; compare performance
- **Performance analytics:** Track improvement over time, identify weak topics, get remediation suggestions

#### Knowledge Graph Integration

**Smart question selection:**

- Prioritize **highly-connected concepts** (concepts appearing in many notes = likely exam-relevant)
- Questions link back to source notes: if user gets answer wrong, immediately review relevant section
- Cross-project quizzes: generate from multiple projects to ensure comprehensive coverage

**Study recommendations:**

- System suggests "study this cluster next" based on weak areas
- Graph shows prerequisites: "master these concepts first before tackling advanced topics"
- Spaced repetition schedule built-in (harder questions resurface more often)

---

## Part 3: Technical Implementation

### 3.1 Services & Architecture

**New services (all implement existing Trovara patterns):**

| Service                    | Responsibility                   | Dependencies                |
| -------------------------- | -------------------------------- | --------------------------- |
| `KnowledgeGraphService`    | Build/query graph, manage edges  | EmbeddingService, ObjectBox |
| `CitationExtractorService` | Parse citations from note text   | (none)                      |
| `SimilarityMatcherService` | Find semantically related notes  | EmbeddingService            |
| `QuizGeneratorService`     | Generate quiz questions          | RagService, LlmClient       |
| `ExportService`            | Multi-format export              | (none)                      |
| `StructureAnalyzerService` | Infer hierarchical relationships | KnowledgeGraphService       |

**Integration points:**

- All services registered in `ServiceLocator` (existing DI pattern)
- Graph building triggered by `NoteRepository` change events
- Quiz generation uses existing `RagService` + `LlmClient` (no new LLM calls needed; reuse RAG infrastructure)
- Export uses existing `NoteRepository` queries

### 3.2 Data Flow

**Graph Building (on note save):**

```
NoteRepository.save(note)
  ↓
KnowledgeGraphService.analyzeNote(note)
  ├─ EmbeddingService.getEmbedding(note) [cached]
  ├─ CitationExtractorService.extract(note) → List<Citation>
  ├─ SimilarityMatcherService.findRelated(note) → List<(Node, strength)>
  └─ GraphBuilder.updateEdges(note, citations, relatedNotes)
      ↓
      ObjectBox transactions update GraphNode, GraphEdge, Citation
      ↓
      Broadcast: "graph updated" (UI listeners refresh)
```

**Quiz Generation (on user request):**

```
User selects notes/project in Quiz Generator
  ↓
QuizGeneratorService.generate(selectedNotes, questionCount)
  ├─ StructureAnalyzerService.analyzeCluster(selectedNotes) → key concepts
  ├─ RagService.buildContext(concepts) → retrieved excerpts
  └─ LlmClient.generateQuestions(concepts, context, difficulty)
      ↓
      Questions returned with source note links
      ↓
      UI displays quiz; progress tracked in ObjectBox
```

### 3.3 Error Handling

| Failure Mode                 | Handling                                            |
| ---------------------------- | --------------------------------------------------- |
| Embedding timeout            | Skip note, log warning, retry on next sync          |
| Malformed citation (bad URL) | Extract but mark as "unconfirmed"; shown in tracker |
| Too many connections (>100)  | Filter to top 20 by strength; full list on demand   |
| Circular graph (A→B→C→A)     | Detect and mark in UI; doesn't break graph          |
| Storage quota exceeded       | Warn user, suggest archiving old notes              |
| Quiz generation fails        | Prompt user to select larger corpus or retry        |
| Export fails                 | Show error dialog, suggest reducing project size    |

### 3.4 Performance Targets

| Operation                           | Target Latency |
| ----------------------------------- | -------------- |
| Graph analysis (note save)          | <2 seconds     |
| Similarity search (1K notes)        | <200ms         |
| Graph query (in-degree, out-degree) | <100ms         |
| Quiz generation (10 questions)      | <5 seconds     |
| Export to PDF (50-note project)     | <3 seconds     |

---

## Part 4: Testing Strategy

### Unit Tests

- `KnowledgeGraphService`: graph construction, edge updates, cycle detection
- `CitationExtractorService`: URL/link regex, malformed input handling
- `SimilarityMatcherService`: embedding retrieval, threshold filtering
- `QuizGeneratorService`: question variety, de-duplication, difficulty assignment

### Integration Tests

- Full note-to-graph lifecycle (create → analyze → query)
- Cross-service workflows (export with citations, quiz from multi-note project)
- ObjectBox entity persistence and querying
- Graph sync to Drive (backup/restore)

### Performance Tests

- Graph query latency with 1K, 10K, 100K notes
- Memory usage (graph size vs note corpus size)
- Background analysis impact on editor responsiveness

### User Testing

- Researchers: bulk analysis workflow, citation tracking, semantic explorer
- Writers: export quality, collaborative feedback, composition workspace
- Students: quiz quality (relevance of generated questions), study flow

---

## Part 5: Monetization & Launch

### Pricing Model

- **Pro Tier:** $24.99 one-time purchase
- No subscription, no free trial
- One-time unlock; all features available immediately
- Cross-device sync (iOS, Android, web) included

### In-App Purchase Flow

- "Unlock Pro" button appears in app menu
- Purchase flow explains features per segment (researchers, writers, students)
- After purchase: badge shown next to user settings; Pro features enabled
- Receipt stored locally (no server validation needed)

### Launch Phases

**Phase 1: MVP (Public Launch)**

- Core graph infrastructure
- Bulk analysis (explorer, connection inspector, stats)
- Citation tracking (inline, bibliography, backlinks)
- Export (markdown, PDF, HTML)
- Quiz generator (auto-generated questions, spaced repetition)
- Graph local + Drive sync

**Phase 2: Post-Launch (Weeks 4–8)**

- Collaborative features (comments, version tracking)
- Additional export formats (Medium, Substack native)
- Graph visualization UI polish
- Cross-device graph sync (mobile)

**Phase 3: Extended (Months 2–3)**

- Study groups & peer comparison
- Advanced analytics (research network visualization)
- Custom quiz templates

### Marketing Strategy

- **Researchers:** Blog posts on "bulk analysis for researchers", semantic search tips; post on research-focused subreddits/forums
- **Writers:** Case studies on "organized writing with Trovara", export samples; promote on Medium, writing communities
- **Students:** Study guides, testimonials from student beta users; promote on student Discord/subreddits

---

## Part 6: Success Criteria

- Graph builds correctly on 100+ note corpus with <2s latency
- Export quality verified by writers (formatting preserved, readable in target format)
- Quiz questions are relevant and varied (manual review + user feedback)
- Citation tracker accurately identifies sources and generates proper bibliographies
- Pro tier achieves 5%+ conversion rate within first month
- No regression in core Trovara experience (note editing, search, sync)

---

## Appendix: Open Questions & Future Directions

1. **Graph visualization:** Should researchers see an interactive graph UI (nodes + edges rendered), or is text-based explorer sufficient for MVP?
2. **Mobile support:** Should Pro features be available on iOS/Android from launch, or desktop-only initially?
3. **Collaborative editing:** Should writers be able to edit notes concurrently, or is comment-based feedback sufficient?
4. **API access:** Future: expose graph as API for integrations (e.g., Obsidian plugin, external analytics)?
5. **Multi-vault support:** Future: manage multiple independent knowledge bases (work vs personal)?
