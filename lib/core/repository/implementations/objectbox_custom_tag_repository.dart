import 'package:noteminds/core/repository/base/base_repository.dart';
import 'package:noteminds/core/repository/base/objectbox_store_manager.dart';
import 'package:noteminds/core/repository/interfaces/custom_tag_repository.dart';
import 'package:noteminds/models/custom_tag.dart';
import 'package:noteminds/objectbox.g.dart';

/// ObjectBox implementation of custom tag repository
class ObjectBoxCustomTagRepository extends BaseRepository implements ICustomTagRepository {
  late Box<CustomTag> _customTagBox;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    final store = await ObjectBoxStoreManager().store;
    _customTagBox = store.box<CustomTag>();
    _isInitialized = true;
  }

  @override
  Future<CustomTag> createCustomTag(String name, {String? color}) async {
    // Check if tag already exists
    final existingTag = getCustomTagByName(name);
    if (existingTag != null) {
      return existingTag;
    }

    final customTag = CustomTag.create(name, color: color);
    final id = _customTagBox.put(customTag);
    customTag.id = id;

    super.notifyListeners();
    return customTag;
  }

  @override
  CustomTag? getCustomTagById(int id) => _customTagBox.get(id);

  @override
  CustomTag? getCustomTagByName(String name) {
    final query = _customTagBox.query(CustomTag_.name.equals(name.trim())).build();
    final results = query.find();
    query.close();

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  @override
  List<CustomTag> getAllCustomTags() => _customTagBox.getAll();

  @override
  List<CustomTag> getMostUsedCustomTags() {
    final query = _customTagBox.query().order(CustomTag_.usageCount, flags: Order.descending).build();
    final results = query.find();
    query.close();
    return results;
  }

  @override
  List<CustomTag> getCustomTagsSortedByName() {
    final query = _customTagBox.query().order(CustomTag_.name).build();
    final results = query.find();
    query.close();
    return results;
  }

  @override
  List<CustomTag> getNewestCustomTags() {
    final query = _customTagBox.query().order(CustomTag_.createdAt, flags: Order.descending).build();
    final results = query.find();
    query.close();
    return results;
  }

  @override
  List<CustomTag> searchCustomTags(String query) {
    if (query.isEmpty) return getAllCustomTags();

    final searchQuery = _customTagBox.query(CustomTag_.name.contains(query, caseSensitive: false)).build();
    final results = searchQuery.find();
    searchQuery.close();
    return results;
  }

  @override
  List<CustomTag> getUnusedCustomTags() {
    final query = _customTagBox.query(CustomTag_.usageCount.equals(0)).build();
    final results = query.find();
    query.close();
    return results;
  }

  @override
  List<CustomTag> getCustomTagsInUse() {
    final query = _customTagBox.query(CustomTag_.usageCount.greaterThan(0)).build();
    final results = query.find();
    query.close();
    return results;
  }

  @override
  Future<void> updateCustomTag(CustomTag customTag) async {
    customTag.updatedAt = DateTime.now();
    _customTagBox.put(customTag);
    super.notifyListeners();
  }

  @override
  Future<void> deleteCustomTag(int id) async {
    _customTagBox.remove(id);
    super.notifyListeners();
  }

  @override
  Future<void> deleteUnusedCustomTags() async {
    final unusedTags = getUnusedCustomTags();
    for (final tag in unusedTags) {
      _customTagBox.remove(tag.id);
    }
    if (unusedTags.isNotEmpty) {
      super.notifyListeners();
    }
  }

  @override
  Map<String, int> getCustomTagStatistics() {
    final allTags = getAllCustomTags();
    final inUseTags = getCustomTagsInUse();
    final unusedTags = getUnusedCustomTags();
    final totalUsage = allTags.fold(0, (sum, tag) => sum + tag.usageCount);

    return {'total': allTags.length, 'inUse': inUseTags.length, 'unused': unusedTags.length, 'totalUsage': totalUsage};
  }

  @override
  bool customTagExists(String name) => getCustomTagByName(name) != null;

  @override
  bool customTagExistsById(int id) => getCustomTagById(id) != null;

  @override
  List<CustomTag> getCustomTagsByIds(List<int> ids) =>
      ids.map((id) => getCustomTagById(id)).where((tag) => tag != null).cast<CustomTag>().toList();
}
