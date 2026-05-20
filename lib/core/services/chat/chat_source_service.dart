import 'package:logger/logger.dart';
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
  final Logger _logger = Logger();

  ChatSourceService({required NoteService noteService}) : _noteService = noteService;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Validation
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  //  Building sources (from RAG results)
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  //  Resolving sources (from persisted message data)
  // ═══════════════════════════════════════════════════════════════════════════
}
