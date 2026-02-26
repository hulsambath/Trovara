import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/interfaces/embedding_repository.dart';
import 'package:trovara/models/note_embedding.dart';
import 'package:trovara/objectbox.g.dart';

/// ObjectBox implementation of [IEmbeddingRepository].
///
/// Stores [NoteEmbedding] entities in the shared ObjectBox store.
class ObjectBoxEmbeddingRepository implements IEmbeddingRepository {
  late Box<NoteEmbedding> _box;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    final store = await ObjectBoxStoreManager().store;
    _box = store.box<NoteEmbedding>();
    _isInitialized = true;
  }

  @override
  Future<void> saveEmbedding(NoteEmbedding embedding) async {
    _box.put(embedding);
  }

  @override
  Future<void> saveEmbeddings(List<NoteEmbedding> embeddings) async {
    _box.putMany(embeddings);
  }

  @override
  List<NoteEmbedding> getEmbeddingsByNoteId(int noteId) =>
      _box.query(NoteEmbedding_.noteId.equals(noteId)).build().find();

  @override
  List<NoteEmbedding> getAllEmbeddings() => _box.getAll();

  @override
  Future<void> deleteByNoteId(int noteId) async {
    final embeddings = getEmbeddingsByNoteId(noteId);
    _box.removeMany(embeddings.map((e) => e.id).toList());
  }

  @override
  Future<void> deleteAll() async {
    _box.removeAll();
  }

  @override
  int get totalEmbeddings => _box.count();

  @override
  void dispose() {
    // Nothing to dispose — the shared Store is managed by ObjectBoxStoreManager.
  }
}
