import 'package:notemyminds/core/repository/base/base_repository.dart';
import 'package:notemyminds/core/repository/base/objectbox_store_manager.dart';
import 'package:notemyminds/core/repository/interfaces/folder_repository.dart';
import 'package:notemyminds/models/folder.dart';
import 'package:notemyminds/objectbox.g.dart';

/// ObjectBox implementation of the folder repository
/// Follows Dependency Inversion Principle - depends on abstraction, not concrete implementation
class ObjectBoxFolderRepository extends BaseRepository implements IFolderRepository {
  late Box<Folder> _folderBox;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    final store = await ObjectBoxStoreManager().store;
    _folderBox = store.box<Folder>();

    // Create default folder if none exists
    if (_folderBox.isEmpty()) {
      final defaultFolder = Folder(
        folderId: 'default',
        name: 'All Notes',
        description: 'Default folder for all notes',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDefault: true,
      );
      _folderBox.put(defaultFolder);
    }

    _isInitialized = true;
  }

  @override
  List<Folder> getAllFolders() => _folderBox.getAll();

  @override
  Folder? getFolderById(String folderId) => _folderBox.query(Folder_.folderId.equals(folderId)).build().findFirst();

  @override
  Future<Folder> createFolder({required String name, String? description, String? color}) async {
    final folder = Folder(
      folderId: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      color: color,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _folderBox.put(folder);
    notifyListeners();
    return folder;
  }

  /// Create a folder with preserved timestamps (for import operations)
  @override
  Future<Folder> createFolderWithTimestamps({
    required String folderId,
    required String name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isDefault = false,
    int noteCount = 0,
  }) async {
    final folder = Folder(
      folderId: folderId,
      name: name,
      description: description,
      color: color,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      isDefault: isDefault,
      noteCount: noteCount,
    );

    _folderBox.put(folder);
    notifyListeners();
    return folder;
  }

  @override
  Future<void> updateFolder(Folder folder) async {
    folder.updatedAt = DateTime.now();
    _folderBox.put(folder);
    notifyListeners();
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    _folderBox.removeMany(_folderBox.query(Folder_.folderId.equals(folderId)).build().findIds());
    notifyListeners();
  }

  @override
  Folder? getDefaultFolder() => _folderBox.query(Folder_.isDefault.equals(true)).build().findFirst();

  @override
  void dispose() {
    clearListeners();
    // Don't close the store here as it's shared
  }
}
