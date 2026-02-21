import 'package:trovara/core/repository/interfaces/custom_tag_repository.dart';
import 'package:trovara/models/custom_tag.dart';

/// Service layer for custom tag operations
class CustomTagService {
  final ICustomTagRepository _customTagRepository;

  CustomTagService({required ICustomTagRepository customTagRepository}) : _customTagRepository = customTagRepository;

  /// Initialize the repository
  Future<void> initialize() async {
    await _customTagRepository.initialize();
    // Load all custom tags into the static collection
    final allTags = _customTagRepository.getAllCustomTags();
    CustomTags.updateCollection(allTags);
  }

  /// Create a new custom tag or return existing one
  Future<CustomTag> createOrGetCustomTag(String name, {String? color}) async {
    final customTag = await _customTagRepository.createCustomTag(name, color: color);
    // Update the static collection
    CustomTags.updateCollection(_customTagRepository.getAllCustomTags());
    return customTag;
  }

  /// Get custom tag by ID
  CustomTag? getCustomTagById(int id) => _customTagRepository.getCustomTagById(id);

  /// Get custom tag by name
  CustomTag? getCustomTagByName(String name) => _customTagRepository.getCustomTagByName(name);

  /// Get all custom tags
  List<CustomTag> getAllCustomTags() {
    final tags = _customTagRepository.getAllCustomTags();
    // Update the static collection to ensure it's in sync
    CustomTags.updateCollection(tags);
    return tags;
  }

  /// Get most used custom tags
  List<CustomTag> getMostUsedCustomTags() => _customTagRepository.getMostUsedCustomTags();

  /// Get custom tags sorted by name
  List<CustomTag> getCustomTagsSortedByName() => _customTagRepository.getCustomTagsSortedByName();

  /// Get newest custom tags
  List<CustomTag> getNewestCustomTags() => _customTagRepository.getNewestCustomTags();

  /// Search custom tags
  List<CustomTag> searchCustomTags(String query) => _customTagRepository.searchCustomTags(query);

  /// Get unused custom tags
  List<CustomTag> getUnusedCustomTags() => _customTagRepository.getUnusedCustomTags();

  /// Get custom tags in use
  List<CustomTag> getCustomTagsInUse() => _customTagRepository.getCustomTagsInUse();

  /// Update custom tag
  Future<void> updateCustomTag(CustomTag customTag) async {
    await _customTagRepository.updateCustomTag(customTag);
  }

  /// Delete custom tag
  Future<void> deleteCustomTag(int id) async {
    await _customTagRepository.deleteCustomTag(id);
  }

  /// Delete unused custom tags
  Future<void> deleteUnusedCustomTags() async {
    await _customTagRepository.deleteUnusedCustomTags();
  }

  /// Get custom tag statistics
  Map<String, int> getCustomTagStatistics() => _customTagRepository.getCustomTagStatistics();

  /// Check if custom tag exists
  bool customTagExists(String name) => _customTagRepository.customTagExists(name);

  /// Check if custom tag exists by ID
  bool customTagExistsById(int id) => _customTagRepository.customTagExistsById(id);

  /// Get multiple custom tags by IDs
  List<CustomTag> getCustomTagsByIds(List<int> ids) => _customTagRepository.getCustomTagsByIds(ids);

  /// Add listener for changes
  void addListener(Function() listener) {
    _customTagRepository.addListener(listener);
  }

  /// Remove listener
  void removeListener(Function() listener) {
    _customTagRepository.removeListener(listener);
  }

  /// Get tag suggestions based on existing tags
  List<CustomTag> getTagSuggestions(String query, {int limit = 10}) {
    if (query.isEmpty) {
      return getMostUsedCustomTags().take(limit).toList();
    }

    final searchResults = searchCustomTags(query);
    // Sort by usage count, then by name
    searchResults.sort((a, b) {
      final usageComparison = b.usageCount.compareTo(a.usageCount);
      if (usageComparison != 0) return usageComparison;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return searchResults.take(limit).toList();
  }

  /// Get popular tags (most used)
  List<CustomTag> getPopularTags({int limit = 20}) => getMostUsedCustomTags().take(limit).toList();

  /// Get recent tags (newest)
  List<CustomTag> getRecentTags({int limit = 10}) => getNewestCustomTags().take(limit).toList();

  /// Clean up unused tags
  Future<int> cleanupUnusedTags() async {
    final unusedTags = getUnusedCustomTags();
    final count = unusedTags.length;
    await deleteUnusedCustomTags();
    return count;
  }
}
