import 'package:notemyminds/models/folder.dart';

/// Interface for folder repository operations
/// Follows Interface Segregation Principle - only folder-related operations
abstract class IFolderRepository {
  /// Initialize the repository
  Future<void> initialize();

  /// Get all folders
  List<Folder> getAllFolders();

  /// Get a folder by ID
  Folder? getFolderById(String folderId);

  /// Create a new folder
  Future<Folder> createFolder({required String name, String? description, String? color});

  /// Create a new folder with preserved timestamps (for import operations)
  Future<Folder> createFolderWithTimestamps({
    required String folderId,
    required String name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isDefault,
    int noteCount,
  });

  /// Update an existing folder
  Future<void> updateFolder(Folder folder);

  /// Delete a folder by ID
  Future<void> deleteFolder(String folderId);

  /// Get the default folder
  Folder? getDefaultFolder();

  /// Add a listener for data changes
  void addListener(Function() listener);

  /// Remove a listener
  void removeListener(Function() listener);

  /// Dispose the repository
  void dispose();
}
