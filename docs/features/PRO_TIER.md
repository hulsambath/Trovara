# Trovara Pro Tier

## Overview

**Trovara Pro** ($24.99, one-time purchase) unlocks powerful knowledge management features designed for researchers, writers, and students. It transforms a personal note app into a sophisticated knowledge management system.

## Features

### Researchers: Bulk Analysis & Citation Tracking

#### Semantic Explorer
Search across all notes for patterns and concepts:
- **Pattern Discovery** — find all arguments about X, examples of Y, definitions of Z
- **Ranked Relevance** — results sorted by semantic similarity (cosine similarity)
- **Multi-Note Context** — drill down to see how concepts connect across your notes

#### Connection Inspector
Visualize your knowledge graph:
- **Incoming/Outgoing Edges** — see what connects to a note
- **Relationship Strength** — edge weights show relevance (0.0–1.0)
- **Relationship Type** — semantic, citation, or hierarchical
- **Context Preview** — hover to see why two notes are connected

#### Citation Tracker
Extract and manage sources systematically:
- **Inline Extraction** — parse `[citation: https://...]` or `[citation: Note Title]`
- **Bibliography Generation** — APA, MLA, Chicago formats
- **Source Metrics** — identify over-reliant sources, find gaps
- **Link Verification** — test URLs and check citation health

### Writers: Export & Collaborative Drafting

#### Export Engine
Multi-format output for different workflows:
- **Markdown** — with embedded frontmatter and metadata
- **PDF** — formatted with table of contents, bookmarks
- **HTML** — standalone or linked, with custom CSS
- **EPUB** — for e-reader distribution

#### Project Bundles
Organize and share related notes:
- **Ordered Collections** — manually arrange notes into chapters/sections
- **Read-Only Sharing** — generate shareable links for collaborators
- **Feedback Integration** — inline comments from reviewers
- **Version Control** — track changes across drafts

### Students: Quiz Generation

#### Intelligent Quizzes
Study smarter with auto-generated assessments:
- **Difficulty Variation** — easy (recall), medium (understanding), hard (application)
- **Source Linking** — tap a question to see the source note
- **Spaced Repetition** — track study progress, review recommendations
- **Explanation Pages** — learn why an answer is correct

## Architecture & Implementation

### Knowledge Graph
The graph automatically builds as you write. It tracks:
- **Semantic Relationships** — computed from embedding similarity
- **Citation Links** — extracted from `[citation: ...]` markers
- **Hierarchical Structure** — inferred from note references and tags

See [Knowledge Graph Architecture](../services/KNOWLEDGE_GRAPH.md) for details.

### Services
- `KnowledgeGraphService` — orchestrates graph analysis
- `CitationExtractorService` — parses inline citations
- `SimilarityMatcherService` — finds semantic connections
- `StructureAnalyzerService` — infers note hierarchies
- `ExportService` — generates multi-format output
- `QuizGeneratorService` — LLM-powered question generation

### Access Control
`ProAccessService` gates Pro features. Check `isPro` before showing:
```dart
if (serviceLocator.proAccessService.isPro) {
  // Show Pro feature
}
```

## Future Work

### Phase 2 (Weeks 4-8)
- Collaborative editing with real-time sync
- Advanced export (custom templates, CSS)
- Graph visualization (interactive node/edge view)
- Search refinements (advanced filters, saved searches)

### Phase 3 (Months 2-3)
- Study groups (share quizzes with classmates)
- Peer comparison (anonymous benchmarking)
- Custom quiz templates (question types, difficulty settings)
- Learning paths (AI-recommended study order)

## Pricing & Availability

| Tier | Price | Features |
|------|-------|----------|
| Free | — | Notes, basic search, cloud sync |
| **Pro** | **$24.99** | **Graph, exports, quiz, citations** |

One-time purchase. Lifetime access. No ads. No subscriptions.

---

## User Guide

### Enabling Pro Features

1. Open **Settings** → **Upgrades**
2. Tap **Unlock Trovara Pro**
3. Complete purchase (IAP)
4. Features unlock immediately

### Using Semantic Explorer

1. Open **Notes** → **Explore**
2. Type a search query (e.g., "learning theories")
3. View ranked results with connections
4. Tap a result to see source note

### Exporting Notes

1. Select one or more notes
2. Tap **Export** → choose format
3. Set options (include citations, table of contents, etc.)
4. Share or save

### Creating Quizzes

1. Select notes to quiz on
2. Tap **Generate Quiz**
3. Choose difficulty mix and question count
4. Study with spaced repetition tracking

### Managing Citations

1. Write notes with `[citation: URL]` or `[citation: Note Title]`
2. Open **Graph** → **Citations**
3. View all sources, missing links, duplicates
4. Export bibliography in APA/MLA/Chicago

---

See [Knowledge Graph Services Documentation](../services/KNOWLEDGE_GRAPH.md) for architecture and API details.
