# ChatSourceService Design Spec

**Date:** 2026-05-20  
**Status:** Approved  
**Author:** Claude Code

---

## Purpose

Centralize all chat source note logic — building, resolving, and validating source notes for chat messages. Ensures sources are valid, existing notes (not tags/labels/archived notes) and handles display edge cases (empty titles).

## Architecture & Dependencies

```
ChatSourceService
  ├─ depends on: NoteService (fetch notes, search by title)
  ├─ depends on: Note model (read properties)
  └─ called by: ChatViewModel (build sources from RAG results, resolve persisted sources)
```

**Single responsibility:** Source note validation, transformation, and matching. Does NOT persist — that's ChatService's job.

---

## Public API

### 1. buildSourceNotes(List<Note> notes, int? excludeNoteId)

**Purpose:** Convert RAG results into ChatSourceNote objects with validation.

**Behavior:**
- Filters: no deleted, no archived, no ID=0, no duplicates, no excluded note
- Returns deduplicated, validated sources
- Preserves order from input list

**Returns:** `List<ChatSourceNote>`

**Usage:**
```dart
final sources = chatSourceService.buildSourceNotes(ragNotes, currentThread?.id);
```

### 2. resolveSourceNotes(ChatMessageEntity entity, int? excludeNoteId)

**Purpose:** Load source notes from persisted chat message data (IDs and titles).

**Behavior:**
- Fallback: if `sourceNoteIds` exist, use them; otherwise resolve by title
- Validates each note exists and isn't deleted/archived
- Returns resolved sources, skipping invalid ones
- Handles title caching: prefers stored title, falls back to current note title

**Returns:** `List<ChatSourceNote>`

**Usage:**
```dart
final sources = chatSourceService.resolveSourceNotes(chatMessageEntity, currentThread?.id);
```

### 3. resolveNoteByTitle(String title)

**Purpose:** Search notes by title with validation.

**Behavior:**
- Case-insensitive, whitespace-trimmed search
- Exact match preferred, falls back to first match
- Validates result isn't deleted/archived
- Returns null if not found or invalid

**Returns:** `Note?`

**Usage:**
```dart
final note = chatSourceService.resolveNoteByTitle('My Note Title');
```

### 4. isValidSource(Note note)

**Purpose:** Explicit validation that a note is a valid source.

**Behavior:**
- Checks: not deleted, not archived, has valid ID
- Confirms note is a Note entity (not tag/label)
- Reusable for UI or business logic checks

**Returns:** `bool`

**Usage:**
```dart
if (chatSourceService.isValidSource(note)) {
  // Use as source
}
```

---

## Validation Rules (In Order)

For each source, reject if:
1. `note.isDeleted == true`
2. `note.isArchived == true` (if archived flag exists on Note model)
3. `note.id == 0`
4. `note.id == excludeNoteId`
5. Already seen in this batch (dedup by ID)

**Display fallback:** If title is empty, use first 9 chars of description. If description is also empty, skip the source entirely.

---

## Data Flow: From RAG to UI

```
RAG Service → List<Note>
    ↓
buildSourceNotes(notes, threadExcludeId)
    ↓
List<ChatSourceNote> (validated, deduped)
    ↓
ChatViewModel persists via ChatService
    ↓
On reload: ChatMessageEntity (stored IDs/titles)
    ↓
resolveSourceNotes(entity, threadExcludeId)
    ↓
List<ChatSourceNote> (re-validated, handles deleted/archived)
    ↓
SourceAttributionWidget displays
```

---

## Integration with ChatViewModel

### Refactoring Steps

1. **Remove from ChatViewModel:**
   - `_buildSourceNotes(List<Note>)` → move logic to service
   - `_resolveSourceNotes(ChatMessageEntity)` → move logic to service
   - `_resolveNoteByTitle(String)` → move to service as public
   - `_bestLabelFor(Note)` → move to service or remove (no longer needed in display)

2. **Update ChatViewModel calls:**
   - Line 158: `sources = _buildSourceNotes(debugNotes)` → `sources = chatSourceService.buildSourceNotes(debugNotes, _currentThread?.id)`
   - Line 225: `sourceNotes: _resolveSourceNotes(entity)` → `sourceNotes: chatSourceService.resolveSourceNotes(entity, _currentThread?.id)`

3. **Inject ChatSourceService:**
   - Add to ChatViewModel constructor: `ChatSourceService? chatSourceService`
   - Default to ServiceLocator: `chatSourceService ?? ServiceLocator().chatSourceService`

### ServiceLocator Registration

Add to `lib/core/di/service_locator.dart`:
```dart
ChatSourceService get chatSourceService => ChatSourceService(noteService: noteService);
```

---

## File Structure

```
lib/core/services/chat/
├── chat_source_service.dart          ← New service (~200 LOC)
├── chat_service.dart                 ← Unchanged
└── chat_drive_sync_service.dart      ← Unchanged
```

**Target file size:** ~200 LOC (well under 300 limit)

---

## Dependencies

- **NoteService** (injected via constructor)
- **Note model** (for properties: isDeleted, isArchived, id, title, description, tags)
- **ChatSourceNote model** (for return type)

---

## Testing

### Unit Test Scope (patrol_test)

- `buildSourceNotes`: deduplication, filtering deleted/archived, excludeNoteId
- `resolveSourceNotes`: fallback from IDs to titles, validation on reload
- `resolveNoteByTitle`: exact vs. fuzzy match, case insensitivity
- `isValidSource`: all validation rules

### Integration Test Scope

- Round-trip: build sources → persist → resolve → validate in ViewModel flow

---

## Success Criteria

1. ChatViewModel delegates all source logic to service
2. Service validates sources explicitly (no deleted, no archived, no tags/labels)
3. Empty titles show first 9 chars of description
4. Service is ≤300 LOC and well-tested
5. No breaking changes to ChatViewModel public API or UI behavior
6. All existing tests pass