import 'package:trovara/core/repository/base/base_repository.dart';
import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/interfaces/chat_thread_repository.dart';
import 'package:trovara/models/chat_thread.dart';
import 'package:trovara/objectbox.g.dart';

/// ObjectBox implementation of the chat thread repository.
class ObjectBoxChatThreadRepository extends BaseRepository implements IChatThreadRepository {
  late Box<ChatThread> _threadBox;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    final store = await ObjectBoxStoreManager().store;
    _threadBox = store.box<ChatThread>();
    _isInitialized = true;
  }

  @override
  ChatThread? getThreadById(int id) => _threadBox.get(id);

  @override
  List<ChatThread> getThreadsByNote(int noteId) => _threadBox
      .query(ChatThread_.noteId.equals(noteId) & ChatThread_.isDeleted.equals(false))
      .order(ChatThread_.updatedAt, flags: Order.descending)
      .build()
      .find();

  @override
  List<ChatThread> getGlobalThreads() => _threadBox
      .query(ChatThread_.type.equals('global') & ChatThread_.isDeleted.equals(false))
      .order(ChatThread_.updatedAt, flags: Order.descending)
      .build()
      .find();

  @override
  List<ChatThread> getAllThreads() => _threadBox
      .query(ChatThread_.isDeleted.equals(false))
      .order(ChatThread_.updatedAt, flags: Order.descending)
      .build()
      .find();

  @override
  Future<ChatThread> createThread({required String type, int? noteId, String? title}) async {
    final thread = ChatThread(type: type, noteId: noteId, title: title);

    final id = _threadBox.put(thread);
    thread.id = id;

    notifyListeners();
    return thread;
  }

  @override
  Future<void> updateThread(ChatThread thread) async {
    thread.updatedAt = DateTime.now();
    _threadBox.put(thread);
    notifyListeners();
  }

  @override
  Future<void> upsertThread(ChatThread thread) async {
    _threadBox.put(thread);
    notifyListeners();
  }

  @override
  Future<void> deleteThread(int id) async {
    final thread = _threadBox.get(id);
    if (thread == null) return;

    thread.softDelete();
    _threadBox.put(thread);
    notifyListeners();
  }

  @override
  void dispose() {
    clearListeners();
  }
}
