import 'package:trovara/models/note_embedding.dart';

/// Interface for embedding persistence operations.
///
/// Follows Interface Segregation Principle — only embedding-related operations.
abstract class IEmbeddingRepository {
  /// Initialize the repository (open ObjectBox box).
  Future<void> initialize();

  /// Save a single embedding entry.
  Future<void> saveEmbedding(NoteEmbedding embedding);

  /// Save multiple embeddings in a batch.
  Future<void> saveEmbeddings(List<NoteEmbedding> embeddings);

  /// Get all embedding chunks for a specific note.
  List<NoteEmbedding> getEmbeddingsByNoteId(int noteId);

  /// Get all stored embeddings (used for brute-force vector search).
  List<NoteEmbedding> getAllEmbeddings();

  /// Delete all embeddings for a specific note.
  Future<void> deleteByNoteId(int noteId);

  /// Delete all embeddings (e.g. on model version upgrade).
  Future<void> deleteAll();

  /// Total number of stored embedding entries.
  int get totalEmbeddings;

  /// Dispose the repository.
  void dispose();
}
