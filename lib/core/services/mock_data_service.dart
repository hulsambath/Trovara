import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:trovara/core/di/service_locator.dart';

/// Utility service for seeding local ObjectBox with mock notes data.
/// This is intended for development only.
class MockDataService {
  /// Seed notes distributed across the provided years.
  /// - Creates simple notes with timestamps in 2024 and 2025 by default.
  /// - If [skipIfNotEmpty] is true, seeding is skipped when there are existing notes.
  Future<void> seedNotesForYears({
    List<int> years = const [2024, 2025],
    int notesPerMonth = 6,
    bool skipIfNotEmpty = false,
    bool patchIfExists = true,
  }) async {
    final noteService = ServiceLocator().noteService;
    final noteRepo = ServiceLocator().noteRepository;

    // Skip if there is already data
    if (skipIfNotEmpty && ServiceLocator().noteRepository.totalNotes > 0) {
      if (kDebugMode) {
        print('[MockDataService] Skipped seeding: repository already has data');
      }
      return;
    }

    final Random random = Random(42);

    // Build a lookup of existing notes by exact createdAt timestamp
    final existing = <DateTime, int>{};
    for (final n in noteRepo.getAllNotes()) {
      existing[n.createdAt] = n.id;
    }

    for (final int year in years) {
      for (int month = 1; month <= 12; month++) {
        final int daysInMonth = _daysInMonth(year, month);
        for (int i = 0; i < notesPerMonth; i++) {
          final int day = 1 + random.nextInt(daysInMonth);

          // Random hour/minute to avoid identical timestamps
          final int hour = random.nextInt(23);
          final int minute = random.nextInt(59);

          final DateTime created = DateTime(year, month, day, hour, minute);

          final String title =
              'Mock Note $year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')} #${i + 1}';
          final String contentJson = '{"ops":[{"insert":"This is a mock note on $year-$month-$day.\n"}]}';

          final int? existingId = existing[created];
          if (existingId != null && patchIfExists) {
            final existingNote = noteRepo.getNoteById(existingId);
            if (existingNote != null) {
              existingNote
                ..title = title
                ..contentJson = contentJson
                ..updatedAt = created;
              await noteRepo.updateNote(existingNote);
            }
          } else {
            final newNote = await noteService.createNoteWithTimestamps(
              title: title,
              contentJson: contentJson,
              folderId: 'default',
              customTagIds: const [],
              createdAt: created,
              updatedAt: created,
              isFavorite: false,
              isArchived: false,
            );
            existing[created] = newNote.id;
          }
        }
      }
    }

    if (kDebugMode) {
      print('[MockDataService] Seeding complete for years: ${years.join(', ')}');
    }
  }

  int _daysInMonth(int year, int month) {
    if (month == 12) return 31;
    final DateTime firstNextMonth = DateTime(year, month + 1, 1);
    final DateTime lastThisMonth = firstNextMonth.subtract(const Duration(days: 1));
    return lastThisMonth.day;
  }
}
