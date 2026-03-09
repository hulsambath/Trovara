import 'package:trovara/core/repository/base/base_repository.dart';
import 'package:trovara/core/repository/base/objectbox_store_manager.dart';
import 'package:trovara/core/repository/interfaces/chat_message_repository.dart';
import 'package:trovara/models/chat_message.dart';
import 'package:trovara/objectbox.g.dart';

/// ObjectBox implementation of the chat message repository.
class ObjectBoxChatMessageRepository extends BaseRepository implements IChatMessageRepository {
  late Box<ChatMessageEntity> _messageBox;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    final store = await ObjectBoxStoreManager().store;
    _messageBox = store.box<ChatMessageEntity>();
    _isInitialized = true;
  }

  @override
  List<ChatMessageEntity> getMessagesForThread(int threadId) => _messageBox
      .query(ChatMessageEntity_.threadId.equals(threadId))
      .order(ChatMessageEntity_.createdAt)
      .build()
      .find();

  @override
  List<ChatMessageEntity> getRecentMessagesForThread(int threadId, {int limit = 50}) {
    final query = _messageBox
        .query(ChatMessageEntity_.threadId.equals(threadId))
        .order(ChatMessageEntity_.createdAt, flags: Order.descending)
        .build();
    query.limit = limit;
    final results = query.find();
    query.close();
    return results.reversed.toList();
  }

  @override
  Future<ChatMessageEntity> createMessage(ChatMessageEntity message) async {
    final id = _messageBox.put(message);
    message.id = id;
    notifyListeners();
    return message;
  }

  @override
  Future<void> updateMessage(ChatMessageEntity message) async {
    message.touch();
    _messageBox.put(message);
    notifyListeners();
  }

  @override
  Future<void> upsertMessage(ChatMessageEntity message) async {
    _messageBox.put(message);
    notifyListeners();
  }

  @override
  Future<void> deleteMessagesForThread(int threadId) async {
    final query = _messageBox.query(ChatMessageEntity_.threadId.equals(threadId)).build();
    final ids = query.findIds();
    query.close();
    if (ids.isNotEmpty) {
      _messageBox.removeMany(ids);
      notifyListeners();
    }
  }

  @override
  Future<void> deleteMessage(int id) async {
    _messageBox.remove(id);
    notifyListeners();
  }

  @override
  void dispose() {
    clearListeners();
  }
}
