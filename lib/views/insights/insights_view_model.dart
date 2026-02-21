import 'package:notemyminds/core/base/base_view_model.dart';
import 'package:notemyminds/core/di/service_locator.dart';
import 'package:notemyminds/core/repository/analytics_repository.dart';

class InsightsViewModel extends BaseViewModel {
  late final AnalyticsRepository _analyticsRepository;

  List<List<int>> _weeksGrid = [];
  bool _isLoading = true;
  late DateTime _startDate;
  int _numWeeks = 20;
  late int _selectedYear;

  List<List<int>> get weeksGrid => _weeksGrid;
  bool get isLoading => _isLoading;
  DateTime get startDate => _startDate;
  int get numWeeks => _numWeeks;
  DateTime get endDate => _startDate.add(Duration(days: (_numWeeks * 7) - 1));
  int get selectedYear => _selectedYear;

  /// Distinct years available based on all notes' createdAt
  List<int> get availableYears {
    final notes = ServiceLocator().noteRepository.getAllNotes();
    final years = <int>{};
    for (final n in notes) {
      years.add(n.createdAt.year);
    }
    final sorted = years.toList()..sort();
    return sorted;
  }

  InsightsViewModel() {
    _analyticsRepository = AnalyticsRepository(noteRepository: ServiceLocator().noteRepository);
    Future.microtask(_initialize);
  }

  Future<void> _initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      final Map<DateTime, int> perDay = _analyticsRepository.getEntriesPerDay();

      // Range: from Jan 1st of current year (aligned to week start) until current week
      final DateTime today = DateTime.now();
      final int weekday = today.weekday; // 1=Mon..7=Sun
      final DateTime startOfThisWeek = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: weekday - 1));

      final DateTime jan1 = DateTime(today.year, 1, 1);
      final DateTime startOfJan1Week = jan1.subtract(Duration(days: jan1.weekday - 1));

      final int daysSpan = startOfThisWeek.difference(startOfJan1Week).inDays;
      _numWeeks = (daysSpan ~/ 7) + 1; // include current week
      _startDate = startOfJan1Week;
      _selectedYear = today.year;

      _weeksGrid = _buildWeeksGrid(perDay, startDate: _startDate, numWeeks: _numWeeks);

      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setYear(int year) async {
    try {
      _isLoading = true;
      notifyListeners();

      final Map<DateTime, int> perDay = _analyticsRepository.getEntriesPerDay();

      final DateTime jan1 = DateTime(year, 1, 1);
      final DateTime startOfJan1Week = jan1.subtract(Duration(days: jan1.weekday - 1));

      final DateTime now = DateTime.now();
      late final DateTime endWeekStart;
      if (year == now.year) {
        final int weekday = now.weekday;
        endWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
      } else {
        final DateTime dec31 = DateTime(year, 12, 31);
        endWeekStart = dec31.subtract(Duration(days: dec31.weekday - 1));
      }

      final int daysSpan = endWeekStart.difference(startOfJan1Week).inDays;
      _numWeeks = (daysSpan ~/ 7) + 1;
      _startDate = startOfJan1Week;
      _selectedYear = year;

      _weeksGrid = _buildWeeksGrid(perDay, startDate: _startDate, numWeeks: _numWeeks);

      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<List<int>> _buildWeeksGrid(Map<DateTime, int> perDay, {required DateTime startDate, required int numWeeks}) {
    if (perDay.isEmpty) return [];

    final Map<DateTime, int> normalized = {};
    perDay.forEach((date, count) {
      final DateTime d = DateTime(date.year, date.month, date.day);
      normalized[d] = (normalized[d] ?? 0) + count;
    });

    final List<List<int>> weeks = [];
    for (int w = 0; w < numWeeks; w++) {
      final DateTime weekStart = startDate.add(Duration(days: w * 7));
      final List<int> days = List<int>.generate(7, (i) {
        final DateTime d = DateTime(weekStart.year, weekStart.month, weekStart.day).add(Duration(days: i));
        return normalized[d] ?? 0;
      });
      weeks.add(days);
    }
    return weeks;
  }
}
