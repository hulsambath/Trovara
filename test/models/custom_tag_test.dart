import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/models/custom_tag.dart';

void main() {
  setUp(() {
    CustomTags.clear();
  });

  group('CustomTag', () {
    test('create trims name and applies default color', () {
      final tag = CustomTag.create('  Focus  ');

      expect(tag.name, equals('Focus'));
      expect(tag.color, equals('#2196F3'));
    });

    test('displayColor falls back to default on invalid color', () {
      final tag = CustomTag(name: 'x', color: 'not-a-color');

      expect(tag.displayColor.value, equals(const Color(0xFF2196F3).value));
    });

    test('incrementUsage and decrementUsage update usageCount safely', () {
      final tag = CustomTag(name: 'habit');

      tag.incrementUsage();
      tag.incrementUsage();
      tag.decrementUsage();
      tag.decrementUsage();
      tag.decrementUsage();

      expect(tag.usageCount, equals(0));
    });

    test('toJson and fromJson preserve fields', () {
      final original = CustomTag(name: 'Work', color: '#FFFFFF', usageCount: 3)..id = 9;
      final json = original.toJson();
      final restored = CustomTag.fromJson(json);

      expect(restored.id, equals(9));
      expect(restored.name, equals('Work'));
      expect(restored.color, equals('#FFFFFF'));
      expect(restored.usageCount, equals(3));
    });

    test('equality is based on id', () {
      final a = CustomTag(name: 'A')..id = 1;
      final b = CustomTag(name: 'B')..id = 1;
      final c = CustomTag(name: 'C')..id = 2;

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('CustomTags static collection', () {
    test('updateCollection replaces the backing list', () {
      final one = CustomTag(name: 'One')..id = 1;
      final two = CustomTag(name: 'Two')..id = 2;
      CustomTags.updateCollection([one]);
      CustomTags.updateCollection([two]);

      expect(CustomTags.all, hasLength(1));
      expect(CustomTags.all.first.id, equals(2));
    });

    test('search is case-insensitive', () {
      CustomTags.updateCollection([CustomTag(name: 'Mindfulness')..id = 1]);

      final results = CustomTags.search('mind');

      expect(results, hasLength(1));
      expect(results.first.name, equals('Mindfulness'));
    });

    test('statistics reports total, inUse, unused, and totalUsage', () {
      final used = CustomTag(name: 'Used', usageCount: 2)..id = 1;
      final unused = CustomTag(name: 'Unused', usageCount: 0)..id = 2;
      CustomTags.updateCollection([used, unused]);

      final stats = CustomTags.statistics;

      expect(stats['total'], equals(2));
      expect(stats['inUse'], equals(1));
      expect(stats['unused'], equals(1));
      expect(stats['totalUsage'], equals(2));
    });
  });
}
