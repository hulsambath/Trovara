import 'package:logger/logger.dart';
import 'package:trovara/core/services/document_resolver_service.dart';
import 'package:trovara/core/services/vector_search_service.dart';
import 'package:trovara/models/retrieved_document.dart';

/// Builds context-rich augmented prompts that combine the user's question
/// with retrieved note content and metadata.
///
/// This is **Step 4** of the RAG pipeline:
///
/// ```
/// List<RetrievedDocument> (Step 3)
///     │
///     ▼
/// PromptBuilderService.build()
///     │
///     ├─ System instructions
///     ├─ Note context blocks (title, date, folder, tags, content)
///     └─ User question
///     │
///     ▼
/// Augmented prompt string (→ Step 5 LLM generator)
/// ```
///
/// The service is stateless and produces deterministic output given the
/// same inputs, making it straightforward to unit test.
class PromptBuilderService {
  final DocumentResolverService _documentResolver;
  final Logger _logger = Logger();

  /// Maximum number of notes to include in the prompt context.
  static const int defaultMaxNotes = 5;

  /// Maximum total characters of note content in the prompt.
  /// Prevents excessive token usage even with Gemini's large context window.
  static const int defaultMaxContextChars = 20000;

  PromptBuilderService({required DocumentResolverService documentResolver}) : _documentResolver = documentResolver;

  // ═══════════════════════════════════════════════════════════════════════════
  //  System Prompt
  // ═══════════════════════════════════════════════════════════════════════════

  /// The system instructions that guide the LLM's behavior.
  ///
  /// Kept as a static constant so it can be tested and referenced
  /// independently of the document context.
  static const String systemPrompt = '''You are a helpful assistant for a personal note-taking app called Trovara.
The user is asking a question about their own notes.

Answer ONLY based on the provided note context below. If the answer cannot be found in the notes, say "I couldn't find relevant information in your notes about this topic."

Be concise, helpful, and reference specific notes by title when possible.''';

  /// Single-turn optimized system prompt (no source mentions).
  static const String singleTurnSystemPrompt =
      '''You are an assistant answering questions based on user-provided information.

Guidelines:
- Respond clearly and naturally
- Do not copy text directly
- Do not mention sources or context
- If the answer is not available, say you don't know''';

  // ═══════════════════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Build a fully augmented prompt from scored embedding chunks.
  ///
  /// This is the **primary entry point** — it resolves chunks to documents
  /// (via [DocumentResolverService]) and assembles the final prompt.
  ///
  /// Parameters:
  /// - [userQuery]: The user's natural-language question
  /// - [scoredChunks]: Raw search results from [VectorSearchService]
  /// - [maxNotes]: Maximum number of notes to include (default: 5)
  /// - [maxContextChars]: Character budget for note content (default: 20,000)
  ///
  /// Returns the complete prompt string ready for the LLM, or `null` if
  /// no relevant documents could be resolved.
  String? buildFromChunks({
    required String userQuery,
    required List<ScoredEmbedding> scoredChunks,
    int maxNotes = defaultMaxNotes,
    int? maxContextChars,
  }) {
    if (scoredChunks.isEmpty) {
      _logger.d('No scored chunks provided — skipping prompt build');
      return null;
    }

    final documents = _documentResolver.resolve(
      scoredChunks,
      topN: maxNotes,
      maxTextLength: maxContextChars ?? defaultMaxContextChars,
    );

    if (documents.isEmpty) {
      _logger.d('No documents resolved — skipping prompt build');
      return null;
    }

    return buildFromDocuments(userQuery: userQuery, documents: documents);
  }

  /// Build an augmented prompt from pre-resolved documents.
  ///
  /// Use this when you already have [RetrievedDocument]s (e.g. from a
  /// cached resolution or manual selection).
  ///
  /// Parameters:
  /// - [userQuery]: The user's natural-language question
  /// - [documents]: Pre-resolved documents from [DocumentResolverService]
  ///
  /// Returns the complete prompt string ready for the LLM, or `null` if
  /// [documents] is empty.
  String? buildFromDocuments({required String userQuery, required List<RetrievedDocument> documents}) {
    if (documents.isEmpty) return null;

    final buffer = StringBuffer();

    // 1. System instructions
    buffer.writeln(systemPrompt);
    buffer.writeln();

    // 2. Note context
    buffer.writeln(_contextHeader);
    buffer.writeln();

    for (int i = 0; i < documents.length; i++) {
      _writeNoteBlock(buffer, documents[i], i + 1);
    }

    buffer.writeln(_contextFooter);
    buffer.writeln();

    // 3. User question
    buffer.writeln('User question: $userQuery');

    final prompt = buffer.toString();
    _logger.d(
      'Built prompt: ${documents.length} notes, '
      '${prompt.length} chars total',
    );

    return prompt;
  }

