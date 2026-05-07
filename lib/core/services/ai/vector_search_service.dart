import 'dart:math';

import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/models/note_embedding.dart';

/// A [NoteEmbedding] paired with its cosine similarity score.
class ScoredEmbedding {
  /// The embedding chunk that matched the query.
  final NoteEmbedding embedding;

  /// Cosine similarity score in the range [0, 1].
  /// Higher scores indicate greater relevance.
  final double score;

  ScoredEmbedding({required this.embedding, required this.score});

  @override
  String toString() =>
      'ScoredEmbedding(noteId: ${embedding.noteId}, chunk: ${embedding.chunkIndex}, score: ${score.toStringAsFixed(4)})';
}

/// Performs cosine-similarity vector search over stored embeddings.
///
/// Uses brute-force in-memory search since ObjectBox Dart does not support
/// HNSW vector indexes. This approach is performant for personal note
/// collections (typically < 10,000 chunks).
///
/// ## Performance Estimates
///
/// | Chunks | Search Time |
/// |--------|-------------|
/// | 500    | ~2–5 ms     |
/// | 2,500  | ~5–15 ms    |
/// | 10,000 | ~30–60 ms   |
///
/// For larger collections, consider:
/// - Pre-loading embeddings into typed Float64List for SIMD-friendly access
/// - Using Isolate.run() to move search off the main thread
/// - External vector DB (Pinecone, Qdrant) for cloud-scale
class VectorSearchService {
  final IEmbeddingRepository _repository;

  VectorSearchService({required IEmbeddingRepository repository}) : _repository = repository;

  // ═══════════════════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Find the top-K most similar chunks to the query embedding.
  ///
  /// Returns a list of [ScoredEmbedding] pairs sorted by descending similarity.
  ///
  /// Parameters:
  /// - [queryEmbedding]: The vector representation of the user's query
  /// - [topK]: Maximum number of results to return (default: 5)
  /// - [minScore]: Minimum similarity threshold (default: 0.3)
  ///
  /// Example:
  /// ```dart
  /// final queryVector = await embeddingService.embedQuery('meditation tips');
  /// final results = vectorSearchService.search(queryVector!, topK: 5);
  /// for (final result in results) {
  ///   print('Note ${result.embedding.noteId}: ${result.score}');
  /// }
  /// ```
  List<ScoredEmbedding> search(List<double> queryEmbedding, {int topK = 5, double minScore = 0.3}) {
    final allEmbeddings = _repository.getAllEmbeddings();
    if (allEmbeddings.isEmpty) return [];

    final scored = <ScoredEmbedding>[];

    for (final emb in allEmbeddings) {
      final score = _cosineSimilarity(queryEmbedding, emb.embedding);
      if (score >= minScore) {
        scored.add(ScoredEmbedding(embedding: emb, score: score));
      }
    }

    // Sort by descending similarity score
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.take(topK).toList();
  }

  /// Find similar chunks, excluding embeddings from specific notes.
  ///
  /// Useful for finding related notes while excluding the current note.
  List<ScoredEmbedding> searchExcluding(
    List<double> queryEmbedding, {
    required Set<int> excludeNoteIds,
    int topK = 5,
    double minScore = 0.3,
  }) {
    final allEmbeddings = _repository.getAllEmbeddings();
    if (allEmbeddings.isEmpty) return [];

    final scored = <ScoredEmbedding>[];

    for (final emb in allEmbeddings) {
      if (excludeNoteIds.contains(emb.noteId)) continue;

      final score = _cosineSimilarity(queryEmbedding, emb.embedding);
      if (score >= minScore) {
        scored.add(ScoredEmbedding(embedding: emb, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList();
  }

  /// Find chunks similar to a specific note's content.
  ///
  /// Averages the embeddings of all chunks in the source note, then searches
  /// for similar chunks (excluding the source note itself).
  ///
  /// Returns empty list if the note has no embeddings.
  List<ScoredEmbedding> findSimilarToNote(int noteId, {int topK = 5, double minScore = 0.3}) {
    final noteEmbeddings = _repository.getEmbeddingsByNoteId(noteId);
    if (noteEmbeddings.isEmpty) return [];

    // Compute the average embedding for all chunks in the note
    final avgEmbedding = _averageEmbeddings(noteEmbeddings.map((e) => e.embedding).toList());

    return searchExcluding(avgEmbedding, excludeNoteIds: {noteId}, topK: topK, minScore: minScore);
  }

  /// Get statistics about the stored embeddings.
  EmbeddingStats getStats() {
    final allEmbeddings = _repository.getAllEmbeddings();
    if (allEmbeddings.isEmpty) {
      return EmbeddingStats(totalChunks: 0, uniqueNotes: 0, avgChunksPerNote: 0, embeddingDimension: 0);
    }

    final uniqueNoteIds = allEmbeddings.map((e) => e.noteId).toSet();

    return EmbeddingStats(
      totalChunks: allEmbeddings.length,
      uniqueNotes: uniqueNoteIds.length,
      avgChunksPerNote: allEmbeddings.length / uniqueNoteIds.length,
      embeddingDimension: allEmbeddings.first.embedding.length,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Private Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Compute cosine similarity between two vectors.
  ///
  /// Returns a value in [0, 1] for normalized vectors (Gemini embeddings
  /// are typically normalized). Returns 0 if vectors have different lengths
  /// or if either has zero magnitude.
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return 0.0;

    return dotProduct / denominator;
  }

  /// Compute the element-wise average of multiple embedding vectors.
  List<double> _averageEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return [];
    if (embeddings.length == 1) return embeddings.first;

    final dimension = embeddings.first.length;
    final result = List<double>.filled(dimension, 0.0);

    for (final emb in embeddings) {
      for (int i = 0; i < dimension; i++) {
        result[i] += emb[i];
      }
    }

    final count = embeddings.length.toDouble();
    for (int i = 0; i < dimension; i++) {
      result[i] /= count;
    }

    return result;
  }
}

/// Statistics about the embedding store.
class EmbeddingStats {
  /// Total number of embedding chunks stored.
  final int totalChunks;

  /// Number of unique notes with embeddings.
  final int uniqueNotes;

  /// Average number of chunks per note.
  final double avgChunksPerNote;

  /// Dimension of the embedding vectors (768 for Gemini text-embedding-004).
  final int embeddingDimension;

  EmbeddingStats({
    required this.totalChunks,
    required this.uniqueNotes,
    required this.avgChunksPerNote,
    required this.embeddingDimension,
  });

  @override
  String toString() =>
      'EmbeddingStats('
      'totalChunks: $totalChunks, '
      'uniqueNotes: $uniqueNotes, '
      'avgChunksPerNote: ${avgChunksPerNote.toStringAsFixed(2)}, '
      'dimension: $embeddingDimension)';
}
