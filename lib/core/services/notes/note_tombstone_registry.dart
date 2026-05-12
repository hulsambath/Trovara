import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Internal helper for [NoteService]. Do not import from outside `lib/core/services/notes/`.
///
/// Persistent registry of permanently-deleted note syncIds (tombstones).
/// Other devices use this list to skip re-importing notes that were
/// intentionally deleted on any device.
///
/// Backed by SharedPreferences with an in-memory cache so synchronous
/// `contains` checks during import loops don't need to await disk reads.
class NoteTombstoneRegistry {
  static const _kKey = 'permanentlyDeletedSyncIds';

  final Logger _logger;
  final Set<String> _cache = {};
  bool _loaded = false;

  NoteTombstoneRegistry({Logger? logger}) : _logger = logger ?? Logger();

  /// Populate the cache from SharedPreferences. Idempotent.
  ///
  /// Awaited at app startup so the cache is ready for synchronous
  /// `contains` checks during the first import.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<String>();
        _cache.addAll(list);
      }
    } catch (e) {
      _logger.w('Failed to load tombstones from disk: $e');
    }
  }

  /// True if [syncId] has been permanently deleted on any device.
  bool contains(String syncId) => _cache.contains(syncId);

  /// All tombstoned syncIds. Used by export to inform other devices.
  List<String> asList() => _cache.toList();

  /// Register [syncId] as permanently deleted. Awaits persistence so the
  /// tombstone is durable before returning.
  Future<void> add(String syncId) async {
    _cache.add(syncId);
    await _persist();
  }

  /// Merge [newIds] into the registry and persist to disk.
  Future<void> addAll(Iterable<String> newIds) async {
    _cache.addAll(newIds);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_cache.toList());
      await prefs.setString(_kKey, encoded);
    } catch (e) {
      _logger.w('Failed to persist tombstones: $e');
    }
  }
}
