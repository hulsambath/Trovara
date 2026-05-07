import 'package:trovara/core/services/ai/vector_search_service.dart';
import 'package:trovara/models/note.dart';

/// A fully-resolved note paired with the relevant embedding chunks that
/// matched a user query and the highest similarity score among them.
///
/// Produced by [DocumentResolverService] after grouping raw
/// [ScoredEmbedding] results by note and fetching the full [Note] entity.
class RetrievedDocument {
  /// The full [Note] entity this document represents.
  final Note note;

  /// The embedding chunks that matched the query, sorted by ascending
  /// [NoteEmbedding.chunkIndex] so they can be displayed in reading order.
  final List<ScoredEmbedding> relevantChunks;

  /// The highest similarity score among all [relevantChunks].
  /// Used to rank documents against each other.
  final double maxScore;

  RetrievedDocument({required this.note, required this.relevantChunks, required this.maxScore});

  /// Combined text of all relevant chunks in reading order.
  ///
  /// Chunks are separated by double newlines. Useful for building the
  /// augmented prompt (Step 4) without re-parsing the original note.
  String get combinedText => relevantChunks.map((c) => c.embedding.chunkText).join('\n\n');

  /// Average similarity score across all matched chunks.
  double get avgScore {
    if (relevantChunks.isEmpty) return 0.0;
    final total = relevantChunks.fold<double>(0.0, (sum, c) => sum + c.score);
    return total / relevantChunks.length;
  }

  /// Number of chunks from this note that matched the query.
  int get matchedChunkCount => relevantChunks.length;

  /// Total character count of the combined relevant text.
  int get combinedTextLength => combinedText.length;

  @override
  String toString() =>
      'RetrievedDocument(noteId: ${note.id}, title: "${note.title}", '
      'chunks: $matchedChunkCount, maxScore: ${maxScore.toStringAsFixed(4)})';
}