  /// Build a single-turn prompt from top chunk context maps.
  ///
  /// Expected map shape: `title`, `date`, `folder`, `tags`, `text`.
  String? buildSingleTurn({required String userQuery, required List<Map<String, String>> topChunkContexts}) {
    final q = userQuery.trim();
    if (q.isEmpty) return null;
    if (topChunkContexts.isEmpty) return null;

    final infoBuf = StringBuffer();
    bool wroteAnyContext = false;
    for (final c in topChunkContexts) {
      final title = (c['title'] ?? '').trim();
      final date = (c['date'] ?? '').trim();
      final folder = (c['folder'] ?? '').trim();
      final tags = (c['tags'] ?? '').trim();
      final text = (c['text'] ?? '').trim();
      if (text.isEmpty) continue;

      wroteAnyContext = true;
      if (title.isNotEmpty) infoBuf.writeln('- Title: $title');
      if (date.isNotEmpty) infoBuf.writeln('  Date: $date');
      if (folder.isNotEmpty) infoBuf.writeln('  Folder: $folder');
      if (tags.isNotEmpty) infoBuf.writeln('  Tags: $tags');
      infoBuf.writeln('  Text: $text');
      infoBuf.writeln();
    }

    if (!wroteAnyContext) return null;

    final buf = StringBuffer();
    buf.writeln(singleTurnSystemPrompt);
    buf.writeln();
    buf.writeln('Question:');
    buf.writeln(q);
    buf.writeln();
    buf.writeln('Information:');
    buf.write(infoBuf.toString());

    final prompt = buf.toString().trimRight();
    _logger.d('Built single-turn prompt: ${topChunkContexts.length} chunk(s), ${prompt.length} chars');
    return prompt;
  }

  /// Extract the list of source note titles from the documents that
  /// would be included in a prompt.
  ///
  /// Useful for source attribution in the chat UI without re-resolving.
  List<String> extractSourceTitles({required List<ScoredEmbedding> scoredChunks, int maxNotes = defaultMaxNotes}) =>
      _documentResolver.resolveToTitles(scoredChunks, topN: maxNotes);

  /// Estimate the token count of a prompt.
  ///
  /// Uses a simple heuristic: ~4 characters per token for English text.
  /// This is a rough estimate — actual token counts depend on the model's
  /// tokenizer.
  static int estimateTokenCount(String prompt) => (prompt.length / 4).ceil();

  // ═══════════════════════════════════════════════════════════════════════════
  //  Private Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _contextHeader = '─── USER\'S NOTES (most relevant) ───';
  static const String _contextFooter = '─── END OF NOTES ───';

  /// Write a single note block into the prompt buffer.
  void _writeNoteBlock(StringBuffer buffer, RetrievedDocument doc, int index) {
    final note = doc.note;

    buffer.writeln('[Note $index]');
    buffer.writeln('Title: ${note.title}');
    buffer.writeln('Date: ${note.createdAt.toIso8601String().split('T')[0]}');

    // Folder — use metadata from the resolver's context maps if available
    // For direct document building, we include what we have
    buffer.writeln('Folder: ${note.folderId}');

    // Build tag string
    final tags = _buildTagString(note);
    if (tags.isNotEmpty) {
      buffer.writeln('Tags: $tags');
    }

    buffer.writeln('Content:');
    buffer.writeln(doc.combinedText);
    buffer.writeln();
  }

  /// Build a human-readable tag string from a note's tag lists.
  ///
  /// Format: `mood: happy, grateful | activity: meditation | time: morning`
  static String _buildTagString(dynamic note) {
    final tags = <String>[];

    final moodTags = note.moodTags as List<String>;
    final activityTags = note.activityTags as List<String>;
    final timeTags = note.timeTags as List<String>;
    final personalGrowthTags = note.personalGrowthTags as List<String>;

    if (moodTags.isNotEmpty) tags.add('mood: ${moodTags.join(', ')}');
    if (activityTags.isNotEmpty) tags.add('activity: ${activityTags.join(', ')}');
    if (timeTags.isNotEmpty) tags.add('time: ${timeTags.join(', ')}');
    if (personalGrowthTags.isNotEmpty) {
      tags.add('growth: ${personalGrowthTags.join(', ')}');
    }

    return tags.join(' | ');
  }
}
