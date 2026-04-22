import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/repository/interfaces/custom_tag_repository.dart';
import 'package:trovara/core/services/custom_tag_service.dart';
import 'package:trovara/models/custom_tag.dart';

class _FakeCustomTagRepository implements ICustomTagRepository {
  final List<CustomTag> _tags = [];
  int _nextId = 1;

  @override
  Future<void> initialize() async {}

  @override
  Future<CustomTag> createCustomTag(String name, {String? color}) async {
    final existing = getCustomTagByName(name);
    if (existing != null) return existing;

    final created = CustomTag.create(name, color: color)..id = _nextId++;
    _tags.add(created);
    return created;
  }

  @override
  CustomTag? getCustomTagById(int id) => _tags.where((t) => t.id == id).firstOrNull;

  @override
  CustomTag? getCustomTagByName(String name) =>
      _tags.where((t) => t.name.toLowerCase() == name.trim().toLowerCase()).firstOrNull;

  @override
  List<CustomTag> getAllCustomTags() => List<CustomTag>.from(_tags);

  @override
  List<CustomTag> getMostUsedCustomTags() =>
      List<CustomTag>.from(_tags)..sort((a, b) => b.usageCount.compareTo(a.usageCount));

  @override
  List<CustomTag> getCustomTagsSortedByName() =>
      List<CustomTag>.from(_tags)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  List<CustomTag> getNewestCustomTags() =>
      List<CustomTag>.from(_tags)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  List<CustomTag> searchCustomTags(String query) =>
      _tags.where((t) => t.name.toLowerCase().contains(query.toLowerCase())).toList();

  @override
  List<CustomTag> getUnusedCustomTags() => _tags.where((t) => t.usageCount == 0).toList();

  @override
  List<CustomTag> getCustomTagsInUse() => _tags.where((t) => t.usageCount > 0).toList();

  @override
  Future<void> updateCustomTag(CustomTag customTag) async {
    final index = _tags.indexWhere((t) => t.id == customTag.id);
    if (index != -1) {
      _tags[index] = customTag;
    }
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
    'totalUsage': _tags.fold(0, (sum, tag) => sum + tag.usageCount),
  };

  @override
  bool customTagExists(String name) => getCustomTagByName(name) != null;

  @override
  bool customTagExistsById(int id) => getCustomTagById(id) != null;

  @override
  List<CustomTag> getCustomTagsByIds(List<int> ids) => _tags.where((t) => ids.contains(t.id)).toList();

  @override
  void addListener(Function() listener) {}

  @override
  void removeListener(Function() listener) {}
}

void main() {
  late _FakeCustomTagRepository repo;
  late CustomTagService service;

  setUp(() {
    CustomTags.clear();
    repo = _FakeCustomTagRepository();
    service = CustomTagService(customTagRepository: repo);
  });

  group('CustomTagService', () {
    test('initialize syncs static CustomTags collection', () async {
      await repo.createCustomTag('Focus');

      await service.initialize();

      expect(CustomTags.all.map((t) => t.name), contains('Focus'));
    });

    test('createOrGetCustomTag returns existing tag for same name', () async {
      final first = await service.createOrGetCustomTag('Work');
      final second = await service.createOrGetCustomTag(' work ');

      expect(second.id, equals(first.id));
      expect(service.getAllCustomTags(), hasLength(1));
    });

    test('getTagSuggestions with query sorts by usage count then name', () async {
      final b = await service.createOrGetCustomTag('Beta');
      b.usageCount = 5;
      final a = await service.createOrGetCustomTag('Alpha');
      a.usageCount = 5;
      final c = await service.createOrGetCustomTag('Calm');
      c.usageCount = 1;
      await repo.updateCustomTag(a);
      await repo.updateCustomTag(b);
      await repo.updateCustomTag(c);

      final suggestions = service.getTagSuggestions('a');

      expect(suggestions.take(3).map((t) => t.name).toList(), equals(['Alpha', 'Beta', 'Calm']));
    });

    test('getTagSuggestions with empty query returns most-used limited list', () async {
      for (var i = 0; i < 12; i++) {
        final tag = await service.createOrGetCustomTag('Tag $i');
        tag.usageCount = i;
        await repo.updateCustomTag(tag);
      }

      final suggestions = service.getTagSuggestions('', limit: 10);

      expect(suggestions, hasLength(10));
      expect(suggestions.first.usageCount, greaterThanOrEqualTo(suggestions.last.usageCount));
    });

    test('cleanupUnusedTags returns removed count and deletes unused tags', () async {
      final used = await service.createOrGetCustomTag('Used');
      used.usageCount = 1;
      await repo.updateCustomTag(used);
      await service.createOrGetCustomTag('Unused');
      await service.createOrGetCustomTag('Unused too');

      final removed = await service.cleanupUnusedTags();

      expect(removed, equals(2));
      expect(service.getAllCustomTags().map((t) => t.name), equals(['Used']));
    });
  });
}
