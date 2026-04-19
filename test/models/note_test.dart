import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/models/note.dart';

void main() {
  group('Note model', () {
    test('content parser handles line breaks as spaces', () {
      final note = Note(
        title: 'n',
        contentJson: '{"ops":[{"insert":"hello"},{"insert":"\\n"},{"insert":"world"},{"insert":"\\n"}]}',
      );

      expect(note.content, 'hello world');
      expect(note.wordCount, 2);
      expect(note.characterCount, 'hello world'.length);
    });

    test('setMoodTags keeps only known mood IDs', () {
      final note = Note(title: 'n', contentJson: '{"ops":[{"insert":"x\\n"}]}');
      note.setMoodTags(['happy', 'invalid', 'sad']);
      expect(note.moodTags, ['happy', 'sad']);
    });

    test('setActivityTags keeps only known activity IDs', () {
      final note = Note(title: 'n', contentJson: '{"ops":[{"insert":"x\\n"}]}');
      note.setActivityTags(['work', 'invalid', 'home']);
      expect(note.activityTags, ['work', 'home']);
    });

    test('setTimeTags keeps only known time IDs', () {
      final note = Note(title: 'n', contentJson: '{"ops":[{"insert":"x\\n"}]}');
      note.setTimeTags(['morning', 'bad', 'night']);
      expect(note.timeTags, ['morning', 'night']);
    });

    test('setPersonalGrowthTags keeps only known growth IDs', () {
      final note = Note(title: 'n', contentJson: '{"ops":[{"insert":"x\\n"}]}');
      note.setPersonalGrowthTags(['learning', 'bad', 'goals']);
      expect(note.personalGrowthTags, ['learning', 'goals']);
    });

    test('toJson/fromJson roundtrip preserves key fields', () {
      final created = DateTime(2026, 1, 1, 9);
      final updated = DateTime(2026, 1, 2, 10);
      final deletedAt = DateTime(2026, 1, 3, 11);
      final note = Note(
        id: 42,
        syncId: 'sync-1',
        title: 'Title',
        contentJson: '{"ops":[{"insert":"Body\\n"}]}',
        createdAt: created,
        updatedAt: updated,
        isFavorite: true,
        isArchived: true,
        isDeleted: true,
        deletedAt: deletedAt,
        driveFileId: 'drive-123',
        userId: 'user-1',
        folderId: 'folder-1',
        customTagIds: [1, 2],
        moodTags: ['happy'],
        activityTags: ['work'],
        timeTags: ['morning'],
        personalGrowthTags: ['learning'],
        source: 'obsidian',
        internalLinks: ['Page A'],
      );

      final jsonMap = jsonDecode(jsonEncode(note.toJson())) as Map<String, dynamic>;
      final parsed = Note.fromJson(jsonMap);

      expect(parsed.id, 42);
      expect(parsed.syncId, 'sync-1');
      expect(parsed.title, 'Title');
      expect(parsed.folderId, 'folder-1');
      expect(parsed.isDeleted, true);
      expect(parsed.deletedAt, deletedAt);
      expect(parsed.source, 'obsidian');
      expect(parsed.internalLinks, ['Page A']);
      expect(parsed.customTagIds, [1, 2]);
      expect(parsed.moodTags, ['happy']);
      expect(parsed.activityTags, ['work']);
      expect(parsed.timeTags, ['morning']);
      expect(parsed.personalGrowthTags, ['learning']);
    });
  });
}
