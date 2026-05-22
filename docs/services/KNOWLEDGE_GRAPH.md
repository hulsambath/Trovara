# Knowledge Graph Architecture

## Overview

The Knowledge Graph is a semantic relationship system that automatically builds as users write notes. It powers researchers, writers, and students with different views of the same underlying data: connection discovery, citation tracking, intelligent organization, and quiz generation.

The graph operates asynchronously—note saves don't block on analysis. It updates whenever notes change, and is queryable at any time.

## Components

### Data Layer

#### ObjectBox Entities

**GraphNode**
- Maps a note to its position in the knowledge graph
- Each note gets one GraphNode
- Stores: `noteId`, `createdAt`, `updatedAt`

**GraphEdge**
- Directional relationship: source node → target node
- Carries metadata about the relationship
- Stores: `sourceNodeId`, `targetNodeId`, `edgeType`, `strength`, `label`, `createdAt`

**Citation**
- External or internal source reference
- Can be a URL, file path, or reference to another note
- Stores: `title`, `url`, `noteId`, `foundAt` (position in note content)

**ProjectBundle**
- Ordered collection of notes (for writers)
- Stores: `title`, `description`, `noteIds` (ordered), `readOnlyShareToken`

#### Repositories

| Interface | Implementation | Purpose |
|---|---|---|
| `IGraphRepository` | `ObjectBoxGraphRepository` | Node and edge CRUD |
| `ICitationRepository` | — | Citation management (TBD) |
| `IProjectBundleRepository` | `ObjectBoxProjectBundleRepository` | Bundle management |

All repositories work through `ObjectBoxStoreManager` (shared singleton).

### Services

#### KnowledgeGraphService (Orchestrator)
Main entry point for graph operations:
- Triggered on note save (async)
- Coordinates analysis pipeline
- Manages graph state and updates

**Public methods:**
```dart
Future<void> analyzeNote(Note note)          // Async analysis on note change
Map<String, dynamic> getGraphStats()         // Node count, edge count, etc.
List<int> getConnectedNotes(int noteId)      // Immediate in-neighbors
```

#### CitationExtractorService
Parses citations from note content:
- Regex: `[citation: source]`
- Supports:
  - URLs: `[citation: https://example.com]`
  - Internal notes: `[citation: Note Title]`
  - Named references: `[citation: Author (2024)]`

**Public methods:**
```dart
List<Citation> extractCitations(String content)
bool isCitation(String text)
```

#### SimilarityMatcherService
Finds semantically similar notes:
- Uses embedding vectors from `EmbeddingService`
- Computes cosine similarity (vectors L2-normalized at insert)
- Configurable threshold (default: 0.7)

**Public methods:**
```dart
List<(int noteId, double score)> findSimilar(List<double> embedding, {double threshold = 0.7})
```

#### StructureAnalyzerService
Infers hierarchical structure:
- Identifies central/hub notes (high in-degree)
- Suggests clusters via connected components
- Computes graph diameter and density

**Public methods:**
```dart
Map<String, dynamic> analyzeStructure()  // Hub nodes, clusters, metrics
List<int> getCentralNotes()               // Top N nodes by connectivity
```

#### ExportService
Multi-format output:
- Markdown with metadata, links, bibliographies
- PDF with table of contents
- HTML standalone or linked

**Public methods:**
```dart
Future<String> exportMarkdown(List<int> noteIds, {bool includeBibliography = true})
Future<String> exportPdf(List<int> noteIds, {String? title})
Future<String> exportHtml(List<int> noteIds, {bool linked = false})
```

#### QuizGeneratorService
LLM-powered assessment generation:
- Retrieves context via RAG
- Prompts LLM for multiple-choice questions
- Parses structured JSON response

**Public methods:**
```dart
Future<List<QuizQuestion>> generateQuiz({
  required List<int> noteIds,
  required int questionCount,
})
```

### Access Control

`ProAccessService` gates Pro features:
```dart
// Check before showing feature
if (serviceLocator.proAccessService.isPro) {
  // Show/enable Pro feature
}
```

## Data Flow

### On Note Save

```
1. NoteService.save(note)
2. ObjectBoxNoteRepository.createNote/updateNote
3. [Async] KnowledgeGraphService.analyzeNote(note)
   a. CitationExtractorService.extractCitations(content)
   b. Get embedding for note
   c. Create GraphNode
   d. SimilarityMatcherService.findSimilar(embedding)
   e. Create semantic GraphEdges
   f. Update IGraphRepository
   g. Broadcast "graph updated"
```

### On Semantic Search (Researcher)

```
1. User searches with RagService.query()
2. Multi-step retrieval via RAG pipeline
3. [if Pro] Rank by graph edges
4. Show results with connection context
```

### On Citation Extraction (Researcher)

