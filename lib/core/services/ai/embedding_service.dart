import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/core/services/notes/text_parser_service.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/models/note_embedding.dart';

enum EmbeddingProvider { openAiCompatible, gemini }

/// Converts note content into vector embeddings via an OpenAI-compatible API.
///
/// Responsibilities:
/// - Extract plain text from Quill Delta JSON via [TextParserService]
/// - Chunk long notes into ~500-token segments with overlap
/// - Call an embeddings endpoint (default: OpenRouter)
/// - Persist embeddings via [IEmbeddingRepository]
/// - Re-embed notes whose content has changed
/// - Provide query embedding for similarity search (Step 2)
class EmbeddingService {
  static const String defaultBaseUrl = 'https://openrouter.ai/api/v1';
  static const String defaultEmbeddingModel = 'openai/text-embedding-3-large';
  static const String defaultGeminiEmbeddingModel = 'gemini-embedding-001';
  static const int _maxChunkChars = 2000; // ~500 tokens
  static const int _overlapChars = 200; // overlap between chunks

  final IEmbeddingRepository _embeddingRepository;
  final EmbeddingProvider _provider;
  final String _apiKey;
  final String _modelName;
  final String _baseUrl;
  final String? _siteUrl;
  final String? _appName;
  final Logger _logger = Logger();

  http.Client? _client;
  GenerativeModel? _geminiModel;
  bool _isInitialized = false;

  EmbeddingApiException? _lastError;

  /// Last API error encountered while embedding (if any).
  EmbeddingApiException? get lastError => _lastError;

  /// Notes that failed to embed (e.g. offline). Will be retried on next
  /// call to [processPendingEmbeddings].
  final List<Note> _pendingQueue = [];

  EmbeddingService({
    required IEmbeddingRepository embeddingRepository,
    EmbeddingProvider provider = EmbeddingProvider.openAiCompatible,
    required String apiKey,
    String modelName = defaultEmbeddingModel,
    String baseUrl = defaultBaseUrl,
    String? siteUrl,
    String? appName,
  }) : _embeddingRepository = embeddingRepository,
       _provider = provider,
       _apiKey = apiKey,
       _modelName = modelName,
       _baseUrl = baseUrl,
       _siteUrl = siteUrl,
       _appName = appName;

  /// Whether the service has a valid API key and has been initialized.
  bool get isAvailable => _isInitialized && _apiKey.isNotEmpty;

  /// Number of notes waiting to be embedded.
  int get pendingCount => _pendingQueue.length;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Initialization
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the embedding client.
  ///
  /// Also initializes the underlying [IEmbeddingRepository].
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _embeddingRepository.initialize();

    if (_apiKey.isEmpty) {
      _logger.w('EmbeddingService: No API key provided — embedding disabled');
      return;
    }

