import 'package:flutter/material.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/auth/google_drive_service.dart';
import 'package:trovara/core/services/notes/custom_tag_service.dart';
import 'package:trovara/core/services/notes/note_service.dart';
import 'package:trovara/core/services/notes/text_parser_service.dart';
import 'package:trovara/models/custom_tag.dart';
import 'package:trovara/models/note.dart';

enum SearchSortOrder { newestFirst, oldestFirst, alphabetical, recentlyUpdated }

/// ViewModel for the full-screen Search + Tag Filter screen.
///
/// Filtering rules:
/// - Text: OR between title and plain-text content.
/// - Tags: OR within each category, AND across categories.
///   (A note must match AT LEAST ONE selected tag in every active category.)
/// - Favorites toggle: narrows to favourited notes only.
class SearchViewModel extends BaseViewModel {
  SearchViewModel({
    NoteService? noteService,
    GoogleDriveService? driveService,
    CustomTagService? customTagService,
    @visibleForTesting String? Function()? currentUserIdForTest,
  }) : _noteService = noteService ?? ServiceLocator().noteService,
       _driveService = driveService ?? ServiceLocator().googleDriveService,
       _customTagService = customTagService ?? ServiceLocator().customTagService,
       _currentUserIdForTest = currentUserIdForTest {
    _noteService.addListener(_onNotesOrTagsChanged);
    _customTagService.addListener(_onNotesOrTagsChanged);
  }

  final NoteService _noteService;
  final GoogleDriveService _driveService;
  final CustomTagService _customTagService;
  final String? Function()? _currentUserIdForTest;

  /// Cached filtered + sorted list; rebuilt when [ _filteredNotesDirty] or backing data changes.
  List<Note> _cachedFilteredNotes = const [];
  bool _filteredNotesDirty = true;

  // ─── Query ──────────────────────────────────────────────────────────────────

  String _query = '';
  String get query => _query;

  // ─── Tag filter state ────────────────────────────────────────────────────────

  final Set<String> _selectedMoodIds = {};
  final Set<String> _selectedActivityIds = {};
  final Set<String> _selectedTimeIds = {};
  final Set<String> _selectedGrowthIds = {};
  final Set<int> _selectedCustomTagIds = {};

  Set<String> get selectedMoodIds => Set.unmodifiable(_selectedMoodIds);
  Set<String> get selectedActivityIds => Set.unmodifiable(_selectedActivityIds);
  Set<String> get selectedTimeIds => Set.unmodifiable(_selectedTimeIds);
  Set<String> get selectedGrowthIds => Set.unmodifiable(_selectedGrowthIds);
  Set<int> get selectedCustomTagIds => Set.unmodifiable(_selectedCustomTagIds);

  // ─── Quick filters ───────────────────────────────────────────────────────────

  bool _showFavoritesOnly = false;
  bool get showFavoritesOnly => _showFavoritesOnly;

  // ─── Sort order ──────────────────────────────────────────────────────────────

  SearchSortOrder _sortOrder = SearchSortOrder.newestFirst;
  SearchSortOrder get sortOrder => _sortOrder;

  // ─── Filter panel visibility ─────────────────────────────────────────────────

  bool _filtersExpanded = false;
  bool get filtersExpanded => _filtersExpanded;

  // ─── Data ────────────────────────────────────────────────────────────────────

  List<CustomTag> get availableCustomTags => _customTagService.getAllCustomTags();

  List<Note> get filteredNotes {
    _rebuildFilteredNotesIfDirty();
    return _cachedFilteredNotes;
  }

  int get resultCount {
    _rebuildFilteredNotesIfDirty();
    return _cachedFilteredNotes.length;
  }

  bool get hasActiveFilters =>
      _query.isNotEmpty ||
      _selectedMoodIds.isNotEmpty ||
      _selectedActivityIds.isNotEmpty ||
      _selectedTimeIds.isNotEmpty ||
      _selectedGrowthIds.isNotEmpty ||
      _selectedCustomTagIds.isNotEmpty ||
      _showFavoritesOnly;

  int get activeTagFilterCount =>
      _selectedMoodIds.length +
      _selectedActivityIds.length +
      _selectedTimeIds.length +
      _selectedGrowthIds.length +
      _selectedCustomTagIds.length;

  // ─── Mutation helpers ────────────────────────────────────────────────────────

  void setQuery(String value) {
    _query = value;
    _markFilteredNotesDirty();
    notifyListeners();
  }

  void clearQuery() {
    _query = '';
    _markFilteredNotesDirty();
    notifyListeners();
  }

  void setSortOrder(SearchSortOrder order) {
    _sortOrder = order;
    _markFilteredNotesDirty();
    notifyListeners();
  }

  void toggleFiltersExpanded() {
    _filtersExpanded = !_filtersExpanded;
    notifyListeners();
  }

  void toggleFavoritesOnly() {
    _showFavoritesOnly = !_showFavoritesOnly;
    _markFilteredNotesDirty();
    notifyListeners();
  }

  void toggleMoodTag(String id) => _toggle(_selectedMoodIds, id);
  void toggleActivityTag(String id) => _toggle(_selectedActivityIds, id);
  void toggleTimeTag(String id) => _toggle(_selectedTimeIds, id);
  void toggleGrowthTag(String id) => _toggle(_selectedGrowthIds, id);
  void toggleCustomTag(int id) => _toggleInt(_selectedCustomTagIds, id);

