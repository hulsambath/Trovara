import 'dart:collection';

import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/models/note.dart';

class AnalyticsRepository {
  final INoteRepository noteRepository;

  AnalyticsRepository({required this.noteRepository});

  Map<DateTime, int> getEntriesPerDay() {
    final List<Note> notes = noteRepository.getAllNotes();
    final Map<DateTime, int> entriesByDate = <DateTime, int>{};

    for (final Note note in notes) {
      final DateTime dateOnly = DateTime(note.createdAt.year, note.createdAt.month, note.createdAt.day);
      entriesByDate.update(dateOnly, (count) => count + 1, ifAbsent: () => 1);
    }

    return SplayTreeMap<DateTime, int>.from(entriesByDate);
  }

  Map<DateTime, double> getAverageSentimentPerDay() {
    final List<Note> notes = noteRepository.getAllNotes();
    final Map<DateTime, _RunningAverage> running = <DateTime, _RunningAverage>{};

    for (final Note note in notes) {
      final double? noteSentiment = _computeNoteSentiment(note);
      if (noteSentiment == null) continue;

      final DateTime dateOnly = DateTime(note.createdAt.year, note.createdAt.month, note.createdAt.day);
      running.update(dateOnly, (acc) => acc.add(noteSentiment), ifAbsent: () => _RunningAverage(noteSentiment, 1));
    }

    final Map<DateTime, double> averages = <DateTime, double>{};
    running.forEach((date, acc) => averages[date] = acc.average);

    return SplayTreeMap<DateTime, double>.from(averages);
  }

  Map<String, int> getTagFrequency() {
    final List<Note> notes = noteRepository.getAllNotes();
    final Map<String, int> frequency = <String, int>{};

    void countAll(Iterable<String> tags) {
      for (final String tag in tags) {
        if (tag.isEmpty) continue;
        frequency.update(tag, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    for (final Note note in notes) {
      countAll(note.moodTags);
      countAll(note.activityTags);
      countAll(note.timeTags);
      countAll(note.personalGrowthTags);
    }

    return SplayTreeMap<String, int>.from(frequency);
  }

  double? _computeNoteSentiment(Note note) {
    if (note.moodTags.isEmpty) return null;

    double sum = 0;
    int count = 0;

    for (final String moodId in note.moodTags) {
      final double? s = _moodSentimentScores[moodId];
      if (s == null) continue;
      sum += s;
      count += 1;
    }

    if (count == 0) return null;
    return sum / count;
  }
}

class _RunningAverage {
  final double sum;
  final int count;

  const _RunningAverage(this.sum, this.count);

  _RunningAverage add(double value) => _RunningAverage(sum + value, count + 1);

  double get average => sum / count;
}

const Map<String, double> _moodSentimentScores = <String, double>{
  // Positive
  'grateful': 0.9,
  'happy': 0.8,
  'calm': 0.5,
  // Negative
  'stressed': -0.5,
  'sad': -0.8,
  'angry': -0.9,
};