    switch (_provider) {
      case EmbeddingProvider.openAiCompatible:
        _client = http.Client();
        _isInitialized = true;
        _logger.i('EmbeddingService initialized (OpenAI-compatible) (baseUrl=$_baseUrl, model=$_modelName)');
        return;
      case EmbeddingProvider.gemini:
        _geminiModel = GenerativeModel(model: _modelName, apiKey: _apiKey);
        _isInitialized = true;
        _logger.i('EmbeddingService initialized (Gemini) (model=$_modelName)');
        return;
    }
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
      if (_apiKey.isNotEmpty) {
        _addToPendingQueue(note);
      }
      return;
    }

    try {
      final embeddingInputs = buildEmbeddingInputs(note);
      if (embeddingInputs.isEmpty) {
        _logger.d('Skipping empty note ${note.id}');
        return;
      }

      final signature = computeContentSignature(
        embeddingInputs,
        modelName: _modelName,
        maxChunkChars: _maxChunkChars,
        overlapChars: _overlapChars,
      );

      // Remove old embeddings for this note
      await _embeddingRepository.deleteByNoteId(note.id);

      // Chunk the text (needed for chunkText storage)
      final title = note.title.trim();
      final content = TextParserService.parseQuillContent(note.contentJson).trim();
      final textForChunking = content.isEmpty ? title : content;
      final chunks = _chunkText(textForChunking);

      // Generate and save embeddings for each chunk
      for (int i = 0; i < chunks.length; i++) {
        final vector = await _generateEmbedding(embeddingInputs[i]);
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
          modelVersion: _modelName,
          contentSignature: signature,
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

  String _buildEmbeddingInput({required String title, required String chunkText}) {
    if (title.isEmpty) return chunkText;
    return 'Title: $title\n\n$chunkText';
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

  /// Check if a note's embeddings are stale.
  ///
  /// Staleness is determined by:
  /// 1. No embeddings exist → stale
  /// 2. Model version mismatch → stale
  /// 3. Content signature comparison (if signature exists)
  /// 4. Lazy fallback to `noteUpdatedAt` when signature is empty
  Future<bool> isNoteStale(Note note) async {
    final embeddings = _embeddingRepository.getEmbeddingsByNoteId(note.id);
    if (embeddings.isEmpty) return true;

    final stored = embeddings.first;

    // Model version mismatch → stale
    if (stored.modelVersion != _modelName) return true;

    // Lazy fallback: no signature yet → use updatedAt
    if (stored.contentSignature.isEmpty) {
      return stored.noteUpdatedAt.isBefore(note.updatedAt);
    }

    // Signature-based check
    final inputs = buildEmbeddingInputs(note);
    if (inputs.isEmpty) return true;
    final currentSig = computeContentSignature(
      inputs,
      modelName: _modelName,
      maxChunkChars: _maxChunkChars,
      overlapChars: _overlapChars,
    );
    return stored.contentSignature != currentSig;
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  Content signature
  // ═══════════════════════════════════════════════════════════════════════════

  /// Build the exact embedding-input strings for a note.
  ///
  /// This is the single source-of-truth for what text gets sent to the
  /// embedding API, used by both [embedNote] and [isNoteStale].
  List<String> buildEmbeddingInputs(Note note) {
    final title = note.title.trim();
    final content = TextParserService.parseQuillContent(note.contentJson).trim();
    final textForChunking = content.isEmpty ? title : content;
    if (textForChunking.isEmpty) return [];
    final chunks = _chunkText(textForChunking);
    return chunks
        .map((chunk) => content.isEmpty ? chunk : _buildEmbeddingInput(title: title, chunkText: chunk))
        .toList();
  }

  /// Compute a deterministic SHA-256 content signature from embedding inputs.
  ///
  /// The hash includes the model name and chunking parameters so that any
  /// change to chunking rules naturally invalidates old signatures.
  static String computeContentSignature(
    List<String> embeddingInputs, {
    required String modelName,
    required int maxChunkChars,
    required int overlapChars,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('model=$modelName');
    buffer.writeln('maxChunk=$maxChunkChars');
    buffer.writeln('overlap=$overlapChars');
    for (final input in embeddingInputs) {
      buffer.writeln('---');
      buffer.writeln(input.replaceAll('\r\n', '\n').trim());
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

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

  /// Call the embeddings API to generate an embedding vector for [text].
  Future<List<double>?> _generateEmbedding(String text) async {
    try {
      if (_provider == EmbeddingProvider.gemini) {
        if (_geminiModel == null) return null;

        final res = await _geminiModel!.embedContent(Content.text(text));
        final values = res.embedding.values;
        _lastError = null;
        return values;
      }

      if (_client == null) return null;

      final uri = Uri.parse('$_baseUrl/embeddings');
      final res = await _client!.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({'model': _modelName, 'input': text}),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        _lastError = EmbeddingApiException.fromHttp(statusCode: res.statusCode, body: res.body);
        _logger.e('Embedding API error (${res.statusCode}): ${_lastError!.message}');
        return null;
      }

      _lastError = null;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;

      final data = decoded['data'];
      if (data is! List || data.isEmpty) return null;

      final first = data.first;
      if (first is! Map) return null;

      final embedding = first['embedding'];
      if (embedding is! List) return null;

      return embedding.map((e) => (e as num).toDouble()).toList(growable: false);
    } catch (e) {
      _lastError = EmbeddingApiException(statusCode: null, message: e.toString());
      _logger.e('Embedding API error: $e');
      return null;
    }
  }

  Map<String, String> _buildHeaders() {
    if (_provider != EmbeddingProvider.openAiCompatible) {
      throw StateError('_buildHeaders is only valid for OpenAI-compatible providers');
    }

    final headers = <String, String>{'Authorization': 'Bearer $_apiKey', 'Content-Type': 'application/json'};

    if (_siteUrl != null && _siteUrl.trim().isNotEmpty) {
      headers['HTTP-Referer'] = _siteUrl.trim();
    }
    if (_appName != null && _appName.trim().isNotEmpty) {
      headers['X-Title'] = _appName.trim();
    }

    return headers;
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

class EmbeddingApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? code;

  EmbeddingApiException({required this.statusCode, required this.message, this.code});

  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  static EmbeddingApiException fromHttp({required int statusCode, required String body}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final err = decoded['error'] as Map;
        return EmbeddingApiException(
          statusCode: statusCode,
          message: err['message']?.toString() ?? body,
          code: err['code']?.toString(),
        );
      }
    } catch (_) {
      // Ignore JSON parse errors.
    }

    final truncated = body.length > 500 ? '${body.substring(0, 500)}…' : body;
    return EmbeddingApiException(statusCode: statusCode, message: truncated);
  }

  @override
  String toString() {
    final parts = <String>['Embedding API error'];
    if (statusCode != null) parts.add('($statusCode)');
    parts.add(': $message');
    if (code != null && code!.isNotEmpty) parts.add('code=$code');
    return parts.join(' ');
  }
}
