import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/models/folder.dart';

void main() {
  group('Folder model', () {
    test('decrementNoteCount never goes below zero', () {
      final folder = Folder(folderId: 'f1', name: 'Folder', noteCount: 0);
      folder.decrementNoteCount();
      expect(folder.noteCount, 0);
    });

    test('increment/decrement update note count correctly', () {
      final folder = Folder(folderId: 'f1', name: 'Folder', noteCount: 1);
      folder.incrementNoteCount();
      folder.decrementNoteCount();
      expect(folder.noteCount, 1);
    });

    test('equality is based on folderId', () {
      final a = Folder(folderId: 'same', name: 'A');
      final b = Folder(folderId: 'same', name: 'B');
      final c = Folder(folderId: 'other', name: 'A');
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('toJson/fromJson roundtrip preserves fields', () {
      final created = DateTime(2026, 1, 1);
      final updated = DateTime(2026, 1, 2);
      final folder = Folder(
        id: 7,
        folderId: 'work',
        name: 'Work',
        description: 'desc',
        color: '#ff0000',
        createdAt: created,
        updatedAt: updated,
        isDefault: true,
        noteCount: 5,
      );

      final jsonMap = jsonDecode(jsonEncode(folder.toJson())) as Map<String, dynamic>;
      final parsed = Folder.fromJson(jsonMap);

      expect(parsed.id, 7);
      expect(parsed.folderId, 'work');
      expect(parsed.name, 'Work');
      expect(parsed.description, 'desc');
      expect(parsed.color, '#ff0000');
      expect(parsed.createdAt, created);
      expect(parsed.updatedAt, updated);
      expect(parsed.isDefault, isTrue);
      expect(parsed.noteCount, 5);
    });
  });
}
