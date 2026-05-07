import 'package:logger/logger.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/repository/analytics_repository.dart';

class InsightsViewModel extends BaseViewModel {
  final Logger _logger = Logger();
  late final AnalyticsRepository _analyticsRepository;

  List<List<int>> _weeksGrid = [];
  bool _isLoading = true;
  String? _errorMessage;
  late DateTime _startDate;
  int _numWeeks = 20;
  late int _selectedYear;

  AnalyticsSnapshot? _snapshot;
  List<(DateTime, double)> _weeklySentiment = const [];
  int _selectedTagCategoryIndex = 0;

  List<List<int>> get weeksGrid => _weeksGrid;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get startDate => _startDate;
  int get numWeeks => _numWeeks;
  DateTime get endDate => _startDate.add(Duration(days: (_numWeeks * 7) - 1));
  int get selectedYear => _selectedYear;

  Map<String, Map<String, int>> get tagFrequencyByCategory => _snapshot?.tagFrequencyByCategory ?? const {};
  List<(DateTime, double)> get weeklySentiment => _weeklySentiment;
  int get selectedTagCategoryIndex => _selectedTagCategoryIndex;
  bool get hasTagData => _snapshot?.hasTagData ?? false;
  bool get hasSentimentData => _snapshot?.hasSentimentData ?? false;
  List<int> get availableYears => _snapshot?.availableYears ?? [];

  List<String> get tagCategories => const ['mood', 'activity', 'time', 'growth', 'custom'];

  InsightsViewModel() {
    _analyticsRepository = AnalyticsRepository(noteRepository: ServiceLocator().noteRepository);
    Future.microtask(_initialize);
  }

  Future<void> _initialize() async {
    _setLoading(true);

    try {
      _snapshot = _analyticsRepository.computeSnapshot();
      _weeklySentiment = _analyticsRepository.computeWeeklySentimentTrend(_snapshot!.averageSentimentPerDay);

      final DateTime today = DateTime.now();
      _selectedYear = today.year;
      _updateYearGrid(_snapshot!.entriesPerDay, _selectedYear);

      _initializeSelectedTagCategory();
      _errorMessage = null;
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize insights', error: e, stackTrace: stackTrace);
      _errorMessage = 'Failed to load insights data';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    await _initialize();
  }

  Future<void> setYear(int year) async {
    if (_snapshot == null || _selectedYear == year) return;

    _setLoading(true);

    try {
      _selectedYear = year;
      _updateYearGrid(_snapshot!.entriesPerDay, year);
      _errorMessage = null;
    } catch (e, stackTrace) {
      _logger.e('Failed to set year to $year', error: e, stackTrace: stackTrace);
      _errorMessage = 'Failed to update year view';
    } finally {
      _setLoading(false);
    }
  }

  void _updateYearGrid(Map<DateTime, int> entriesPerDay, int year) {
    final DateTime jan1 = DateTime(year, 1, 1);
    final DateTime startOfJan1Week = jan1.subtract(Duration(days: jan1.weekday - 1));

    final DateTime now = DateTime.now();
    final DateTime endWeekStart = (year == now.year)
        ? DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1))
        : DateTime(year, 12, 31).subtract(Duration(days: DateTime(year, 12, 31).weekday - 1));

    final int daysSpan = endWeekStart.difference(startOfJan1Week).inDays;
    _numWeeks = (daysSpan ~/ 7) + 1;
    _startDate = startOfJan1Week;

    _weeksGrid = _buildWeeksGrid(entriesPerDay, startDate: _startDate, numWeeks: _numWeeks);
  }

  void _initializeSelectedTagCategory() {
    if (hasTagData) {
      final int firstWithData = tagCategories.indexWhere((c) => (tagFrequencyByCategory[c] ?? const {}).isNotEmpty);
      _selectedTagCategoryIndex = firstWithData != -1 ? firstWithData : 0;
    } else {
      _selectedTagCategoryIndex = 0;
    }
  }

  void selectTagCategory(int index) {
    if (index < 0 || index >= tagCategories.length) return;
    if (_selectedTagCategoryIndex == index) return;
    _selectedTagCategoryIndex = index;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
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