  void clearAllFilters() {
    _query = '';
    _selectedMoodIds.clear();
    _selectedActivityIds.clear();
    _selectedTimeIds.clear();
    _selectedGrowthIds.clear();
    _selectedCustomTagIds.clear();
    _showFavoritesOnly = false;
    _markFilteredNotesDirty();
    notifyListeners();
  }

  @override
  void dispose() {
    _noteService.removeListener(_onNotesOrTagsChanged);
    _customTagService.removeListener(_onNotesOrTagsChanged);
    super.dispose();
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  void _onNotesOrTagsChanged() {
    _markFilteredNotesDirty();
    notifyListeners();
  }

  void _markFilteredNotesDirty() {
    _filteredNotesDirty = true;
  }

  void _rebuildFilteredNotesIfDirty() {
    if (!_filteredNotesDirty) return;
    _cachedFilteredNotes = List<Note>.unmodifiable(_computeFilteredNotes());
    _filteredNotesDirty = false;
  }

  void _toggle(Set<String> set, String id) {
    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }
    _markFilteredNotesDirty();
    notifyListeners();
  }

  void _toggleInt(Set<int> set, int id) {
    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }
    _markFilteredNotesDirty();
    notifyListeners();
  }

  String? get _currentUserId {
    final override = _currentUserIdForTest;
    if (override != null) return override();
    return _driveService.currentUser?.id;
  }

  List<Note> _sourceNotes() {
    final userId = _currentUserId;
    return userId == null ? _noteService.notes : _noteService.notesForUser(userId);
  }

  List<Note> _computeFilteredNotes() {
    var notes = List<Note>.from(_sourceNotes());

    // ── Text filter ─────────────────────────────────────────────────────────
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      notes = notes.where((n) {
        if (n.title.toLowerCase().contains(q)) return true;
        // Parse Quill JSON to plain text for content search.
        final plainText = TextParserService.parseQuillContent(n.contentJson).toLowerCase();
        return plainText.contains(q);
      }).toList();
    }

    // ── Tag filters (OR within category, AND across categories) ─────────────
    if (_selectedMoodIds.isNotEmpty) {
      notes = notes.where((n) => n.moodTags.any(_selectedMoodIds.contains)).toList();
    }
    if (_selectedActivityIds.isNotEmpty) {
      notes = notes.where((n) => n.activityTags.any(_selectedActivityIds.contains)).toList();
    }
    if (_selectedTimeIds.isNotEmpty) {
      notes = notes.where((n) => n.timeTags.any(_selectedTimeIds.contains)).toList();
    }
    if (_selectedGrowthIds.isNotEmpty) {
      notes = notes.where((n) => n.personalGrowthTags.any(_selectedGrowthIds.contains)).toList();
    }
    if (_selectedCustomTagIds.isNotEmpty) {
      notes = notes.where((n) => n.customTagIds.any(_selectedCustomTagIds.contains)).toList();
    }

    // ── Favourites ───────────────────────────────────────────────────────────
    if (_showFavoritesOnly) {
      notes = notes.where((n) => n.isFavorite).toList();
    }

    // ── Sort ─────────────────────────────────────────────────────────────────
    switch (_sortOrder) {
      case SearchSortOrder.newestFirst:
        notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SearchSortOrder.oldestFirst:
        notes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SearchSortOrder.alphabetical:
        notes.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SearchSortOrder.recentlyUpdated:
        notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }

    return notes;
  }

  /// Build a single-line preview snippet for a search result card.
  ///
  /// When the query is empty, returns the first 120 characters of plain text.
  /// When the query matches, centres a 100-character window around the first
  /// match so the highlighted text is visible. Returns an empty string for
  /// notes with no plain-text content.
  String previewFor(Note note) {
    final full = TextParserService.parseQuillContent(note.contentJson);
    final q = _query.trim();

    if (q.isEmpty) return _truncate(full, 120);

    final idx = full.toLowerCase().indexOf(q.toLowerCase());
    if (idx == -1) return _truncate(full, 120);

    const window = 100;
    final start = (idx - window ~/ 2).clamp(0, full.length).toInt();
    final end = (start + window).clamp(0, full.length).toInt();
    final prefix = start > 0 ? '…' : '';
    final suffix = end < full.length ? '…' : '';
    return '$prefix${full.substring(start, end)}$suffix';
  }

  String _truncate(String text, int max) => text.length <= max ? text : '${text.substring(0, max)}…';

  /// Highlight occurrences of the search query within [text].
  ///
  /// Returns a list of [TextSpan]s suitable for use in a [RichText].
  List<TextSpan> buildHighlightSpans(String text, TextStyle defaultStyle, TextStyle highlightStyle) {
    if (_query.trim().isEmpty) return [TextSpan(text: text, style: defaultStyle)];

    final q = _query.trim().toLowerCase();
    final spans = <TextSpan>[];
    int cursor = 0;

    while (cursor < text.length) {
      final matchStart = text.toLowerCase().indexOf(q, cursor);
      if (matchStart == -1) {
        spans.add(TextSpan(text: text.substring(cursor), style: defaultStyle));
        break;
      }
      if (matchStart > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, matchStart), style: defaultStyle));
      }
      spans.add(TextSpan(text: text.substring(matchStart, matchStart + q.length), style: highlightStyle));
      cursor = matchStart + q.length;
    }

    return spans;
  }
}
