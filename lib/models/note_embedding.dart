import 'package:objectbox/objectbox.dart';

/// Stores a single embedding vector for a chunk of a note's content.
///
/// A note may have multiple [NoteEmbedding] entries when the content is long
/// enough to be split into overlapping chunks.
///
/// The embedding vector is serialized as a comma-separated string because
/// ObjectBox Dart does not support float-list / HNSW vector indexes.
@Entity()
class NoteEmbedding {
  @Id()
  int id;

  /// The ID of the [Note] this embedding belongs to.
  int noteId;

  /// Zero-based index of this chunk within the note.
  /// A short note has a single chunk (index 0).
  int chunkIndex;

  /// The plain-text chunk that was embedded.
  /// Stored so it can be returned as retrieval context without re-parsing.
  String chunkText;

  /// The embedding vector serialized as a comma-separated string of doubles.
  /// Embedding vectors are model-dependent (dimension varies by provider/model).
  String embeddingData;

  /// The embedding model version used (e.g. "text-embedding-004").
  /// Used to detect stale embeddings when the model is upgraded.
  String modelVersion;

  /// Deterministic signature of the exact text passed to the embeddings
  /// API (per note), including chunking parameters.
  ///
  /// Used to detect stale embeddings when the note content changes while
  /// ignoring metadata-only `Note.updatedAt` churn.
  String contentSignature;

  /// Timestamp when this embedding was generated.
  DateTime createdAt;

  /// The [Note.updatedAt] at the time of embedding.
  /// Used to detect if the note content has changed and needs re-embedding.
  DateTime noteUpdatedAt;

  NoteEmbedding({
    this.id = 0,
    required this.noteId,
    required this.chunkIndex,
    required this.chunkText,
    required this.embeddingData,
    required this.modelVersion,
    this.contentSignature = '',
    DateTime? createdAt,
    required this.noteUpdatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Deserialize the embedding string back to a [List<double>].
  List<double> get embedding => embeddingData.split(',').map((s) => double.parse(s.trim())).toList();

  /// Serialize a [List<double>] into the comma-separated storage format.
  static String serializeEmbedding(List<double> vector) => vector.map((d) => d.toStringAsFixed(8)).join(',');
}
