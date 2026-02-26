import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logger/logger.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/core/services/text_parser_service.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/models/note_embedding.dart';

/// Converts note content into vector embeddings via Google Gemini API.
///
/// Responsibilities:
/// - Extract plain text from Quill Delta JSON via [TextParserService]
/// - Chunk long notes into ~500-token segments with overlap
/// - Call Gemini `text-embedding-004` to generate 768-dim vectors
/// - Persist embeddings via [IEmbeddingRepository]
/// - Re-embed notes whose content has changed
/// - Provide query embedding for similarity search (Step 2)
class EmbeddingService {
  static const String _modelVersion = 'text-embedding-004';
  static const int _maxChunkChars = 2000; // ~500 tokens
  static const int _overlapChars = 200; // overlap between chunks

  final IEmbeddingRepository _embeddingRepository;
  final String _apiKey;
  final Logger _logger = Logger();

  late final GenerativeModel _embeddingModel;
  bool _isInitialized = false;

  /// Notes that failed to embed (e.g. offline). Will be retried on next
  /// call to [processPendingEmbeddings].
  final List<Note> _pendingQueue = [];

  EmbeddingService({required IEmbeddingRepository embeddingRepository, required String apiKey})
    : _embeddingRepository = embeddingRepository,
      _apiKey = apiKey;

  /// Whether the service has a valid API key and has been initialized.
  bool get isAvailable => _isInitialized && _apiKey.isNotEmpty;

  /// Number of notes waiting to be embedded.
  int get pendingCount => _pendingQueue.length;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Initialization
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the Gemini embedding model.
  ///
  /// Also initializes the underlying [IEmbeddingRepository].
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _embeddingRepository.initialize();

    if (_apiKey.isEmpty) {
      _logger.w('EmbeddingService: No API key provided — embedding disabled');
      return;
    }

    _embeddingModel = GenerativeModel(model: _modelVersion, apiKey: _apiKey);
    _isInitialized = true;
    _logger.i('EmbeddingService initialized with model $_modelVersion');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Public API — called from NoteService
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate and store embeddings for a single note.
  ///
  /// 1. Extract plain text via [TextParserService]
  /// 2. Split into overlapping chunks
  /// 3. Generate an embedding vector for each chunk
  /// 4. Persist to repository (replaces any old embeddings for this note)
  ///
  /// This is a fire-and-forget operation — errors are logged, not thrown,
  /// and failed notes are added to the pending queue for retry.
  Future<void> embedNote(Note note) async {
    if (!isAvailable) {
      _addToPendingQueue(note);
      return;
    }

    try {
      final plainText = TextParserService.parseQuillContent(note.contentJson);
      if (plainText.trim().isEmpty) {
        _logger.d('Skipping empty note ${note.id}');
        return;
      }

      // Remove old embeddings for this note
      await _embeddingRepository.deleteByNoteId(note.id);

      // Chunk the text
      final chunks = _chunkText(plainText);

      // Generate and save embeddings for each chunk
      for (int i = 0; i < chunks.length; i++) {
        final vector = await _generateEmbedding(chunks[i]);
        if (vector == null) {
          _logger.w('Failed to generate embedding for note ${note.id} chunk $i');
          _addToPendingQueue(note);
          return;
        }

        final noteEmbedding = NoteEmbedding(
          noteId: note.id,
          chunkIndex: i,
          chunkText: chunks[i],
          embeddingData: NoteEmbedding.serializeEmbedding(vector),
          modelVersion: _modelVersion,
          noteUpdatedAt: note.updatedAt,
        );

        await _embeddingRepository.saveEmbedding(noteEmbedding);
      }

      _logger.i('Embedded note ${note.id}: ${chunks.length} chunk(s)');
    } catch (e) {
      _logger.e('Failed to embed note ${note.id}: $e');
      _addToPendingQueue(note);
    }
  }

  /// Embed a user query for similarity comparison.
  ///
  /// Returns the raw vector (not stored in the repository).
  /// Returns `null` if the API call fails.
  Future<List<double>?> embedQuery(String query) async {
    if (!isAvailable) return null;
    return _generateEmbedding(query);
  }