```
1. User opens "Citations" in Graph view
2. CitationExtractorService.extractCitations() on all notes
3. Group by URL and frequency
4. Show missing/broken links
5. Export as APA/MLA/Chicago bibliography
```

### On Export (Writer)

```
1. User selects notes + format
2. ExportService.exportMarkdown/Pdf/Html()
3. Resolve internal links [[Note Title]] → URLs
4. Embed citations as footnotes
5. Output file or copy to clipboard
```

### On Quiz Generation (Student)

```
1. User selects notes + count
2. QuizGeneratorService.generateQuiz()
   a. RagService.query() for context
   b. LlmClient.generate(prompt) for questions
   c. Parse structured JSON
3. UI displays quiz with difficulty mix
4. On answer, show explanation + source note
```

## Performance Targets

| Operation | Latency | Notes |
|-----------|---------|-------|
| Note save | <500ms | Graph analysis is async, doesn't block |
| Graph analysis (1 note) | <2s | Embedding + similarity search |
| Similarity search (1K notes) | <200ms | Indexed vector search |
| Citation extraction (100 notes) | <100ms | Regex-based, linear scan |
| Quiz generation (10 Q) | <5s | LLM latency dominates |
| Export to PDF (50 notes) | <3s | File I/O + rendering |

## Database Schema

### GraphNode
```
id: int (PK)
noteId: int (FK to Note)
createdAt: DateTime
updatedAt: DateTime
```

### GraphEdge
```
id: int (PK)
sourceNodeId: int (FK to GraphNode)
targetNodeId: int (FK to GraphNode)
edgeType: String (semantic|citation|hierarchical)
strength: double (0.0–1.0)
label: String? (optional relationship name)
createdAt: DateTime
```

### Citation
```
id: int (PK)
title: String
url: String?
noteId: int (FK to Note)
foundAt: int (byte offset in content)
createdAt: DateTime
```

### ProjectBundle
```
id: int (PK)
title: String
description: String?
noteIds: List<int> (ordered)
readOnlyShareToken: String?
createdAt: DateTime
updatedAt: DateTime
```

## Testing Strategy

### Unit Tests (`patrol_test/core/services/`)
- `KnowledgeGraphService` — orchestration logic
- `CitationExtractorService` — citation parsing
- `SimilarityMatcherService` — vector similarity
- `StructureAnalyzerService` — graph metrics
- `ExportService` — export formats
- `QuizGeneratorService` — question generation

### Integration Tests (`patrol_test/integration/`)
- `graph_lifecycle_test.dart` — note save → graph update → query lifecycle

### Repository Tests (`patrol_test/core/repository/`)
- Graph repository CRUD (TBD)
- Project bundle repository CRUD (TBD)

### E2E Tests (`integration_test/`)
- Full Pro feature workflows (deferred to Phase 2)

## Extending the Graph

### Adding a New Edge Type

1. Update `GraphEdge.edgeType` values in documentation
2. Compute edge in the appropriate service
3. Insert via `IGraphRepository.createEdge()`
4. Example: add `"similarity_user_marked"` for manual note links

### Adding a New Analysis Service

1. Create `lib/core/services/graph/<name>_service.dart`
2. Implement analysis logic
3. Register in `ServiceLocator` as lazy getter
4. Call from `KnowledgeGraphService.analyzeNote()`

Example:
```dart
// In KnowledgeGraphService.analyzeNote()
final customAnalysis = serviceLocator.customAnalysisService.analyze(note);
// Store results in graph
```

### Integrating a New LLM Provider

The QuizGeneratorService uses `LlmClient.generate()`, which already supports
multiple providers (Gemini, OpenAI, OpenRouter). No changes needed—just ensure
the API key is configured in `ConfigConstants`.

## Known Limitations & Future Work

### Current (Phase 1)

- Graph visualization is deferred (Phase 2)
- Collaborative editing not yet implemented
- No custom quiz templates (fixed question types)
- No study group features
- Limited to one embedding model per build (configurable at runtime via API key)

### Phase 2 (Weeks 4-8)

- Interactive graph visualization (nodes, edges, force-directed layout)
- Collaborative note editing with real-time sync
- Custom export templates with CSS
- Advanced search filters (date range, tag, note type)
- Saved search queries

### Phase 3 (Months 2-3)

- Study groups (share quizzes, compare scores)
- Learning paths (AI recommends what to study next)
- Peer comparison (anonymous benchmarking)
- Custom quiz templates (essay, multiple-select, fill-in-blank)
- Flashcard generation from quiz questions

---

## API Reference

See `lib/core/services/graph/` for full implementation.

For Pro feature integration in UI, see:
- `lib/views/graph/` (deferred to Phase 2)
- `lib/views/export/` (deferred to Phase 2)
- `lib/views/quiz/` (deferred to Phase 2)
