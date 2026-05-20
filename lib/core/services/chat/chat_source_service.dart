import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/models/chat_message.dart';
import 'package:trovara/models/chat_source_note.dart';
import 'package:trovara/models/note.dart';

/// Service for validating, building, and resolving chat source notes.
///
/// Centralizes all source note logic: filtering, deduplication, validation,
/// and title-to-note resolution. Ensures sources are existing notes only
/// (not tags/labels, not deleted, not archived).
class ChatSourceService {
  final NoteService _noteService;

  ChatSourceService({required NoteService noteService}) : _noteService = noteService;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Validation
  // ═══════════════════════════════════════════════════════════════════════════

  /// Validates a note is a valid source for chat context.
  ///
  /// Returns false if the note is:
  /// - deleted (isDeleted == true)
  /// - archived (isArchived == true)
  /// - has invalid ID (id == 0)
  /// - not a Note entity (implicit: checked at type level)
  bool isValidSource(Note note) {
    if (note.isDeleted) return false;
    if (note.isArchived) return false;
    if (note.id == 0) return false;
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Building sources (from RAG results)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Converts RAG results (list of notes) into validated ChatSourceNote objects.
  ///
  /// Filters and deduplicates sources, excludes [excludeNoteId] if provided.
  /// Returns sources in input order, skipping invalid ones.
  List<ChatSourceNote> buildSourceNotes(List<Note> notes, int? excludeNoteId) {
    final seenIds = <int>{};
    final out = <ChatSourceNote>[];

    for (final note in notes) {
      if (!isValidSource(note)) continue;
      if (note.id == excludeNoteId) continue;
      if (seenIds.contains(note.id)) continue;

      seenIds.add(note.id);
      out.add(ChatSourceNote(id: note.id, title: note.title, label: ''));
    }

    return out;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Resolving sources (from persisted message data)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Searches for a note by title with validation.
  ///
  /// Exact match (case-insensitive, whitespace-trimmed) is preferred;
  /// falls back to first search result if exact not found.
  /// Returns null if note not found or is deleted/archived.
  Note? resolveNoteByTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;

    final matches = _noteService.searchNotes(trimmed);
    if (matches.isEmpty) return null;

    final lowerTitle = trimmed.toLowerCase();
    final exact = matches.firstWhere(
      (note) => note.title.toLowerCase().trim() == lowerTitle,
      orElse: () => matches.first,
    );

    if (!isValidSource(exact)) return null;
    return exact;
  }

  /// Loads source notes from persisted chat message data.
  ///
  /// Fallback strategy: if [sourceNoteIds] exist, use them; otherwise
  /// resolve by [sourceNoteTitles]. Validates each note exists and isn't
  /// deleted/archived. Returns resolved sources, skipping invalid ones.
  /// Prefers stored title over current note title.
  List<ChatSourceNote> resolveSourceNotes(ChatMessageEntity entity, int? excludeNoteId) {
    final out = <ChatSourceNote>[];

    // Fallback 1: resolve by IDs if available
    if (entity.sourceNoteIds.isNotEmpty) {
      for (int i = 0; i < entity.sourceNoteIds.length; i++) {
        final id = entity.sourceNoteIds[i];
        if (id == excludeNoteId) continue;

        final note = _noteService.getNote(id);
        if (note == null || !isValidSource(note)) continue;

        final title = entity.sourceNoteTitles.length > i && entity.sourceNoteTitles[i].trim().isNotEmpty
            ? entity.sourceNoteTitles[i]
            : note.title;
        final label = entity.sourceNoteLabels.length > i ? entity.sourceNoteLabels[i] : '';

        out.add(ChatSourceNote(id: note.id, title: title, label: label));
      }
      return out;
    }

    // Fallback 2: resolve by title
    for (final title in entity.sourceNoteTitles) {
      final resolved = resolveNoteByTitle(title);
      if (resolved == null || resolved.id == excludeNoteId) continue;
      out.add(ChatSourceNote(id: resolved.id, title: resolved.title, label: ''));
    }

    return out;
  }
}
