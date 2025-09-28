import 'package:noteminds/models/custom_tag.dart';

/// Interface for custom tag repository operations
abstract class ICustomTagRepository {
  /// Initialize the repository
  Future<void> initialize();

  /// Create a new custom tag
  Future<CustomTag> createCustomTag(String name, {String? color});

  /// Get custom tag by ID
  CustomTag? getCustomTagById(int id);

  /// Get custom tag by name (case-insensitive)
  CustomTag? getCustomTagByName(String name);

  /// Get all custom tags
  List<CustomTag> getAllCustomTags();

  /// Get custom tags sorted by usage count
  List<CustomTag> getMostUsedCustomTags();

  /// Get custom tags sorted by name
  List<CustomTag> getCustomTagsSortedByName();

  /// Get custom tags sorted by creation date
  List<CustomTag> getNewestCustomTags();

  /// Search custom tags by name
  List<CustomTag> searchCustomTags(String query);

  /// Get unused custom tags
  List<CustomTag> getUnusedCustomTags();

  /// Get custom tags in use
  List<CustomTag> getCustomTagsInUse();

  /// Update custom tag
  Future<void> updateCustomTag(CustomTag customTag);

  /// Delete custom tag
  Future<void> deleteCustomTag(int id);

  /// Delete unused custom tags
  Future<void> deleteUnusedCustomTags();

  /// Get custom tag statistics
  Map<String, int> getCustomTagStatistics();

  /// Check if custom tag exists by name
  bool customTagExists(String name);

  /// Check if custom tag exists by ID
  bool customTagExistsById(int id);

  /// Get multiple custom tags by IDs
  List<CustomTag> getCustomTagsByIds(List<int> ids);

  /// Add listener for repository changes
  void addListener(Function() listener);

  /// Remove listener
  void removeListener(Function() listener);
}
