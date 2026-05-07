import 'dart:collection';

import 'package:trovara/core/repository/interfaces/note_repository.dart';
import 'package:trovara/models/mood_tag.dart';
import 'package:trovara/models/note.dart';

class AnalyticsRepository {
  final INoteRepository noteRepository;

  AnalyticsRepository({required this.noteRepository});

  /// Aggregated analytics snapshot computed once from all notes
  AnalyticsSnapshot computeSnapshot() {
    final List<Note> notes = noteRepository.getAllNotes();
    return AnalyticsSnapshot(
      entriesPerDay: _computeEntriesPerDay(notes),
      averageSentimentPerDay: _computeAverageSentimentPerDay(notes),
      tagFrequencyByCategory: _computeTagFrequencyByCategory(notes),
      availableYears: _computeAvailableYears(notes),
    );
  }

  Map<DateTime, int> _computeEntriesPerDay(List<Note> notes) {
    final Map<DateTime, int> entriesByDate = <DateTime, int>{};

    for (final Note note in notes) {
      final DateTime dateOnly = _normalizeDate(note.createdAt);
      entriesByDate.update(dateOnly, (count) => count + 1, ifAbsent: () => 1);
    }

    return SplayTreeMap<DateTime, int>.from(entriesByDate);
  }

  Map<DateTime, double> _computeAverageSentimentPerDay(List<Note> notes) {
    final Map<DateTime, _RunningAverage> running = <DateTime, _RunningAverage>{};

    for (final Note note in notes) {
      final double? noteSentiment = _computeNoteSentiment(note);
      if (noteSentiment == null) continue;

      final DateTime dateOnly = _normalizeDate(note.createdAt);
      running.update(dateOnly, (acc) => acc.add(noteSentiment), ifAbsent: () => _RunningAverage(noteSentiment, 1));
    }

    final Map<DateTime, double> averages = <DateTime, double>{};
    running.forEach((date, acc) => averages[date] = acc.average);

    return SplayTreeMap<DateTime, double>.from(averages);
  }

  Map<String, Map<String, int>> _computeTagFrequencyByCategory(List<Note> notes) {
    final Map<String, Map<String, int>> result = <String, Map<String, int>>{
      'mood': <String, int>{},
      'activity': <String, int>{},
      'time': <String, int>{},
      'growth': <String, int>{},
      'custom': <String, int>{},
    };

    void countAll(Map<String, int> bucket, Iterable<String> tags) {
      for (final String tag in tags) {
        if (tag.isEmpty) continue;
        bucket.update(tag, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    for (final Note note in notes) {
      countAll(result['mood']!, note.moodTags);
      countAll(result['activity']!, note.activityTags);
      countAll(result['time']!, note.timeTags);
      countAll(result['growth']!, note.personalGrowthTags);

      for (final customTag in note.customTagObjects) {
        final String name = customTag.name.trim();
        if (name.isEmpty) continue;
        result['custom']!.update(name, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    return result;
  }

  List<int> _computeAvailableYears(List<Note> notes) {
    final Set<int> years = <int>{};
    for (final Note note in notes) {
      years.add(note.createdAt.year);
    }
    return years.toList()..sort();
  }

  List<(DateTime, double)> computeWeeklySentimentTrend(Map<DateTime, double> perDay, {int weeks = 12}) {
    if (weeks <= 0 || perDay.isEmpty) return const [];

    final DateTime latestDay = perDay.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    final DateTime endWeekStart = latestDay.subtract(Duration(days: latestDay.weekday - 1));
    final DateTime startWeekStart = endWeekStart.subtract(Duration(days: (weeks - 1) * 7));

    final List<(DateTime, double)> out = [];

    for (int w = 0; w < weeks; w++) {
      final DateTime weekStart = startWeekStart.add(Duration(days: w * 7));

      double sum = 0;
      int count = 0;
      for (int i = 0; i < 7; i++) {
        final DateTime day = _normalizeDate(weekStart).add(Duration(days: i));
        final double? s = perDay[day];
        if (s == null) continue;
        sum += s;
        count += 1;
      }

      if (count == 0) continue;
      out.add((_normalizeDate(weekStart), sum / count));
    }

    return out;
  }

  DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  double? _computeNoteSentiment(Note note) {
    if (note.moodTags.isEmpty) return null;

    double sum = 0;
    int count = 0;

    for (final String moodId in note.moodTags) {
      final double? s = _getMoodSentimentScore(moodId);
      if (s == null) continue;
      sum += s;
      count += 1;
    }

    if (count == 0) return null;
    return sum / count;
  }

  double? _getMoodSentimentScore(String moodId) {
    final MoodTag? tag = MoodTags.getById(moodId);
    if (tag == null) return null;

    return switch (moodId) {
      'grateful' => 0.9,
      'happy' => 0.8,
      'calm' => 0.5,
      'stressed' => -0.5,
      'sad' => -0.8,
      'angry' => -0.9,
      _ => 0.0, // Default neutral for any new mood tags
    };
  }
}

/// Immutable snapshot of analytics data computed from notes
class AnalyticsSnapshot {
  final Map<DateTime, int> entriesPerDay;
  final Map<DateTime, double> averageSentimentPerDay;
  final Map<String, Map<String, int>> tagFrequencyByCategory;
  final List<int> availableYears;

  const AnalyticsSnapshot({
    required this.entriesPerDay,
    required this.averageSentimentPerDay,
    required this.tagFrequencyByCategory,
    required this.availableYears,
  });

  bool get hasTagData => tagFrequencyByCategory.values.any((m) => m.isNotEmpty);
  bool get hasSentimentData => averageSentimentPerDay.isNotEmpty;
}

class _RunningAverage {
  final double sum;
  final int count;

  const _RunningAverage(this.sum, this.count);

  _RunningAverage add(double value) => _RunningAverage(sum + value, count + 1);

  double get average => sum / count;
}
