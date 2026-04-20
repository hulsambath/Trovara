import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/repository/interfaces/custom_tag_repository.dart';
import 'package:trovara/core/services/custom_tag_service.dart';
import 'package:trovara/models/custom_tag.dart';

class _FakeCustomTagRepository implements ICustomTagRepository {
  final List<CustomTag> _tags;
  int _nextId;

  _FakeCustomTagRepository(List<CustomTag> initialTags)
    : _tags = List<CustomTag>.from(initialTags),
      _nextId = initialTags.isEmpty ? 1 : initialTags.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;

  @override
  Future<void> initialize() async {}

  @override
  Future<CustomTag> createCustomTag(String name, {String? color}) async {
    final normalized = name.trim().toLowerCase();
    final existing = _tags.where((t) => t.name.toLowerCase() == normalized).firstOrNull;
    if (existing != null) {
      return existing;
    }

    final tag = CustomTag(id: _nextId++, name: name.trim(), color: color ?? '#2196F3');
    _tags.add(tag);
    return tag;
  }

  @override
  CustomTag? getCustomTagById(int id) => _tags.where((t) => t.id == id).firstOrNull;

  @override
  CustomTag? getCustomTagByName(String name) {
    final normalized = name.trim().toLowerCase();
    return _tags.where((t) => t.name.toLowerCase() == normalized).firstOrNull;
  }

  @override
  List<CustomTag> getAllCustomTags() => List<CustomTag>.from(_tags);

  @override
  List<CustomTag> getMostUsedCustomTags() => List<CustomTag>.from(_tags)
    ..sort((a, b) => b.usageCount.compareTo(a.usageCount));

  @override
  List<CustomTag> getCustomTagsSortedByName() => List<CustomTag>.from(_tags)
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  List<CustomTag> getNewestCustomTags() => List<CustomTag>.from(_tags)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  List<CustomTag> searchCustomTags(String query) {
    final normalized = query.toLowerCase();
    return _tags.where((t) => t.name.toLowerCase().contains(normalized)).toList();
  }

  @override
  List<CustomTag> getUnusedCustomTags() => _tags.where((t) => t.usageCount == 0).toList();

  @override
  List<CustomTag> getCustomTagsInUse() => _tags.where((t) => t.usageCount > 0).toList();

  @override
  Future<void> updateCustomTag(CustomTag customTag) async {
    final index = _tags.indexWhere((t) => t.id == customTag.id);
    if (index == -1) return;
    _tags[index] = CustomTag(
      id: customTag.id,
      name: customTag.name,
      color: customTag.color,
      createdAt: customTag.createdAt,
      updatedAt: customTag.updatedAt,
      usageCount: customTag.usageCount,
    );
  }

  @override
  Future<void> deleteCustomTag(int id) async {
    _tags.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> deleteUnusedCustomTags() async {
    _tags.removeWhere((t) => t.usageCount == 0);
  }

  @override
  Map<String, int> getCustomTagStatistics() => {
    'total': _tags.length,
    'inUse': _tags.where((t) => t.usageCount > 0).length,
    'unused': _tags.where((t) => t.usageCount == 0).length,
    'totalUsage': _tags.fold(0, (sum, t) => sum + t.usageCount),
  };

  @override
  bool customTagExists(String name) => getCustomTagByName(name) != null;

  @override
  bool customTagExistsById(int id) => getCustomTagById(id) != null;

  @override
  List<CustomTag> getCustomTagsByIds(List<int> ids) =>
      _tags.where((t) => ids.contains(t.id)).toList();

  @override
  void addListener(Function() listener) {}

  @override
  void removeListener(Function() listener) {}
}

void main() {
  group('CustomTagService cache synchronization', () {
    setUp(() {
      CustomTags.clear();
    });

    tearDown(() {
      CustomTags.clear();
    });

    test('initialize populates static CustomTags collection', () async {
      final repo = _FakeCustomTagRepository([
        CustomTag(id: 1, name: 'focus', usageCount: 2),
        CustomTag(id: 2, name: 'sleep', usageCount: 1),
      ]);
      final service = CustomTagService(customTagRepository: repo);

      await service.initialize();

      expect(CustomTags.all, hasLength(2));
      expect(CustomTags.getByName('focus')?.id, 1);
    });

    test('createOrGetCustomTag refreshes static collection', () async {
      final repo = _FakeCustomTagRepository([]);
      final service = CustomTagService(customTagRepository: repo);

      await service.initialize();
      await service.createOrGetCustomTag('health');

      expect(CustomTags.exists('health'), isTrue);
      expect(CustomTags.all, hasLength(1));
    });

    test('updateCustomTag keeps static collection in sync', () async {
      final repo = _FakeCustomTagRepository([CustomTag(id: 7, name: 'old-name')]);
      final service = CustomTagService(customTagRepository: repo);
      await service.initialize();

      final updatedTag = CustomTag(id: 7, name: 'new-name');
      await service.updateCustomTag(updatedTag);

      expect(CustomTags.getById(7)?.name, 'new-name');
    });

    test('deleteCustomTag keeps static collection in sync', () async {
      final repo = _FakeCustomTagRepository([
        CustomTag(id: 1, name: 'to-delete'),
        CustomTag(id: 2, name: 'to-keep'),
      ]);
      final service = CustomTagService(customTagRepository: repo);
      await service.initialize();

      await service.deleteCustomTag(1);

      expect(CustomTags.getById(1), isNull);
      expect(CustomTags.getById(2), isNotNull);
    });

    test('deleteUnusedCustomTags keeps static collection in sync', () async {
      final repo = _FakeCustomTagRepository([
        CustomTag(id: 1, name: 'used', usageCount: 3),
        CustomTag(id: 2, name: 'unused', usageCount: 0),
      ]);
      final service = CustomTagService(customTagRepository: repo);
      await service.initialize();

      await service.deleteUnusedCustomTags();

      expect(CustomTags.getById(1), isNotNull);
      expect(CustomTags.getById(2), isNull);
    });
  });
}