  /// Remove all embeddings for a note.
  ///
  /// Called when a note is permanently deleted.
  Future<void> deleteEmbeddingsForNote(int noteId) async {
    await _embeddingRepository.deleteByNoteId(noteId);
    _logger.d('Deleted embeddings for note $noteId');
  }

  /// Check if a note's embeddings are stale (note updated after embedding).
  Future<bool> isNoteStale(Note note) async {
    final embeddings = _embeddingRepository.getEmbeddingsByNoteId(note.id);
    if (embeddings.isEmpty) return true;
    return embeddings.first.noteUpdatedAt.isBefore(note.updatedAt);
  }

  /// Re-embed all notes whose content has changed since last embedding.
  ///
  /// Typically called after import or sync operations.
  Future<void> reembedStaleNotes(List<Note> notes) async {
    if (!isAvailable) return;

    int staleCount = 0;
    for (final note in notes) {
      if (note.isDeleted) continue;
      if (await isNoteStale(note)) {
        await embedNote(note);
        staleCount++;
      }
    }
    _logger.i('Re-embedded $staleCount stale note(s) out of ${notes.length}');
  }

  /// Process any notes that failed to embed earlier (e.g. due to being offline).
  ///
  /// Call this when connectivity is restored or on app foreground.
  Future<void> processPendingEmbeddings() async {
    if (!isAvailable || _pendingQueue.isEmpty) return;

    _logger.i('Processing ${_pendingQueue.length} pending embedding(s)');
    final queue = List<Note>.from(_pendingQueue);
    _pendingQueue.clear();

    for (final note in queue) {
      await embedNote(note);
    }
  }

  /// Delete all embeddings and re-embed all provided notes.
  ///
  /// Used when the embedding model version changes.
  Future<void> reembedAll(List<Note> notes) async {
    if (!isAvailable) return;

    _logger.i('Re-embedding all ${notes.length} note(s) (model upgrade)');
    await _embeddingRepository.deleteAll();

    for (final note in notes) {
      if (note.isDeleted) continue;
      await embedNote(note);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Text chunking
  // ═══════════════════════════════════════════════════════════════════════════

  /// Split text into overlapping chunks of ~500 tokens.
  ///
  /// Chunking rules:
  /// - Max chunk size: 2000 chars (~500 tokens)
  /// - Overlap: 200 chars between consecutive chunks
  /// - Prefers to break at sentence boundaries (". ") or newlines
  /// - Skips empty chunks
  List<String> chunkText(String text) => _chunkText(text);

  List<String> _chunkText(String text) {
    if (text.length <= _maxChunkChars) return [text];

    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      int end = start + _maxChunkChars;
      if (end >= text.length) {
        chunks.add(text.substring(start).trim());
        break;
      }

      // Try to break at a sentence or paragraph boundary
      final segment = text.substring(start, end);
      final lastPeriod = segment.lastIndexOf('. ');
      final lastNewline = segment.lastIndexOf('\n');
      final halfChunk = _maxChunkChars ~/ 2;

      // Pick the later of the two boundary points, but only if it's
      // in the second half of the chunk (so chunks aren't too small).
      int breakPoint = -1;
      if (lastPeriod > halfChunk) breakPoint = lastPeriod + 1;
      if (lastNewline > halfChunk && lastNewline > breakPoint) {
        breakPoint = lastNewline;
      }

      if (breakPoint > 0) {
        end = start + breakPoint + 1;
      }

      final chunk = text.substring(start, end).trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }

      start = end - _overlapChars;
    }

    return chunks.where((c) => c.isNotEmpty).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Private helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Call Gemini API to generate an embedding vector for [text].
  Future<List<double>?> _generateEmbedding(String text) async {
    try {
      final result = await _embeddingModel.embedContent(Content.text(text));
      return result.embedding.values;
    } catch (e) {
      _logger.e('Gemini embedding API error: $e');
      return null;
    }
  }

  /// Add a note to the pending retry queue (deduplicated by noteId).
  void _addToPendingQueue(Note note) {
    if (!_pendingQueue.any((n) => n.id == note.id)) {
      _pendingQueue.add(note);
      _logger.d(
        'Added note ${note.id} to pending embedding queue '
        '(queue size: ${_pendingQueue.length})',
      );
    }
  }
}
